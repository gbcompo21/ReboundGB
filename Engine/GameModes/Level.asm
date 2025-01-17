section "Level state memory",wram0

; Levels are divided into 16-block tall "subareas", which are further divided into 16-block wide "screens"
Engine_CurrentSubarea:          ; (shared with Engine_CurrentScreen)
Engine_CurrentScreen:       db  ; upper two bits = subarea, remaining bits = screen number
Engine_NumScreens:          db  ; number of screens per subarea (effectively "map width")
Engine_NumSubareas:         db  ; number of subareas
Engine_CollisionBank:       db  ; bank of current collision table
Engine_CollisionPointer:    dw  ; pointer to current collision table
Engine_ObjPointer:          dw  ; pointer to object layout
Engine_LastRow:             db  ; last row drawn
Engine_MapBank:             db  ; which ROM bank the current map is in
Engine_LevelID:             db  ; currently loaded level
Engine_LevelMusic:          db  ; music for current map

Engine_CameraX:             db
Engine_CameraY:             db
Engine_CameraTargetX:       db
Engine_CameraTargetY:       db
Engine_BounceCamTarget:     db
Engine_LockCamera:          db
Engine_CameraIsTracking:    db

section "Level background buffer",wram0,align[8]
Engine_BackgroundBuffer:    ds  16*16

section "Level memory",wramx[$d000]
Engine_LevelData:       ds  256*16

section "Level routines",rom0

; INPUT: A = Map ID
GM_Level:
    call    GetLevel
    push    hl
    ; initialize variables
    call    ClearScreen
    xor     a
    ld      [Engine_CurrentScreen],a
    ld      [Engine_LastRow],a
    ; initialize player object
    call    InitPlayer
    
    ; load palettes
    ldfar   hl,Pal_PlainsObjects
    ld      a,9
    call    LoadPal
    ld      a,10
    call    LoadPal
    ld      a,11
    call    LoadPal
    ld      a,12
    call    LoadPal
    ld      a,13
    call    LoadPal
    ld      a,14
    call    LoadPal
    ld      a,15
    call    LoadPal
    resbank

    pop     hl
    call    LoadMap
    
    ld      a,high(_VRAM)
    ld      [Engine_ParallaxDest],a
    
    ; initialize camera
    xor     a
    ld      [Engine_CameraX],a
    ld      [Engine_CameraTargetX],a
    ld      [Engine_LockCamera],a
    ld      [Engine_CameraIsTracking],a
    ld      [Engine_BounceCamTarget],a
    ld      a,256-SCRN_Y
    ld      [Engine_CameraY],a
    ld      a,1
    ld      [sys_EnableHDMA],a      ; enable parallax HDMA transfer
    
    ; initialize object lists
    call    ClearMonsters
    call    ClearParticles
    call    ClearRespawn
    
    ; spawn initial objects
    call    InitSpawnMonsters
    
    ; load particle GFX
    ld      a,1
    ldh     [rVBK],a
    ldfar   hl,ParticleTiles
    ld      de,$8040
    call    DecodeWLE
    ldfar   hl,HUDTiles
    ld      de,$8100
    call    DecodeWLE
    
    call    Level_InitHUD

    ; setup registers
    ld      a,LCDCF_ON | LCDCF_BG8000 | LCDCF_OBJ16 | LCDCF_OBJON | LCDCF_BGON | LCDCF_WINON | LCDCF_WIN9C00
    ldh     [rLCDC],a
    ld      a,IEF_VBLANK
    ldh     [rIE],a

    ; wait for VBlank to avoid VRAM access violations during palette copy
    ld      hl,rLY
    ld      a,SCRN_Y
:   cp      [hl]
    jr      nz,:-
    ei
    
LevelLoop::
    
.docamera
    ld      a,[Engine_LockCamera]
    and     a
    jp      nz,.nocamera
    
    ld      a,[Engine_CameraX]
    rra
    ld      d,a
    and     a
    ld      a,[Engine_CameraY]
    rra
    ld      e,a

    ld      a,[Player_XPos]
