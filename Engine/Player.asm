; ==================
; Player RAM defines
; ==================

section "Player RAM",wram0
PlayerRAM:

Player_MovementFlags::      db  ; bit 0 = moving, bit 7 = dir (0 = left, 1 = right)
Player_XPos::               db  ; current X position
Player_XSubpixel::          db  ; current X subpixel
Player_YPos::               db  ; current Y position
Player_YSubpixel::          db  ; current Y subpixel
Player_XVelocity::          db  ; current X velocity
Player_XVelocityS::         db  ; current X fractional velocity
Player_YVelocity::          db  ; current Y velocity
Player_YVelocityS::         db  ; current Y fractional velocity
Player_LastBounceY::        db  ; last bounce Y position (absolute)
Player_AnimPointer::        dw  ; pointer to current animation sequence
Player_AnimTimer::          db  ; time until next animation frame is displayed (if -1, frame will be displayed indefinitely)
Player_CurrentFrame::       db  ; current animation frame being displayed

Player_CheckpointX::        db
Player_CheckpointY::        db
Player_CheckpointScreen::   db
Player_CoinCount::          dw

PlayerRAM_End:

Player_MaxSpeed             equ $140
Player_MaxSpeedWater        equ $e0
Player_Accel                equ 24
Player_Decel                equ 12
Player_Gravity              equ $25

Player_BounceHeight         equ -$340
Player_HighBounceHeight     equ -$480
Player_LowBounceHeight      equ -$1c0

Player_WallBounceHeight     equ -$280
Player_HighWallBounceHeight equ -$400
Player_LowWallBounceHeight  equ -$100

Player_TerminalVelocity     equ $600
Player_HitboxSize           equ 6

; Player_MovementFlags defines

bPlayerIsMoving             = 0
bPlayerIsUnderwater         = 1
bPlayerIsDead               = 2
bPlayerVictory              = 3
bPlayerUnused4              = 4
bPlayerUnused5              = 5
bPlayerUnused6              = 6
bPlayerDirection            = 7

; ========================
; Player animation defines
; ========================

F_Player_Idle               equ 0
F_Player_Idle_Blink1        equ 1
F_Player_Idle_Blink2        equ 2
F_Player_Idle_Blink3        equ 3
F_Player_Idle_Blink4        equ 4

F_Player_Left1              equ 8
F_Player_Left1_Blink1       equ 9
F_Player_Left1_Blink2       equ 10
F_Player_Left1_Blink3       equ 11
F_Player_Left1_Blink4       equ 12

F_Player_Left2              equ 16
F_Player_Left2_Blink1       equ 17
F_Player_Left2_Blink2       equ 18
F_Player_Left2_Blink3       equ 19
F_Player_Left2_Blink4       equ 20

F_Player_Right1             equ 24
F_Player_Right1_Blink1      equ 25
F_Player_Right1_Blink2      equ 26
F_Player_Right1_Blink3      equ 27
F_Player_Right1_Blink4      equ 28

F_Player_Right2             equ 32
F_Player_Right2_Blink1      equ 33
F_Player_Right2_Blink2      equ 34
F_Player_Right2_Blink3      equ 35
F_Player_Right2_Blink4      equ 36

F_Player_Win                equ 5
F_Player_Hurt1              equ 6
F_Player_Hurt2              equ 7
F_Player_Angry              equ 13
F_Player_Sad                equ 14
F_Player_Surprise           equ 15
F_Player_LookUp             equ 21
F_Player_LookDown           equ 22

; ===============
; Player routines
; ===============

section "Player routines",rom0

InitPlayer:
    ; init RAM
    ld      hl,PlayerRAM
    ld      b,PlayerRAM_End-PlayerRAM
    xor     a
    call    _FillRAMSmall
    ; initialize animation pointer
    ld      a,low(Anim_Player_Idle)
    ld      [Player_AnimPointer],a
    ld      a,high(Anim_Player_Idle)
    ld      [Player_AnimPointer+1],a
    ; initialize animation timer
    ld      a,-1
    ld      [Player_AnimTimer],a
    ; load player palette
    ldfar   hl,Pal_Player
    ld      a,8
    call    LoadPal
    ret

; ========

ProcessPlayer:
    ; Player Input
    ld      a,[sys_btnPress]
    bit     btnSelect,a
    call    nz,KillPlayer
    
    ld      a,[Player_MovementFlags]
    bit     bPlayerIsDead,a
    jr      z,.notdead
    
    ld      a,[Player_YVelocity]
    bit     7,a ; is player falling?
    jp      nz,.moveair2
    ld      a,[Player_YPos]
    and     $f0
    sub     16
    ld      b,a
    ld      a,[Engine_CameraY]
    and     $f0
    add     SCRN_Y
    cp      b
    call    z,Player_Respawn
    jp      .moveair2
