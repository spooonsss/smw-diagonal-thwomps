;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Diagonal Thwomp, by yoshicookiezeus
;;
;; Description:
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

			; symbolic names for RAM addresses (don't change these)
			!SPRITE_Y_SPEED	= !AA
			!SPRITE_X_SPEED	= !B6
			!SPRITE_STATE	= !C2
			!SPRITE_Y_POS	= !D8
			!SPRITE_Y_POS_HI	= !14D4
			!SPRITE_X_POS	= !E4
			!SPRITE_X_POS_HI	= !14E0
			!ORIG_Y_POS	= !151C
			!EXPRESSION	= !1528
			!FREEZE_TIMER	= !1540
			!SPR_OBJ_STATUS	= !1588
			!H_OFFSCREEN	= !15A0
			!V_OFFSCREEN	= !186C

			; definitions of bits (don't change these)
			!IS_ON_GROUND	= $08
			!IS_ON_WALL	= $01

			; sprite data
			!GRAVITY_Y	= $FC
			!MAX_Y_SPEED	= $C2
			!RISE_SPEED_Y	= $10
			!GRAVITY_X	= $04
			!MAX_X_SPEED	= $3E
			!RISE_SPEED_X	= $F0
			!TIME_TO_SHAKE	= $18
			!SOUND_EFFECT	= $09
			!TIME_ON_GROUND	= $40
			!ANGRY_TILE	= $CA

X_OFFSET:		db $FC,$04,$FC,$04,$00
Y_OFFSET:		db $00,$00,$10,$10,$08
TILE_MAP:		db $8E,$8E,$AE,$AE,$C8
PROPERTIES:		db $03,$43,$03,$43,$03

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; sprite init JSL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

			PRINT "INIT ",pc
			LDA !SPRITE_Y_POS,x
			STA !ORIG_Y_POS,x
			LDA !E4,x
			CLC
			ADC #$08
			STA !E4,x
			STA !1534,x
			RTL


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; sprite code JSL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

			PRINT "MAIN ",pc
			PHB
			PHK
			PLB
			JSR SPRITE_CODE_START
			PLB
			RTL


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; sprite main code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RETURN:			RTS

SPRITE_CODE_START:	JSR SUB_GFX

			LDA !14C8,x		; RETURN if sprite status != 8
			CMP #$08
			BNE RETURN

			LDA $9D			; RETURN if sprites locked
			BNE RETURN

			; LDA #$00
			%SubOffScreen()	; only process sprite while on screen

			JSL $01A7DC|!BankB		; interact with mario

			LDA !SPRITE_STATE,x
			CMP #$01
			BEQ FALLING
			CMP #$02
			BEQ RISING1

;-----------------------------------------------------------------------------------------
; state 0
;-----------------------------------------------------------------------------------------

HOVERING:		LDA !V_OFFSCREEN,x	;fall if offscreen vertically
			BNE SET_FALLING

			LDA !H_OFFSCREEN,x	;RETURN if offscreen horizontally
			BNE RETURN0

			%SubHorzPos() ;determine if mario is close and act accordingly
			TYA
			STA !157C,x
			;STZ !EXPRESSION,x
			;LDA $0E
			;CLC
			;ADC #$40
			;CMP #$80
			;BCS THWOMP_4
			;LDA #$01
			;STA !EXPRESSION,x
THWOMP_4:		;LDA $0E
			;CLC
			;ADC #$24
			;CMP #$50
			BNE RETURN0

SET_FALLING:		LDA #$02		;set expression
			STA !EXPRESSION,x

			INC !SPRITE_STATE,x	;chage state to FALLING

			LDA #$FF
			STA !SPRITE_Y_SPEED,x	;set initial speed
			STZ !SPRITE_X_SPEED,x	;set initial speed

RETURN0:			RTS

RISING1:			JMP RISING


;-----------------------------------------------------------------------------------------
; state 1
;-----------------------------------------------------------------------------------------

FALLING:			JSL $01801A|!BankB		;apply speed
			JSL $018022|!BankB

			LDA !SPRITE_Y_SPEED,x	;increase speed if below the max
			CMP #!MAX_Y_SPEED
			BCC DONT_INC_Y
			CLC
			ADC #!GRAVITY_Y
			STA !SPRITE_Y_SPEED,x

DONT_INC_Y:		LDA !SPRITE_X_SPEED,x	;increase speed if below the max
			CMP #!MAX_X_SPEED
			BCS DONT_INC_X
			CLC
			ADC #!GRAVITY_X
			STA !SPRITE_X_SPEED,x

DONT_INC_X:		JSL $019138|!BankB		;interact with objects

			LDA !SPR_OBJ_STATUS,x	;RETURN if not on the ground
			AND #!IS_ON_GROUND
			BNE HIT

			LDA !SPRITE_X_POS,x
			PHA
			CLC
			ADC #$07
			STA !SPRITE_X_POS,x
			LDA !SPRITE_X_POS_HI,x
			PHA
			ADC #$00
			STA !SPRITE_X_POS_HI,x


			JSL $019138|!BankB		;interact with objects

			PLA
			STA !SPRITE_X_POS_HI,x
			PLA
			STA !SPRITE_X_POS,x

			LDA !SPR_OBJ_STATUS,x	;RETURN if not in contact
			AND #!IS_ON_WALL
			BNE HIT

			RTS


HIT:			JSR SUB_9A04		; ?? speed related

			LDA #!TIME_TO_SHAKE	;shake ground
			STA $1887|!Base2

			LDA #!SOUND_EFFECT	;play sound effect
			STA $1DFC|!Base2

			LDA #!TIME_ON_GROUND	;set time to stay on ground
			STA !FREEZE_TIMER,x

			INC !SPRITE_STATE,x	;go to RISING state

RETURN1:			RTS

;-----------------------------------------------------------------------------------------
; state 2
;-----------------------------------------------------------------------------------------

RISING:              	LDA !FREEZE_TIMER,x	;if we're still waiting on the ground, RETURN
			BNE RETURN2

			STZ !EXPRESSION,x	;reset expression

			LDA !SPRITE_Y_POS,x	;check if the sprite is in original position
			CMP !ORIG_Y_POS,x
			BNE RISE

			STZ !SPRITE_STATE,x	;reset state to HOVERING

			LDA !1534,x
			STA !E4,x
			RTS

RISE:			LDA #!RISE_SPEED_Y	;set RISING speed and apply it
			STA !SPRITE_Y_SPEED,x
			LDA #!RISE_SPEED_X
			STA !SPRITE_X_SPEED,x
			JSL $01801A|!BankB
			JSL $018022|!BankB
RETURN2:			RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; graphics routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SUB_GFX:
			%GetDrawInfo()

			LDA !EXPRESSION,x
			STA $02
			PHX
			LDX #$03
			CMP #$00
			BEQ LOOP_START
			INX
LOOP_START:		LDA $00
			CLC
			ADC X_OFFSET,x
			STA $0300|!Base2,y

			LDA $01
			CLC
			ADC Y_OFFSET,x
			STA $0301|!Base2,y

			LDA PROPERTIES,x
			ORA $64
			STA $0303|!Base2,y

			LDA TILE_MAP,x
			CPX #$04
			BNE NORMAL_TILE
			PHX
			LDX $02
			CPX #$02
			BNE NOT_ANGRY
			LDA #!ANGRY_TILE
NOT_ANGRY:		PLX
NORMAL_TILE:		STA $0302|!Base2,y

			INY
			INY
			INY
			INY
			DEX
			BPL LOOP_START

			PLX

			LDY #$02		; \ 460 = 2 (all 16x16 tiles)
			LDA #$04		;  | A = (number of tiles drawn - 1)
			%FinishOAMWrite()		; / don't draw if offscreen
			RTS			; RETURN


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; speed related
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SUB_9A04:		LDA !SPR_OBJ_STATUS,x
			BMI THWOMP_1
			LDA #$00
			LDY !15B8,x
			BEQ THWOMP_2
THWOMP_1:		LDA #$18
THWOMP_2:		STA !SPRITE_Y_SPEED,x

			LDA !SPR_OBJ_STATUS,x
			BMI THWOMP_01
			LDA #$00
			LDY !15B8,x
			BEQ THWOMP_02
THWOMP_01:		LDA #$18
THWOMP_02:		STA !SPRITE_X_SPEED,x
			RTS