.checkleft
    sub     SCRN_X / 2
    jr      nc,.checkright
    ld      b,a
    ld      a,[Engine_CurrentScreen]
    and     $f
    and     a
    ld      a,b
    jr      nz,.setcamx
    xor     a
    jr      .setcamx
.checkright
    ld      a,[Engine_CurrentScreen]
    and     $f
    ld      b,a
    ld      a,[Engine_NumScreens]
    cp      b
    jr      nz,.skipright
    ld      a,[Player_XPos]
    sub     SCRN_X / 2
    cp      256 - SCRN_X
    jr      c,.setcamx
    ld      a,256 - SCRN_X
    jr      .setcamx
.skipright
    ld      a,[Player_XPos]
    sub     SCRN_X / 2
.setcamx
    ld      [Engine_CameraTargetX],a

    ld      a,[Player_YPos]
.checkup
    sub     SCRN_Y / 2
    jr      nc,.checkdown
    xor     a
    jr      .setcamy
.checkdown
    cp      256 - SCRN_Y
    jr      c,.setcamy
    ld      a,256 - SCRN_Y
.setcamy
    ld      [Engine_CameraTargetY],a
    
    ; TODO: X following logic
    ld      a,[Engine_CameraTargetX]
    ld      [Engine_CameraX],a

    ; Vertical camera following logic:
    ; Whenever the player bounces on a floor higher than their last bounce, the camera
    ; moves to follow the player vertically. This helps to reduce motion sickness on big
    ; screens (i.e. Game Boy Player, emulators)

    ; if player is falling and Y position > Y position at last bounce, camera Y follows player directly
    ld      a,[Player_LastBounceY]
    ld      b,a
;   ld      a,[Player_YVelocity]
;   add     2
;   add     b                       ; add Y velocity + 1 to prevent camera following on bounce at same height
;   ld      b,a
    ld      a,[Player_YPos]
    cp      b
    jr      c,.checkhigher
    ld      a,[Engine_CameraTargetY]
    ld      [Engine_CameraY],a
    jr      .doparallax
.checkhigher
    ; if player bounces on higher surface than previous surface, then move camera vertically to follow player    
    ld      a,[Player_LastBounceY]
    ld      b,a
    ld      a,[Player_YPos]
    cp      b
    jr      nc,.doparallax
    ld      a,[Engine_CameraIsTracking]
    and     a
    jr      z,.doparallax           ; if camera isn't tracking the player, skip

    ld      a,[Engine_CameraY]
    sub     2
    jr      nc,.noreset             ; reset camera if overflow occurs
    xor     a
    ld      [Engine_CameraY],a
    ld      [Engine_CameraIsTracking],a
    jr      .doparallax
.noreset
    ld      [Engine_CameraY],a
    ld      b,a
    ld      a,[Engine_BounceCamTarget]
    cp      b                       ; is camera Y < target camera Y?
    jr      c,.doparallax           ; if not, skip

    ld      [Engine_CameraY],a
    xor     a
    ld      [Engine_CameraIsTracking],a
    
.doparallax
    and     a   ; clear carry
    push    de
    ld      a,[Engine_CameraX]
    rra
    sub     d
    jr      z,.skipX
    cpl
    inc     a
.check7F
    cp      $7f
    jr      nz,.check81
    ld      a,$ff
    jr      .dohoriz
.check81
    cp      $81
    jr      nz,.dohoriz
    ld      a,$01
    
.dohoriz
    farcall Parallax_ShiftHorizontal

.skipX
    pop     de
    ld      a,[Engine_CameraY]
    srl     a
    sub     e
    jr      z,.skipY
    cpl
    inc     a
    ld      c,1
    farcall Parallax_ShiftVertical
.skipY

.nocamera
    
    call    SpawnMonsters
    call    BeginSprites
    ld      a,[Player_XPos]
    push    af
    call    ProcessPlayer
    call    DrawPlayer
    pop     bc
    ld      a,[Player_XPos]
    cp      b
    jr      z,.skipload
    jr      nc,.loadright