.notdead
    bit     bPlayerVictory,a
    jr      z,.notvictory
    
    call    Player_AccelerateRight
    ld      a,[Player_XVelocity]
    ld      h,a
    ld      a,[Player_XVelocityS]
    ld      l,a
    ld      a,[Player_XPos]
    ld      d,a
    ld      a,[Player_XSubpixel]
    ld      e,a
    add     hl,de
    ld      a,h
    ld      [Player_XPos],a
    ld      a,l
    ld      [Player_XSubpixel],a
    ld      a,h
    cp      $80
    jp      nc,.moveair
    cp      32
    jp      c,.moveair
    
    ld      a,MUS_PLAINS_CLEAR
    farcall DS_Init
    ; TODO: Advance to next level
    ; Exit to debug menu for now
    ld      b,0
:   halt
    dec     b
    jr      nz,:-
    call	PalFadeOutWhite
    ; wait for fade to finish
:   halt
	ld		a,[sys_FadeState]
	bit		0,a
    jr      nz,:-
    xor     a
    ldh     [rLCDC],a
    jp      GM_DebugMenu
    
.notvictory
    lb      bc,0,1
    ld      a,[sys_btnHold]
    bit     btnLeft,a
    jr      nz,.accelLeft
    bit     btnRight,a
    jr      nz,.accelRight
    ; if left or right aren't being held...
    ld      a,[Player_MovementFlags]
    res     0,a
    ld      [Player_MovementFlags],a
    ld      d,a
    jp      .noaccel
.accelLeft
    call    Player_AccelerateLeft
    jr      .continue
.accelRight
    call    Player_AccelerateRight
    
.continue
    ld      a,c
    or      e
    ld      d,a
    
.noaccel
    ; check if we're underwater
    res     1,d
    ld      a,[Player_YPos]
    ld      l,a
    ld      a,[Player_XPos]
    ld      h,a
    call    GetTileCoordinates
    ld      e,a
    and     a               ; clear carry
    call    GetTileL        ; doesn't matter if we use GetTileL or GetTileR, the result is the same
    cp      COLLISION_WATER ; are we touching a water tile?
    jr      nz,.checkcoin   ; if not, skip
    ld      a,[Player_MovementFlags]
    bit     bPlayerIsUnderwater,a             ; are we already underwater?
    jr      nz,:+           ; if not, skip playing splash sound
    PlaySFX splash          ; play splash sound
    
    call    Player_Splash
:    
    set     1,d             ; set player's "is underwater" flag
    jp      .decel
    
.checkcoin
    cp      COLLISION_COIN  ; are we touching a coin?
    jr      nz,.checkgoal
    ; replace coin tile with "blank" tile
    ; TODO: Get tile from background
    push    de
    ld      a,[Player_YPos]
    ld      l,a
    ld      a,[Player_XPos]
    ld      h,a
    call    GetTileCoordinates
    ld      e,a
    
    ld      hl,Engine_LevelData
    ld      a,[Engine_CurrentScreen]
    and     $f
    add     h
    ld      h,a
    ld      a,[Engine_CurrentScreen]
    and     $30
    swap    a
    add     2
    ldh     [rSVBK],a
    ld      l,e
    xor     a
    ld      [hl],a
    ld      b,a
    ld      a,e
    swap    a
    call    DrawMetatile
    ; play sound effect
    PlaySFX coin
    ; increment coin count
    pop     de
    ld      a,[Player_CoinCount]
    add     1   ; inc a doesn't set carry
    ld      [Player_CoinCount],a
    jr      nc,.decel
    ld      a,[Player_CoinCount+1]
    add     1   ; inc a doesn't set carry
    ld      [Player_CoinCount+1],a
    jr      nc,.decel
    ld      a,$ff
    ld      [Player_CoinCount],a
    ld      [Player_CoinCount+1],a
    jr      .decel
    
.checkgoal
    cp      COLLISION_GOAL
    jr      nz,.decel
.dogoal
    ld      a,1
    ld      [Engine_LockCamera],a
    ld      a,[Player_MovementFlags]
    set     bPlayerVictory,a
    ld      [Player_MovementFlags],a
    jp      .moveair
    
.decel
    ld      a,d
    ld      [Player_MovementFlags],a
    bit     0,a
    jr      nz,.nodecel
    bit     7,a
    jr      z,.decelRight
.decelLeft
    ld      hl,Player_XVelocity
    ld      a,[hl+]
    ld      l,[hl]
    ld      h,a
    ld      bc,Player_Decel
    add     hl,bc
    bit     7,h
    jr      nz,:+    ; reset X speed to zero on overflow
    ld      hl,0
:   ld      a,h
    ld      [Player_XVelocity],a
    ld      a,l
    ld      [Player_XVelocityS],a
    jr      .nodecel
.decelRight
    ld      hl,Player_XVelocity
    ld      a,[hl+]
    ld      l,[hl]
    ld      h,a
    ; sub hl,r16 doesn't exist so...
    ld      bc,-Player_Decel
    add     hl,bc
    bit     7,h
    jr      z,:+    ; reset X speed to zero on overflow
    ld      hl,0
:   ld      a,h
    ld      [Player_XVelocity],a
    ld      a,l
    ld      [Player_XVelocity+1],a
    jr      .nodecel

    ; fall through
