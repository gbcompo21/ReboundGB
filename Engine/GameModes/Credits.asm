GM_Credits:
    ; TODO
    ret

; ================================================================

; Subject to change as development continues
CreditsText:
;            ####################
    db      "                    "
    db      "    - REBOUND -     "
    db      "  A game  by DevEd  "
    db      "                    "
    db      " Lead programmer:   "
    db      "              DevEd "
    db      "                    "
    db      " Programmers:       "
    db      "              Arkia "
    db      "                    "
    db      " Graphics:          "
    db      "          Twoflower "
    db      "              DevEd "
    db      "                    "
    db      " Music composition: "
    db      "              DevEd "
    db      "                    "
    db      " Sound programming: "
    db      "              DevEd "
    db      "                ??? "
    db      "                    "
    db      " Tools used:        "
    db      "                BGB "
    db      "            Tilekit "
    db      "          DefleMask "
    db      "              RGBDS "
    db      "                    "
    db      " Special thanks:    "
    db      "       Gunpei Yokoi "
    db      "    Hirokazu Tanaka "
    db      "          Superogue "
    db      "             ISSOtm "
    db      "             Beware "
    db      "      Elmar Krieger "
    db      "   Alberto Gonzalez "
    db      "       Moviemovies1 "
    db      "                    "
    db      "     THANK  YOU     "
    db      "    FOR PLAYING!    "
    db      "                    "

; ================================================================

section "Credits GFX",romx

DevSoundLogoTiles:  incbin  "GFX/DevSoundLogo.2bpp.wle"
DevSoundLogoMap:    incbin  "GFX/DevSoundLogo.til.wle"
DevSoundLogoAttr:   incbin  "GFX/DevSoundLogo.atr.wle"

Pal_DevSoundLogo:   incbin  "GFX/DevSoundLogo.pal"