.loadleft
    ld      a,[Engine_CurrentScreen]
    and     $30
    ld      c,a
    ld      a,[Engine_CurrentScreen]
    and     $0f
    ld      e,a

    ld      a,[Engine_LastRow]
    ld      b,a
    ld      a,[Player_XPos]
    sub     SCRN_X / 2
    jr      nc,.skipdecscreen
    dec     e
.skipdecscreen
    and     $f0
    ld      d,a
    cp      b
    jr      z,.skipload
    ld      [Engine_LastRow],a
    
    ld      a,e
    or      c
    ld      e,a
    jr      .doload
.loadright
    ld      a,[Engine_CurrentScreen]
    and     $30
    ld      c,a
    ld      a,[Engine_CurrentScreen]
    and     $0f
    ld      e,a

    ld      a,[Engine_LastRow]
    ld      b,a
    ld      a,[Player_XPos]
    add     SCRN_X / 2
    jr      nc,.skipincscreen
    inc     e
.skipincscreen
    and     $f0
    ld      d,a
    cp      b
    jr      z,.skipload
    ld      [Engine_LastRow],a
    
    ld      a,e
    or      c
    ld      e,a
    ; fall through
.doload
    call    Level_LoadMapRow
    ; fall through
.skipload
    call    UpdateMonsters
    call    AnimateMonsters
    call    UpdateParticles
    call    RenderMonsters
    call    RenderParticles
    call    EndSprites
    call    Level_UpdateHUD

    ; pause game if Start is pressed
    ld      a,[sys_btnPress]
    bit     btnStart,a
    jr      z,:+   
    ld      a,1
    ld      [sys_PauseGame],a
    ; disable sound output to clear sustained notes
    xor     a
    ldh     [rNR52],a
    ; re-enable sound output
    set     7,a
    ldh     [rNR52],a
    ld      a,%11111111
    ldh     [rNR51],a
    ld      a,%01110111
    ldh     [rNR50],a
    PlaySFX pause
    call    Level_PauseLoop
:   halt
    jp      LevelLoop
    
Level_InitHUD:
    xor     a
    ldh     [rVBK],a
    ld      de,_SCRN1
    ld      a,$10
    ld      [de],a
    inc     e
    ld      a,$12
    ld      [de],a
    inc     e
    ld      a,$1d
    ld      [de],a
    inc     e
    ld      a,$1d
    ld      [de],a
    inc     e
    ld      a,$1d
    ld      [de],a
    inc     e
    ld      a,$1d
    ld      [de],a
    inc     e
    ld      a,$1d
    ld      [de],a
    ld      de,_SCRN1+32
    ld      a,$11
    ld      [de],a
    inc     e
    ld      a,$12
    ld      [de],a
    inc     e
    ld      a,$1d
    ld      [de],a
    inc     e
    ld      a,$1d
    ld      [de],a
    inc     e
    ld      a,$1d
    ld      [de],a
    inc     e
    ld      a,$1d
    ld      [de],a
    inc     e
    ld      a,$1d
    ld      [de],a
    ld      a,1
    ldh     [rVBK],a
    ld      a,$8f
    ld      [_SCRN1],a
    ld      [_SCRN1+1],a
    ld      [_SCRN1+2],a
    ld      [_SCRN1+3],a
    ld      [_SCRN1+4],a
    ld      [_SCRN1+5],a
    ld      [_SCRN1+6],a
    ld      [_SCRN1+32],a
    ld      [_SCRN1+33],a
    ld      [_SCRN1+34],a
    ld      [_SCRN1+35],a
    ld      [_SCRN1+36],a
    ld      [_SCRN1+37],a
    ld      [_SCRN1+38],a
    ld      a,SCRN_Y-16
    ldh     [rWY],a
    ld      a,SCRN_X-48
    ldh     [rWX],a
    ret
    