.nodecel
    ; Horizontal Movement
    ; Movement
    ld      a,[Player_XVelocity]
    ld      h,a
    ld      a,[Player_XVelocityS]
    ld      l,a
    ld      a,[Player_XPos]
    ld      d,a
    ld      a,[Player_XSubpixel]
    ld      e,a
    add     hl,de
    ld      a,h
    ld      [Player_XPos],a
    ld      a,l
    ld      [Player_XSubpixel],a
    ; Check Screen Crossing
    ld      a,[Player_XVelocity]
    bit     7,a
    jr      z,:+
    jr      c,.xMoveDone
    ; Left edge crossed, decrement current screen
    ld      a,[Engine_CurrentScreen]
    and     $30
    ld      b,a
    ld      a,[Engine_CurrentScreen]
    and     $f
    sub     1
    jr      c,.xMoveDone
    or      b
    ld      [Engine_CurrentScreen],a
    jr      .xMoveDone
:
    jr      nc,.xMoveDone
    ; Right edge crosses, increment current screen
    ld      a,[Engine_CurrentScreen]
    and     $30
    ld      b,a
    ld      a,[Engine_CurrentScreen]
    push    bc
    ld      b,a
    ld      a,[Engine_NumScreens]
    cp      b
    ld      a,b
    pop     bc
    jr      z,.xMoveDone
    inc     a
    or      b
    ld      [Engine_CurrentScreen],a
.xMoveDone:

    ; Horizontal Collision
    ld      a,[Player_XVelocity]
    bit     7,a
    jp      z,.rightCollision
    ; Check Left Collision
    ; Top Left
    ld      a,[Player_YPos]
    sub     Player_HitboxSize
    ld      l,a
    ld      a,[Player_XPos]
    sub     Player_HitboxSize
    push    af
    ld      h,a
    call    GetTileCoordinates
    ld      e,a
    pop     af
    call    GetTileL
    cp      COLLISION_SOLID
    jr      z,:+
    ; Bottom Left
    ld      a,[Player_YPos]
    add     Player_HitboxSize
    ld      l,a
    ld      a,[Player_XPos]
    sub     Player_HitboxSize
    push    af
    ld      h,a
    call    GetTileCoordinates
    ld      e,a
    pop     af
    call    GetTileL
    cp      COLLISION_SOLID
    jp      nz,.xCollideEnd
:
    ; Collision with left wall
    ; Negate velocity
    ld      a,[sys_btnHold]
    bit     btnB,a
    jr      nz,:+       ; don't bounce off walls if B is held
    ld      a,[Player_MovementFlags]
    bit     bPlayerIsUnderwater,a
    jr      nz,.waterL
.airL
    ld      a,high(Player_MaxSpeed)
    ld      [Player_XVelocity],a
    ld      a,low(Player_MaxSpeed)
    ld      [Player_XVelocityS],a
    jr      :+
.waterL
    ld      a,high(Player_MaxSpeedWater)
    ld      [Player_XVelocity],a
    ld      a,low(Player_MaxSpeedWater)
    ld      [Player_XVelocityS],a
:   ; Calculate penetration depth
    ld      a,[Player_XPos]
    ld      c,a
    sub     Player_HitboxSize
    and     $f
    ld      b,a
    ld      a,16
    sub     b
    ; Push player out of tile
    add     c
    ld      [Player_XPos],a
    ; Make player bounce vertically
    push    af
    ld      a,[sys_btnHold]
    bit     btnB,a
    jr      nz,:+       ; don't bounce off walls if B is held
    call    Player_WallBounce
:   pop     af
    ; Check Screen Crossing
    jp      nc,.xCollideEnd
    ; Right edge crosses, increment current screen
    ld      a,[Engine_CurrentScreen]
    and     $30
    ld      b,a
    ld      a,[Engine_CurrentScreen]
    push    bc
    ld      b,a
    ld      a,[Engine_NumScreens]
    cp      b
    ld      a,b
    pop     bc
    jp      z,.xCollideEnd
    inc     a
    or      b
    ld      [Engine_CurrentScreen],a
    jp      .xCollideEnd
.rightCollision:
    ; Check Right Collision
    ; Top Right
    ld      a,[Player_YPos]
    sub     Player_HitboxSize
    ld      l,a
    ld      a,[Player_XPos]
    add     Player_HitboxSize
    push    af
    ld      h,a
    call    GetTileCoordinates
    ld      e,a
    pop     af
    call    GetTileR
    cp      COLLISION_SOLID
    jr      z,:+
    ; Bottom Right
    ld      a,[Player_YPos]
    add     Player_HitboxSize
    ld      l,a
    ld      a,[Player_XPos]
    add     Player_HitboxSize
    push    af
    ld      h,a
    call    GetTileCoordinates
    ld      e,a
    pop     af
    call    GetTileR
    cp      COLLISION_SOLID
    jr      nz,.xCollideEnd
:
    ; Collision with right wall
    ; Bounce off of walls
    ld      a,[sys_btnHold]
    bit     btnB,a
    jr      nz,:+       ; don't bounce off walls if B is held
    ld      a,[Player_MovementFlags]
    bit     bPlayerIsUnderwater,a
    jr      nz,.waterR
.airR
    ld      a,high(-Player_MaxSpeed)
    ld      [Player_XVelocity],a
    ld      a,low(-Player_MaxSpeed)
    ld      [Player_XVelocityS],a
    jr      :+
.waterR
    ld      a,high(-Player_MaxSpeedWater)
    ld      [Player_XVelocity],a
    ld      a,low(-Player_MaxSpeedWater)
    ld      [Player_XVelocityS],a 
:   ; Calculate penetration depth
    ld      a,[Player_XPos]
    push    af
    add     Player_HitboxSize
    and     $f
    inc     a
    ld      b,a
    pop     af
    ; Push player out of tile
    sub     b
    ld      [Player_XPos],a
    ; Make player bounce vertically
    push    af
    ld      a,[sys_btnHold]
    bit     btnB,a
    jr      nz,:+       ; don't bounce off walls if B is held
    call    Player_WallBounce
:   pop     af
    ; Check Screen Crossing
    jr      nc,.xCollideEnd
    ; Left edge crossed, decrement current screen
    ld      a,[Engine_CurrentScreen]
    and     $30
    ld      b,a
    ld      a,[Engine_CurrentScreen]
    and     $f
    sub     1
    jr      c,.xCollideEnd
    or      b
    ld      [Engine_CurrentScreen],a
.xCollideEnd:
    
    ; Vertical Movement
    ; Gravity Acceleration
.moveair
    ld      a,[Player_MovementFlags]
    bit     bPlayerIsUnderwater,a
    jr      nz,.movewater
.moveair2
    ld      a,[Player_YVelocity]
    ld      h,a
    ld      a,[Player_YVelocityS]
    ld      l,a
    ld      de,Player_Gravity
    add     hl,de
    ld      a,h
    bit     7,a
    jr      nz,:+
    ld      b,h
    ld      c,l
    ld      de,Player_TerminalVelocity
    call    Compare16
    jr      c,:+
    ld      hl,Player_TerminalVelocity
:
    ld      a,h
    ld      [Player_YVelocity],a
    ld      a,l
    ld      [Player_YVelocityS],a
    ; Velocity
    ld      a,[Player_YSubpixel]
    add     l
    ld      [Player_YSubpixel],a
    ld      a,[Player_YPos]
    adc     h
    ld      [Player_YPos],a
    jr      .checkCollisionVertical
.movewater
    ld      a,[Player_YVelocity]
    ld      h,a
    ld      a,[Player_YVelocityS]
    ld      l,a
    ld      de,Player_Gravity/2
    add     hl,de
    ld      a,h
    bit     7,a
    jr      nz,:+
    ld      b,h
    ld      c,l
    ld      de,Player_TerminalVelocity/4
    call    Compare16
    jr      c,:+
    ld      hl,Player_TerminalVelocity/4
:
    ld      a,h
    ld      [Player_YVelocity],a
    ld      a,l
    ld      [Player_YVelocityS],a
    ; Velocity
    ld      a,[Player_YSubpixel]
    add     l
    ld      [Player_YSubpixel],a
    ld      a,[Player_YPos]
    adc     h
    ld      [Player_YPos],a
 
.checkCollisionVertical   
    ld      a,[Player_MovementFlags]
    bit     bPlayerIsDead,a
    jp      nz,.yCollideEnd
    ; Vertical Collision
    ld      a,[Player_YVelocity]
    bit     7,a
    jr      z,.bottomCollision
    ; Check Top Collision
    ; Top Left
    ld      a,[Player_YPos]
    sub     Player_HitboxSize
    ld      l,a
    ld      a,[Player_XPos]
    sub     Player_HitboxSize
    push    af
    ld      h,a
    call    GetTileCoordinates
    ld      e,a
    pop     af
    call    GetTileL
    cp      COLLISION_SOLID
    jr      z,:+
    ; Top Right
    ld      a,[Player_YPos]
    sub     Player_HitboxSize
    ld      l,a
    ld      a,[Player_XPos]
    add     Player_HitboxSize
    push    af
    ld      h,a
    call    GetTileCoordinates
    ld      e,a
    pop     af
    call    GetTileR
    cp      COLLISION_SOLID
    jp      nz,.yCollideEnd
:
    ; Collision with ceiling
    ld      a,[Player_MovementFlags]
    bit     bPlayerVictory,a
    jr      nz,.bottomCollision
    ; Clear Velocity
    xor     a
    ld      [Player_YVelocity],a
    ld      [Player_YVelocityS],a
    ; Calculate penetration depth
    ld      a,[Player_YPos]
    ld      c,a
    sub     Player_HitboxSize
    and     $f
    ld      b,a
    ld      a,16
    sub     b
    ; Push player out of tile
    add     c
    ld      [Player_YPos],a
    jr      .yCollideEnd