Level_UpdateHUD:
    xor     a
    ldh     [rVBK],a
    ld      a,[Player_LifeCount]
    call    Hex2Dec8
    ld      hl,sys_StringBuffer
    ld      de,_SCRN1+4
    ld      a,[hl+]
    ld      c,a
    ld      b,a
    and     a
    jr      z,:+
    WaitForVRAM
    ld      a,c
    add     $13
    ld      [de],a
:   inc     e
    ld      a,[hl+]
    ld      c,a
    and     a
    jr      z,:++
:   WaitForVRAM
    ld      a,c
    add     $13
    ld      [de],a
    jr      :++
:   cp      b
    jr      nz,:--
:   inc     e
    WaitForVRAM
    ld      a,[hl]
    add     $13
    ld      [de],a
    
    ld      hl,Player_CoinCount
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    call    Hex2Dec16
    ld      hl,sys_StringBuffer
    ld      de,_SCRN1+34
    ld      b,5
:   WaitForVRAM
    ld      a,[hl+]
    add     $13
    ld      [de],a
    inc     e
    dec     b
    jr      nz,:-
    ret
    
Level_PauseLoop:
    halt
    ld      a,[sys_btnPress]
    if DebugMode
        bit     btnSelect,a
        jr      z,:+
        xor     a
        ldh     [rLCDC],a
        jp      GM_DebugMenu
    endc
:   bit     btnStart,a
    jr      z,Level_PauseLoop
    xor     a
    ld      [sys_PauseGame],a
    ret
    
Level_TransitionUp:
    ld      a,[Engine_CurrentSubarea]
    and     $30
    jr      z,:+
    ld      a,[Player_MovementFlags]
    bit     2,a
    ret     nz
    
    ld      a,[Engine_CurrentSubarea]
    sub     $10
    and     $3f
    ld      [Engine_CurrentSubarea],a

    PlaySFX transitionup
    
    ld      b,16
.loop
    push    bc
    ld      a,[Engine_CameraX]
    and     $f0
    ld      c,a
    ld      d,b
    dec     d
    call    Level_LoadMapColumn
    ld      a,[Player_YPos]
    ld      [Player_LastBounceY],a
    ld      a,[Engine_CameraY]
    sub     SCRN_Y/16
    ld      [Engine_CameraY],a
    call    TransitionUpdateMonsters
    call    BeginSprites
    call    DrawPlayer
    call    RenderMonsters
    call    RenderParticles
    call    EndSprites
    pop     bc

    halt
    dec     b
    jr      nz,.loop
    call    ClearMonsters
    call    ClearParticles
    jp      InitSpawnMonsters
:
    xor     a
    ld      [Player_YVelocity],a
    ld      [Player_YVelocityS],a
    ld      [Player_YSubpixel],a
    ld      a,8
    ld      [Player_YPos],a
    ld		[Player_LastBounceY],a
    ld		a,[Engine_CameraY]
    ld		[Engine_CameraTargetY],a
    ret
    
Level_TransitionDown:
    ld      a,[Engine_CurrentSubarea]
    cp      $30
    jp      nc,KillPlayer
    ld      a,[Player_MovementFlags]
    bit     2,a
    ret     nz
    
    ld      a,[Engine_CurrentSubarea]
    add     $10
    and     $3f
    ld      [Engine_CurrentSubarea],a
    PlaySFX transitiondown
    
    ld      b,16
.loop
    push    bc
    ld      a,[Engine_CameraX]
    and     $f0
    ld      c,a
    ld      a,b
    xor     $f
    inc     a
    and     $f
    ld      d,a
    call    Level_LoadMapColumn
    ld      a,[Player_YPos]
    ld      [Player_LastBounceY],a
    ld      a,[Engine_CameraY]
    add     SCRN_Y/16
    ld      [Engine_CameraY],a
    call    TransitionUpdateMonsters
    call    BeginSprites
    call    DrawPlayer
    call    RenderMonsters
    call    RenderParticles
    call    EndSprites
    pop     bc

    halt
    dec     b
    jr      nz,.loop
    ld		a,[Player_YPos]
    ld		[Player_LastBounceY],a
    ld		a,[Engine_CameraY]
    ld		[Engine_CameraTargetY],a
    call  ClearMonsters
    call  ClearParticles
    jp    InitSpawnMonsters  