.bottomCollision:
    ; Check Bottom Collision
    ld      a,[Player_YPos]
    add     Player_HitboxSize
    ld      l,a
    ld      a,[Player_XPos]
    sub     Player_HitboxSize
    push    af
    ld      h,a
    call    GetTileCoordinates
    ld      e,a
    pop     af
    call    GetTileL
    cp      COLLISION_TOPSOLID
    jr      nz,.nottopsolid1
    ld      b,a
    ld      a,[sys_btnHold]
    bit     btnDown,a
    ld      a,b
    jr      nz,.nottopsolid1
    jr      :+
.nottopsolid1
    cp      COLLISION_SOLID
    jr      z,:+
    ld      a,[Player_YPos]
    add     Player_HitboxSize
    ld      l,a
    ld      a,[Player_XPos]
    add     Player_HitboxSize
    push    af
    ld      h,a
    call    GetTileCoordinates
    ld      e,a
    pop     af
    call    GetTileR
    cp      COLLISION_TOPSOLID
    jr      nz,.nottopsolid2
    ld      b,a
    ld      a,[sys_btnHold]
    bit     btnDown,a
    ld      a,b
    jr      nz,.nottopsolid2
    jr      :+
.nottopsolid2
    cp      COLLISION_SOLID
    jr      nz,.yCollideEnd
:
    ; Collision with floor
    ; Calculate penetration depth
    ld      a,[Player_YPos]
    push    af
    add     Player_HitboxSize
    and     $f
    inc     a
    ld      b,a
    pop     af
    ; Push player out of tile
    sub     b
    ld      [Player_YPos],a
    ; Bounce
    call    Player_Bounce
.yCollideEnd:
    jp    AnimatePlayer
    
Player_Bounce:
    ld      a,[Player_LastBounceY]
    add     7
    ld      b,a
    ld      a,[Player_YPos]
    add     7
    ld      [Player_LastBounceY],a
    push    af
    cp      b                       ; compare previous bounce Y with current bounce Y
    jr      nc,.skipcamtrack        ; if old Y < new Y, skip tracking
    ld      a,1
    ld      [Engine_CameraIsTracking],a
.skipcamtrack
    pop     af
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
    and     %11110000
    ld      [Engine_BounceCamTarget],a

    ld      a,[Player_MovementFlags]
    bit     bPlayerIsUnderwater,a
    jr      nz,.water

    ld      a,[sys_btnHold]
    bit     btnA,a
    jr      nz,.highbounce
    bit     btnB,a
    jr      nz,.lowbounce
.normalbounce
    ld      a,high(Player_BounceHeight)
    ld      [Player_YVelocity],a
    ld      a,low(Player_BounceHeight)
    ld      [Player_YVelocityS],a
    ret
.lowbounce
    ld      a,high(Player_LowBounceHeight)
    ld      [Player_YVelocity],a
    ld      a,low(Player_LowBounceHeight)
    ld      [Player_YVelocityS],a
    ret
.highbounce
    ld      a,high(Player_HighBounceHeight)
    ld      [Player_YVelocity],a
    ld      a,low(Player_HighBounceHeight)
    ld      [Player_YVelocityS],a
    ret
    
.water
    ld      a,[sys_btnHold]
    bit     btnA,a
    jr      nz,.highbouncewater
    bit     btnB,a
    jr      nz,.lowbouncewater
.normalbouncewater
    ld      a,high(Player_BounceHeight/2)
    ld      [Player_YVelocity],a
    ld      a,low(Player_BounceHeight/2)
    ld      [Player_YVelocityS],a
    ret
.lowbouncewater
    ld      a,high(Player_LowBounceHeight/2)
    ld      [Player_YVelocity],a
    ld      a,low(Player_LowBounceHeight/2)
    ld      [Player_YVelocityS],a
    ret
.highbouncewater
    ld      a,high(Player_HighBounceHeight/2)
    ld      [Player_YVelocity],a
    ld      a,low(Player_HighBounceHeight/2)
    ld      [Player_YVelocityS],a
    ret
    
Player_WallBounce:
    ld      a,[Player_LastBounceY]
    add     7
    ld      b,a
    ld      a,[Player_YPos]
    add     7
    ld      [Player_LastBounceY],a
    push    af
    cp      b                       ; compare previous bounce Y with current bounce Y
    jr      nc,.skipcamtrack        ; if old Y < new Y, skip tracking
    ld      a,1
    ld      [Engine_CameraIsTracking],a
.skipcamtrack
    pop     af
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
    and     %11110000
    ld      [Engine_BounceCamTarget],a

    ld      a,[Player_MovementFlags]
    bit     bPlayerIsUnderwater,a
    jr      nz,.water

    ld      a,[sys_btnHold]
    bit     btnA,a
    jr      nz,.highbounce
    bit     btnB,a
    ret     nz
.normalbounce
    ld      a,high(Player_WallBounceHeight)
    ld      [Player_YVelocity],a
    ld      a,low(Player_WallBounceHeight)
    ld      [Player_YVelocityS],a
    ret
.lowbounce
    ld      a,high(Player_LowWallBounceHeight)
    ld      [Player_YVelocity],a
    ld      a,low(Player_LowWallBounceHeight)
    ld      [Player_YVelocityS],a
    ret
.highbounce
    ld      a,high(Player_HighWallBounceHeight)
    ld      [Player_YVelocity],a
    ld      a,low(Player_HighWallBounceHeight)
    ld      [Player_YVelocityS],a
    ret

.water
    ld      a,[sys_btnHold]
    bit     btnA,a
    jr      nz,.highbouncewater
    bit     btnB,a
    ret     nz
.normalbouncewater
    ld      a,high(Player_WallBounceHeight/2)
    ld      [Player_YVelocity],a
    ld      a,low(Player_WallBounceHeight/2)
    ld      [Player_YVelocityS],a
    ret
.highbouncewater
    ld      a,high(Player_HighWallBounceHeight/2)
    ld      [Player_YVelocity],a
    ld      a,low(Player_HighWallBounceHeight/2)
    ld      [Player_YVelocityS],a
    ret
    
; ========

Player_AccelerateLeft:
        ld      a,[Player_MovementFlags]
    bit     bPlayerIsUnderwater,a
    jr      nz,.accelLeftWater
    push    bc
    ld      bc,-Player_Accel
    ld      hl,Player_XVelocity
    ld      a,[hl+]
    ld      l,[hl]
    ld      h,a
    add     hl,bc
    ld      b,h
    ld      c,l
    ld      de,-Player_MaxSpeed
    call    Compare16
    jr      nc,:+
    ld      de,$8000
    call    Compare16
    jr      c,:+
    ld      hl,-Player_MaxSpeed
:   ld      a,h
    ld      [Player_XVelocity],a
    ld      a,l
    ld      [Player_XVelocityS],a
    pop     bc
    ld      e,%10000000
    ret
.accelLeftWater
    push    bc
    ld      bc,-Player_Accel/2
    ld      hl,Player_XVelocity
    ld      a,[hl+]
    ld      l,[hl]
    ld      h,a
    add     hl,bc
    ld      b,h
    ld      c,l
    ld      de,-Player_MaxSpeedWater
    call    Compare16
    jr      nc,:+
    ld      de,$8000
    call    Compare16
    jr      c,:+
    ld      hl,-Player_MaxSpeedWater
:   ld      a,h
    ld      [Player_XVelocity],a
    ld      a,l
    ld      [Player_XVelocityS],a
    pop     bc
    ld      e,%10000000
    ret

Player_AccelerateRight:
    ld      a,[Player_MovementFlags]
    bit     bPlayerIsUnderwater,a
    jr      nz,.accelRightWater
    push    bc
    ld      bc,Player_Accel
    ld      hl,Player_XVelocity
    ld      a,[hl+]
    ld      l,[hl]
    ld      h,a
    add     hl,bc
    ld      d,h
    ld      e,l
    ld      bc,Player_MaxSpeed
    call    Compare16
    jr      nc,:+
    ld      bc,$8000
    call    Compare16
    jr      c,:+
    ld      hl,Player_MaxSpeed
:   ld      a,h
    ld      [Player_XVelocity],a
    ld      a,l
    ld      [Player_XVelocityS],a
    pop     bc
    ld      e,%00000000
    ret
.accelRightWater
    push    bc
    ld      bc,Player_Accel/2
    ld      hl,Player_XVelocity
    ld      a,[hl+]
    ld      l,[hl]
    ld      h,a
    add     hl,bc
    ld      d,h
    ld      e,l
    ld      bc,Player_MaxSpeedWater
    call    Compare16
    jr      nc,:+
    ld      bc,$8000
    call    Compare16
    jr      c,:+
    ld      hl,Player_MaxSpeedWater
:   ld      a,h
    ld      [Player_XVelocity],a
    ld      a,l
    ld      [Player_XVelocityS],a
    pop     bc
    ld      e,%00000000
    ret
    

; ========
    
DrawPlayer:
    ; load correct frame in player VRAM area
    ld      a,[Player_CurrentFrame]
    add     a
    add     a
    ld      l,a
    ld      h,0
    add     hl,hl   ; x2
    add     hl,hl   ; x4
    add     hl,hl   ; x8
    add     hl,hl   ; x16
    ldfar   de,PlayerTiles
    add     hl,de
    ld      b,$40
    ld      de,$8000
    ld      a,1
    ldh     [rVBK],a
.loadtiles
    ldh     a,[rSTAT]
    and     2
    jr      nz,.loadtiles
    ld      a,[hl+]
    ld      [de],a
    inc     e
    dec     b
    jr      nz,.loadtiles
    xor     a
    ldh     [rVBK],a

    ld      hl,OAMBuffer
    ld      a,[Engine_CameraY]
    ld      e,a
    ld      a,[Player_YPos]
    sub     e
    add     8
    ld      b,a
    ld      [hl+],a
    ld      a,[Engine_CameraX]
    ld      e,a
    ld      a,[Player_XPos]
    sub     e
    ld      c,a
    ld      [hl+],a
    xor     a
    ld      [hl+],a
    ld      a,%00001000
    ld      [hl+],a
    ld      a,b
    ld      [hl+],a
    ld      a,c
    add     8
    ld      [hl+],a
    ld      a,2
    ld      [hl+],a
    ld      a,%00001000
    ld      [hl],a
    
    ld      hl,Sprite_NextSprite
    inc     [hl]
    inc     [hl]
    ret