; ================================================================

; Input:     A = Level ID
; Output:   HL = Pointer to level header, ROMB0 = ROM bank containing level header
; Destroys: BC

GetLevel:
    cp      NUM_LEVELS  ; is level ID valid?
    jr      c,:+        ; if yes, skip
    xor     a           ; load default level (MapID_Plains1)
:   ld      [Engine_LevelID],a
    ld      c,a
    ld      b,0
    ld      hl,LevelPointers
    add     hl,bc   ; x1
    add     hl,bc   ; x2
    add     hl,bc   ; x3
    ld      a,[hl+]
    ld      b,a
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    jp      _Bankswitch
    
include "Data/LevelPointers.asm"

; ================================================================

; Input:    HL = Pointer to map header
LoadMap:
    ld      a,[sys_CurrentBank]
    ld      [Engine_MapBank],a
    ld      a,[hl+] ; get screen count
    and     $f      ; maximum of 16 screens allowed
    ld      [Engine_NumScreens],a
    ld      a,[hl+] ; get subarea count
    and     $3      ; maximum of 4 subareas allowed
    ld      [Engine_NumSubareas],a
    
    ; load player start X position
    ld      a,[hl]  ; we'll need this byte again so don't inc hl yet
    and     $f0     ; \ convert to
    add     8       ; / correct format
    ld      [Player_XPos],a
    ; load player start Y position
    ld      a,[hl+]
    and     $0f     ; \ convert to 
    swap    a       ; | correct 
    add     8       ; / format
    ld      [Player_YPos],a
    add     16
    ld      [Player_LastBounceY],a
    ; load player starting screen + subarea
    ld      a,[hl+]
    ld      [Engine_CurrentScreen],a ; no need to convert to different format here
    
    ; load music
    ld      a,[hl+]
    ld      [Engine_LevelMusic],a
    push    hl
    farcall DevSound_Init
    pop     hl
    resbank
    ldh     [sys_TempBank3],a

	; get tileset pointer
    ld		a,[hl+]
	ld		[Engine_TilesetBank],a
	ld		b,a
	ld		a,[hl+]
	ld		[Engine_TilesetPointer],a
	ld		a,[hl+]
	ld		[Engine_TilesetPointer+1],a
	
	; get collision pointer
	push	hl
	ld		hl,Engine_TilesetPointer
	ld		a,[hl+]
	ld		h,[hl]
	ld		l,a
    ld      a,[Engine_TilesetBank]
    ld      b,a
	call    _Bankswitch
	ld		a,[hl+]
	ld		[Engine_CollisionPointer],a
	ld		a,[hl+]
	ld		[Engine_CollisionPointer+1],a
    ; load level graphics
    ld      a,[hl+]
    ld      b,a
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    call    _Bankswitch
    ld      de,$8000
    call    DecodeWLE
    ; copy first 16 tiles to parallax buffer
    ld      hl,$8000
    ld      de,Engine_ParallaxBuffer
    ld      b,0
:   ld      a,[hl+]
    ld      [de],a
    inc     e
    dec     b
    jr      nz,:-
    ldh     a,[sys_TempBank3]
    ld      b,a
    call    _Bankswitch
    pop		hl
    
    ; load palette
    ld      a,[hl+]
    ld      b,a
    push    hl
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    call    _Bankswitch
    ld      b,8
    xor     a
:   push    af
    push    bc
    call    LoadPal
    pop     bc
    pop     af
    inc     a
    dec     b
    jr      nz,:-
    call    ConvertPals
    call    PalFadeInWhite
    pop     hl
    inc     hl
    inc     hl
    resbank
    
    ; load background
    ld      a,[hl+]
    ld      b,a
    call    _Bankswitch
    push    hl
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    ld      de,Engine_BackgroundBuffer
:   ld      a,[hl+]
    ld      [de],a
    inc     e
    jr      nz,:-
    pop     hl
    inc     hl
    inc     hl
    resbank
	
    ; load map into mem
    lb      bc,4,0