; ====

KillPlayer:
    ld      hl,Player_MovementFlags
    bit     bPlayerIsDead,[hl]
    ret     nz
    ld      a,[Player_XPos]
    ld      [Player_CheckpointX],a
    ld      a,[Player_YPos]
    ld      [Player_CheckpointY],a
    ld      a,[Engine_CurrentScreen]
    ld      [Player_CheckpointScreen],a
    
    xor     a
    ld      [Player_XVelocity],a
    ld      [Player_XVelocityS],a
    ld      [Player_YVelocityS],a
    ld      a,-4
    ld      [Player_YVelocity],a
    set     bPlayerIsDead,[hl]
    ld      a,1
    ld      [Engine_LockCamera],a
    ld      hl,Anim_Player_Hurt
    call    Player_SetAnimation
    PlaySFX death
    ret
    
Player_Respawn:
    xor     a
    ld      [Engine_LockCamera],a
    ld      hl,Player_MovementFlags
    res     bPlayerIsDead,[hl]
    ld      hl,Anim_Player_Idle
    call    Player_SetAnimation
    
    ld      a,[Player_CheckpointX]
    ld      [Player_XPos],a
    ld      a,[Player_CheckpointY]
    ld      [Player_YPos],a
; TODO: Fix this
;    ld      a,[Player_CheckpointScreen]
;    ld      [Engine_CurrentScreen],a
;    call    Level_LoadScreen
    xor     a
    ld      [Player_XSubpixel],a
    ld      [Player_YSubpixel],a
    ld      [Player_YVelocity],a
    ld      [Player_YVelocityS],a
    xor     a
    ret
    
Player_Splash:
    ret
    ; TODO: Fix this
/*
    ; left splash particle
    call    GetParticleSlot
    ld      a,b
    or      c
    cp      $ff
    jr      z,:+                    ; don't spawn any particles if no free slots are left
    ld      bc,PARTICLE_COUNT
    ld      [hl],4                  ; tile number
    add     hl,bc
    ld      [hl],%00000010          ; attributes
    add     hl,bc
    ld      [hl],0  ; collsion flags
    add     hl,bc
    ld      a,[Engine_CurrentScreen]
    ld      [hl],a
    add     hl,bc
    ld      [hl],8                  ; time to live
    add     hl,bc
    ld      a,[Player_XPos]
    sub     8
    ld      [hl],a                  ; X position
    add     hl,bc
    ld      [hl],0                  ; X subpixel
    ld      a,[Player_YPos]
    and     $f0
    sub     8
    ld      [hl],a                  ; Y position
    add     hl,bc
    ld      [hl],0                  ; Y subpixel
    add     hl,bc
    ; X velocity
    ld      [hl],high(-$0080)
    add     hl,bc
    ld      [hl],low(-$0080)
    add     hl,bc
    ; Y velocity
    ld      [hl],high(-$0100)
    add     hl,bc
    ld      [hl],low(-$0100)
    add     hl,bc
:    
    ; right splash particle
    call    GetParticleSlot
    ld      a,b
    or      c
    cp      $ff
    ret     z                       ; don't spawn any particles if no free slots are left
    ld      bc,PARTICLE_COUNT
    ld      [hl],4                  ; tile number
    add     hl,bc
    ld      [hl],%01100010          ; attributes
    add     hl,bc
    ld      [hl],0  ; collsion flags
    add     hl,bc
    ld      a,[Engine_CurrentScreen]
    ld      [hl],a
    add     hl,bc
    ld      [hl],8
    add     hl,bc
    ld      a,[Player_XPos]
    add     8
    ld      [hl],a                  ; X position
    add     hl,bc
    ld      [hl],0                  ; X subpixel
    ld      a,[Player_YPos]
    and     $f0
    sub     8
    ld      [hl],a                  ; Y position
    add     hl,bc
    ld      [hl],0                  ; Y subpixel
    add     hl,bc
    ; X velocity
    ld      [hl],high($0080)
    add     hl,bc
    ld      [hl],low($0080)
    add     hl,bc
    ; Y velocity
    ld      [hl],high(-$0100)
    add     hl,bc
    ld      [hl],low(-$0100)
    add     hl,bc
    ret
 */

; ===================
; Animation constants
; ===================

C_SetAnim   equ $80

; ================
; Animation macros
; ================

NUM_ANIMS   set 0   ; no touchy!

defanim:        macro
AnimID_\1       equ NUM_ANIMS
NUM_ANIMS       set NUM_ANIMS+1
Anim_\1:
    endm

; ==================
; Animation routines
; ==================

Player_SetAnimation:
    ld      a,l
    ld      [Player_AnimPointer],a
    ld      a,h
    ld      [Player_AnimPointer+1],a
    ld      a,1
    ld      [Player_AnimTimer],a
    ret

AnimatePlayer:
    ld      a,[Player_AnimTimer]
    cp      -1
    ret     z   ; return if current frame time = -1
    dec     a
    ld      [Player_AnimTimer],a
    ret     nz  ; return if anim timer > 0

    ; get anim pointer
    ld      a,[Player_AnimPointer]
    ld      l,a
    ld      a,[Player_AnimPointer+1]
    ld      h,a
    
    ; get frame / command number
.getEntry
    ld      a,[hl+]
    bit     7,a
    jr      nz,.cmdProc
    ld      [Player_CurrentFrame],a
    ld      a,[hl+]
    ld      [Player_AnimTimer],a
.doneEntry
    ld      a,l
    ld      [Player_AnimPointer],a
    ld      a,h
    ld      [Player_AnimPointer+1],a
    ret
    
.cmdProc
    push    hl
    ld      hl,.cmdProcTable
    add     a
    add     l
    ld      l,a
    jr      nc,.nocarry
    inc     h
.nocarry
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    jp      hl
    
.cmdProcTable:
    dw      .setAnim
    
.setAnim
    pop     hl
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    jr      .getEntry

; ==============
; Animation data
; ==============

; Animation format:
; XX YY
; XX = Frame ID / command (if bit 7 set)
; YY = Wait time (one byte) / command parameter (can be more than one byte)

    defanim Player_Left2
    db      F_Player_Left2,-1
    
    defanim Player_Left1
    db      F_Player_Left1,-1

    defanim Player_Idle
    db      F_Player_Idle,-1

    defanim Player_Right1
    db      F_Player_Right1,-1
    
    defanim Player_Right2
    db      F_Player_Right2,-1
    
    defanim Player_Left2Blink
    db      F_Player_Left2_Blink1,1
    db      F_Player_Left2_Blink2,1
    db      F_Player_Left2_Blink3,1
    db      F_Player_Left2_Blink4,4
    db      F_Player_Left2_Blink3,1
    db      F_Player_Left2_Blink2,1
    db      F_Player_Left2_Blink1,1
    dbw     C_SetAnim,Anim_Player_Left2
    
    defanim Player_Left1Blink
    db      F_Player_Left1_Blink1,1
    db      F_Player_Left1_Blink2,1
    db      F_Player_Left1_Blink3,1
    db      F_Player_Left1_Blink4,4
    db      F_Player_Left1_Blink3,1
    db      F_Player_Left1_Blink2,1
    db      F_Player_Left1_Blink1,1
    dbw     C_SetAnim,Anim_Player_Left1
    
    defanim Player_IdleBlink
    db      F_Player_Idle_Blink1,1
    db      F_Player_Idle_Blink2,1
    db      F_Player_Idle_Blink3,1
    db      F_Player_Idle_Blink4,4
    db      F_Player_Idle_Blink3,1
    db      F_Player_Idle_Blink2,1
    db      F_Player_Idle_Blink1,1
    dbw     C_SetAnim,Anim_Player_Idle
    
    defanim Player_Right1Blink
    db      F_Player_Right1_Blink1,1
    db      F_Player_Right1_Blink2,1
    db      F_Player_Right1_Blink3,1
    db      F_Player_Right1_Blink4,4
    db      F_Player_Right1_Blink3,1
    db      F_Player_Right1_Blink2,1
    db      F_Player_Right1_Blink1,1
    dbw     C_SetAnim,Anim_Player_Right1
    
    defanim Player_Right2Blink
    db      F_Player_Right2_Blink1,1
    db      F_Player_Right2_Blink2,1
    db      F_Player_Right2_Blink3,1
    db      F_Player_Right2_Blink4,4
    db      F_Player_Right2_Blink3,1
    db      F_Player_Right2_Blink2,1
    db      F_Player_Right2_Blink1,1
    dbw     C_SetAnim,Anim_Player_Right2
    
    defanim Player_Hurt
    db      F_Player_Hurt1,6
    db      F_Player_Hurt2,6
    dbw     C_SetAnim,Anim_Player_Hurt
    
    defanim Player_SMH
    db      F_Player_Left1,2
    db      F_Player_Left2,2
    db      F_Player_Left1,2
    db      F_Player_Idle,2
    db      F_Player_Right1,2
    db      F_Player_Right2,2
    db      F_Player_Right1,2
    db      F_Player_Idle,2
    db      F_Player_Left1,2
    db      F_Player_Left2,2
    db      F_Player_Left1,2
    db      F_Player_Idle,2
    db      F_Player_Right1,2
    db      F_Player_Right2,2
    db      F_Player_Right1,2
    db      F_Player_Idle,2
    db      F_Player_Left1,2
    db      F_Player_Left2,2
    db      F_Player_Left1,2
    db      F_Player_Idle,2
    db      F_Player_Right1,2
    db      F_Player_Right2,2
    db      F_Player_Right1,2
    dbw     C_SetAnim,Anim_Player_Idle

; ================================

section "Player tiles",romx,align[8]
PlayerTiles:
    incbin  "GFX/PlayerTiles.2bpp"