.loop
    push    hl
    push    bc
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    
    ld      a,c
    add     2
    ld      [rSVBK],a
    
    ld      de,Engine_LevelData
    call    DecodeWLE
    
    pop     bc
    pop     hl
    inc     hl
    inc     hl
    inc     c
    dec     b
    jr      nz,.loop
    
    ld      a,[hl+]
    ld      [Engine_ObjPointer],a
    ld      a,[hl]
    ld      [Engine_ObjPointer+1],a
    
    ld      a,[Engine_CurrentScreen]
    call    Level_LoadScreen
    
    ld      a,1
    ldh     [rSVBK],a
    ret
    
; ========

; INPUT: a = screen ID
Level_LoadScreen:
    ld      b,a
    and     $30
    swap    a
    add     2
    ldh     [rSVBK],a
    ld      hl,Engine_LevelData
    ld      a,b
    and     $0f
    add     h
    ld      h,a
    lb      bc,16,0
    ld      e,0
.loop
    push    bc
    push    de
    ld      a,[hl+]
    push    hl
    ld      b,a
    ; get Y coordinate
    ld      a,e
    and     $f
    swap    a
    ld      d,a
    ; get X coordinate
    ld      a,c
    and     $f
    or      d
    call    DrawMetatile
    
    pop     hl
    pop     de
    pop     bc
    inc     e
    dec     b
    jr      nz,.loop
    ld      b,16
    ld      e,0
    inc     c
    ld      a,c
    cp      16
    jr      nz,.loop
    ret
    
; ========

; INPUT: d = row to load
;        e = screen to load from
Level_LoadMapRow:
    ld      a,[Player_MovementFlags]
    bit     3,a
    ret     nz

    ld      hl,Engine_LevelData
    ldh     a,[rSVBK]
    and     7
    ldh     [sys_TempSVBK],a
    ; get subarea
    ld      a,e
    and     $f0
    swap    a
    ; set correct WRAM bank
    add     2
    ldh     [rSVBK],a
    
    ; get screen
    ld      a,e
    and     $f
    add     h
    ld      h,a
    ; get row
    ld      a,d
    and     $f0
    add     l
    ld      l,a
    
    ld      b,16
.loop
    push    bc
    ld      a,[hl]
    push    hl
    ld      b,a
    
    ld      a,l ; L = tile coordinates
    swap    a   ; DrawMetatile expects unswapped coordinates
    call    DrawMetatile
    pop     hl
    inc     l
    pop     bc
    dec     b
    jr      nz,.loop

    ret
    
; ========

; INPUT: c = camera X position
;        d = column to load
;        e = screen to load from
Level_LoadMapColumn:
    push    de
    ld      a,[Engine_CurrentScreen]
    and     $f
    sub     1   ; dec a doesn't set carry and we need to check for overflow
    jr      nc,:+
    xor     a
:   ld      h,high(Engine_LevelData)
    or      h
    ld      h,a
    ld      a,c
    add     d
    ld      l,a
    ldh     a,[rSVBK]
    and     7
    ldh     [sys_TempSVBK],a
    ; get subarea
    ld      a,[Engine_CurrentScreen]
    swap    a
    and     $f
    ; set correct WRAM bank
    add     2
    ldh     [rSVBK],a
    
    ld      b,16
.loop
    push    bc
    ld      a,[hl]
    push    hl
    ld      b,a
    
    ld      a,l ; L = tile coordinates
    swap    a   ; DrawMetatile expects unswapped coordinates
    call    DrawMetatile
    pop     hl
    ld      a,l
    add     16
    ld      l,a
    jr      nc,:+
	inc		h
:
    pop     bc
    dec     b
    jr      nz,.loop
    pop     de
    ret

; ================================================================
; Tileset data
; ================================================================

include "Data/Tilesets.asm"

; ================================================================
; Backgrounds
; ================================================================

include "Data/Backgrounds.asm"

