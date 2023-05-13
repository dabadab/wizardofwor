;============================================================
;
; CHARACTER ENCODINGS
;
; the game uses three different character sets (the built-in, a 2x1 character set for most text and a huge one for text like "ready" and "go")
; to write the 'a' character you have to encode that differently for these charset: $69 for the first one, $0a for the second and $00 for the last
; these encoding definitions tell the assembler that which character is represented by what value in a specific encoding
;
;============================================================

; -------------

.enc "petscii"  ;define an ascii->petscii encoding
	.cdef " @", 32  ;characters
	.cdef "AZ", $c1
	.cdef "az", $41

; -------------

.enc "2x1"  ; the 2x1 character set
	; $00-$09: digits, $0a - $23: letters, $24: (C), $25: space, $26: dot)
	.cdef "09", $00
	.cdef "az", $0a
	.cdef "©©", $24
	.edef "(c)", $24
	.cdef "  ", $25
	.cdef "..", $26

; --------------

.enc "charrom" ; the characters copied from the character rom
	.cdef "az", $69
	.cdef "09", $83
	.cdef "  ", $00
	.cdef "__", $06

; --------------

.enc "bigwords" ; the oversized characters - it does not include all letters, just the necessary ones
	.cdef "aa", $00
	.cdef "bb", $01
	.cdef "cc", $02
	.cdef "dd", $03
	.cdef "ee", $04
	.cdef "gg", $05
	.cdef "ll", $06
	.cdef "mm", $07
	.cdef "nn", $08
	.cdef "oo", $09
	.cdef "rr", $0a
	.cdef "ss", $0b
	.cdef "tt", $0c
	.cdef "uu", $0d
	.cdef "vv", $0e
	.cdef "yy", $0f

;============================================================
;
; MACROS
;
; macros that generate data
;
;============================================================

; -------------
;
; the first part of the macros create tables to store data
;
; -------------

; a table (actually two tables) for storing 16 byte values: first all the lower bytes (marked with the local "lo" label) then the high bytes ("hi" label)
lohi_tbl .macro
	_ = ( \@ )
lo	.byte <_
hi	.byte >_

.endm

; -------------

; this is functionally equivalent to lohi_tbl, but the coder sometimes used this form so it is preserved here too
hilo_tbl .macro
	_ = ( \@ )
hi	.byte >_
lo	.byte <_

.endm

; -------------

; this is a variation of the lohi_tbl - the difference is that the "lo" and "hi" labels are placed a byte earlier than they should be so the first value
; can be accessed with an index of 1, not 0
lohi_tbl_1 .macro
	_ = ( \@ )
lo	= *-1
	.byte <_
hi	= *-1
	.byte >_
.endm

; -------------

; a table for storing 16 byte values: but in case only the lower bytes are stored as the high byte is the same for all
lo_tbl .macro
	_ = ( \@ )
lo	.byte <_

.endm

; -------------

; like lo_tbl, but like above, the first value can be accessed with an index of 1
lo_tbl_1 .macro
	_ = ( \@ )
lo	= *-1
	.byte <_
.endm

; -------------
;
; the second part of the macros are there to help with the storage of text
;
; -------------


; for text with the oversized characters the text is written backwards
big_text .macro text
	.enc "bigwords"
	.text \text[::-1]
.endm

; -------------

; the routine that writes text with 2x1 charset to the screen expects the text to be prefixed with the color and the position of the text
text_line .macro color, row, col, text
	.byte \color
	.byte \row
	.byte \col
	.enc "2x1"
	.ptext \text
.endm


; -------------
;
; the last macro lets the sprites be defined in a visual way - see the inc.sprites* files
;
; -------------

; sprite definition
sprite .macro def
	.cerror (len(\def) != 24), "sprite definition is not 24 char long"
	.bfor byte := 0, byte < 3, byte += 1
		val := 0;
		.for bit := 0, bit < 8, bit += 1
			val <<= 1
			.switch \def[byte*8+bit]
			.case ' '
				val += 0
			.case '_'
				val += 0
			.case '.'
				val += 0

			.case '#'
				val += 1
			.case '*'
				val += 1
			.default
				.error "illegal char in sprite definition"
			.endswitch
		.next
		.byte val
	.next
.endm



;============================================================
;
; MACRO FUNCTIONS
;
; all these functions are about setting and manipulating 16 bit pointers
;
;============================================================

; -------------
;
; the first two ones simply set a pointer to a given value
;
; -------------

; simply sets a pointer to a given value
PTR_SET .function ptr, val
	LDA #<val
	STA ptr
	LDA #>val
	STA ptr+1
.endf

; -------------

; this is functionally equivalent to PTR_SET, but the coder sometimes used this form so it is preserved here too
PTR_SET2 .function ptr, val
	LDA #>val
	STA ptr+1
	LDA #<val
	STA ptr
.endf

; -------------
;
; the next four ones are about setting pointers with values from the "lohi_tbl" (or "hilo_tbl") tables mentioned above - where only the lower byte is stored in a table as the high byte is the same for all values
; all do the same thing: load the lower and high byte from a table indexed by the X or Y register and put it into the pointer
; the first two uses the X, the next to the Y registers and there are the usual variations on if the high or the lower byte is stored first
;
; -------------

PTR_SET_TBL_X .function ptr, tbl
	LDA tbl.lo,x
	STA ptr
	LDA tbl.hi,x
	STA ptr+1
.endf

; -------------

PTR_SET_TBL_X2 .function ptr, tbl
	LDA tbl.hi,x
	STA ptr+1
	LDA tbl.lo,x
	STA ptr
.endf

; -------------

PTR_SET_TBL_Y .function ptr, tbl
	LDA tbl.lo,y
	STA ptr
	LDA tbl.hi,y
	STA ptr+1
.endf

; -------------

PTR_SET_TBL_Y2 .function ptr, tbl
	LDA tbl.hi,y
	STA ptr+1
	LDA tbl.lo,y
	STA ptr
.endf

; -------------
;
; the next four ones are about setting pointers with values from the "lo_tbl" tables mentioned above - where only the lower byte is stored in a table as the high byte is the same for all values
;
; -------------

; this is a helper macro that is used only in the next three macros - it sets the fixed high byte and does an error checking
PTR_SET_LOTBL_HI .function ptr, tbl
	; this scheme depends on the fact that all stored values have the same high byte
	; check it by comparing the high byte of the first (assumed to be the lowest) and the last (assumed to be the highest) value of the table
	; this check is not necessary for this disassembly but if you modify the code it saves you from rude suprises
	.cerror (>tbl._[0]) != (>tbl._[-1]), "addresses not on the same page"
	LDA #>tbl._[0]
	STA ptr+1
.endf

; -------------

; set up the pointer from the table using the X register as index
PTR_SET_LOTBL_X .function ptr, tbl
	PTR_SET_LOTBL_HI ptr, tbl
	LDA tbl.lo,x
	STA ptr
.endf

; -------------

; functionally same as PTR_SET_LOTBL_X
PTR_SET_LOTBL_X2 .function ptr, tbl
	LDA tbl.lo,x
	STA ptr
	PTR_SET_LOTBL_HI ptr, tbl
.endf

; -------------

; set up the pointer from the table using the Y register as index
PTR_SET_LOTBL_Y .function ptr, tbl
	PTR_SET_LOTBL_HI ptr, tbl
	LDA tbl.lo,y
	STA ptr
.endf

; -------------
;
; the last three ones add or substract an 8 bit value to/from a pointer
;
; -------------

; add an 8 bit value to the pointer
PTR_ADD .function ptr, val
	LDA ptr
	CLC
	ADC val
	STA ptr
	BCC +
	INC ptr+1
+
.endf

; -------------

; functionally the same as PTR_ADD
PTR_ADD2 .function ptr, val
	LDA val
	CLC
	ADC ptr
	STA ptr
	BCC +
	INC ptr+1
+
.endf

; -------------

; add an 8 bit value from the pointer
PTR_SUB .function ptr, val
	LDA ptr
	SEC
	SBC val
	STA ptr
	BCS +
	DEC ptr+1
+
.endf


;============================================================
;
; CONSTANTS
;
; these define labels to memory locations and fixed values
;
; the game uses zero page addresses for variables - some
; have a single functions these are named accordingly, some
; have multiple purposes, these are named tmp_hitbox_char_noXXX where
; XXXX is the actual address
;
;============================================================

	; gameplay constants

	MAX_PLAYERS = 2
	MAX_MONSTERS = 6
	MAX_ACTORS = MAX_PLAYERS + MAX_MONSTERS
	STARTING_EXTRA_LIVES = 2

	; locations of zero page variables

	* = $0002
tmp_0002 	.byte ?

	* = $0004
tmp_0004_ptr		.addr ?
tmp_0006_ptr		.addr ?
tmp_0008		.byte ?
tmp_0009		.byte ?
tmp_000a		.byte ?
tmp_000b		.byte ?
tmp_000c		.byte ?
tmp_000d		.byte ?
tmp_000e		.byte ?
tmp_000f		.byte ?
tmp_0010_ptr		.addr ?
dungeon_layout_ptr	.addr ?
tmp_0014_ptr		.addr ?
actor_heading_x		.byte ?
actor_heading_y		.byte ?
actor_x_9th_bit		.byte ?
tmp_sprite_x		.byte ?
tmp_sprite_y		.byte ?
tmp_001b		.byte ?
actor_heading_x_tbl	.fill MAX_ACTORS ; the horizontal direction in which the actor looks: $ff: left, 0: none, $01: right
actor_heading_y_tbl	.fill MAX_ACTORS ; the vertical direction in which the actor looks: $ff: up, 0: none, $01: down
animation_phase		.byte ?
tmp_text_lo_ptr		.addr ?
actual_actor		.byte ?
actor_bit_0		.byte ?
actor_sprite_pos_offset	.byte ?
actor_bit_1		.byte ?
animation_timer_tbl	.fill MAX_ACTORS
new_heading_y_tbl	.fill MAX_ACTORS ; TODO: better name?
new_heading_x_tbl	.fill MAX_ACTORS ; TODO: better name?
monster_dest_x		.byte ?
monster_dest_y		.byte ?
monster_dest_9th	.byte ?
horiz_anim_ptr		.addr ?
vert_anim_ptr		.addr ?
irq_timer_sec		.byte ? ; a timer run by the IRQ - decreased in about every second (every 64th frame, to be precise)
irq_timer_frame		.byte ? ; a timer run by the IRQ - decreased in every frame
launch_status		.fill MAX_PLAYERS ; status of the launch from the cage: $ff: no launch in progress, $00: countdown in progress, $07: launch in progress
sprite_tmp		.fill MAX_ACTORS ; the players' sprites are stored here when they shoot
snd_ingame_dur		.byte ?
snd_ingame_dur_cnt	.byte ?
snd_ingame_status	.byte ?
snd_voice_base_ptr	.addr ?
snd_sfx_to_start	.byte ?
snd_sfx_ptr		.addr ?
snd_sfx_shifts_no	.byte ?
snd_sfx_dur_cnt		.byte ?
snd_sfx_freq_lo		.byte ?
snd_sfx_freq_hi		.byte ?
snd_sfx_freq_inc_lo	.byte ?
snd_sfx_freq_inc_hi	.byte ?
snd_sfx_no_of_channels_idx .byte ?
snd_sfx_effect_switch	.byte ?
snd_pattern_no		.byte ?
snd_pattern_pos		.byte ?
snd_voice_offset	.byte ?
snd_duration		.byte ?
snd_pattern_ptr 	.addr ?
snd_vibrato		.byte ?
MV_sentence_idx		.byte ?
MV_sentence		.byte ?
MV_sentence_ptr		.addr ?
one_second_wait_tbl	.fill MAX_ACTORS
launch_counters		.byte ?,?
is_monster		.byte ? ; current actor is: 0: player, non-0 (2-7): monster
actor_type_before_dying_tbl .fill MAX_ACTORS ; actor's original type is saved here when it goes to dying (0) type
burwors_alive		.byte ?
tmp_text_hi_ptr		.addr ?
monster_bullet_move_counter .byte ?
tmp_0090		.byte ? ; used for many purposes
normal_monsters_on_screen .byte ? ; actually normal monsters on screen - 1
gameplay_ptr		.addr ?
is_easter_egg_activated	.byte ?
random_number		.byte ?
word_len_cnt		.byte ?
score_ptr		.addr ?

			.fill 38 ; unused

firing_status		.fill MAX_ACTORS
			FIRING_BULLET_ACTIVE	= $80
			FIRING_FIRE_BUTTON	= $01

			.byte ? ; unused

bullet_char		.fill MAX_ACTORS
bullet_pos		.lohi_tbl ?,?,?,?,?,?,?,? ; ? * MAX_ACTORS
bullet_direction	.fill MAX_ACTORS

			.byte ? ; unused

tmp_00e9		.byte ? ; used as various local variables






	; $0200 page variables



	* = $200
is_MV_missing		.byte ? ; 0: Magic Voice cartridge is present 1: no MV cartridge
current_dungeon		.byte ?
prev_dungeon_layout	.byte ?
lives_player2		.byte ?
lives_player1		.byte ?
actor_speed_tbl		.fill MAX_ACTORS ; actually it is relevant only for the monsters
monster_speed_tbl	 = actor_speed_tbl + MAX_PLAYERS

once_in_a_while_timer	.byte ?

	* = $215
time_to_invis_counter	.fill MAX_ACTORS

actor_type_tbl		.fill MAX_ACTORS
monster_type_tbl	= actor_type_tbl + MAX_PLAYERS
			DEAD_PLAYER = $f0
			DEAD_MONSTER = $ff
			DYING_ACTOR = $00
			PLAYER1 = $02
			PLAYER2 = $01
			BURWOR = $03
			GARWOR = $04
			THORWOR = $05
			WORLUK = $07
			WIZARD = $08

unused_01		.byte ? ; unused

is_title_screen		.byte ? ; 0: game is in progress, 1: title screen

animation_counter_tbl	.fill 8 ; used for timing animation phases
monster_anim_counter_tbl = animation_counter_tbl + MAX_PLAYERS

player1_score_string	.fill 6
player2_score_string	.fill 6

; TODO: rest of the status codes
game_status		.byte ?
			STATUS_GAME_OVER = $AA

monster_head_ptr_tbl	.hilo_tbl ?,?,?,?,?,?,?,? ; ? * MAX_ACTORS
tmp_irq_ptr_save	.addr ?

high_scores
high_score_1		.fill 6
high_score_2		.fill 6
high_score_3		.fill 6
high_score_4		.fill 6
high_score_5		.fill 6

bullet_move_counter	.byte ?

	* = $26D
tmp_score		.byte ?

	* = $26F
music_speed		.byte ?
curr_sfx_idx		.byte ?
next_sfx_idx		.byte ?
			SFX_MONSTER_SHOOTS = $00
			SFX_PLAYER_SHOOTS = $01
			SFX_MONSTER_HIT = $02
			SFX_WORLUK_MOVING = $03
			SFX_WARP_DOOR_CLOSED = $04
			SFX_INVISIBILITY_ENDS = $05
			SFX_PLAYER_HIT = $06
			SFX_PLAYER_LAUNCH = $07
			SFX_WORLUK_KILLED = $08
			SFX_WORLUK_ESCAPED = $09
			SFX_WIZARD_ESCAPED = $0a
			SFX_WIZARD_KILLED = $0b
			SFX_NO_SFX = $80




	; screen ram locations
	SCR_04C8 = $04C8
	SCR_04CA = $04CA
	SCR_04EC = $04EC
	SCR_04ED = $04ED
	SCR_04F0 = $04F0
	SCR_04F2 = $04F2
	SCR_0500 = $0500
	SCR_0514 = $0514
	SCR_0515 = $0515
	SCR_0518 = $0518
	SCR_051A = $051A
	SCR_051B = $051B
	SCR_051C = $051C
	SCR_053A = $053A
	SCR_053B = $053B
	SCR_053C = $053C
	SCR_053E = $053E
	SCR_0540 = $0540
	SCR_0542 = $0542
	SCR_0564 = $0564
	SCR_0565 = $0565
	SCR_0568 = $0568
	SCR_056A = $056A
	SCR_058C = $058C
	SCR_058D = $058D
	SCR_0600 = $0600
	SCR_06AB = $06AB
	SCR_06AC = $06AC
	SCR_06AD = $06AD
	SCR_06C9 = $06C9
	SCR_06CA = $06CA
	SCR_06CB = $06CB
	SCR_06D3 = $06D3
	SCR_06D6 = $06D6
	SCR_06DD = $06DD
	SCR_06E7 = $06E7
	SCR_06E8 = $06E8
	SCR_06F0 = $06F0
	SCR_06F1 = $06F1
	SCR_0706 = $0706
	SCR_0728 = $0728
	SCR_072E = $072E
	SCR_073C = $073C
	SCR_0756 = $0756
	SCR_077E = $077E
	SCR_07A6 = $07A6
	SCR_07CE = $07CE


	SPRITE_PTR = $07F8

	nmi_handler = $1F47

	; calls of the Magic Voice interface
	MV_RESET = $C003
	MV_GET_STATUS = $C006
	MV_SAY_IT = $C009
	MV_SET_SPEED = $C00F
	MV_SET_SPEECH_TABLE = $C012
	MV_ENABLE_COMPLETION_CODE = $C015
	MV_COMPLETION_HOOK = $C018

	; chip registers
	VIC_S0X = $D000
	VIC_S0Y = $D001
	VIC_S1X = $D002
	VIC_S1Y = $D003
	VIC_D004 = $D004
	VIC_D005 = $D005
	VIC_D010 = $D010
	VIC_D011 = $D011
	VIC_D012 = $D012
	VIC_D015 = $D015
	VIC_D016 = $D016
	VIC_D019 = $D019
	VIC_D01C = $D01C
	VIC_D020 = $D020
	VIC_D021 = $D021
	VIC_D022 = $D022
	VIC_D023 = $D023
	VIC_D027 = $D027
	VIC_D028 = $D028
	VIC_D02B = $D02B

	SID_FrqLo1 = $D400
	SID_FrqHi1 = $D401
	SID_PulLo1 = $D402
	SID_PulHi1 = $D403
	SID_WV1 = $D404
	SID_AD1 = $D405
	SID_SR1 = $D406
	SID_PulLo2 = $D409
	SID_PulHi2 = $D40A
	SID_WV2 = $D40B
	SID_AD2 = $D40C
	SID_SR2 = $D40D
	SID_PulLo3 = $D410
	SID_PulHi3 = $D411
	SID_WV3 = $D412
	SID_AD3 = $D413
	SID_SR3 = $D414
	SID_FltLo = $D415
	SID_FltHi = $D416
	SID_Rsn_IO = $D417
	SID_FltMod_Vol = $D418
	SID_Osc = $D41B
	SID_Env = $D41C

	; color ram locations
	COL_D800 = $D800
	COL_D807 = $D807
	COL_D900 = $D900
	COL_D918 = $D918
	COL_D93E = $D93E
	COL_DA00 = $DA00
	COL_DAD3 = $DAD3
	COL_DADD = $DADD
	COL_DAE7 = $DAE7
	COL_DAE8 = $DAE8
	COL_DAF1 = $DAF1
	COL_DB00 = $DB00
	COL_DB06 = $DB06
	COL_DB28 = $DB28
	COL_DB2E = $DB2E
	COL_DB3C = $DB3C
	COL_DB56 = $DB56
	COL_DB7E = $DB7E
	COL_DBA6 = $DBA6
	COL_DBCE = $DBCE

	CIA1_JOY_KEY1 = $DC00
	CIA1_JOY_KEY2 = $DC01
	CIA1_IRQ = $DC0D
	CIA2_PORTA = $DD00

	KERNAL_IOINIT = $FF84

	; dungeon chars
	FLOOR = $0f
	MONSTER_CENTER = $63
	MONSTER_HEAD =  $38
	MONSTER_BULLET_H =  $42
	MONSTER_BULLET_V =  $43
	PLAYER_BULLET_H =  $40
	PLAYER_BULLET_V =  $41

	; sprites
	BOOM1 = $94
	BOOM2 = $95
	NO_SPRITE = $D6



;============================================================
;
; ACTUAL CODE
;
;============================================================

	; code start at $8000 because that's where the cartridge is mapped into the memory
	* = $8000

	; when the C64 powers on, the KERNAL routines look at $8000 to see if there is a header for a cartridge that takes over the boot process
	; this is that header

	 ; boot address
	.word start

	; nmi vector
	.word nmi_handler

	; magic signature "CBM80" - this is what the KERNAL looks for
	.enc "petscii"
	.text "CBM80"

	; end of header

start

	; various initialization routines

	; set up memory layout
	LDA #$57 ; RAM / CART / RAM / IO / KERNAL
	STA $01
	LDA #$2F
	STA $00

	; set up IRQ and NMI handlers
	SEI

	JSR copy_nmi_hander_to_ram
	PTR_SET $0318, nmi_handler

	PTR_SET $0314, irq_handler

	JSR init_sid_cia_mem
	JSR reset_scores
	JSR reset_per_dungeon_stuff

init_stuff ; nmi handler jumps here
	JSR create_sprites
	JSR init_cset

	; disable CIA IRQs
	LDA #$7F
	STA CIA1_IRQ
	LDA CIA1_IRQ ; clear any pending CIA IRQ

	; TODO: effectively clears bit 3 (userport data PA 2), but why?
	LDA #$93
	STA CIA2_PORTA

	CLI


	; The title screens

display_high_scores_and_enemies
	JSR vic_init

	; high score + copyright
	JSR clear_screen
	JSR display_copyright_and_high_scores
	LDX tmp_0090
	BNE start_game

	; the tables with the names, pictures and point values of the enemies
	JSR clear_screen
	JSR print_enemies_table
	LDX tmp_0090
	BNE start_game

	JSR clear_screen ; this seems to be superfluous
	JMP display_high_scores_and_enemies


start_game
	JSR reset_scores
	JSR clear_screen

start_dungeon
	;
	; all the stuff before the actual gameplay begins
	;

	; print the previous dungeon (except for the first one, of course) to use as background
	LDA current_dungeon
	BMI + ; skip if we have just started the game (dungeon = $ff)
	JSR draw_dungeon
+
	JSR select_dungeon_layout
	JSR reset_per_dungeon_stuff

	; GET READY ... GO
	JSR vic_init
	JSR get_ready_go_screen

	; DOUBLE SCORE DUNGEON / bonus player
	JSR clear_screen
	JSR check_double_score_and_bonus_life

	; prepare the screen
	JSR clear_screen
	JSR draw_playfield
	JSR draw_dungeon
	JSR draw_score_boxes
	JSR score.print
	JSR score.print.only_player2
	JSR draw_player1_lives
	JSR draw_player2_lives
	LDA #$01
	STA irq_timer_sec
	LDA #$80
	STA snd_ingame_status ; start in-game music

	; find out the title for this dungeon
	LDX #$05 ; title: radar
	LDA current_dungeon
	BEQ _print_fixed_title ; this is the first dungeon

	LDX #$02 ; title: the Arena
	LDA prev_dungeon_layout
	CMP #$18
	BEQ _print_fixed_title

	DEX      ; title: the Pit
	CMP #$17
	BEQ _print_fixed_title

	DEX      ; title: dungeon
	JSR print_radar_title

	; print dungeon number with one or two digits
	LDX current_dungeon
	INX
	TXA
	; count the tens
	LDX #$00
	SEC
-	INX
	SBC #$0A
	BCS -
	DEX
	; print the ones, with color
	ADC #$8D
	STA SCR_06E8
	LDA #$02
	STA COL_DAE8

	; print the tens, with color
	TXA
	BEQ _end_of_title_print ; no tens
	CLC
	ADC #$83
	STA SCR_06E7
	LDA #$02
	STA COL_DAE7
	BNE _end_of_title_print ; always branch

_print_fixed_title
	JSR print_radar_title
_end_of_title_print

	; say something appropriate
	LDA VIC_D012
	AND #$07
	TAX
	LDY MV_dungeon_start_tbl,X
	JSR magic_voice.say

normal_gameplay_loop
	;
	; the actual gameplay loop
	;

	; check keyboard (pause / easter egg)
	JSR check_keyboard

	; next actor
	INC actual_actor
	LDA actual_actor

	; update radar only when all but one actors are processed
	CMP #MAX_ACTORS-1
	BNE _no_radar_update
	JSR update_radar
_no_radar_update

	; move bullets
	JSR move_bullets

	; check if game is over
	LDA game_status
	CMP #STATUS_GAME_OVER
	BNE _no_game_over
	JSR game_over_screen
	JMP high_score.set
_no_game_over

	; keep the actual actor in the 0-7 range
	LDA actual_actor
	AND #$07
	STA actual_actor

	; update offset of X and Y coordinates of the actor's sprite
	; this is twice actor's number, as the 0. sprite's X is at D000, the 1. is at D002, the 2. at D004, etc
	TAX
	ASL A
	STA actor_sprite_pos_offset

	; update current monster status
	TXA
	AND #$FE
	STA is_monster

	; check if actor is dead
	LDA actor_type_tbl,X
	BPL _actor_not_dead ; it's not dead
	; actor is dead, no further processing is needed for it
	; this short busy loop is probably here to keep the game from being to fast with just a few (or a single) monsters
	LDY #$20
-	DEY
	BNE -
	BEQ normal_gameplay_loop ; always branch

_actor_not_dead
	BNE _actor_is_alive ; it's alive
	JMP actor_is_dying ; it's dying
_actor_is_alive

	; check if actor is hit by bullet
	JSR check_hitbox_of_current_actor

	; decrease animation timer for monsters - for players it's done in the IRQ handler
	LDX actual_actor
	LDA is_monster
	BEQ _is_player
	DEC animation_timer_tbl,X
	BEQ _do_monster_action
	BNE normal_gameplay_loop ; always branch


_is_player
	; check if player's animation counter has underflown - if so, reset the counter and move the player
	LDA animation_timer_tbl,X
	BPL normal_gameplay_loop ; no underflow, skip movement
	LDA #$00
	STA animation_timer_tbl,X
	JMP _handle_movement


_do_monster_action
	INC animation_counter_tbl,X

	; keep monster's speed from underflowing
	; also, if that happens be sure to disable invisibility
	LDA actor_speed_tbl,X
	BPL +
	LDA VIC_D015
	ORA power_of_2_tbl,X
	STA VIC_D015
	LDA #$00
	STA actor_speed_tbl,X
+
	TAY
	INY
	STY animation_timer_tbl,X

	; decide if monster should shoot
	;   50% chance of trying to shoot
	LDA random_number
	BPL _dont_shoot
	;   skip if it already has a bullet out there
	LDA bullet_direction,X
	BNE _dont_shoot
	;   skip if it already has a bullet out there by firin status TODO: isn't it redundant?
	LDA firing_status,X
	BNE _dont_shoot

	; shoot only if on the same row or column as one of the player - even numbered monsters shoot only P2, odd numbered ones p1
	LDA actor_sprite_pos_offset
	TAX
	AND #$02
	TAY
	LDA VIC_S0X,X
	CMP VIC_S0X,Y
	BEQ _shoot
	LDA VIC_S0Y,X
	CMP VIC_S0Y,Y
	BNE _dont_shoot
_shoot
	; it's been decided, shoot!
	LDX actual_actor
	JSR fire_bullet
	LDX actual_actor
	LDA firing_status,X
	AND #FIRING_BULLET_ACTIVE
	STA firing_status,X
	LDA bullet_char,X
	CLC
	ADC #$02
	STA bullet_char,X
	LDA #SFX_MONSTER_SHOOTS
	STA next_sfx_idx
_dont_shoot
	LDX actual_actor
	DEC once_in_a_while_timer,X ; it is the only place where this timer is accessed
	BEQ _turn_towards_player ; once in every while :)
	BNE _set_heading ; always branches


_turn_towards_player
	; monster turns towards a random player
	;   select random player
	LDA irq_timer_frame
	AND #$01
	TAY
	ASL A
	TAX

	;   set the player's position as the destination position
	LDA VIC_S0X,X
	STA monster_dest_x
	LDA VIC_S0Y,X
	STA monster_dest_y
	LDA power_of_2_tbl,Y
	AND VIC_D010
	BEQ +
	LDA #$01
+	STA monster_dest_9th
	;   get heading to the player
	JSR calculate_monster_heading
_set_heading
	LDA new_heading_y_tbl,X
	STA actor_heading_y
	LDA new_heading_x_tbl,X
	STA actor_heading_x

_handle_movement
	; this is where players join back
	JSR move_actor
	LDX actual_actor

	; periodically set a random heading
	LDA random_number
	BEQ _set_random_heading

	; also set a random heading if actor is stopped
	;   for players this has no effect as move_actor overwrites it with the joystick input
	;   for monsters it comes into play after they hit a wall
	LDA actor_heading_x
	ORA actor_heading_y
	BNE + ; keep heading as-is
_set_random_heading
	LDA VIC_D012
	AND #$01
	TAY
	LDA heading_tbl,Y
	STA new_heading_x_tbl,X
	LDA random_number
	LDX actual_actor
	LSR A
	AND #$01
	TAY
	LDA heading_tbl,Y
	STA new_heading_y_tbl,X
+

	JSR warp_door_handler
	JSR check_if_monster_can_be_invisible
	JSR check_hitbox_of_current_actor
	JMP normal_gameplay_loop



ninth_bit_heading_tbl .byte $00,$01,$FF,$00

heading_tbl	= ninth_bit_heading_tbl+1 ; effectively .byte $01,$FF


MV_dungeon_start_tbl	.byte $01,$03,$04,$05,$09,$0E,$13,$05

; -----------------------------------------

	; TODO: this should be in the "magic voice" block

MV_tbl
	; this is a custom vocabulary table for the Magic Voice
	; words use big-endian order
	;
	.word ><MV_tbl_end-MV_tbl ; size of the table ($4c, $24 entries)
	.byte $FF,$20 ; unknown
	; a list of offsets (from the beginning of this table) to the speech data for each word
	_ = (MV_word_0,MV_word_1,MV_word_2,MV_word_3,MV_word_4,MV_word_5,MV_word_6,MV_word_7,MV_word_8,MV_word_9,MV_word_10,MV_word_11,MV_word_12,MV_word_13,MV_word_14,MV_word_15,MV_word_16,MV_word_17,MV_word_18,MV_word_19,MV_word_20,MV_word_21,MV_word_22,MV_word_23,MV_word_24,MV_word_25,MV_word_26,MV_word_27,MV_word_28,MV_word_29,MV_word_30,MV_word_31,MV_word_32,MV_word_33,MV_word_34,MV_word_35) - MV_tbl
	.word ><_
MV_tbl_end
	; end of table marker
	.word $0000

	; the speech data - seems like the first byte is always $4a
MV_word_0
	.byte $4a,$43,$ee,$93,$61,$60,$63,$0f,$ea,$f9,$db,$bd,$f5,$82,$71,$76,$12,$b0,$28,$63,$d7,$de,$c7,$fe,$8b,$bf,$8f,$93,$9a,$e2,$68,$00
	.byte $72,$a1,$00,$94,$9d,$c7,$a6,$2f,$d1,$2c
MV_word_1
	.byte $4a,$03,$e7,$f9,$3b,$31,$96,$24,$20,$3e,$14,$5e,$0e,$05,$4a,$25,$82,$40,$67,$f9
MV_word_2
	.byte $4a,$6b,$78,$af,$2f,$f3,$cf,$35,$80,$93,$e2,$6a,$09,$20,$3c,$89,$29,$23,$6d,$d3,$5f,$e6,$02,$a6,$f1,$3d,$28,$00,$58,$f9,$97,$cf
	.byte $36,$05,$f0,$a5,$82,$32,$69,$10,$af,$73,$ea,$6d,$35,$b5,$04,$00,$04,$61,$a4,$dc,$f5,$ab,$01,$3c,$d5,$2c
MV_word_3
	.byte $4a,$83,$eb,$99,$21,$b6,$b7,$33,$02,$08,$4f,$d4,$60,$61,$a0,$94,$49,$c6,$de,$8c,$b2,$a7,$1c,$b1,$d3,$d8,$f9,$b1,$bc,$cb,$9b,$e2
	.byte $2d,$f5,$d6,$3a,$7d,$79,$b8,$00,$00,$76,$45,$d9,$0b,$28,$8d,$bd,$59,$5a,$ad,$52,$9e,$c7,$d1,$db,$db,$2e,$8f,$25,$01,$00,$50,$d6
	.byte $56,$fb,$bd,$b4,$76,$b9,$ec,$77,$96
MV_word_4
	.byte $4a,$83,$f0,$f9,$0c,$e4,$35,$d5,$11,$c1,$d5,$04,$01,$12,$d5,$db,$9a,$2f,$b5,$7a,$99,$46,$e1,$65,$fd,$7b,$92,$c4,$67,$4f,$8a,$c7
	.byte $16,$82,$00,$65,$13,$5f,$47,$7c,$3c,$0c,$bb,$82,$02,$40,$d9,$8b,$d8,$9b,$ad,$d5,$2e
MV_word_5
	.byte $4a,$43,$e4,$99,$c7,$56,$4a,$6a,$e2,$ab,$f1,$29,$ae,$88,$b2,$fc,$7a,$28,$0a,$99,$f5,$f3,$b8,$9a,$80,$46,$97,$80,$b0,$91,$0b,$e4
	.byte $1c,$00,$94,$35,$1c,$9b,$5e,$d6,$50,$3b,$b7,$fc
MV_word_6
	.byte $4a,$c3,$d3,$27,$43,$cb,$9a,$e2,$8d,$e3,$1d,$e3,$be,$71,$1d,$00,$40,$78,$20,$6a,$84,$ae,$30,$c4,$dc,$eb,$ad,$20,$65,$cd,$db,$8e
	.byte $78,$5c,$9d,$04,$00,$43,$b0,$b6,$de,$f5,$a3,$70,$48,$64,$93,$44,$23,$4f,$b9,$29,$56,$dd,$cb,$7d,$93,$24,$e0,$0c,$00,$42,$05,$ec
	.byte $02,$f6,$b8,$ca,$2e,$46,$3f,$2e,$7c,$3c,$c5,$c9,$97,$d3,$03,$18,$a2,$e6,$fc,$55,$bf,$cd,$8a,$b8,$d3,$08,$3d,$41,$d9,$55,$6c,$88
	.byte $4d,$57,$5a,$51,$f6,$74,$6c,$b7,$c6,$8f,$06,$bc,$73,$f9,$76,$9c,$f1,$49,$12,$a1,$2a,$31,$5b,$b4,$d6,$5a,$05,$0a,$23,$8c,$f5,$8d
	.byte $97,$1d,$f7,$36,$c5,$43,$fc,$22,$89,$84,$31,$32,$00,$14,$36,$c7,$86,$c6,$ce,$aa,$6b,$f9
MV_word_7
	.byte $4a,$c3,$df,$4f,$1f,$93,$96,$cf,$ae,$14,$3f,$1f,$0b,$13,$1c,$18,$99,$e0,$ac,$f5,$91,$e9,$04,$27,$3d,$ae,$06,$08,$4f,$48,$86,$3e
	.byte $24,$80,$32,$4b,$cc,$1b,$0f,$3d,$7e,$1e,$29,$07,$00,$00,$ec,$71,$34,$d6,$30,$e6,$5c,$5a,$6b,$c8,$f2
MV_word_8
	.byte $4a,$83,$ee,$79,$3d,$b6,$12,$f1,$91,$00,$52,$0e,$0a,$43,$00,$94,$b5,$d5,$26,$6a,$2d,$7c,$02,$d2,$82,$4c,$fb,$52,$ad,$bc,$e6,$7c
	.byte $b4,$b8,$25,$4e,$60,$79,$7c,$a2,$de,$f6,$4a,$91,$18,$00,$0a,$2b,$67,$bf,$63,$6d,$b5,$c6,$6d,$ce,$b5,$fc
MV_word_9
	.byte $4a,$43,$d3,$d3,$c7,$e2,$2d,$75,$d2,$ed,$bc,$20,$3e,$00,$89,$09,$c9,$c4,$e7,$5e,$2f,$85,$7b,$9b,$8e,$5a,$db,$af,$24,$c5,$73,$24
	.byte $29,$8e,$0b,$46,$e6,$20,$8c,$0d,$2b,$a0,$00,$91,$9a,$57,$a2,$84,$20,$52,$65,$0f,$c7,$4a,$8f,$66,$f9
MV_word_10
	.byte $4a,$c3,$dc,$63,$68,$5f,$3c,$e7,$92,$f6,$34,$0e,$8e,$a0,$85,$23,$54,$d1,$d9,$54,$24,$08,$88,$4a,$a6,$40,$a1,$14,$9a,$fb,$79,$74
	.byte $ad,$bf,$e2,$4f,$c7,$a7,$9b,$b8,$a4,$ce,$5b,$49,$82,$90,$24,$66,$e8,$65,$a1,$3a,$67,$79,$08,$80,$b2,$32,$68,$ee,$75,$69,$4d,$d6
	.byte $82,$c7,$0b,$17,$c2,$76,$c4,$42,$e8,$60,$64,$2a,$01,$e5,$73,$d0,$48,$d4,$2c,$b5,$87,$e7,$5e,$47,$ad,$b9,$c7,$23,$4d,$52,$24,$37
	.byte $49,$3c,$82,$04,$e4,$51,$02,$e0,$d7,$50,$58,$19,$8d,$1d,$2e,$bd,$70,$c6,$8f,$f8,$9c,$d1,$24,$11,$1d,$66,$a6,$35,$6a,$94,$70,$9c
	.byte $ba,$dc,$17,$00,$54,$02,$48,$4c,$78,$00,$18,$89,$8e,$a1,$8f,$61,$d6,$dd,$45,$f9,$b1,$fc
MV_word_11
	.byte $4a,$03,$f9,$f9,$79,$2c,$29,$8e,$03,$42,$c7,$d4,$0c,$fd,$dc,$b9,$cc,$40,$50,$b0,$b6,$df,$9e,$33,$a4,$38,$ae,$e0,$20,$25,$6c,$65
	.byte $05,$c1,$a4,$c4,$8b,$46,$29,$9b,$1e,$db,$3d,$ca,$7f,$71,$da,$c7,$a3,$4d,$45,$19,$22,$f7,$bd,$49,$b0,$8e,$ce,$da,$fd,$f1,$f3,$f8
	.byte $6c,$f1,$50,$90,$a0,$73,$58,$10,$00,$4e,$85,$93,$80,$45,$29,$7b,$5b,$bb,$7d,$db,$d3,$26,$29,$29,$89,$eb,$8e,$33,$16,$09,$a6,$03
	.byte $e0,$3c,$42,$12,$1e,$18,$02,$36,$34,$1a,$3b,$ab,$de,$00,$8e,$f8,$e3,$ea,$4a,$18,$c3,$91,$30,$46,$06,$c6,$be,$cd,$7e,$9c,$7e,$39
	.byte $79,$03,$00,$a0,$64,$ce,$86,$a2,$b1,$b3,$65,$ef,$dd,$b3,$50,$08,$a2,$e5
MV_word_12
	.byte $4a,$03,$e3,$31,$98,$f7,$9b,$24,$09,$20,$0c,$31,$83,$e8,$40,$89,$d9,$8e,$68,$94,$4d,$45,$a1,$ec,$91,$bb,$1e,$0d,$a4,$ae,$bf,$b7
	.byte $33,$76,$92,$24,$00,$e6,$83,$ba,$ff,$fe,$28,$70,$c5,$0e,$c5,$da,$fe,$78,$4e,$93,$24,$71,$5c,$95,$83,$84,$ad,$ac,$00,$28,$91,$82
	.byte $79,$61,$f9,$2c,$37,$56,$5a,$8d,$2e,$7c,$ee,$e5,$e4,$24,$49,$02,$4e,$a7,$0c,$c1,$a2,$74,$6c,$3a,$d6,$02,$90,$5d,$a5,$d5,$68,$3d
	.byte $8f,$13,$38,$fd,$93,$e2,$38,$4e,$96,$28,$14,$d8,$15,$21,$cb,$90,$06,$cd,$bd,$6e,$c5,$da,$76,$39,$e9,$f1,$98,$14,$69,$43,$62,$c6
	.byte $89,$a1,$8f,$e5,$dd,$6e,$ab,$b7,$dd,$69,$00,$65,$c3,$cc,$b2,$6c,$02,$d8,$2e,$f0,$f2,$d1,$98,$f3,$d1,$2c
MV_word_13
	.byte $4a,$2b,$be,$68,$9f,$19,$b6,$17,$1f,$bc,$9c,$d1,$04,$00,$f3,$c5,$b6,$97,$fd,$3e,$ba,$96
MV_word_14
	.byte $4a,$43,$fb,$d3,$c7,$8e,$e7,$4c,$e2,$ec,$e5,$20,$2b,$e4,$68,$46,$85,$a9,$00,$00,$0a,$c0,$8e,$20,$2a,$a5,$b4,$d6,$b8,$74,$34,$b8
	.byte $f0,$63,$ed,$1c,$b7,$13,$47,$44,$d4,$00,$c2,$b3,$18,$8b,$e6,$5e,$bf,$ca,$53,$b9,$f6,$b2,$fc
MV_word_15
	.byte $4a,$83,$e5,$e9,$10,$5d,$c0,$c1,$db,$c9,$4d,$50,$a0,$e4,$4a,$39,$99,$5d,$21,$51,$ca,$86,$e8,$1b,$67,$bc,$dc,$57,$f1,$3b,$a3,$c2
	.byte $11,$15,$c2,$b1,$50,$6c,$b6,$f6,$f7,$22,$f1,$d9,$71,$70,$25,$86,$63,$64,$24,$ca,$30,$cb,$2c,$1c,$b1,$9c,$1e,$e1,$25,$80,$e8,$cc
	.byte $c7,$ca,$63,$97,$63,$ce,$6d,$bf,$2d
MV_word_16
	.byte $4a,$c3,$c4,$d3,$e9,$e1,$12,$9c,$f4,$f5,$58,$13,$00,$00,$f3,$c1,$cb,$29,$fb,$34,$d6,$38,$fa,$01,$58,$6b,$5c,$59,$cf,$1e,$47,$2c
	.byte $51,$3b,$02,$a0,$ec,$ed,$a3,$1f,$d6,$54,$99,$2c
MV_word_17
	.byte $4a,$2b,$be,$08,$9f,$6f,$18,$da,$38,$79,$27,$00,$49,$a2,$6c,$ae,$fa,$03,$ac,$05,$05,$6b,$f7,$e5,$e8,$2b,$49,$84,$21,$1c,$50,$16
	.byte $64,$f9,$f5,$60,$84,$e3,$a4,$08,$db,$e6,$28,$65,$43,$b1,$d6,$da,$d3,$a0,$b4,$ba,$70,$c4,$cb,$d5,$2b,$49,$00,$40,$10,$0a,$8b,$b2
	.byte $b6,$da,$f4,$60,$4f,$83,$b2,$5f,$d5,$38,$6d,$7e,$39,$8a,$35,$67,$a7,$49,$49,$49,$70,$5c,$c0,$41,$c6,$66,$05,$01,$f3,$52,$58,$e9
	.byte $68,$ec,$c1,$c8,$96,$0e,$9e,$1b,$79,$e0,$b9,$4d,$3c,$92,$14,$97,$2e,$2f,$ac,$b3,$03,$82,$16,$92,$51,$29,$9b,$0a,$a0,$94,$3d,$02
	.byte $76,$4d,$97,$ee,$f5,$10,$00,$d1,$4a,$fd,$e3,$0c,$20,$3a,$f1,$e1,$3c,$60,$6a,$82,$30,$ba,$c4,$c2,$64,$4e,$63,$2d,$c7,$9e,$c2,$7e
	.byte $8d,$c5,$c9,$44,$1a,$7d,$bc,$a9,$de,$b2,$bc,$35,$09,$4e,$3e,$24,$0a,$00,$64,$ce,$ae,$28,$19,$b2,$2b,$f6,$62,$db,$9b,$b1,$d6,$2c
MV_word_18
	.byte $4a,$c3,$9b,$a7,$8f,$c5,$5b,$c7,$49,$b7,$f3,$00,$00,$20,$3e,$00,$14,$60,$41,$80,$3d,$2a,$48,$d0,$ae,$8f,$35,$e6,$7e,$8e,$62,$6d
	.byte $1f,$cf,$d9,$69,$12,$c7,$05,$25,$a0,$b1,$09,$da,$0a,$08,$07,$f3,$42,$59,$01,$7b,$b8,$75,$e1,$e0,$d7,$e7,$8e,$d3,$23,$08,$00,$2b
	.byte $67,$88,$9a,$f3,$a5,$85,$75,$97,$46,$bb,$5a,$78,$01,$2f,$dc,$4e,$da,$29,$6e,$86,$53,$49,$0c,$00,$ac,$ed,$b1,$df,$5b,$17,$ac,$b2
	.byte $56,$1c,$47,$dc,$29,$09,$48,$9b,$c6,$d0,$47,$c7,$d9,$e3,$f4,$25,$73,$28,$19,$c2,$26,$58,$fe,$58,$69,$94,$e7,$d7,$af,$eb,$a1,$fa
	.byte $45,$84,$ad,$b0,$39,$8a,$c4,$ae,$24,$42,$b6,$b9,$5b,$f7,$ea,$38,$2c,$49,$00,$df,$60,$89,$12,$8b,$96
MV_word_19
	.byte $4a,$03,$f9,$f9,$19,$70,$6b,$e2,$61,$82,$43,$09,$a8,$31,$f4,$6d,$ae,$d1,$02,$ac,$b2,$e6,$9c,$b4,$92,$24,$05,$c7,$05,$12,$94,$80
	.byte $c6,$26,$68,$94,$2c,$99,$97,$02,$65,$f9,$b5,$d2,$ea,$68,$01,$00,$7c,$fe,$e5,$e4,$3a,$2e,$1e,$e6,$6a,$80,$21,$68,$ef,$f5,$a3,$70
	.byte $48,$fc,$23,$48,$dc,$51,$2b,$f8,$03,$ca,$0a,$81,$22,$01,$25,$4b,$e6,$ad,$95,$1e,$a5,$0b,$80,$b5,$ac,$83,$ef,$14,$f7,$45,$18,$32
	.byte $68,$c1,$e0,$1c,$89,$b2,$10,$94,$e6,$ae,$8f,$39,$8e,$95,$b3,$5d,$ba,$5d,$85,$04,$fc,$08,$28,$a5,$94,$2e,$fb,$e7,$b1,$46,$cb
MV_word_20
	.byte $4a,$83,$f9,$f9,$3e,$b6,$13,$40,$18,$88,$59,$a8,$a0,$ec,$88,$42,$81,$c2,$a6,$62,$47,$ac,$71,$d9,$d7,$a5,$61,$35,$89,$68,$45,$7c
	.byte $9c,$dd,$24,$41,$e8,$89,$cd,$01,$65,$57,$e7,$97,$4b,$39,$64,$04,$05,$f8,$70,$65,$45,$bc,$52,$84,$2d,$74,$10,$76,$82,$92,$0b,$50
	.byte $28,$cb,$9e,$fb,$f9,$28,$d6,$c2,$b7,$9b,$27,$01,$14,$42,$c5,$38,$74,$ee,$f5,$75,$51,$8a,$b5,$fd,$f2,$1c,$29,$24,$8e,$2b,$0e,$52
	.byte $c2,$b6,$82,$00,$26,$95,$28,$cc,$cb,$f2,$a1,$ee,$e7,$52,$6b,$cb,$f6,$a5,$e2,$d4,$a6,$71,$73,$c0,$79,$30,$35,$0c,$11,$cd,$fd,$bd
	.byte $25,$90,$c8,$ae,$6d,$af,$34,$48,$0c,$84,$2a,$1c,$a1,$82,$4d,$45,$54,$5a,$3b,$3a,$77,$1d,$14,$f2,$96
MV_word_21
	.byte $4a,$c3,$fc,$93,$01,$dc,$e5,$39,$c5,$c1,$85,$15,$92,$25,$3b,$92,$98,$8a,$73,$80,$87,$28,$9b,$dd,$56,$7b,$2b,$70,$e9,$cb,$55,$93
	.byte $90,$48,$10,$40,$a1,$d0,$28,$7b,$14,$97,$12,$8e,$5d,$c7,$2c,$ac,$15,$d6,$12,$dc,$cd,$f5,$ec,$bf,$dc,$ef,$78,$57,$69,$35,$0e,$c5
	.byte $3a,$d0,$24,$8d,$4b,$57,$aa,$a3,$83,$70,$50,$26,$65,$53,$44,$05,$09,$72,$84,$d2,$a2,$10,$15,$7e,$34,$ae,$aa,$eb,$02,$88,$0f,$44
	.byte $87,$98,$51,$42,$02,$34,$ca,$e8,$0c,$41,$61,$67,$31,$c3,$d8,$8b,$d1,$e2,$92,$78,$f8,$93,$ea,$38,$e0,$20,$53,$53,$46,$87,$45,$c7
	.byte $5a,$23,$d3,$28,$bc,$95,$b7,$8d,$e6,$3e,$b7,$f2,$b2,$5a,$92,$38,$e9,$e5,$66,$24,$38,$89,$a1,$63,$92,$cb,$2c,$cb,$6c,$b4,$ee,$7a
	.byte $9c,$fd,$45,$d0,$66,$86,$90,$d0,$98,$e5,$58,$2b,$23,$50,$de,$ce,$c1,$49,$4d,$11,$b4,$52,$68,$cc,$52,$9b,$8e,$b4,$82,$52,$d6,$12
	.byte $23,$c4,$c5,$73,$cf,$f2,$8d,$7f,$96
MV_word_22
	.byte $4a,$c3,$f9,$f3,$19,$d8,$5b,$5e,$58,$e1,$88,$59,$a8,$89,$82,$04,$e1,$80,$b2,$10,$a5,$31,$6f,$b5,$12,$f1,$92,$f1,$d5,$ba,$3f,$b6
	.byte $2a,$b1,$92,$00,$ae,$e2,$41,$e0,$21,$28,$b0,$32,$28,$f3,$d4,$6a,$1e,$5d,$ae,$7e,$a7,$a6,$02,$80,$f0,$c0,$48,$34,$86,$1e,$6b,$0d
	.byte $0a,$6b,$89,$35,$55,$e3,$ef,$6f,$6b,$5b,$77,$1d,$0d,$80,$9b,$44,$bc,$4a,$2f,$2f,$dc,$72,$84,$23,$61,$25,$05,$70,$69,$40,$69,$2d
	.byte $32,$a4,$a6,$24,$ee,$af,$ad,$b2,$08,$25,$25,$80,$44,$3c,$18,$97,$92,$90,$92,$32,$94,$c2,$3c,$b5,$86,$5b,$c3,$aa,$59,$71,$ef,$c4
	.byte $c8,$d1,$18,$8e,$91,$f7,$7d,$b2,$4a,$3e,$8e,$1e,$c4,$0c,$46,$65,$ba,$98,$74,$c9,$12,$80,$d2,$58,$b9,$5f,$f6,$8a,$fb,$49,$49,$01
	.byte $65,$e0,$32,$04,$6b,$8d,$b2,$09,$1a,$e1,$a7,$3a,$fb,$49,$90,$a8,$a1,$ab,$c7,$f4,$4d,$71,$f4,$e5,$a4,$88,$d9,$0a,$a2,$b5,$bc,$af
	.byte $4b,$b7,$1f,$ed,$04,$a5,$4c,$05,$b0,$23,$4a,$59,$57,$b1,$dc,$71,$55,$ac,$71,$94,$5d,$5b,$fe
MV_word_23
	.byte $4a,$6b,$e5,$cb,$83,$a7,$43,$64,$27,$25,$f1,$92,$48,$24,$f1,$d5,$b8,$9f,$ad,$42,$a4,$20,$21,$91,$ca,$92,$14,$92,$c8,$91,$a9,$20
	.byte $47,$88,$0a,$39,$12,$15,$89,$05,$c9,$94,$07,$99,$14,$12,$b2,$32,$ca,$1e,$f3,$72,$5a,$9b,$be,$ec,$57,$1d,$5c,$32,$7d,$d7,$51,$00
	.byte $2b,$f8,$37,$11,$9c,$91,$01,$00,$24,$a8,$44,$09,$ce,$c0,$fc,$f2,$32,$88,$cc,$56,$cd,$ed,$8a,$78,$49,$01,$7c,$35,$b8,$9f,$3d,$8a
	.byte $0c,$28,$8d,$46,$93,$e2,$91,$fa,$40,$20,$01,$2c,$02,$7c,$15,$12,$c4,$af,$49,$48,$49,$99,$f2,$f2,$28,$3b,$67,$e5,$94,$59,$46,$19
	.byte $81,$b2,$a6,$5a,$9c,$25,$ea,$d3,$17,$f6,$ff,$b2,$f3,$59,$fe
MV_word_24
	.byte $4a,$43,$fb,$73,$f2,$a4,$78,$ce,$a3,$1c,$17,$07,$a3,$8c,$cd,$0a,$80,$48,$01,$30,$2f,$1b,$a8,$e5,$8e,$6e,$70,$c6,$6f,$4a,$92,$a0
	.byte $4c,$fa,$d5,$0d,$e0,$b3,$77,$5a,$1e,$aa,$4b,$91,$28,$29,$30,$0e,$f3,$c6,$2c,$ee,$bf,$b7,$f2,$e1,$2c,$6f,$29,$60,$c4,$a6,$06,$cd
	.byte $f2
MV_word_25
	.byte $4a,$c3,$f9,$73,$0f,$e0,$1e,$c1,$25,$80,$4a,$50,$80,$80,$86,$8e,$49,$07,$1f,$e0,$05,$43,$8a,$a3,$09,$28,$6a,$00,$90,$0b,$84,$2d
	.byte $17,$00,$80,$52,$4a,$63,$0d,$47,$47,$a9,$7b,$65,$f9
MV_word_26
	.byte $4a,$43,$fb,$33,$8f,$c5,$73,$76,$82,$e3,$92,$08,$88,$b1,$09,$da,$0a,$22,$4b,$e6,$45,$02,$60,$f9,$49,$ac,$34,$7a,$2b,$9c,$f1,$4e
	.byte $4d,$52,$00,$00,$84,$83,$f2,$0b,$a8,$fb,$fc,$51,$6a,$75,$c6,$7e,$f1,$a6,$26,$de,$52,$57,$5f,$ce,$2b,$98,$0f,$89,$02,$00,$b0,$20
	.byte $14,$4a,$54,$36,$05,$65,$b9,$b1,$08,$cb,$9d,$fb,$59,$1a,$60,$25,$7f,$d2,$72,$5c,$12,$65,$64,$4e,$8f,$c6,$10,$31,$cb,$98,$33,$f8
	.byte $04,$94,$14,$08,$e9,$ae,$47,$ad,$5e,$72,$df,$31,$71,$dd,$4b,$3a,$fc,$9a,$07,$81,$b2,$dc,$51,$5a,$1b,$88,$92,$5c,$7f,$20,$05,$cf
	.byte $9d,$c4,$07,$82,$fb,$ab,$ec,$9a,$94,$81,$cd,$c6,$97,$28,$39,$72,$15,$09,$5a,$24,$96,$cb,$23,$f0,$12,$ae,$0a,$2e,$85,$85,$24,$0a
	.byte $9b,$a5,$d1,$b1,$dd,$e3,$92,$f9,$65,$81,$16,$77,$56,$f6,$db,$79,$83,$98,$41,$48,$ca,$10,$c7,$2c,$31,$02,$25,$16,$9f,$e3,$f3,$15
	.byte $30,$d5,$11,$90,$a8,$90,$34,$1a,$6b,$59,$42,$40,$61,$2d,$2c,$3e,$72,$1b,$0d,$eb,$23,$57,$36,$49,$94,$85,$2c,$cb
MV_word_27
	.byte $4a,$43,$ce,$d3,$a1,$7d,$27,$8d,$83,$c7,$0a,$49,$01,$22,$b5,$20,$e7,$30,$15,$64,$ca,$a9,$21,$31,$0e,$65,$a1,$ca,$f9,$bd,$de,$0a
	.byte $7c,$25,$89,$d2,$e0,$ca,$8a,$7e,$b9,$7a,$61,$38,$0e,$32,$3a,$43,$50,$46,$67,$88,$fe,$72,$db,$92,$ab,$01,$56,$e9,$d7,$0b,$46,$a4
	.byte $80,$12,$af,$52,$ca,$a6,$ab,$17,$ab,$63,$a2,$60,$9d,$7b,$39,$79,$92,$c4,$e9,$40,$29,$25,$51,$94,$d2,$68,$ee,$ef,$92,$55,$12,$05
	.byte $ac,$e6,$6f,$5a,$29,$ce,$20,$3a,$05,$a0,$9c,$c4,$78,$30,$cb,$63,$ad,$b0,$16,$58,$53,$b4,$56,$1b,$b5,$96,$35,$f9,$f1,$c1,$93,$22
	.byte $3e,$00,$50,$24,$28,$8f,$41,$21,$08,$05,$4a,$e6,$94,$52,$46,$db,$96,$77,$5c,$5f,$67,$5f,$36,$71,$4c,$3e,$cb
MV_word_28
	.byte $4a,$43,$e8,$c9,$50,$b0,$af,$17,$f2,$02,$40,$02,$a0,$14,$80,$49,$69,$f4,$e8,$81,$d5,$f1,$5e,$96,$91,$c5,$3e,$b2,$0a,$b5,$9a,$7f
	.byte $d2,$00,$a6,$03,$e2,$43,$74,$e0,$bc,$80,$32,$12,$8b,$56,$6b,$13,$4b,$b7,$ff,$e2,$4f,$9b,$ea,$4b,$c5,$75,$3b,$45,$a8,$a2,$c3,$63
	.byte $00,$65,$6d,$bd,$df,$b7,$05,$90,$98,$c8,$90,$ac,$f8,$ed,$ea,$1b,$70,$1e,$00,$30,$12,$8b,$c5,$bc,$97,$46,$c4,$a6,$8f,$0e,$ab,$08
	.byte $b0,$46,$ae,$34,$e0,$03,$24,$5f,$3a,$b0,$f1,$63,$95,$8f,$34,$b9,$64,$fc,$e2,$4a,$07,$f1,$01,$12,$d3,$65,$96,$97,$c6,$5d,$1f,$6f
	.byte $9b,$14,$27,$45,$29,$19,$b6,$dd,$0d,$0a,$8d,$bf,$a5,$0f,$80,$17,$c4,$cd,$4f,$7a,$12,$12,$10,$2a,$76,$14,$53,$c5,$4a,$8e,$45,$a2
	.byte $f1,$01,$1e,$89,$97,$34,$35,$05,$7c,$35,$00,$36,$05,$00,$94,$ab,$28,$39,$b2,$29,$72,$a4,$e7,$7e,$1f,$5f,$60,$ca,$f2
MV_word_29
	.byte $4a,$83,$e6,$79,$3d,$c6,$11,$cb,$d1,$84,$24,$3a,$31,$8b,$4e,$01,$c6,$19,$5b,$0a,$28,$ac,$a5,$1a,$3b,$59,$ee,$dd,$ae,$bb,$3d,$06
	.byte $00,$04,$01,$16,$5e,$76,$f9,$56,$ac,$93,$44,$a3,$c0,$4d,$20,$11,$af,$d2,$cb,$23,$05,$48,$f0,$01,$ee,$8f,$3d,$8a,$07,$21,$21,$eb
	.byte $88,$94,$d9,$df,$97,$2e,$e5,$a5,$9c,$b0,$bc,$85,$2f,$15,$57,$1d,$99,$c2,$57,$59,$24,$3e,$00,$b0,$08,$90,$47,$24,$7e,$0d,$09,$49
	.byte $19,$4a,$59,$43,$b4,$ba,$ec,$a0,$1a,$00,$f0,$07,$12,$97,$5e,$a9,$8e,$1e,$07,$e1,$74,$08,$5b,$49,$54,$49,$9b,$46,$47,$69,$b5,$a6
	.byte $8f,$4d,$d0,$90,$48,$9e,$2c,$78,$e3,$76,$d2,$c7,$63,$00,$84,$64,$31,$4a,$59,$39,$fb,$5d,$5d,$ba,$96
MV_word_30
	.byte $4a,$43,$fb,$73,$0d,$e4,$8d,$e3,$92,$02,$02,$0a,$5b,$59,$01,$40,$bc,$ca,$a5,$c4,$8b,$e5,$07,$cb,$ad,$95,$b2,$ef,$47,$0b,$b0,$7a
	.byte $a5,$ac,$98,$e5,$e1,$e3,$08,$88,$9a,$04,$05,$c2,$c3,$48,$b1,$e9,$0d,$32,$61,$d3,$ee,$5a,$3a,$78,$f8,$22,$51,$1a,$67,$ad,$a4,$3b
	.byte $8d,$c7,$98,$8f,$c7,$88,$4f,$62,$12,$42,$2e,$c0,$1e,$c7,$cf,$d9,$e5,$b6,$a7,$b7,$e6,$b7,$cb,$bc,$4c,$5d,$db,$5e,$4e,$6d,$8a,$93
	.byte $00,$5a,$5d,$66,$61,$2d,$91,$37,$d2,$82,$83,$27,$35,$41,$61,$17,$1c,$4d,$61,$16,$e6,$05,$a8,$e5
MV_word_31
	.byte $4a,$03,$e7,$b9,$07,$ea,$9e,$14,$44,$87,$c4,$50,$58,$74,$eb,$17,$56,$f3,$8d,$39,$0a,$70,$ac,$ae,$78,$5b,$7d,$f5,$91,$48,$e2,$ab
	.byte $12,$40,$82,$48,$08,$29,$d3,$d8,$e3,$58,$c3,$58,$cd,$b2,$5f,$f5,$6a,$29,$de,$14,$e7,$bd,$12,$00,$10,$1f,$0a,$00,$44,$a7,$6c,$2a
	.byte $76,$5d,$ad,$95,$3e,$1a,$6f,$9f,$b4,$3c,$27,$29,$89,$83,$63,$05,$cc,$8b,$04,$00,$24,$84,$95,$45,$a3,$d5,$a5,$0b,$d6,$50,$4e,$d6
	.byte $b6,$ed,$85,$c7,$66,$41,$0a,$e0,$4b,$00,$14,$00,$e6,$0d,$58,$e9,$ba,$9f,$ad,$96
MV_word_32
	.byte $4a,$ab,$7c,$91,$3c,$6b,$08,$ef,$43,$92,$08,$0e,$50,$1a,$1b,$1a,$93,$3d,$cb
MV_word_33
	.byte $4a,$eb,$e1,$ca,$17,$c5,$f3,$7e,$2c,$09,$a0,$50,$16,$59,$b6,$77,$69,$97
MV_word_34
	.byte $4a,$c3,$c4,$63,$b0,$2c,$3e,$11,$6f,$bb,$9d,$57,$67,$c0,$d5,$00,$40,$d9,$c4,$8f,$89,$b3,$12,$53,$15,$ac,$b9,$db,$23,$e3,$25,$e3
	.byte $aa,$a4,$b8,$99,$51,$b9,$8e,$50,$01,$84,$24,$51,$8d,$d6,$26,$6a,$6f,$d9,$7f,$e7,$7e,$6b,$4b,$a2,$60,$d5,$5c,$4e,$bd,$52,$94,$e8
	.byte $00,$e5,$c3,$c1,$2e,$a2,$cc,$b2,$64,$02,$00,$00,$00,$b0,$5d,$ca,$f9,$35,$e7,$d2,$b3,$fc
MV_word_35
	.byte $4a,$83,$f9,$79,$4f,$be,$25,$ae,$8b,$53,$23,$e6,$04,$00,$8c,$4a,$d9,$51,$74,$6c,$a9,$ba,$4c,$4f,$0b,$eb,$bf,$ac,$8d,$93,$f8,$1d
	.byte $5e,$d2,$94,$84,$04,$5f,$0d,$40,$02,$58,$09,$0f,$02,$c0,$39,$2c,$04,$b0,$32,$1a,$6b,$78,$34,$1a,$cd,$f2,$00


; -----------------------------------------

vic_init .proc
	; initialize VIC and set the initial positions for the monsters

	LDY #$22
_copy
	LDA _vic_contents,Y
	STA $D004,Y
	DEY
	BPL _copy
	RTS
_vic_contents
	.byte $4F,$4D,$7F,$35,$97,$7D,$C7,$4D
	.byte $F7,$35,$0F,$65,$80,$1B,$1B,$00
	.byte $00,$00,$1F,$00,$12,$00,$01,$00
	.byte $00,$00,$00,$00,$00,$00,$06,$06
	.byte $00,$0A,$0E

.pend

; -----------------------------------------

clear_screen .proc
	; clear screen
	LDX #$00
	TXA
_clr_scr
	STA $0400,X
	STA $0500,X
	STA $0600,X
	STA $06E8,X
	DEX
	BNE _clr_scr
	RTS
.pend

; -----------------------------------------

draw_playfield .proc
	; it draws the parts of the playfield that are the same for every dungeon: the side borders, doos, player cages and the radar box

	screen_ptr = tmp_0014_ptr

	PTR_SET2 screen_ptr, $0402

	; drawing four vertical lines, each 20 chars long
	; most of it will be overwritten but it was easier to code this way
	LDX #$14
-
	LDA #$04 ; border on the right side of the char
	LDY #$00
	STA (screen_ptr),Y ; the left border of the dungeon and the player2 cage
	LDY #$AB
	STA (screen_ptr),Y ; the left border of the radar box
	LDY #$22
	LDA #$01 ; border on the left side of the char
	STA (screen_ptr),Y ; the right border of the dungeon and the player1 cage
	LDY #$B7
	STA (screen_ptr),Y ; the right border of the radar box
	LDY #$04
	STA (screen_ptr),Y ; the right border of the player2 cage
	LDA #$04
	STA SCR_06F0 ; TODO: probably unneeded, a char in the left border of the player1 cage
	LDY #$1E
	STA (screen_ptr),Y ; the left border of the player1 cage

	PTR_ADD screen_ptr, #40 ; next line

	DEX
	BPL -

	; drawing the warp doors on the left and right side
	LDX #$01
	STX SCR_06D6 ; TODO: probably unneeded, a char in the right border of the player2 cage
-
	LDA #$06
	STA SCR_04C8,X ; left warp door tunnel top, upper side
	STA SCR_04ED,X ; right warp door tunnel top, upper side
	STA SCR_0540,X ; left warp door tunnel bottom, upper side
	STA SCR_0565,X ; right warp door tunnel bottom, upper side
	LDA #$02
	STA SCR_04F0,X ; left warp door tunnel top, lower side
	STA SCR_0515,X ; right warp door tunnel top, lower side
	STA SCR_0568,X ; left warp door tunnel bottom, lower side
	STA SCR_058D,X ; right warp door tunnel bottom, lower side
	DEX
	BPL -


	; drawing the corners for the doors
	LDX #$03
	STX SCR_058C
	INX
	INX
	STX SCR_056A
	INX
	INX
	STX SCR_04EC
	INX
	STX SCR_04CA
	INX
	STX SCR_04F2
	STX SCR_0514
	INX
	TXA
	STX SCR_051A
	STX SCR_053C
	INX
	STX SCR_0542
	STX SCR_0564
	; the two arrows in the doors
	INX
	STX SCR_0518
	INX
	STX SCR_053E

	; fill color mem (A = $02)
	LDX #$00
-
	STA COL_D800,X
	STA COL_D900,X
	STA COL_DA00,X
	STA COL_DB00,X
	DEX
	BNE -

	; set the char color yellow for the lives of player1 on the right side
	LDX #$08
	PTR_SET2 screen_ptr, $DA05
-
	LDA #$07
	LDY #$01
-	STA (screen_ptr),Y
	DEY
	BPL -
	PTR_ADD screen_ptr, #40 ; next line
	DEX
	BPL --

	; TODO: what is colored here?
	LDX #$08
-
	LDY draw_dungeon.block_offsets,X
	LDA #$07
	STA COL_DAF1,Y
	LDA #$06
	STA COL_DAD3,Y
	DEX
	BPL -

	; TODO: what is colored here?
	LDX #$08
	PTR_SET2 screen_ptr, $D9E0
-
	LDA #$06
	LDY #$01
-
	STA (screen_ptr),Y
	DEY
	BPL -
	PTR_ADD screen_ptr, #40 ; next line
	DEX
	BPL --

	; show warp door arrows
	LDA #$02
	STA COL_D918
	STA COL_D93E

	; draw the radar screen covering chars
	LDA #$0E ; solid blocks
fill_radar_chars
	LDX #$0A
-
	STA SCR_0706,X
	STA SCR_072E,X
	STA SCR_0756,X
	STA SCR_077E,X
	STA SCR_07A6,X
	STA SCR_07CE,X
	STX COL_D800    ; TODO: this seems to be unnecessary
	DEX
	BPL -
	RTS

.pend

; -----------------------------------------


dungeon_layouts .block

layout_0	.byte $36,$3a,$2a,$51,$c3,$0a,$80,$24,$1a,$34,$55,$12,$55,$10,$c5,$98,$c9,$a8
layout_1	.byte $3a,$63,$a2,$53,$80,$a0,$84,$30,$65,$38,$45,$55,$1a,$0c,$10,$9a,$8a,$cd
layout_2	.byte $3a,$63,$a2,$1a,$00,$20,$82,$c5,$55,$3c,$3c,$10,$1a,$c3,$45,$9a,$ac,$98
layout_3	.byte $3a,$63,$a2,$53,$08,$a0,$04,$1a,$65,$1c,$53,$80,$53,$80,$65,$98,$ac,$98
layout_4	.byte $3a,$a2,$2a,$1a,$2c,$1a,$82,$43,$82,$3c,$14,$30,$53,$c1,$45,$98,$ac,$98
layout_5	.byte $3a,$a6,$32,$53,$a8,$45,$84,$32,$80,$34,$51,$a8,$51,$00,$a2,$98,$c9,$a8
layout_6	.byte $3a,$22,$a2,$53,$84,$38,$84,$30,$0a,$38,$45,$92,$1a,$41,$28,$9a,$8c,$9a
layout_7	.byte $3a,$63,$2a,$1a,$45,$92,$86,$10,$28,$38,$c5,$1a,$1a,$20,$0a,$9a,$c9,$8a
layout_8	.byte $32,$22,$22,$55,$55,$55,$80,$49,$45,$34,$92,$00,$51,$61,$c5,$9c,$98,$a8
layout_9	.byte $36,$3a,$2a,$51,$43,$82,$8c,$59,$65,$32,$8a,$45,$51,$22,$08,$9c,$9c,$9a
layout_10	.byte $36,$3a,$2a,$51,$c3,$0a,$80,$24,$1a,$34,$55,$12,$55,$10,$c5,$98,$c9,$a8
layout_11	.byte $36,$3a,$2a,$51,$0a,$0a,$84,$16,$92,$34,$94,$38,$51,$20,$82,$98,$c9,$a8
layout_12	.byte $3a,$63,$a2,$1a,$84,$38,$82,$20,$02,$3c,$55,$55,$1a,$04,$90,$9a,$c9,$a8
layout_13	.byte $3a,$22,$a2,$53,$84,$38,$84,$30,$0a,$38,$45,$92,$1a,$41,$28,$9a,$8c,$9a
layout_14	.byte $3a,$63,$2a,$1a,$45,$92,$86,$10,$28,$38,$c5,$1a,$1a,$20,$0a,$9a,$8c,$9a
layout_15	.byte $32,$22,$a2,$1c,$90,$65,$06,$3c,$90,$59,$06,$30,$16,$98,$00,$98,$aa,$88
layout_16	.byte $32,$22,$22,$51,$45,$10,$45,$14,$55,$14,$51,$45,$10,$45,$10,$98,$88,$88
layout_17	.byte $3a,$22,$a2,$16,$90,$28,$00,$69,$02,$10,$06,$90,$14,$10,$65,$98,$88,$88
layout_18	.byte $3a,$22,$2a,$12,$84,$1a,$41,$28,$02,$51,$82,$08,$18,$24,$1a,$9a,$88,$8a
layout_19	.byte $3a,$22,$22,$16,$18,$c5,$0c,$53,$20,$12,$8c,$10,$14,$32,$00,$98,$88,$88
layout_20	.byte $3a,$22,$22,$16,$90,$c5,$00,$65,$30,$10,$c5,$90,$1c,$30,$65,$9a,$88,$88
layout_21	.byte $32,$22,$22,$59,$0c,$10,$06,$12,$45,$18,$49,$45,$53,$06,$10,$98,$88,$88
layout_22	.byte $32,$22,$a2,$10,$0c,$30,$00,$c3,$00,$1c,$30,$c5,$12,$0c,$30,$98,$8a,$88
layout_23	.byte $32,$22,$22,$10,$00,$00,$00,$00,$00,$10,$00,$00,$10,$00,$00,$98,$88,$88
layout_24	.byte $3a,$2a,$a2,$1a,$c3,$20,$0a,$20,$00,$16,$90,$88,$51,$20,$2a,$9c,$9c,$9a

.bend

; -----------------------------------------

draw_dungeon .proc
	; draws the variable parts of dungeons
	; a pointer to the dungeon layout is supplied in dungeon_layout_ptr
	;
	; dungeons are drawn by using 3x3 character blocks
	; a dungeon is composed by 11x6 such blocks but only 6x6 is stored as the dungeon is horizontally mirrored

	; aliases
	blocks_to_go = tmp_0002
	index_tmp = tmp_0008
	screen_ptr = tmp_0004_ptr
	screen_ptr_mirror = tmp_0006_ptr
	dungeon_block_ptr = tmp_0010_ptr

	; print the 72 (2 x $24) blocks
	LDX #$23

draw_block
	STX blocks_to_go
	; set up screen pointer
	; hi byte of screen pointer calculated: 04 for the first 17 (0-$10) entries, 05 for the next 13 ($11-$1D) and 06 for the rest
	LDY #$04
	CPX #$11
	BCC +
	INY
	CPX #$1E
	BCC +
	INY
+	STY screen_ptr+1
	LDA screen_tbl,X
	STA screen_ptr

	; set up second screen pointer
	PTR_SET_TBL_X2 screen_ptr_mirror, screen_tbl_mirror

	; read dungeon data
	; data is packed into nybbles - so get the right nybble (high for even X, low for odd)
	TXA
	LSR A  ; here we set C
	TAY
	LDA (dungeon_layout_ptr),Y
	BCS _odd
	LSR A
	LSR A
	LSR A
	LSR A
_odd	AND #$0F
	STA index_tmp ; store it, we will need it again in a moment

	; set up dungeon block pointer
	TAX
	PTR_SET_LOTBL_X dungeon_block_ptr, dungeon_block_tbl

	; draw a single block
	LDX #$08
-	TXA
	TAY
	LDA (dungeon_block_ptr),Y
	LDY block_offsets,X
	STA (screen_ptr),Y
	DEX
	BPL -

	; set up dungeon block pointer mirrored
	; every block has a mirrored pair (it could be itself), use that
	LDX index_tmp
	LDY dungeon_block_mirror_pair_tbl,X
	LDA dungeon_block_tbl,Y
	STA dungeon_block_ptr

	; draw a single block (the mirrored one)
	LDX #$08
-	TXA
	TAY
	LDA (dungeon_block_ptr),Y
	LDY block_offsets,X
	STA (screen_ptr_mirror),Y
	DEX
	BPL -

	; check if there are more blocks to go
	LDX blocks_to_go
	DEX
	BPL draw_block
	RTS

dungeon_block_00	.byte $00,$0f,$00,$0f,$0f,$0f,$00,$0f,$00
dungeon_block_01	.byte $01,$0f,$00,$01,$0f,$0f,$01,$0f,$00
dungeon_block_02	.byte $02,$02,$02,$0f,$0f,$0f,$00,$0f,$00
dungeon_block_03	.byte $03,$02,$02,$01,$0f,$0f,$01,$0f ; ,$00 - but it's the same as the first byte of dungeon_block_4 so a byte was saved here :)
dungeon_block_04	.byte $00,$0f,$04,$0f,$0f,$04,$00,$0f,$04
dungeon_block_05	.byte $01,$0f,$04,$01,$0f,$04,$01,$0f,$04
dungeon_block_06	.byte $02,$02,$05,$0f,$0f,$04,$00,$0f,$04
dungeon_block_07	.byte $03,$02,$05,$01,$0f,$04,$01,$0f,$04
dungeon_block_08	.byte $00,$0f,$00,$0f,$0f,$0f,$06,$06,$06
dungeon_block_09	.byte $01,$0f,$00,$01,$0f,$0f,$07,$06,$06
dungeon_block_10	.byte $02,$02,$02,$0f,$0f,$0f,$06,$06,$06
dungeon_block_11	.byte $03,$02,$02,$01,$0f,$0f,$07,$06,$06
dungeon_block_12	.byte $00,$0f,$04,$0f,$0f,$04,$06,$06,$08
dungeon_block_13	.byte $01,$0f,$04,$01,$0f,$04,$07,$06,$08
dungeon_block_14	.byte $02,$02,$05,$0f,$0f,$04,$06,$06,$08
dungeon_block_15	.byte $03,$02,$05,$01,$0f,$04,$07,$06,$08

block_offsets	; offsets for drawing 3x3 blocks on screen
		.byte $00,$01,$02,$28,$29,$2A,$50,$51,$52

dungeon_block_mirror_pair_tbl	.byte $00,$04,$02,$06,$01,$05,$03,$07,$08,$0C,$0A,$0E,$09,$0D,$0B,$0F

dungeon_block_tbl	.lo_tbl (dungeon_block_00,dungeon_block_01,dungeon_block_02,dungeon_block_03,dungeon_block_04,dungeon_block_05,dungeon_block_06,dungeon_block_07,dungeon_block_08,dungeon_block_09,dungeon_block_10,dungeon_block_11,dungeon_block_12,dungeon_block_13,dungeon_block_14,dungeon_block_15)

screen_tbl		.lo_tbl     ($0403,$0406,$0409,$040C,$040F,$0412, $047B,$047E,$0481,$0484,$0487,$048A, $04F3,$04F6,$04F9,$04FC,$04FF,$0502, $056B,$056E,$0571,$0574,$0577,$057A, $05E3,$05E6,$05E9,$05EC,$05EF,$05F2, $065B,$065E,$0661,$0664,$0667,$066A)

screen_tbl_mirror	.hilo_tbl ($0421,$041E,$041B,$0418,$0415,$0412, $0499,$0496,$0493,$0490,$048D,$048A, $0511,$050E,$050B,$0508,$0505,$0502, $0589,$0586,$0583,$0580,$057D,$057A, $0601,$05FE,$05FB,$05F8,$05F5,$05F2, $0679,$0676,$0673,$0670,$066D,$066A)

.pend

; -----------------------------------------

select_dungeon_layout .proc
	; sets dungeon layout pointer

	LDA #$00
	STA dungeon_layout_ptr+1
	INC current_dungeon
get_dungeon_layout
	LDX current_dungeon
	; after dungeon 98 loop back to dungeon 97 so after reaching this loop every other dungeon is a Pit
	CPX #$62
	BNE +
	LDX #$60
	STX current_dungeon
+
	TXA

	; dungeon-specific stuff
	; mostly magic voice sentences and some fixed layouts

	CMP #$03
	BNE _not_arena

	; dungeon 4 - the Arena: layout 24, magic voice 6
	LDY #$06
	JSR magic_voice.say
	LDA #$18 ; always use layout 24
	BNE _layout_selected ; always branch

_not_arena
	CMP #$07
	BCS _dungeon_over_8
	; first 8 dungeons, not Arena: set dungeon layout to a random number in the 0-14 range, no magic voice
-	LDA random_number
	AND #$0F
	CMP #$0F
	BEQ -
	BNE _layout_selected ; always branch

_dungeon_over_8
	; these are the "worlord" dungeons
	; calculate current_dungeon mod 6
	SBC #$06
	BCS _dungeon_over_8
	ADC #$06
	BNE _not_pit ; branch if modulo is not zero

	; dungeons 13, 19, etc: the Pit, layout 23, magic voice 7
	LDY #$07
	JSR magic_voice.say
	LDA #$17 ; always use layout 23
	BNE _layout_selected ; always branch

_not_pit
	; rest of the dungeons: set dungeon layout to a random number in the 15-22 range, magic voice randomized
	LDA random_number
	AND #$07
	TAX
	LDY worlord_dungeons_MV_tbl,X
	JSR magic_voice.say

	LDA random_number
	AND #$07
	CLC
	ADC #$0F

_layout_selected
	; check if this layout was used in the previous dungeon
	; TODO: BUG: this generates a second magic voice announcement
	CMP prev_dungeon_layout
	BEQ get_dungeon_layout
	STA prev_dungeon_layout

	; get the pointer to the layout
	; a layout consists of 36 block ids (blocks are 3x3 char) packed into 18 bytes (block ids are 0-f, so a nybble is enough for them)
	;  ...first multiply layout number by 18 (add it to itself 17 times)
	LDX #$10
	STA dungeon_layout_ptr
_mul
	CLC
	ADC dungeon_layout_ptr
	BCC +
	INC dungeon_layout_ptr+1
+	DEX
	BPL _mul
	;  ...then add it to the base pointer
	CLC
	ADC #<dungeon_layouts
	STA dungeon_layout_ptr
	LDA dungeon_layout_ptr+1
	ADC #>dungeon_layouts
	STA dungeon_layout_ptr+1
	RTS
worlord_dungeons_MV_tbl	.byte $01,$03,$04,$05,$09,$0C,$0D,$01

.pend

; -----------------------------------------

move_actor .proc
	; moves actors, stops them on collision, handles joystick input for players
	;
	;  X: actual actor

	; alias
	screen_ptr = tmp_0014_ptr
	colorram_ptr = tmp_000b


	; set up variables
	LDA power_of_2_tbl,X
	STA actor_bit_1
	EOR #$FF
	STA actor_bit_0
	LDA is_monster
	BEQ _not_monster

	; monster-specific stuff
	; remove the marker chars for monsters
	;  ...first the center marker
	LDX actor_sprite_pos_offset
	LDA VIC_S0X,X
	STA tmp_sprite_x
	LDA VIC_S0Y,X
	STA tmp_sprite_y
	LDX #$01
	JSR sprite_pos_to_char_ptr
	LDA #FLOOR
	LDY tmp_0008
	STA (screen_ptr),Y
	;  ...then the head marker but only if it was not overwritten by something else
	LDX actual_actor
	LDA monster_head_ptr_tbl.hi,X
	STA screen_ptr+1
	LDA monster_head_ptr_tbl.lo,X
	STA screen_ptr
	LDY #$00
	LDA (screen_ptr),Y
	CMP #MONSTER_HEAD
	BNE _skip_head ; there's something else there, leave it alone
	LDA #FLOOR
	STA (screen_ptr),Y
_skip_head
_not_monster

	; set actor_x_9th_bit
	LDX actual_actor
	CPX #MAX_PLAYERS
	LDY #$00
	LDA VIC_D010
	AND actor_bit_1
	STA actor_x_9th_bit
	LDX actual_actor
	BCC _player
	JMP do_movement

_player
	; the player-specific stuff
	; either do handle launch from the cage or control player with the joystick

	LDA launch_status,X
	BPL handle_launch    ; player has not launched yet
	JMP control_player   ; player is already in play

handle_launch
	BNE launch_player ; launch is in progress

	; player is still waiting in cage, countdown is... counting down
	; print launch countdown next to the cage
	LDA launch_cnt_screen_ptr_tbl,X
	STA screen_ptr
	STA colorram_ptr
	LDA #$07
	STA screen_ptr+1
	CLC
	ADC #$D4
	STA colorram_ptr+1
	LDA VIC_D027,X
	AND #$07
	STA tmp_00e9
	LDA launch_counters,X
	JSR print_2x1_letter

	; check if joystick is pushed up
	LDA CIA1_JOY_KEY1,X
	AND #$01
	BEQ start_launch
	JMP return_01 ; stay waiting in the cage

start_launch
	; starts moving out of cage
	LDA #SFX_PLAYER_LAUNCH
	STA next_sfx_idx
	STA launch_status,X

	; clear launch countdown display
	LDA launch_cnt_screen_ptr_tbl,X
	STA screen_ptr
	STA colorram_ptr
	LDA #$07
	STA screen_ptr+1
	CLC
	ADC #$D4
	STA colorram_ptr+1
	.enc "2x1"
	LDA #' '
	JSR print_2x1_letter

	; start launcing players
	;   they look horizontally
	LDA #$00
	STA actor_heading_y_tbl,X
	;   launch counter is not used
	LDA #$FF
	STA launch_counters,X
	;   set Y coordinate
	LDA player_vic_offset_tbl,X
	TAX
	LDA #$C5
	STA VIC_S0Y,X

	; check if it's player 1 or 2
	LDA VIC_D010
	CPX #$00
	BNE _player1

	; player 2
	;   clear X pos 9th bit
	AND #$FE
	STA VIC_D010
	;   look to the right
	LDA #$01
	STA actor_heading_x_tbl

	LDA #$37
	BNE _set_x_pos ; always branch

_player1
	;   set X pos 9th bit
	ORA #$02
	STA VIC_D010
	;   look to the left
	LDA #$FF
	STA actor_heading_x_tbl+1

	LDA #$27
_set_x_pos
	STA VIC_S0X,X
	RTS

launch_player
	; move player sprite a pixel higher
	LDX actual_actor
	LDA player_vic_offset_tbl,X
	TAX
	DEC VIC_S0Y,X
	LDA VIC_S0Y,X
	CMP #$AD
	BNE return_01 ; it has not reached final position
	; launch ended
	LDX actual_actor
	BEQ _player1
	; close cage
	LDA #$08
	STA SCR_06CB
	LDA #$06
	STA SCR_06C9
	STA SCR_06CA
	BNE _end_launch ; always branch

_player1
	; close cage
	LDA #$07
	STA SCR_06AB
	LDA #$06
	STA SCR_06AC
	STA SCR_06AD
_end_launch
	LDA #$FF
	STA launch_status,X
	BNE control_player ; always branch

return_01
	RTS

control_player
	LDX actual_actor
	JSR read_joy_direction ; sets actor_heading_x and actor_heading_y
	CPX #$00
	BNE _joy_is_pushed
	CPY #$00
	BEQ _joy_is_not_pushed
_joy_is_pushed
	LDX actual_actor
	INC animation_counter_tbl,X

_joy_is_not_pushed
	LSR A ; fire button into C bit
	LDX actual_actor
	LDA firing_status,X
	BCS no_fire_button ; fire button is not pushed
	BMI do_movement ; fire button is pushed, there's already a bullet
	BNE fire_button_held ; fire button is pushed and it was pushed previously

	; fire button is pushed, it was not pushed previously and the player has no bullet in the playfield, so:
	; shoot!

	; save current sprite
	LDA SPRITE_PTR,X
	STA sprite_tmp,X
	; reset animation timer
	LDA #$04
	STA animation_timer_tbl,X
	; find out which sprite to use
	LDA actor_heading_x_tbl,X
	BEQ _vertical_shot
	TAX
	INX
	LDA shooting_sprites.hor,X
	BNE _update_sprite ; always branch

_vertical_shot
	LDA actor_heading_y_tbl,X
	BEQ do_movement ; player does not look anywhere, so it's not active
	CPX #$00
	BEQ _player2_vert ; player2's head points to the right, player1's to the left

	; player 1 vertical shot
	TAX
	INX
	LDA shooting_sprites.vert_p1,X
	BNE _update_sprite ; always branch

_player2_vert
	; player 2 vertical shot
	TAX
	INX
	LDA shooting_sprites.vert_p2,X

_update_sprite
	LDX actual_actor
	STA SPRITE_PTR,X
	LDA #SFX_PLAYER_SHOOTS
	STA next_sfx_idx
	JSR fire_bullet
	RTS

shooting_sprites .block
hor	.byte $83,$00,$BD ; fire left, <invalid>, fire right

; since both tables have a hole in the middle we can pack them together: A1,?,A2 + B1,?,B2 -> A1,B1,A2,B2
vert_p1	.byte $CF,  ?,$D4 ; head to the left: fire up, invalid, fire down
	*=*-2
vert_p2	.byte $99,  ?,$AB ; head to the right: fire up, invalid, fire down
.bend

fire_button_held
	; TODO: this seems unnecessary
	LDA firing_status,X
	ORA #FIRING_FIRE_BUTTON ; keep FIRING_FIRE_BUTTON on
	STA firing_status,X
	BNE do_movement ; always branch

no_fire_button
	LDA firing_status,X
	AND #FIRING_BULLET_ACTIVE ; switch off FIRING_FIRE_BUTTON
	STA firing_status,X


	;
	; this is again common for both monsters and players
	;
do_movement
	; alias
	dont_draw_monster_center = tmp_000b

	; move actor and store resulting sprite coordinates in tmp_sprite_x + actor_x_9th_bit and tmp_sprite_y
	;
	;

	; move actor horizontally
	CLC
	LDX actor_sprite_pos_offset
	LDA actor_heading_x
	BEQ _no_x_movement
	BMI _negative_offset
	ADC VIC_S0X,X
	STA tmp_sprite_x
	BCC _horizontal_move_done
	LDA actor_x_9th_bit
	EOR actor_bit_1
	STA actor_x_9th_bit
	BCS _horizontal_move_done ; always branch

_negative_offset
	ADC VIC_S0X,X
	STA tmp_sprite_x
	BCS _horizontal_move_done
	LDA actor_x_9th_bit
	EOR actor_bit_1
	STA actor_x_9th_bit
_horizontal_move_done

	; check if horizontal movement results in a collision
	LDA VIC_S0Y,X
	STA tmp_sprite_y
	LDA #$01
	STA dont_draw_monster_center
	LDA actual_actor
	JSR check_actor_collision
	BEQ _no_coll_x

	; undo horizontal movement, stop actor
	LDX actor_sprite_pos_offset
_no_x_movement
	LDA VIC_S0X,X
	STA tmp_sprite_x
	LDA VIC_D010
	AND actor_bit_1
	STA actor_x_9th_bit
	LDA #$00
	STA actor_heading_x
_no_coll_x

	; check if vertical movement results in a collision
	LDX actor_sprite_pos_offset
	LDA VIC_S0Y,X
	CLC
	ADC actor_heading_y
	STA tmp_sprite_y
	LDA #$00
	STA dont_draw_monster_center
	LDA actual_actor
	JSR check_actor_collision
	BEQ _no_coll_y

	; undo vertical movement, stop actor
	LDX actor_sprite_pos_offset
	LDA VIC_S0Y,X
	STA tmp_sprite_y
	LDA #$00
	STA actor_heading_y
_no_coll_y

	; update sprite position
	LDX actor_sprite_pos_offset
	LDA tmp_sprite_x
	STA VIC_S0X,X
	LDA VIC_D010
	AND actor_bit_0
	ORA actor_x_9th_bit
	STA VIC_D010
	LDA tmp_sprite_y
	STA VIC_S0Y,X
	LDA actor_heading_x
	BNE _actor_is_moving
	LDA actor_heading_y
	BNE _actor_is_moving

	; handle stopped actors

	LDA actual_actor
	CMP #MAX_PLAYERS
	BCS _check_if_actor_was_moving ; not a player

	; check if joystick is pushed into any direction
	TAX
	LDA CIA1_JOY_KEY1,X
	AND #$0F
	EOR #$0F
	BNE _check_if_actor_was_moving ; yes, it is

	; player just stands

	; check if it was firing
	LDY #$08 ; TODO: BUG: it's probably a typo, should be 6
	LDA SPRITE_PTR,X

-	CMP shooting_sprites,Y
	BEQ _was_shooting
	DEY
	BPL -

	BMI _return ; always branch - was not shooting, leave its sprite alone

_was_shooting
	LDA sprite_tmp,X ; restore the sprite it had before firing
	STA SPRITE_PTR,X
_return
	RTS

_check_if_actor_was_moving
	; check if actor was freshly stopped
	LDX actual_actor
	LDA actor_heading_x_tbl,X
	BNE _actor_was_moving
	LDA actor_heading_y_tbl,X
	BEQ _return ; does not move

_actor_was_moving
	; yes, actor is freshly stopped
	; recalculate move
	; TOOD: why?
	LDA actor_heading_x_tbl,X
	STA actor_heading_x
	LDA actor_heading_y_tbl,X
	STA actor_heading_y
	LDA #$00
	STA actor_heading_x_tbl,X
	STA actor_heading_y_tbl,X
	JMP do_movement


_actor_is_moving
	LDX actual_actor
	CPX #MAX_PLAYERS
	BCC _update_animation_phase
	LDA actor_heading_x
	BNE _update_animation_phase
	LDA actor_heading_y
	BEQ _dont_update_animation_phase ; TODO: it seems like this never branches
_update_animation_phase
	; animation phase advances every fourth time
	; and it is in a 0-1-2-1 loop
	LDA animation_counter_tbl,X
	LSR A
	LSR A
	AND #$03
	CMP #$03
	BNE +
	LDA #$01 ; the fourth phase is 1 again
+
	STA animation_phase
_dont_update_animation_phase
	LDX actual_actor
	LDY actor_type_tbl,X
	PTR_SET_LOTBL_Y horiz_anim_ptr, horizontal_animation_ptr_tbl
	PTR_SET_LOTBL_Y vert_anim_ptr, vertical_animation_ptr_tbl

	; set sprite color
	LDA type_color_tbl,Y
	STA VIC_D027,X

	; update heading
	LDA actor_heading_x
	STA actor_heading_x_tbl,X
	LDA actor_heading_y
	STA actor_heading_y_tbl,X
	; make headings useable as indices
	INC actor_heading_y
	INC actor_heading_x
	; calculate animation as vertical movement
	LDY actor_heading_y
	LDA (vert_anim_ptr),Y
	CLC
	ADC animation_phase
	; check if movement should not be rather horizonta
	LDY actor_heading_x
	CPY #$01
	BEQ _movement_is_really_vertical

	; calculate animation as horizontal movement
	LDA (horiz_anim_ptr),Y
	CLC
	ADC animation_phase

_movement_is_really_vertical
	; set sprite shape
	LDY actual_actor
	STA SPRITE_PTR,Y

	; restore headings to original values
	DEC actor_heading_x
	DEC actor_heading_y

	JSR draw_monster_head
	RTS

player_vic_offset_tbl		.byte $00,$02
launch_cnt_screen_ptr_tbl	.byte $00,$16

.pend

; -----------------------------------------

check_actor_collision .proc
	; checks if current actor may move to an X,Y position
	;  tmp_sprite_x: the new X position
	;  tmp_sprite_y: the new Y position
	;  tmp_000b: draw monster center for monsters if pos is free: 0: yes, 1: no
	; result:
	;  A / Z flag: 0: no block 1: something blocks

	dont_draw_monster_center = tmp_000b
	collision_found = tmp_0090

	screen_ptr = tmp_0014_ptr
	screen_offset = tmp_0008




	LDA #$00
	STA collision_found

	LDX #$05 ; start probing with the corners
_loop
	; see if there's something
	JSR sprite_pos_to_char_ptr
	LDA (screen_ptr),Y

	LDY is_monster
	BEQ _not_monster ; not monster

	; ignore these for monsters
	CMP #MONSTER_CENTER
	BEQ _no_collision
	CMP #MONSTER_HEAD
	BEQ _no_collision
	CMP #MONSTER_BULLET_V
	BEQ _no_collision
	CMP #MONSTER_BULLET_H
	BEQ _no_collision
	; ignore these for everyone
_not_monster
	CMP #FLOOR
	BEQ _no_collision

	; there was collision
	LDA collision_found
	BNE _exit_loop ; a loop with the center was already done
	; make a last try with the center - to set up pointers for the monster center drawing
	INC collision_found
	LDX #$01
	BNE _loop ; always branch

_no_collision
	; check next in-sprite position
	DEX
	BNE _loop
_exit_loop
	LDA is_monster
	BEQ _skip_monster_center_drawing ; not monster
	LDA dont_draw_monster_center
	BNE _skip_monster_center_drawing

	; put down monster center
	LDA #MONSTER_CENTER
	LDY screen_offset
	STA (screen_ptr),Y

_skip_monster_center_drawing
	LDA collision_found
	RTS

.pend

; -----------------------------------------

power_of_2_tbl
	.byte $01,$02,$04,$08,$10,$20,$40,$80

	; the start address of each of the 25 lines on the text screen
screen_line_ptr .lohi_tbl $400 + range(0, 1000, 40)


; -----------------------------------------

create_sprites .proc
	; this creates the sprites 86 in total) for the game in various ways
	; 1. copy from cartridge to ram: the VIC can't see the cart and it's in the wrong bank anyway, so copy sprites to $2000 (40 sprites - 3 of these are unused and contain the code for 3 subroutines)
	; 2. create vertically mirrored versions of some of these sprites (18 sprites)
	; 3. create horizontally mirrored versions (28 sprites)

	; the zero page pointers used
	src_ptr = tmp_0014_ptr
	dst_ptr = tmp_0008
	sprite_no = tmp_0090
	sprites_to_go = tmp_0002
	mirror_tmp = tmp_000a
	src_mirror_ptr = tmp_text_lo_ptr

	; set up pointers
	PTR_SET2 src_ptr, sprites_rom
	PTR_SET2 dst_ptr, $2000

	; clear the destination area for 91 sprites (that seems to be a mistake as there are only 86 sprites)
	LDX #$5A

clear_sprites
	LDY #$3F
	LDA #$00

_clear_single_sprite
	STA (dst_ptr),Y
	DEY
	BPL _clear_single_sprite

	PTR_ADD dst_ptr, #$40
	DEX
	BPL clear_sprites

	; reset dest pointers
	PTR_SET2 dst_ptr, $2000

	; copy $28 sprites
	;
	; sprites are stored in the ram as 24x18 images (the last 3 lines which are always empty, are not stored)
	; so a source sprite is only 54 bytes long
	LDX #$27

copy_sprites
	LDY #$35

_copy_single_sprite
	LDA (src_ptr),Y
	STA (dst_ptr),Y
	DEY
	BPL _copy_single_sprite

	; move src_ptr to the next sprite location
	PTR_ADD src_ptr, #$36

	; move dst_ptr to the next sprite location
	PTR_ADD dst_ptr, #$40

	DEX
	BPL copy_sprites

	; generating additional sprites

	; starting with sprite $96 ($2580) take the sprites previously copied to ram and mirror them vertically
	LDA #$95
	STA sprite_no

	; we will mirror vertically $12 sprites
	LDX #$11

mirror_sprites_vertically
	STX sprites_to_go
	INC sprite_no
	; calculate src pointer to beginning of the sprite's last non-empty line ( ptr = (sprite_no * 64) + (17*3) )
	LDA sprite_no
	STA src_ptr
	LDA #$00
	STA src_ptr+1
	LDX #$05
_shift_src_ptr
	ASL src_ptr
	ROL src_ptr+1
	DEX
	BPL _shift_src_ptr
	PTR_ADD src_ptr, #$33

	LDX #$11 ; we will copy 18 lines
_mirror_single_sprite
	LDY #$02
_copy_sprite_line
	LDA (src_ptr),Y
	STA (dst_ptr),Y
	DEY
	BPL _copy_sprite_line

	; move forward to next dst sprite line
	PTR_ADD dst_ptr, #3
	; move backward to next src sprite line
	PTR_SUB src_ptr, #3

	DEX
	BPL _mirror_single_sprite

	; skip empty lines on dst part
	PTR_ADD dst_ptr, #10

	LDX sprites_to_go
	DEX
	BPL mirror_sprites_vertically


	; we will mirror horizontally $12 sprites
	LDX #$1B

mirror_sprites_horizontally
	STX sprites_to_go
	; load number of sprite to mirror
	LDA sprites_to_mirror_horizontally,X

	; calculate src ptr ( ptr = sprite no * 64 )
	STA src_ptr
	LDA #$00
	STA src_ptr+1
	LDX #$05
	CLC
-
	ASL src_ptr
	ROL src_ptr+1
	DEX
	BPL -
	LDY #$33
	LDA src_ptr
	CLC
	ADC #$02
	STA src_mirror_ptr
	LDX src_ptr+1
	BCC +
	INX
+
	STX src_mirror_ptr+1
_mirror_single_sprite
	; the two bytes on the sides are mirrored by rotating each others bits into the other one (one is in A, the other is in mirror_tmp)
	LDA (src_ptr),Y ; left side byte
	STA mirror_tmp
	LDA (src_mirror_ptr),Y ; right side byte
	LDX #$07
	CLC
-
	ROL A
	ROR mirror_tmp
	DEX
	BPL -
	ROL A

	; store the mirrored bytes
	INY
	INY
	STA (dst_ptr),Y
	DEY
	DEY
	LDA mirror_tmp
	STA (dst_ptr),Y

	; the middle byte - the same procedure is applied as above but in this case this single byte is put both into A and mirror tmp
	INY
	LDA (src_ptr),Y
	STA mirror_tmp
	LDA #$00
	LDX #$07
	CLC
-
	ROR mirror_tmp
	ROL A
	DEX
	BPL -
	; store mirrored byte
	STA (dst_ptr),Y

	DEY
	DEY
	DEY
	DEY
	BPL _mirror_single_sprite

	PTR_ADD dst_ptr, #$40

	LDX sprites_to_go
	DEX
	BPL mirror_sprites_horizontally
	RTS

sprites_to_mirror_horizontally
	.byte $AC,$AB,$AA,$A9,$A8,$9A,$99,$98
	.byte $97,$96,$91,$90,$8F,$8E,$8D,$8C
	.byte $8B,$8A,$89,$88,$87,$86,$85,$84
	.byte $83,$82,$81,$80

.pend

; -----------------------------------------

	; the custom character set

cset_rom_custom2
	.byte $80,$40,$40,$80,$40,$80,$80,$40,$96,$69,$00,$00,$00,$00,$00,$00,$65,$96,$40,$40,$80,$40,$80,$80,$01,$01,$02,$01,$02,$02,$01,$02
	.byte $a6,$69,$02,$01,$01,$02,$01,$02,$00,$00,$00,$00,$00,$00,$66,$99,$40,$80,$80,$40,$80,$40,$69,$96,$02,$01,$01,$02,$01,$02,$a6,$99
	.byte $69,$92,$0c,$0c,$00,$0c,$0c,$00,$0c,$0c,$00,$0c,$0c,$00,$0c,$0c,$00,$0c,$0c,$00,$0c,$0c,$62,$99,$1c,$30,$60,$ff,$ff,$60,$30,$1c
	.byte $38,$0c,$06,$ff,$ff,$06,$0c,$38,$00,$7e,$7e,$7e,$7e,$7e,$7e,$00

cset_rom_custom_packed
	.byte $78,$fc,$cc,$cc,$cc,$30,$70,$f0,$30,$30,$78,$fc,$cc,$0c,$7c,$cc,$cc,$cc,$cc,$fc,$fc,$fc,$c0,$c0,$f8,$78,$fc,$cc,$c0,$f8,$fc,$fc
	.byte $18,$18,$30,$78,$fc,$cc,$cc,$78,$78,$fc,$cc,$cc,$fc,$f8,$fc,$cc,$cc,$f8,$78,$fc,$cc,$c0,$c0,$f8,$fc,$cc,$cc,$cc,$0c,$0c,$0c,$0c
	.byte $0c,$fc,$fc,$30,$30,$30,$cc,$cc,$cc,$d8,$f8,$c0,$c0,$c0,$c0,$c0,$c6,$ee,$fe,$fe,$d6,$cc,$ec,$fc,$dc,$cc,$cc,$cc,$cc,$cc,$cc,$c6
	.byte $c6,$c6,$c6,$c6,$cc,$cc,$cc,$fc,$78,$30,$30,$30,$fc,$fc,$f8,$c0,$c0,$fc,$fc,$7c,$0c,$cc,$fc,$78,$fc,$0c,$0c,$0c,$0c,$fc,$cc,$cc
	.byte $fc,$78,$30,$60,$60,$c0,$c0,$78,$cc,$cc,$fc,$78,$fc,$cc,$cc,$cc,$cc,$f8,$cc,$cc,$fc,$f8,$c0,$c0,$cc,$fc,$78,$cc,$cc,$cc,$fc,$f8
	.byte $0c,$0c,$cc,$fc,$78,$f8,$c0,$c0,$c0,$c0,$dc,$dc,$cc,$fc,$78,$f8,$d8,$cc,$cc,$cc,$c0,$c0,$c0,$fc,$fc,$c6,$c6,$c6,$c6,$c6,$cc,$cc
	.byte $cc,$cc,$cc,$30,$30,$30,$30,$30,$00,$00,$00,$00,$00,$d6,$fe,$fe,$ee,$c6,$78,$30,$30,$30,$30,$30,$60,$60,$fc,$fc,$00,$00,$00,$18
	.byte $18

cset_rom_custom1
	.byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$78,$c6,$38,$6c,$60,$60,$6c,$38,$c6,$7c,$00,$00,$00,$00,$00,$00,$ff,$ff,$00,$00,$00
	.byte $30,$30,$30,$30,$30,$30,$30,$30,$00,$00,$00,$33,$cc,$00,$00,$00,$0c,$0c,$30,$30,$0c,$0c,$30,$30,$00,$00,$00,$03,$05,$01,$0f,$03
	.byte $00,$00,$00,$80,$c0,$c8,$80,$b0,$00,$00,$06,$16,$06,$00,$00,$00,$03,$06,$0e,$aa,$2a,$0f,$07,$07,$f8,$58,$50,$70,$f0,$b0,$80,$c0
	.byte $0f,$1c,$38,$30,$f1,$00,$00,$00,$c0,$c0,$e0,$60,$e0,$00,$00,$00,$00,$00,$00,$01,$03,$13,$01,$0d,$00,$00,$00,$c0,$a0,$80,$f0,$c0
	.byte $1f,$1a,$0a,$0e,$0f,$0d,$01,$03,$c0,$60,$70,$55,$54,$f0,$e0,$e0,$00,$00,$60,$68,$60,$00,$00,$00,$03,$03,$07,$06,$07,$00,$00,$00
	.byte $f0,$38,$1c,$0c,$8f,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$70,$b8,$39,$f0,$76,$40,$40,$80,$43,$40,$80,$40,$80
	.byte $00,$00,$c1,$d5,$c5,$01,$00,$00,$7f,$cb,$ca,$4e,$5e,$f6,$f0,$f8,$01,$03,$07,$06,$1e,$00,$00,$00,$f8,$98,$1c,$0c,$3c,$00,$00,$00
	.byte $00,$00,$00,$0e,$1d,$9c,$0f,$76,$00,$00,$00,$00,$00,$00,$80,$00,$fe,$31,$53,$72,$7a,$6f,$0f,$1f,$00,$00,$83,$ab,$a3,$80,$00,$00
	.byte $01,$02,$02,$c1,$02,$01,$01,$02,$1f,$19,$38,$30,$3c,$00,$00,$00,$80,$c0,$e0,$60,$78,$00,$00,$00,$69,$92,$0c,$0c,$0c,$0c,$0c,$0c
	.byte $0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$92,$69,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$00,$00,$00,$ff,$00
	.byte $00,$00,$03,$00,$00,$00,$7f,$00,$00,$00,$c0,$00,$00,$00,$fc,$00,$00,$00,$fc,$00,$00,$00,$c0,$00,$00,$00,$7f,$00,$00,$00,$03,$00

; -----------------------------------------

	; the stored sprites

sprites_rom
	.include "inc.sprites_player.asm"

; -----------------------------------------
	; TODO: this should be in the magic_voice block

MV_init .proc
	; MAGIC VOICE is a speech synthesis cartridge
	; Wizard of Wor is one of the very few games that support is to produce a few short sentences during the game like "get ready worrior" etc

	; first detect if we have a Magic Voice installed
	LDX #$03
-	LDA MV_COMPLETION_HOOK-1,X ; X is 1-based
	CMP _MV_default_hook_code-1,X
	BNE +
	DEX
	BNE -
+
	STX is_MV_missing
	BNE _no_magic_voice

	; set up Magic Voice
	JSR MV_RESET

	LDX #>MV_tbl
	LDA #<MV_tbl
	JSR MV_SET_SPEECH_TABLE

	LDA #$02
	JSR MV_SET_SPEED

	; copy hook to call our code when speaking a word is finished
	LDX #$02
-	LDA MV_hook_code,X
	STA MV_COMPLETION_HOOK,X
	DEX
	BPL -

	; advance sentence index
	INX
	STX MV_sentence_idx
_MV_default_hook_code
	; If Magic Voice is present, at boot there's 'NOP; NOP; RTS' at $C018 - this code is replicated here and actually used instead of a simple RTS
	NOP
	NOP
_no_magic_voice
	RTS

MV_hook_code
	JMP magic_voice.completion

.pend

; -----------------------------------------

	.byte $CF ; TODO: unused?

; -----------------------------------------

	.include "inc.sprites_monsters1.asm"

; -----------------------------------------

reset_scores .proc
	LDA #$00
	STA is_title_screen
	LDX #STARTING_EXTRA_LIVES
	STX lives_player1
	LDA tmp_0090
	STA lives_player2

	; fill up score strings with zero
	LDX #$04
	LDA #$25
-	STA player1_score_string,X
	STA player2_score_string,X
	DEX
	BPL -

	STX current_dungeon ; init dungeon to $ff

	; set last character of scores to 0
	INX
	STX player1_score_string+5
	STX player2_score_string+5

	; set player 2 type to 1
	INX
	STX actor_type_tbl
	; set player 1 type to 2
	INX
	STX actor_type_tbl+1
	STX game_status
	RTS
.pend

; -----------------------------------------

	.byte $00,$CF,$00,$FF  ; TODO: unused?

; -----------------------------------------

	.include "inc.sprites_misc.asm"

; -----------------------------------------

flashing_after_worluk	.proc
	; flashes the screen after Worluk is killed or has escaped

	; flash the screen 50 times
	LDX #50
_set_colors
	; cycle the border and background color between four colors
	TXA
	AND #$03
	TAY
	LDA flashing_background_colors,Y
	STA VIC_D020
	STA VIC_D021

	; multichar backgrounds are dark blue
	LDA #$02
	STA VIC_D022
	STA VIC_D023

	; wait four frames
	LDY #$03
_wait_frame
-	LDA VIC_D011
	BPL -
-	LDA VIC_D011
	BMI -
	DEY
	BPL _wait_frame

	DEX
	BNE _set_colors

	RTS

flashing_background_colors	.byte $02,$00,$06,$00

.pend

; -----------------------------------------

	.byte $0C,$EF,$00,$FF,$00,$FF,$00,$FF  ; TODO: unused?

; -----------------------------------------

	.include "inc.sprites_monsters2.asm"

; -----------------------------------------

draw_player1_lives .proc
	; draws from characters the extra lives of player1

	screen_ptr = tmp_text_lo_ptr
	tmp_lives = tmp_0002

	LDX lives_player1
	BPL _draw_p1_lives ; player1 is alive
	LDX #DEAD_PLAYER
	STX actor_type_tbl+1
	STX lives_player1
	; switch off player1 sprite
	LDA VIC_D015
	AND #$FD
	STA VIC_D015

	LDA lives_player2
	BPL _p2_alive ; player2 is alive

	; everybody's dead, game over
	LDA #STATUS_GAME_OVER
	STA game_status
_p2_alive
	RTS

_draw_p1_lives
	; open player1 cage
	LDA #$04
	STA SCR_06CB
	LDA #$00
	STA SCR_06C9
	STA SCR_06CA

	 ; start launch counter
	LDA #$09
	STA launch_counters+1

	; clear the space on the right side where the lives are displayed with "01 00 00" pattern, for 9 lines
	PTR_SET2 screen_ptr, $0604
	LDX #$08

_clear_lives
	; "00 00"
	LDA #$00
	LDY #$02
-	STA (screen_ptr),Y
	DEY
	BNE -

	; "01"
	LDA #$01
	STA (screen_ptr),Y

	; this clears the p1 cage, one character for each line
	LDY draw_dungeon.block_offsets,X
	LDA #$00
	STA SCR_06F1,Y

	PTR_ADD screen_ptr, #40 ; next line

	DEX
	BPL _clear_lives


	LDX lives_player1
	DEX
	DEX
	BMI _no_side_lives ; less than 2 extra lives left

_draw_side_lives
	STX tmp_lives
	PTR_SET_LOTBL_X screen_ptr, side_lives_pos_tbl
	LDX #$08
-	LDY draw_dungeon.block_offsets,X
	LDA block_player1_life,X
	STA (screen_ptr),Y
	DEX
	BPL -
	LDX tmp_lives
	DEX
	BPL _draw_side_lives

_no_side_lives
	LDX lives_player1
	DEX
	BMI _no_cage_life ; last life, no life in cage

	; draw life in cage
	LDX #$08
-	LDY draw_dungeon.block_offsets,X
	LDA block_player1,X
	STA SCR_06F1,Y
	DEX
	BPL -

_no_cage_life
	; position player sprite
	; TODO: why not simply put the sprite into the cage?
	; set sprite X coord
	LDA #$42
	LDX lives_player1
	BNE +
	LDA #$26
+
	STA VIC_S1X

	; Y coord
	LDA player_life_y_pos,X
	STA VIC_S1Y

	; sprite shape
	LDA #$82
	STA SPRITE_PTR+1

	; set Y coord MSB
	LDA VIC_D010
	ORA #$02
	STA VIC_D010

	; start launch countdown
	LDA #$00
	STA launch_status+1

	; set sprite color
	LDA #$07
	STA VIC_D028
	RTS

side_lives_pos_tbl	.lo_tbl $06F4,$067C,$0604

block_player1_life	.byte $01,$52,$53,$54,$55,$56,$01,$57,$58 ; ; 3x3 chars, player character looking left, border on left char, player in only on two rightmost chars

.pend

; -----------------------------------------

block_player1	.byte $00,$44,$45,$46,$47,$48,$00,$49,$4A ; 3x3 chars, player character looking left

player_life_y_pos	.byte $C5,$C5,$AD,$95,$7D

; -----------------------------------------

draw_player2_lives .proc
	; draws from characters the extra lives of player2
	; for comments see draw_player1_lives

	screen_ptr = tmp_text_lo_ptr
	tmp_lives = tmp_0002

	LDX lives_player2
	BPL _draw_p2_lives
	; player 2 is dead
	LDX #DEAD_PLAYER
	STX lives_player2
	STX actor_type_tbl
	LDA VIC_D015
	AND #$FE
	STA VIC_D015
	LDA lives_player1
	BPL _p1_alive
	LDA #STATUS_GAME_OVER
	STA game_status
_p1_alive
	RTS

_draw_p2_lives
	LDA #$01
	STA SCR_06AB
	LDA #$00
	STA SCR_06AC
	STA SCR_06AD

	LDA #$09
	STA launch_counters

	PTR_SET2 screen_ptr, $05e0
	LDX #$08
_clear_lives
	LDA #$00
	LDY #$01
-	STA (screen_ptr),Y
	DEY
	BPL -

	LDY #$02
	LDA #$04
	STA (screen_ptr),Y

	LDY draw_dungeon.block_offsets,X
	LDA #$00
	STA SCR_06D3,Y

	PTR_ADD screen_ptr, #40 ; next line

	DEX
	BPL _clear_lives

	LDX lives_player2
	DEX
	DEX
	BMI _no_side_lives

_draw_side_lives
	STX tmp_lives

	PTR_SET_TBL_X2 screen_ptr, side_lives_pos_tbl

	LDX #$08
-	LDY draw_dungeon.block_offsets,X
	LDA block_player2_life,X
	STA (screen_ptr),Y
	DEX
	BPL -
	LDX tmp_lives
	DEX
	BPL _draw_side_lives
_no_side_lives
	LDX lives_player2
	DEX
	BMI _no_cage_life

	LDX #$08
-	LDY draw_dungeon.block_offsets,X
	LDA block_player2,X
	STA SCR_06D3,Y
	DEX
	BPL -

_no_cage_life
	LDA #$1A
	LDX lives_player2
	BNE +
	LDA #$38
+
	STA VIC_S0X
	LDA player_life_y_pos,X
	STA VIC_S0Y
	LDA #$BC
	STA SPRITE_PTR
	LDA VIC_D010
	AND #$FE
	STA VIC_D010
	LDA #$00
	STA launch_status
	LDA #$06
	STA VIC_D027
	RTS

side_lives_pos_tbl	.lohi_tbl $06D0,$0658,$05E0
block_player2_life	.byte $59,$5A,$04,$5B,$5C,$5D,$5E,$5F,$04

.pend

; -----------------------------------------


block_player2	.byte $4B,$4C,$00,$4D,$4E,$4F,$50,$51,$00  ; 3x3 chars, player character looking right


; -----------------------------------------

open_warp_door .proc

	; show arrow
	LDA #$02
	STA COL_D918
	STA COL_D93E
	; draw the dashed lines
	LDX #$09
	STX SCR_04F2
	STX SCR_0514
	INX
	STX SCR_051A
	STX SCR_053C
	INX
	STX SCR_0542
	STX SCR_0564
	; remove invisible block from door
	LDA #$0F
	STA SCR_051B
	STA SCR_053B
	RTS

.pend

; -----------------------------------------

read_joy_direction .proc
	; read joy direction
	;  X: 0: port2, 1: port1
	; results:
	;  actor_heading_x: X direction ($ff: left / $00: center / $01: right)
	;  actor_heading_y: X direction ($ff: up / $00: center / $01: down)

	LDA CIA1_JOY_KEY1,X
	LDX #$00
	LDY #$00
	; up
	LSR A
	BCS +
	DEY
+
	; down
	LSR A
	BCS +
	INY
+
	; left
	LSR A
	BCS +
	DEX
+
	; right
	LSR A
	BCS +
	INX
+
	; store result
	STX actor_heading_x
	STY actor_heading_y

	RTS
.pend

; -----------------------------------------

; the animation tables - these hold only the first sprite of the animation, the other two should be the next two sprites in memory
;   some fun facts:
;     p1 and p2 have the same horizontal sprites but different vertical ones
;     worluk has only sprites for horizontal movement - it seems there was just no space left for that in the C64 version
;     the type between thorwor and worluk is not used, it's filled with worluk's animation as a placeholder
horizontal_animation_ptr_tbl	.lo_tbl_1 anim_pl_h, anim_pl_h, anim_bw_v, anim_gw_h, anim_tw_v, anim_vl_h, anim_vl_h, anim_ww_h
vertical_animation_ptr_tbl	.lo_tbl_1 anim_p2_v, anim_p1_v, anim_bw_h, anim_gw_v, anim_tw_h, anim_vl_h, anim_vl_h, anim_ww_v

type_color_tbl = *-1
		.byte $06,$07,$0E,$07,$0A,$00,$07,$0E

; since every tables have a hole in the middle we can pack them together by pairs: A1,?,A2 + B1,?,B2 -> A1,B1,A2,B2
anim_pl_h	.byte $80,?,$ba
	*=*-2
anim_p2_v	.byte $96,?,$a8

anim_p1_v	.byte $cc,?,$d1
	*=*-2
anim_bw_v	.byte $85,?,$bf

anim_bw_h	.byte $9b,?,$ad
	*=*-2
anim_gw_h	.byte $88,?,$c2

anim_gw_v	.byte $9e,?,$b0
	*=*-2
anim_tw_v	.byte $8b,?,$c5

anim_tw_h	.byte $a1,?,$b3
	*=*-2
anim_vl_h	.byte $92,?,$92

anim_ww_h	.byte $8e,?,$c8
	*=*-2
anim_ww_v	.byte $a4,?,$b6


; -----------------------------------------

init_cset .proc
	; set up character set at $0800-$1000
	; 0800-0808: left blank
	; 0808-0878: copied from cartridge
	; 0878-0880: left blank
	; 0880-09e8: copied from cartridge (packed chars)
	; 09e8-0b48: copied from cartridge
	; 0b48-0ce8: copied from char rom (uppercase letters, digits and some symbols - these are probably just as a side effect as 2*26 characters are copied: first A-Z, then 0-9 and the next 16 characters)
	; 0ce8-1000: left blank

	src_ptr = tmp_0014_ptr
	dst1_ptr = tmp_0008
	dst2_ptr = tmp_text_hi_ptr

	; charset locations
	cset_ram_custom1 = $09e8
	cset_ram_custom2 = $0808
	cset_ram_custom3 = $0880
	cset_ram_charrom1 = $0b48
	cset_ram_charrom2 = $0c18
	CHAR_ROM_A = $d008
	CHAR_ROM_B = $d180


	; first clear the memory for the custom cset
	LDA #$00
	TAX
_clr_cset
	STA $0800,X
	STA $0900,X
	STA $0a00,X
	STA $0b00,X
	DEX
	BNE _clr_cset

	; copy custom characters from cartridge
	PTR_SET2 src_ptr, cset_rom_custom1
	PTR_SET2 dst1_ptr, cset_ram_custom1

	; copy $300 bytes (09e8 - 0be8 (intended range is 09e8 - 0b48, but it was simpler to code it this way))
	LDX #$02
_cset_cpy
	LDY #$00
-	LDA (src_ptr),Y
	STA (dst1_ptr),Y
	DEY
	BNE -

	INC src_ptr+1
	INC dst1_ptr+1
	DEX
	BPL _cset_cpy

	; copy $70 bytes
	LDY #$6F
_cset_cpy_2
	LDA cset_rom_custom2,Y
	STA cset_ram_custom2,Y
	DEY
	BPL _cset_cpy_2

	; make char rom visible
	LDA #$53 ; RAM / CART / RAM / CHAR ROM / KERNAL
	STA $01

	; copy characters from the char rom
	; $1a0 bytes, 0b48-0ce8
	LDY #$D0
_cset_cpy_from_rom
	LDA CHAR_ROM_A-1,Y
	STA cset_ram_charrom1,Y
	LDA CHAR_ROM_B-1,Y
	STA cset_ram_charrom2,Y
	DEY
	BNE _cset_cpy_from_rom

	; switch back IO instead of char rom
	LDA #$57 ; RAM / CART / RAM / IO / KERNAL
	STA $01

	; copy packed chars
	; $168 bytes ($0880-$09e8)
	PTR_SET src_ptr,cset_rom_custom_packed
	; for the first $14 chars the upper 3 lines are empty
	PTR_SET dst2_ptr,cset_ram_custom3+3

	LDX #$13
	JSR copy_packed_chars

	; for the next $19 chars the lower 3 lines are empty
	PTR_SUB dst2_ptr, #3

	LDX #$18
	JSR copy_packed_chars
	RTS

copy_packed_chars
	; the number of chars to be copied is X+1
	; the lower or upper 3 lines of these chars are empty so it's not stored in the cart

	; copy five lines
	LDY #$04
_copy
	LDA (src_ptr),Y
	STA (dst2_ptr),Y
	DEY
	BPL _copy

	; inc dest by 8
	PTR_ADD dst2_ptr, #8
	; inc src by 5
	PTR_ADD src_ptr, #5

	; check if we need to copy more chars
	DEX
	BPL copy_packed_chars
	RTS
.pend

; ----------------------------------------------

irq_handler
	; called in every screen refresh at raster line $1B


	; acknowledge irq
	LDA VIC_D019
	STA VIC_D019

	AND #$01
	BEQ _run_timer ; skip the rest if it was not a raster interrupt - though I have no idea how that could happen (and have never seen happening)

	; the value of this counter is basically used as a random number
	DEC random_number

	; decrease animation timer for players and the bullets
	DEC animation_timer_tbl
	DEC animation_timer_tbl+1
	DEC bullet_move_counter

	; save pointer
	LDA tmp_0014_ptr
	STA tmp_irq_ptr_save
	LDA tmp_0014_ptr+1
	STA tmp_irq_ptr_save+1

	LDA is_title_screen
	BEQ _dont_skip_ingame_processing
	BNE _run_timer ; always branch

_dont_skip_ingame_processing

	; stop / start sound effects if necessary
	LDX next_sfx_idx
	BMI _leave_alone_sfx ; $80 means no new sfx

	CPX curr_sfx_idx
	BCC _leave_alone_sfx ; the current one has greater priority

	; stop current sfx and start next, clear next_sfx_idx
	JSR sfx.end_of_sfx ; BUG: X should be the no of channels idx, 1 or 2 - but here we pass it the idx (priority, actually) of the next sound effect
	LDX next_sfx_idx
	STX curr_sfx_idx
	LDA sfx_by_priority,X
	STA snd_sfx_to_start
	LDA #SFX_NO_SFX
	STA next_sfx_idx
_leave_alone_sfx

	; make garwors and thorwors invisible after a certain time
	LDX #MAX_PLAYERS
_check_invisibility_timers
	DEC one_second_wait_tbl,X
	BPL _not_invisible
	LDA #$3C
	STA one_second_wait_tbl,X
	DEC time_to_invis_counter,X
	BPL _not_invisible
	LDA #$0A ; will be invisible again after 10 seconds
	STA time_to_invis_counter,X
	DEC actor_speed_tbl,X
	; skip burwors (light blue sprites)
	LDA VIC_D027,X
	AND #$0F
	CMP #$0E
	BEQ _not_invisible
	; switch off sprite visibility
	LDA power_of_2_tbl,X
	EOR #$FF
	AND VIC_D015
	STA VIC_D015
_not_invisible
	INX
	CPX #$08
	BNE _check_invisibility_timers

_run_timer
	; timer for player launch and warp door opening
	DEC irq_timer_frame
	BNE _end_of_timer_section
	LDA #$41
	STA irq_timer_frame

	; check launch status for player2
	LDA launch_counters+1
	BMI _check_p1 ; no launch process ATM
	DEC launch_counters+1
	BNE _check_p1 ; countdown in process
	LDA lives_player1
	BMI _check_p1 ; no more lives for player1
	LDX #$01
	JSR move_actor.start_launch
_check_p1
	; check launch status for player1
	LDA launch_counters
	BMI _dont_launch_p1 ; no launch process ATM
	DEC launch_counters
	BNE _dont_launch_p1 ; countdown in process
	LDA lives_player2
	BMI _dont_launch_p1 ; no more lives for player1
	LDX #$00
	JSR move_actor.start_launch
_dont_launch_p1

	DEC unused_01 ; this seems to be unused
	; check warp door opening timer
	DEC irq_timer_sec
	BNE _end_of_timer_section
	; timer expired: open warp door, speed up music
	JSR open_warp_door
	DEC music_speed
	; keep music_speed above zero
	BNE _end_of_timer_section
	INC music_speed
_end_of_timer_section

	JSR sfx.play
	JSR jingles.play
	LDA #$C8
	STA VIC_D012

	; restore pointer
	LDA tmp_irq_ptr_save
	STA tmp_0014_ptr
	LDA tmp_irq_ptr_save+1
	STA tmp_0014_ptr+1

	; restore registers and end irq
	PLA
	TAY
	PLA
	TAX
	PLA
	RTI

sfx_by_priority	.byte $14,$06,$05,$09,$01,$07,$02,$04,$0B,$0C,$12,$11

; -----------------------------------------

warp_door_handler .proc
	; check if any actor entered the warp door, and if it did, teleport it and close the door
	;   returns: Z flag: 0: actor warped 1: no warp

	; for the warp door detection we check if X is one less than the X position in the leftmost corridor or one more than the X in the rightmost one
	; it can only happen in the warp door when it's open
	LDX actor_sprite_pos_offset
	LDA VIC_S0X,X
	CMP #$28 ; right door - it's actually $128, but we don't have to check the 9th bit because $028 is not a possible position
	BNE _check_left_door
	LDA #$37
	BNE _set_new_x_position ; always jump

_check_left_door
	CMP #$36
	BNE not_at_a_door ; TODO: when can this happen?
	LDA #$27

_set_new_x_position
	; set X
	STA VIC_S0X,X
	; invert 9th bit
	LDX actual_actor
	LDA VIC_D010
	EOR power_of_2_tbl,X
	STA VIC_D010

close
	; as the title says

	; hide arrows
	LDA #$00
	STA COL_D918
	STA COL_D93E

	; put invisible blocks in front of the doors
	STA SCR_051B
	STA SCR_053B

	; draw the solid lines
	LDX #$60
	STX SCR_04F2
	STX SCR_0514
	INX
	STX SCR_051A
	STX SCR_053C
	INX
	STX SCR_0542
	STX SCR_0564

	; set time until doors open again
	LDA #$0A
	STA irq_timer_sec
	LDA #SFX_WARP_DOOR_CLOSED
	STA next_sfx_idx

	; remove monster markers from the old positions
	LDA #$0F
	STA SCR_051C
	STA SCR_053A

	LDA #$00
not_at_a_door
	RTS

.pend

; -----------------------------------------


init_sid_cia_mem .proc
	; zero mem locations and init SID


	LDY #$00
	TYA

	; zero out variable storage area: the zero page (actually $0002-$0102, because $00 and $01 are reserved by the CPU) and $0200-$0300
-	STA $02,Y
	STA $0200,Y
	INY
	BNE -

	JSR KERNAL_IOINIT ; Initialize CIA's, SID volume; setup memory configuration; set and start interrupt timer.

	SEI

	; random seed :)
	LDA VIC_D012
	EOR #$55
	STA random_number

	JSR MV_init

	; reset high scores
	; fill up with spaces
	LDA #$25
	LDX #$1D
-	STA high_scores,X
	DEX
	BPL -

	; set the last digits to 0
	INX
	STX high_score_1+5
	STX high_score_2+5
	STX high_score_3+5
	STX high_score_4+5
	STX high_score_5+5
	TXA

	; zero out SID
	LDX #$18
_sidzero
	STA $d400,X
	DEX
	BPL _sidzero

	; volume to max
	LDA #$0F
	STA SID_FltMod_Vol

	LDA #$15
	STA snd_ingame_dur ; initialize in-game music speed
	LDA #$80
	STA snd_ingame_status ; start in-game music
	DEC lives_player1
	DEC lives_player2
	RTS

.pend

; -----------------------------------------

reset_per_dungeon_stuff .proc
	LDA #$04
	STA bullet_move_counter
	LDA #SFX_NO_SFX
	STA next_sfx_idx
	DEC game_status
	LDX #$05
	STX normal_monsters_on_screen
	LDA #$06
	STA burwors_alive
	LDA actor_type_tbl
	BMI + ; player2 is dead
	LDA #$01
	STA actor_type_tbl
+

	LDA actor_type_tbl+1
	BMI + ; player1 is dead
	LDA #$02
	STA actor_type_tbl+1
+

	; init all monsters to be burwors
	LDX #MAX_MONSTERS-1
	LDA #BURWOR
-	STA monster_type_tbl,X
	DEX
	BPL -

	; set initial music and monster speed based on dungeon number
	; in worlord dungeons (9+) it is set to the fastest possible value ($01)
	LDA current_dungeon
	CMP #$08
	BCC _not_worlord_dungeon
	LDA #$07
_not_worlord_dungeon
	EOR #$07
	TAX
	INX
	STX music_speed
	TXA
	LDX #$05
-	STA monster_speed_tbl,X
	DEX
	BPL -

	; initialize various stuff for actors
	LDX #$07
-	; somewhat randomize invisibility counter (values in $04-$07 range)
	LDA monster_head_ptr_tbl.hi,X
	STA time_to_invis_counter,X
	; reset various values
	LDA #$00
	STA curr_sfx_idx
	STA monster_head_ptr_tbl.lo,X
	STA firing_status,X
	STA bullet_direction,X
	STA bullet_pos.lo,X
	LDA #$04
	STA animation_timer_tbl,X
	STA monster_head_ptr_tbl.hi,X
	STA bullet_pos.hi,X
	LDA #$85
	STA SPRITE_PTR,X
	LDA #$0E
	STA VIC_D027,X
	DEX
	BPL -

	PTR_SET gameplay_ptr, normal_gameplay_loop ; regular monsterkilling

	; all sprites hi-res
	LDA #$00
	STA VIC_D01C

	RTS

.pend

; -----------------------------------------

update_radar .proc
	; as the title says

	radar_ptr = tmp_0014_ptr

	; set the radar to black
	LDX #$0A
	LDA #$00
-
	STA COL_DB06,X
	STA COL_DB2E,X
	STA COL_DB56,X
	STA COL_DB7E,X
	STA COL_DBA6,X
	STA COL_DBCE,X
	DEX
	BPL -


	; print enemies on the radar
	LDX #$0E
_put_monster_on_radar
	STX tmp_0002
	; calculate that in which 3x3 char block is the sprite
	; first calculate Y coordinate
	LDA VIC_S0Y,X ; get the sprite's y coordinate
	BEQ _next ; if it's 0, this monster is not active, skip it
	SEC
	SBC #$28    ; $28 is the first legal position
	LSR A       ; divide by 8
	LSR A
	LSR A

	LDY #$00    ; this is the line number on the radar display
	SEC
-	INY
	SBC #$03    ; because of the divide, it's essentially 24 (TODO: the whole LSR business is unneeded, just use 24 here? rounding?)
	BCS -
	DEY         ; we've got the line number (0-5) in Y
	CPY #$06    ; it should be 0-5, really :)  (TODO: when does this happen?)
	BCS _next
	PTR_SET_LOTBL_Y radar_ptr, radar_lines_tbl ; get pointer to the beginning of radar line

	; now the X coordinate, as above
	LDA VIC_S0X,X
	SEC
	SBC #$2A
	LSR A
	LSR A
	LSR A
	LDY #$00
	SEC
-	INY
	SBC #$03
	BCS -
	DEY
	CPY #$0B
	BCS _next
	; we have the column in Y

	; get the color of the sprite
	LDA tmp_0002
	LSR A
	TAX
	LDA VIC_D027,X
	AND #$07
	; and write it to the color ram to light up that position on the radar
	STA (radar_ptr),Y
_next
	LDX tmp_0002
	DEX
	DEX
	CPX #$02
	BNE _put_monster_on_radar
	; set in-game music's note duration
	LDA music_speed
	ASL A
	ASL A
	STA snd_ingame_dur
	RTS

radar_lines_tbl	.lo_tbl $DB06,$DB2E,$DB56,$DB7E,$DBA6,$DBCE

.pend

; -----------------------------------------

check_if_monster_can_be_invisible .proc
	; invisible monsters are shown if they are on the same row or column as one of the players
	; being on the same column/row is defined as the difference of their x/y coordinates is less than 21

	LDX actor_sprite_pos_offset
	;  if it's on the same row as...
	;   ...player 1
	LDA VIC_S0X,X
	SEC
	SBC VIC_S0X
	CMP #$16
	BCC _must_be_visible
	CMP #$E9
	BCS _must_be_visible
	;   ...player2
	LDA VIC_S0X,X
	SEC
	SBC VIC_S1X
	CMP #$16
	BCC _must_be_visible
	CMP #$E9
	BCS _must_be_visible

	;  if it's on the same coloumn as...
	;   ...player 1
	LDA VIC_S0Y,X
	SEC
	SBC VIC_S0Y
	CMP #$16
	BCC _must_be_visible
	CMP #$E9
	BCS _must_be_visible
	;   ...player2
	LDA VIC_S0Y,X
	SEC
	SBC VIC_S1Y
	CMP #$16
	BCC _must_be_visible
	CMP #$E9
	BCS _must_be_visible

	; check if it's a Burwor (by the color of the sprite) - they are always visible
	LDX actual_actor
	LDA VIC_D027,X
	AND #$0F
	CMP #$0E
	BEQ _show_actor ; yes, it's a Burwor
	RTS

_must_be_visible
	LDX actual_actor
	LDA time_to_invis_counter,X ; skip the "invisibility ends" sfx if the invisibility timer is about to trigger again
	BEQ _show_actor
	; if it actually WAS invisible play the "invisibility ends" sfx
	LDA VIC_D015
	AND power_of_2_tbl,X
	BNE _end ; it was not invisible to begin with
	LDA #SFX_INVISIBILITY_ENDS
	STA next_sfx_idx
_show_actor
	LDX actual_actor
	LDA VIC_D015
	ORA power_of_2_tbl,X
	STA VIC_D015
_end
	RTS

.pend

; -----------------------------------------



; ====================================================================
;
; sound stuff begins
;

;============================================================

jingles	.block

; -----------------------------------------

play .proc
	; the music player - this plays the three tunes: get ready / get ready + double score dungeon / game over
	LDY snd_pattern_pos
	BNE _play
	LDX snd_pattern_no
	BNE _init_snd
	RTS

_init_snd
	LDA #$08
	STA SID_PulHi2
	STA SID_PulHi3
	LDA #$F0
	STA SID_SR1
	LDA #$60
	STA SID_SR2
	LDA #$A0
	STA SID_SR3
	; Y is zero here
	STY SID_PulLo2
	STY SID_PulLo3
	STY SID_AD1
	STY SID_AD2
	STY SID_AD3
	STY SID_WV1
	STY SID_WV2
	STY SID_WV3
	STY snd_ingame_status
	STY snd_sfx_dur_cnt
	STY SID_Rsn_IO
	LDA #$0F
	STA SID_FltMod_Vol

	; initialize pattern pointer
	PTR_SET_LOTBL_X2 snd_pattern_ptr,snd_pattern_ptr_tbl

	LDA #$21
	STA SID_WV1
	LDA #$41
	STA SID_WV2
	STA SID_WV3
	BNE _read_next_pattern_entry ; always jump

_play
	DEC snd_duration
	BNE _do_vibrato
	TYA
	CLC
	ADC #$03
	TAY
_read_next_pattern_entry
	LDA (snd_pattern_ptr),Y
	BEQ _end_of_music
	STA snd_duration
	INY
	STY snd_pattern_pos

_do_vibrato
	LDA snd_duration
	AND #$07
	TAX
	LDA snd_vibrato_tbl,X
	STA snd_vibrato
	LDA #$00
	STA snd_voice_offset
	JSR snd_set_sound_freq
	LDA #$07
	STA snd_voice_offset
	INY
	JSR snd_set_sound_freq
	LDA #$0E
	STA snd_voice_offset
	INY
	JSR snd_set_sound_freq
	RTS

_end_of_music
	; A is zero here
	STA SID_WV1
	STA SID_WV2
	STA SID_WV3
	STA snd_pattern_pos
	STA snd_pattern_no
	RTS

snd_vibrato_tbl	.byte $00,$14,$3C,$64,$78,$64,$3C,$14
snd_freq	.lohi_tbl_1 $0598,$0647,$070C,$0A8F,$0B30,$0E18,$11C3,$12D1,$151F,$1660,$1A9C,$10C3

snd_set_sound_freq
	LDA (snd_pattern_ptr),Y
	BEQ _set_freq_lo
	TAX
	LDA snd_vibrato
	CLC
	ADC snd_freq.lo,X
_set_freq_lo
	LDX snd_voice_offset
	STA SID_FrqLo1,X
	INC snd_voice_offset ; TODO: this is stupid, really, just use SID_FrqHi1 in the next STA
	LDA (snd_pattern_ptr),Y
	BEQ _set_freq_hi
	TAX
	LDA snd_freq.hi,X
	ADC #$00
_set_freq_hi
	LDX snd_voice_offset
	STA SID_FrqLo1,X
	RTS
	.pend

; -----------------------------------------

.bend ; jingles

;============================================================


sfx	.block
;
; in-game music + sfx player
; this plays the in-game music and the sound effects
;
snd_voice_base_tbl .lohi_tbl_1 $d400, $d407, $d40e, $d415

snd_pitch_tbl .lohi_tbl_1 $0300, $0325, $0340

; -----------------------------------------

play .proc
	; plays the ingame music and effects

	; this is the in-game "music", played on channel 1
	LDX snd_ingame_status ; status:
	BEQ _sfx_player       ; 0: no music
	BPL _play             ; $80 (and above, but only $80 is used): start music
	                      ; 01-03: music is playing Nth note (starting note is the 2nd and it's played backwards: 2,1,3,2,1,3 etc)
	; init sound
	LDX #$00
	STX SID_PulLo1
	INX
	STX snd_ingame_dur_cnt
	INX
	STX snd_ingame_status
	LDA #$08
	STA SID_PulHi1
	LDA #$00
	STA SID_SR1
	LDA #$0A
	STA SID_AD1
_play
	DEC snd_ingame_dur_cnt
	BNE _sfx_player
	LDA #$00
	STA SID_WV1
	PTR_SET_TBL_X SID_FrqLo1, snd_pitch_tbl
	LDA snd_ingame_dur
	STA snd_ingame_dur_cnt
	LDA #$41
	STA SID_WV1
	DEC snd_ingame_status
	BNE _sfx_player
	LDA #$03
	STA snd_ingame_status


_sfx_player
	; the effect player
	;
	; there are two kinds of effect: ones that are played on a single channel (voice 3) and ones that are played on two channels (voice 2 and 3)
	; voice 3 is restarted when its envelope is 0 (i.e. the D phase is over and S is zero), these restarts may use a different waveform than the first run
	;
	; the sfx's are described by 20 / 27 bytes of data
	;
	; first byte of the effect:
	;  bits 0-2: duration of sfx (0-7)
	;  bit    3: some effect (0: off, 1: on)
	;  bits 4-6: value of frequency change amplification (0-7)
	;  bit    7: number of channels to be used for the effect (0: channel 3, 1: channels 2+3)
	; next 11 / 18 bytes of the sfx are the initial values for sid registers starting from $d40e (single channel) or $d407 (dual channel) up to $d418 (although 8 more is copied)
	; next byte is the waveform used for restarts of voice 3
	; the last byte is the number of sfx to start when the current one is finished so the sfx's can be chained
	; the rest of the bytes seem to be unused

	LDX snd_sfx_to_start
	BNE _start_sfx
	LDA snd_sfx_dur_cnt
	BNE play_sfx
	RTS

_start_sfx
	; first check if music have to be stopped
	; effects $01-$08 and $14 (the single-channel ones) do not stop it, everything else (the dual-channel ones) does
	CPX #$14
	BEQ _load_sfx
	CPX #$09
	BCC _load_sfx
	; stop music
	LDA #$00
	STA snd_ingame_status
_load_sfx
	; set up pointer to effect data
	PTR_SET_TBL_X snd_sfx_ptr, snd_sfx_ptr_tbl
	; init sid and variables
	LDY #$00
	STY snd_sfx_effect_switch
	STY snd_sfx_to_start
	STY SID_WV1 ; I guess it would be only necessary when stopping music TODO: check it
	STY SID_WV3
	STY SID_AD3
	STY SID_SR3

	; load first byte of the effect
	LDA (snd_sfx_ptr),Y
	TAX
	; get the freq change amplification value
	AND #$70
	LSR A
	LSR A
	LSR A
	LSR A
	STA snd_sfx_shifts_no
	; find out the duration
	TXA
	AND #$07
	STA snd_sfx_dur_cnt
	; get the effect switch
	TXA
	AND #$08
	STA snd_sfx_effect_switch
	; find out how many channels to use
	TXA
	ASL A
	LDX #$02 ; default is one
	BCC _prepare_to_sid_copy
	DEX ; oh, bit 7 is set, is we use two channles

_prepare_to_sid_copy
	STX snd_sfx_no_of_channels_idx ; number of channels used index: 1 - 2 channels, 2 - 1 channels
	LDY bytes_to_copy_into_sid_tbl-1,X ; X is 1-based
	JSR snd_set_up_sfx_base_sid_ptr
_copy_to_sid
	LDA (snd_sfx_ptr),Y
	DEY
	STA (snd_voice_base_ptr),Y
	BNE _copy_to_sid
	RTS

.pend

; -----------------------------------------

bytes_to_copy_into_sid_tbl
	.byte $19,$12


second_wv3_pos
	.byte $13,$0C

; -----------------------------------------

play_sfx .proc
	; called periodically to keep effects playing

	LDX snd_sfx_no_of_channels_idx
	LDA SID_Env
	BNE _sound_manipulation

	; the ADSR curve for voice3 is at its end, restart voice3
	STA SID_WV3
	; for the second (and subsequent) plays a second waveform is used
	LDY second_wv3_pos-1,X ; X is 1-based
	LDA (snd_sfx_ptr),Y
	STA SID_WV3

	DEC snd_sfx_dur_cnt ; decrease duration counter and check if we are at the end
	BNE _sound_manipulation
	BEQ end_of_sfx ; counter is zero, stop this sfx

_sound_manipulation

	LDY #$01 ; first for the first channel
_freq_manipulation
	; first get the original freq
	JSR snd_set_up_sfx_base_sid_ptr
	LDA (snd_sfx_ptr),Y
	STA snd_sfx_freq_lo
	INY
	LDA (snd_sfx_ptr),Y
	STA snd_sfx_freq_hi
	LDA SID_Osc ; the oscillator value of voice 3 - I guess it's used as a somewhat random value
	BNE _inc_freq
	LDY snd_sfx_effect_switch ; TODO: find out what audible effect it causes
	BEQ _inc_freq
	TAY
	STA snd_sfx_freq_lo
	BEQ _set_freq_to_sid ; always branches

_inc_freq
	JSR increase_sfx_freq
	STA snd_sfx_freq_hi
	LDA SID_Env
	JSR increase_sfx_freq
_set_freq_to_sid
	INY
	STA (snd_voice_base_ptr),Y
	DEY
	LDA snd_sfx_freq_lo
	STA (snd_voice_base_ptr),Y
	; if it's a dual channel effect do this also for the second channel
	CPX #$01
	BNE _filter_manipulation
	INX
	LDY #$08
	BNE _freq_manipulation

_filter_manipulation
	; shift voice 3 freq lo byte up by 5 bits and use it as the lo byte of the filter freq
	LDY #$05
_shift_loop
	ASL A
	DEY
	BNE _shift_loop
	STA SID_FltLo
	; use voice 3 freq hi byte as the hi byte of the filter freq
	LDA snd_sfx_freq_hi
	STA SID_FltHi
	RTS
.pend

; -----------------------------------------

increase_sfx_freq .proc
	; A - (random) value to increase freq with

	; store value as a 16 bit number
	STA snd_sfx_freq_inc_lo
	LDA #$00
	STA snd_sfx_freq_inc_hi

	; multiply it with 2^snd_sfx_shifts_no
	LDY snd_sfx_shifts_no
	BEQ _no_shifting
_shift_loop
	ASL snd_sfx_freq_inc_lo
	ROL snd_sfx_freq_inc_hi
	DEY
	BNE _shift_loop
_no_shifting

	; add it to the frequency
	LDA snd_sfx_freq_lo
	CLC
	ADC snd_sfx_freq_inc_lo
	STA snd_sfx_freq_lo
	LDA snd_sfx_freq_hi
	ADC snd_sfx_freq_inc_hi
	RTS
.pend

; -----------------------------------------

end_of_sfx .proc
	; stops currently playing effect
	;  X: if effect uses two channels ($01 - yes)
	LDA #$00
	STA curr_sfx_idx
	STA snd_sfx_dur_cnt
	STA SID_WV3
	STA SID_AD3
	STA SID_SR3
	CPX #$01      ; was this a dual-channel effect?
	BNE _dont_reset_music_voice
	STA SID_WV1   ;  yes, reset music voice too
_dont_reset_music_voice
	STA SID_WV2
	; load chained effect
	LDY bytes_to_copy_into_sid_tbl-1,X ; X is 1-based
	INY
	LDA (snd_sfx_ptr),Y
	STA snd_sfx_to_start
	RTS
.pend

; -----------------------------------------

snd_set_up_sfx_base_sid_ptr .proc
	; X - voice
	; sets the base voice pointer to the appropiate sid voice

	PTR_SET_TBL_X snd_voice_base_ptr, snd_voice_base_tbl
	RTS

.pend

; -----------------------------------------

; the effects
; see _sfx_player for an explanation of what each byte means

snd_sfx_1	.byte $51,$25,$13,$00,$00,$11,$00,$f0,$00,$16,$00,$08,$41,$a0,$00,$00,$00,$01,$cf,$00
snd_sfx_2	.byte $41,$00,$1d,$c0,$01,$43,$00,$f0,$88,$00,$00,$08,$41,$c0,$00,$00,$00,$01,$cf,$03
snd_sfx_3	.byte $41,$25,$03,$00,$00,$81,$0a,$00,$00,$00,$00,$00,$01,$09,$00,$00,$00,$01,$cf,$00
snd_sfx_4	.byte $51,$90,$11,$00,$00,$15,$00,$f0,$00,$00,$00,$00,$01,$b0,$00,$00,$00,$01,$cf,$00
snd_sfx_5	.byte $57,$00,$18,$00,$00,$81,$00,$80,$00,$00,$00,$00,$01,$32,$00,$00,$00,$01,$cf,$00
snd_sfx_6	.byte $71,$00,$03,$00,$00,$13,$00,$f0,$00,$00,$00,$00,$01,$7a,$00,$00,$00,$01,$cf,$00
snd_sfx_7	.byte $3b,$77,$2a,$94,$00,$41,$00,$f0,$00,$16,$00,$08,$41,$90,$00,$00,$00,$01,$cf,$00
snd_sfx_8	.byte $4a,$77,$28,$00,$01,$41,$00,$f0,$00,$16,$00,$08,$41,$a0,$00,$00,$00,$01,$cf,$00
snd_sfx_9	.byte $d3,$00,$04,$00,$08,$43,$00,$80,$08,$04,$00,$00,$81,$00,$f0,$00,$00,$00,$00,$01,$b9,$00,$00,$00,$f3,$cf,$0a
snd_sfx_10	.byte $a1,$00,$04,$00,$08,$43,$00,$70,$00,$04,$00,$00,$81,$00,$f0,$0a,$00,$00,$00,$11,$f0,$00,$00,$00,$f3,$cf,$09
snd_sfx_11	.byte $a9,$00,$00,$00,$06,$43,$00,$70,$00,$04,$00,$00,$81,$00,$70,$70,$00,$00,$08,$41,$ba,$00,$00,$00,$00,$8f,$00
snd_sfx_12	.byte $8c,$00,$3d,$77,$08,$43,$00,$f0,$00,$3c,$88,$07,$41,$00,$f0,$b3,$00,$00,$08,$41,$70,$00,$00,$00,$f3,$cf,$0d
snd_sfx_13	.byte $e1,$00,$01,$77,$08,$41,$00,$f0,$00,$80,$02,$07,$43,$00,$f0,$00,$16,$00,$08,$21,$07,$00,$00,$00,$f3,$cf,$0e
snd_sfx_14	.byte $d9,$00,$01,$77,$08,$41,$00,$f0,$00,$00,$51,$07,$41,$00,$f0,$a0,$01,$00,$08,$41,$80,$00,$00,$00,$f3,$cf,$00

	; effect 1 is reused in the pointer table (snd_sfx_ptr_tbl) as effect 15 and 16

snd_sfx_17	.byte $c5,$00,$15,$00,$00,$81,$00,$f0,$88,$35,$00,$08,$43,$00,$f0,$80,$00,$00,$00,$11,$ca,$00,$00,$00,$f2,$cf,$00
snd_sfx_18	.byte $cd,$00,$2d,$00,$00,$15,$00,$f0,$88,$09,$00,$00,$15,$00,$f0,$14,$02,$00,$08,$41,$90,$00,$00,$00,$00,$0f,$13
snd_sfx_19	.byte $d9,$00,$00,$00,$00,$15,$00,$f0,$00,$00,$00,$00,$15,$00,$f0,$14,$02,$00,$08,$41,$09,$00,$00,$00,$00,$0f,$00
snd_sfx_20	.byte $43,$00,$05,$00,$00,$81,$0a,$00,$00,$00,$00,$00,$01,$44,$00,$00,$00,$01,$cf,$00

snd_sfx_ptr_tbl .lohi_tbl_1 (snd_sfx_1,snd_sfx_2,snd_sfx_3,snd_sfx_4,snd_sfx_5,snd_sfx_6,snd_sfx_7,snd_sfx_8,snd_sfx_9,snd_sfx_10,snd_sfx_11,snd_sfx_12,snd_sfx_13,snd_sfx_14,snd_sfx_1,snd_sfx_1,snd_sfx_17,snd_sfx_18,snd_sfx_19,snd_sfx_20)

.bend

;============================================================

	; the three jingles

	; get ready music
snd_pattern_1	.byte $3f,$01,$06,$08,$15,$02,$04,$09,$2a,$03,$05,$0a,$34,$01,$06,$08,$15,$00,$00,$00,$00

	; double score dungeon (played after pattern 1)
snd_pattern_2	.byte $c8,$03,$0c,$0b,$00

	; game over (game over tune is pattern 3 + pattern 1)
snd_pattern_3	.byte $54,$03,$08,$0a,$54,$03,$07,$09,$00

snd_pattern_ptr_tbl .lo_tbl_1 snd_pattern_1, snd_pattern_2, snd_pattern_3


; -----------------------------------------

;============================================================

magic_voice .block

; -----------------------------------------

say .proc
	; say a sentence (a sequence of words)
	; code of the sentence is in Y
	LDA is_MV_missing
	BNE _dont_say
	STY MV_sentence
	JSR MV_GET_STATUS
	BNE _dont_say
	LDY MV_sentence
	; set up pointer to sentence
	PTR_SET_LOTBL_Y MV_sentence_ptr, magic_voice.sentences_ptr_tbl

	; set up index (words in sentence are read from the end backwards)
	LDY #$00
	LDA (MV_sentence_ptr),Y
	STA MV_sentence_idx
	TAY
	TAX

	; wait until Magic Voice is ready
-	JSR MV_ENABLE_COMPLETION_CODE
	DEX
	BNE -

	; get first word
	LDA (MV_sentence_ptr),Y
	LDX #$01
	JSR MV_SAY_IT
_dont_say
	RTS
.pend

; -----------------------------------------

completion .proc
	; called by Magic Voice when speaking a word is completed

	; say next word
	DEC MV_sentence_idx
	LDY MV_sentence_idx
	LDA (MV_sentence_ptr),Y
	LDX #$01
	JSR MV_SAY_IT
	RTS
.pend

; -----------------------------------------


sentence_0	.byte $03,$23,$00,$03
sentence_1	.byte $02,$05,$04
sentence_2	.byte $01,$06
sentence_3	.byte $04,$09,$00,$08,$07
sentence_4	.byte $05,$0d,$0d,$0d,$0d,$0a
sentence_5	.byte $06,$0d,$0d,$0d,$0d,$0c,$0b
sentence_6	.byte $06,$0d,$0d,$0d,$0d,$0f,$0e
sentence_7	.byte $06,$0d,$0d,$0d,$0d,$10,$0e
sentence_8	.byte $05,$0d,$0d,$0d,$0d,$12
sentence_9	.byte $06,$0d,$0d,$0d,$0d,$14,$13
sentence_10	.byte $06,$0d,$0d,$0d,$0d,$23,$15
sentence_11	.byte $05,$0d,$0d,$0d,$0d,$16
sentence_12	.byte $03,$10,$18,$17
sentence_13	.byte $02,$1a,$19
sentence_14	.byte $05,$0d,$0d,$0d,$0d,$1b
sentence_15	.byte $05,$0d,$0d,$0d,$0d,$1c
sentence_16	.byte $07,$0d,$0d,$0d,$0d,$23,$00,$1d
sentence_17	.byte $06,$0d,$0d,$0d,$0d,$1f,$1e
sentence_18	.byte $0b,$22,$0d,$0d,$0d,$0d,$21,$21,$21,$20,$20,$20
sentence_19	.byte $05,$0d,$0d,$0d,$0d,$11
sentence_20	.byte $04,$02,$01,$23,$00

sentences_ptr_tbl .lo_tbl (sentence_0,sentence_1,sentence_2,sentence_3,sentence_4,sentence_5,sentence_6,sentence_7,sentence_8,sentence_9,sentence_10,sentence_11,sentence_12,sentence_13,sentence_14,sentence_15,sentence_16,sentence_17,sentence_18,sentence_19,sentence_20)

.bend

;============================================================

;
; sound stuff ends
;
; ====================================================================


; -----------------------------------------

fire_bullet .proc
	; handles firing a bullet
	;  X: actual actor

	screen_ptr = tmp_0014_ptr
	screen_offset = tmp_0008

	LDA #(FIRING_BULLET_ACTIVE | FIRING_FIRE_BUTTON)
	STA firing_status,X
	; set bullet direction and char
	; horizontal shot
	LDY #$40
	LDA actor_heading_x_tbl,X
	STA bullet_direction,X
	BNE _really_horizontal
	; no, it's a vertical shot
	LDA actor_heading_y_tbl,X
	BEQ _shot_cancelled ; it's not a vertical shot, either - this may happen when the player is just killed or its sprite is changed to BOOM1
	TAY
	INY
	LDA vertical_bullet_direction_tbl,Y
	STA bullet_direction,X
	LDY #$41
_really_horizontal
	STY bullet_char,X

	; calculate the starting position of the bullet
	LDY actor_sprite_pos_offset
	LDA VIC_S0Y,Y
	STA tmp_sprite_y
	LDA VIC_S0X,Y
	STA tmp_sprite_x
	LDX #$01
	JSR sprite_pos_to_char_ptr

	; store bullet position
	LDX actual_actor
	LDA screen_ptr+1
	STA bullet_pos.hi,X
	LDA screen_ptr
	CLC
	ADC screen_offset
	STA bullet_pos.lo,X
	BCC +
	INC bullet_pos.hi,X
+
	; check if something's blocking the bullet
	LDA (screen_ptr),Y
	CMP #FLOOR
	BEQ _not_blocked
	CMP #MONSTER_HEAD
	BEQ _not_blocked
	CMP #$82 ; TODO: ?
	BEQ _not_blocked
_shot_cancelled
	LDA firing_status,X
	AND #FIRING_FIRE_BUTTON ; clear FIRING_BULLET_ACTIVE
	STA firing_status,X
_not_blocked
	RTS

vertical_bullet_direction_tbl	.byte $D8,$00,$28

.pend

; -----------------------------------------

move_bullets .proc
	; bullets are represented by chars on the screen
	; this procedure moves them around the screen and checks collision with other bullets and walls

	screen_ptr = tmp_0014_ptr

	; move bullets on every 2nd screen refresh
	LDA bullet_move_counter
	BMI _check_bullets
	RTS
_check_bullets
	LDA #$01
	STA bullet_move_counter

	; monster bullets are moved in only every 4th screen refresh
	; except for the Wizard - its bullets as fast as the players'
	INC monster_bullet_move_counter
	LDX #MAX_ACTORS-1
	LDA monster_type_tbl     ; is it the wizard?... (the wizard is always the first monster in the type tbl)
	CMP #WIZARD
	BEQ _move_bullet ; ...yes, don't skip monster bullets
	LDA monster_bullet_move_counter
	AND #$01
	BEQ _move_bullet
	LDX #MAX_PLAYERS-1 ; move only player's bullets

_move_bullet
	; clear bullet on screen
	PTR_SET_TBL_X screen_ptr, bullet_pos
	LDY #$00
	LDA #$0F
	STA (screen_ptr),Y

	LDA bullet_direction,X
	BNE _bullet_is_moving

	LDA firing_status,X
	AND #FIRING_FIRE_BUTTON ; clear FIRING_BULLET_ACTIVE
	STA firing_status,X

_reset_bullet_pos
	LDA #$00
	STA bullet_pos.lo,X
	LDA #$04
	STA bullet_pos.hi,X
	BNE _next ; always branch

_bullet_is_moving
	; treat A as a signed number
	; and add it to screen_ptr and bullet_pos,X
	CLC
	ADC screen_ptr
	STA screen_ptr
	STA bullet_pos.lo,X
	LDA bullet_direction,X
	BMI _dec_pos ; A is negative
	BCC _check_new_pos
	INC bullet_pos.hi,X
	INC screen_ptr+1
_check_new_pos
	; check what's on the new position
	LDA (screen_ptr),Y
	CMP #FLOOR
	BEQ _print_bullet
	CMP #MONSTER_BULLET_V
	BEQ _print_bullet
	CMP #MONSTER_BULLET_H
	BEQ _print_bullet
	CMP #MONSTER_HEAD
	BEQ _print_bullet
	CMP #PLAYER_BULLET_V
	BEQ _player_bullet_hit
	CMP #PLAYER_BULLET_H
	BNE _wall_is_hit
_player_bullet_hit
	; a player's bullet is hit...
	CPX #MAX_PLAYERS
	BCS _print_bullet
	; ...by another player: cancel both

	LDA #$00
	STA bullet_direction
	STA bullet_direction+1
	LDX #$01
	BNE _move_bullet ; always branch

_dec_pos
	BCS _check_new_pos
	DEC screen_ptr+1
	DEC bullet_pos.hi,X
	BNE _check_new_pos ; always branch

_print_bullet
	LDA bullet_char,X
	STA (screen_ptr),Y
_next
	DEX
	BPL _move_bullet

	RTS

_wall_is_hit
	LDA #$00
	STA bullet_direction,X
	BEQ _reset_bullet_pos ; always branch

.pend

; -----------------------------------------

print_2x1_letter	.proc
	; prints a letter / digit that is two characters high and one character wide
	;  A: code of the char to be printed
	;  tmp_00e9: color of the char
	;  tmp_0014_ptr: pointer to the letter's upper char on screen
	;  tmp_000b: pointer to the letter's upper char in color ram
	;
	; A, X, Y are preserved

	; aliases
	store_a = tmp_0008
	store_y = tmp_0009
	store_x = tmp_000a
	line_color = tmp_00e9
	screen_ptr = tmp_0014_ptr
	colorram_ptr = tmp_000b

	; save A, X, Y
	STA store_a
	STY store_y
	STX store_x
	; print top character and set color
	TAX
	LDY #$00
	LDA top_char,X
	STA (screen_ptr),Y
	LDA line_color
	STA (colorram_ptr),Y
	; set bottom character color and print it
	LDY #$28
	STA (colorram_ptr),Y
	LDA bottom_char,X
	STA (screen_ptr),Y

	; increase pointers for the next char
	INC colorram_ptr
	INC screen_ptr
	BNE +
	INC screen_ptr+1
	INC colorram_ptr+1
+
	; restore A, X, Y
	LDA store_a
	LDY store_y
	LDX store_x
	RTS

	; tables to create the digits/letters
top_char
	.byte $10,$11,$12,$12,$13,$14,$15,$16
	.byte $17,$18,$18,$19,$1A,$1B,$14,$14
	.byte $1A,$13,$1D,$1C,$1E,$1F,$20,$21
	.byte $10,$19,$3D,$19,$15,$1D,$22,$22
	.byte $23,$3D,$22,$16,$3E,$00,$00

bottom_char
	.byte $24,$25,$26,$27,$28,$27,$29,$2A
	.byte $2B,$27,$2C,$2D,$2E,$2F,$26,$31
	.byte $32,$2C,$25,$30,$33,$34,$35,$36
	.byte $24,$31,$3D,$33,$27,$37,$24,$38
	.byte $39,$3D,$3A,$3B,$3F,$00,$3C
.pend

; -----------------------------------------

display_copyright_and_high_scores .proc
	; displays copyrights and high scores

	LDA #$01
	STA is_title_screen

	; initialize suff

	; hires, scroll pos 0
	LDA #$0F
	STA VIC_D016
	; hide sprites
	LDA #$00
	STA VIC_D015

	; stop music
	STA snd_ingame_status ; stop in-game music
	STA SID_WV1           ; mute music
	STA snd_pattern_pos   ; stop jingle music

	; print four lines: copyrights, "HIGH SCORES" and "GET READY"
	PTR_SET tmp_text_hi_ptr, text_ptr.hi
	PTR_SET tmp_text_lo_ptr, text_ptr.lo
	LDX #$03
	JSR print_text_lines

	; draw the player scores
	JSR draw_score_boxes
	JSR score.print
	JSR score.print.only_player2

	JSR print_easter_egg

	JSR high_score.print

	JSR check_if_game_is_started
	RTS

text_01	.text_line $0E,$01,$09,"©1980 midway mfg. co."
text_02	.text_line $0E,$03,$0C,  "©1983 commodore"
text_03	.text_line $0A,$06,$0E,    "high scores"
text_04	.text_line $0A,$16,$0F,     "get ready"

text_ptr	.lohi_tbl (text_01, text_02, text_03, text_04)

.pend

; -----------------------------------------

print_enemies_table .proc
	; displays the names and score values of enemies

	; hires, scroll pos 0
	LDA #$0F
	STA VIC_D016
	; sprites 0-6 visible, 7 invisible
	LDA #$7F
	STA VIC_D015

	; set the all sprites' x and y positions to $97
	; the intent is just to set the X position but it's simpler this way and we will overwrite Y positions in the next loop
	LDX #$0F
	LDA #$97
-	STA VIC_S0X,X
	DEX
	BPL -

	; set the y positions of the first seven sprites: 7th one is at 56 and every next one is 24 pixel deeper
	LDA #$38
	LDX #$0D
-	STA VIC_S0X,X
	CLC
	ADC #$18
	DEX
	DEX
	BPL -

	; set the color of sprite 4 (the second Worrior) - this seems to be superfluous as we set the color of all seven in the next loop
	LDA #$0A
	STA VIC_D02B

	; the first two sprites (Worluk and Wizard) are multi, the rest are hires
	LDA #$02
	STA VIC_D01C

	; set the MSB of the X position to 0 for all sprites
	LDA #$00
	STA VIC_D010

	; set the sprite shapes and color for the seven visible sprites
	LDX #$06
-	LDA sprites_shape_tbl,X
	STA SPRITE_PTR,X
	LDA sprites_color_tbl,X
	STA VIC_D027,X
	DEX
	BPL -

	; since the Worluk description has an extra line, the Wizard of Wor sprite has to be moved down 16 pixels
	LDA VIC_S0Y
	CLC
	ADC #$10
	STA VIC_S0Y

	; set up pointers to lines of text
	PTR_SET tmp_text_hi_ptr, text_ptr.hi
	PTR_SET tmp_text_lo_ptr, text_ptr.lo
	LDX #$07 ; print 8 lines
	JSR print_text_lines
	JSR check_if_game_is_started
	RTS

text_0	.text_line $0e,$01,$07,       " burwor      100  points"
text_1	.text_line $07,$04,$08,        "garwor      200  points"
text_2	.text_line $0a,$07,$07,       "thorwor      500  points"
text_3	.text_line $0e,$0a,$07,       "worrior     1000  points"
text_4	.text_line $07,$0d,$07,       "worrior     1000  points"
text_5	.text_line $0a,$10,$08,        "worluk     1000  points"
text_6	.text_line $0a,$12,$13,                   "double score"
text_7	.text_line $07,$15,$01, "wizard of wor     2500  points"

text_ptr .hilo_tbl (text_0,text_1,text_2,text_3,text_4,text_5,text_6,text_7)

sprites_shape_tbl	.byte $8E,$92,$82,$82,$8C,$89,$87
sprites_color_tbl	.byte $0E,$07,$07,$0E,$0A,$07,$0E

.pend

; -----------------------------------------

print_text_lines .proc
	; prints colored text lines wit the 2x1 charset
	;  tmp_text_lo_ptr: pointer table with the lo bytes of pointers to text lines
	;  tmp_text_hi_ptr: pointer table with the hi bytes of pointers to text lines
	;  X: number of lines-1
	;
	; text line structure (see .struct text_line):
	;  0: color
	;  1: number of screen line
	;  2: starting character pos in the line
	;  3: text lenght
	;  4: text (in a custom coding, $00-$09: digits, $0a - $23: letters, $24: (C), $25: space, $26: .)

	; aliases
	actual_line = tmp_0002
	text_line_ptr = tmp_000d
	text_length = tmp_000f

	line_color = tmp_00e9
	screen_ptr = tmp_0014_ptr
	colorram_ptr = tmp_000b

	; set up pointer to the actual line
	STX actual_line
	LDY actual_line
	LDA (tmp_text_hi_ptr),Y
	STA text_line_ptr+1
	LDA (tmp_text_lo_ptr),Y
	STA text_line_ptr


	; get text color
	LDY #$00
	LDA (text_line_ptr),Y
	STA line_color
	; get screen line to write
	INY
	LDA (text_line_ptr),Y
	TAX
	LDA screen_line_ptr.lo,X
	; get the position in the line and set up screen and color ram pointers
	CLC
	INY
	ADC (text_line_ptr),Y
	STA screen_ptr
	STA colorram_ptr
	LDA screen_line_ptr.hi,X
	ADC #$00
	STA screen_ptr+1
	ADC #$D4
	STA colorram_ptr+1

	; get text length
	INY
	LDA (text_line_ptr),Y
	STA text_length
	PTR_ADD text_line_ptr, #4

	; print characters
	LDY #$00
-	LDA (text_line_ptr),Y
	JSR print_2x1_letter
	INY
	CPY text_length
	BNE -

	; check if there's more lines to print
	LDX actual_line
	DEX
	BPL print_text_lines

	; try to say something
	LDA random_number
	AND #$0F
	TAY
	JSR magic_voice.say
	RTS

.pend

; -----------------------------------------

;============================================================

score .block

; -----------------------------------------

add_to_p1
	; increases player1's score by a given amount
	; A = score increase / 100

	; check double score
	LDY game_status
	BPL _not_double_score
	ASL A
_not_double_score
	STA tmp_score
	PTR_SET score_ptr, player1_score_string

add_score
	LDX tmp_score

_inc_score_by_100
	; the last two zeroes are just decoration so we basically just add 1 to the score
	LDY #$03

_increase_digit
	.enc "2x1"
	LDA (score_ptr),Y
	CLC
	ADC #$01
	STA (score_ptr),Y
	CMP #' '+1 ; it was a space
	BNE _not_space
	LDA #'1'
	STA (score_ptr),Y
_not_space
	CMP #'9'+1 ; we have just increased a '9'
	BNE _no_carry
	LDA #'0'
	STA (score_ptr),Y
	DEY
	BPL _increase_digit
_no_carry
	DEX
	BNE _inc_score_by_100
	; and if we increased the score, the penultimate character must be 0, not space
	TXA ; '0'
	LDY #$04
	STA (score_ptr),Y

print .proc
	; prints the scores of the players

	; aliases
	line_color = tmp_00e9
	screen_ptr = tmp_0014_ptr
	colorram_ptr = tmp_000b

	; set up pointers to screen and color ram
	LDA #$07
	STA screen_ptr+1
	LDA #$DB
	STA colorram_ptr+1
	LDA #$8F
	STA screen_ptr
	STA colorram_ptr
	; set color
	LDA #$07
	STA line_color
	; print the score
	LDX #$00
-	LDA player1_score_string,X
	JSR print_2x1_letter
	INX
	CPX #$06
	BNE -

only_player2 ; TODO: calls to this label seems to be unnecessary
	; set up pointers to screen and color ram
	LDA #$07
	STA screen_ptr+1
	LDA #$DB
	STA colorram_ptr+1
	LDA #$72
	STA screen_ptr
	; set color
	STA colorram_ptr
	LDA #$06
	STA line_color
	; print the score
	LDX #$00
-	LDA player2_score_string,X
	JSR print_2x1_letter
	INX
	CPX #$06
	BNE -

	RTS
	.pend
; -----------------------------------------

add_to_p2 .proc
	; increases player2's score by a given amount
	; A = score increase / 100

	; check double score
	LDY game_status
	BPL _not_double_score
	ASL A
_not_double_score
	STA tmp_score
	PTR_SET2 score_ptr, player2_score_string
	BNE add_score ; always branches
	.pend

.bend

;============================================================

; -----------------------------------------

draw_score_boxes .proc
	; displays the two boxes on the bottom that display the scores

	screen_ptr = tmp_0014_ptr

	; draw the upper and bottom lines and set char color for the whole box
	LDY #$09
-
	LDA #$3D
	STA $0748,Y
	STA $07C0,Y
	STA $0765,Y
	STA $07DD,Y
	LDA #$06
	STA $DB48,Y
	STA $DB70,Y
	STA $DB98,Y
	STA $DBC0,Y
	LDA #$07
	STA $DB65,Y
	STA $DB8D,Y
	STA $DBB5,Y
	STA $DBDD,Y
	DEY
	BPL -

	; draw the right and left sides of the boxes
	INY
	LDX #$07
	STX screen_ptr+1
-
	LDA box_side_ptr_lo,X
	STA screen_ptr
	LDA #$3D
	STA (screen_ptr),Y
	DEX
	BPL -
	RTS

box_side_ptr_lo	.byte $70,$98,$79,$A1,$8D,$B5,$96,$BE

.pend

; -----------------------------------------

print_radar_title	.proc
	; prints a predefined text on top of the radar
	; word is selected by X
	; 0: dungeon
	; 1: the Pit
	; 2: the Arena
	; 3: worlord (in blue) - not used
	; 4: worlord (in yellow)
	; 5: radar
	; 6: escaped
	; 7: worluk
	; 8: wizard of wor
	; 9: double score

	title_ptr = tmp_0014_ptr
	tmp_color = tmp_00e9

	; set up pointer
	PTR_SET_LOTBL_X title_ptr, title_text_tbl

	; get color
	LDA title_color_tbl,X
	STA tmp_color

	; do the printing
	LDY #$0C
_print_fixed_title
	LDA (title_ptr),Y
	STA SCR_06DD,Y
	; underscores are always printed in multi-color black
	CMP #$06
	BNE _not_underscore
	LDA #$08
	BNE _set_color ; always branch
_not_underscore
	LDA tmp_color
_set_color
	STA COL_DADD,Y
	DEY
	BPL _print_fixed_title

	RTS

	.enc "charrom"
title_text_0	.text " dungeon____ "
title_text_1	.text " __the_pit__ "
title_text_2	.text " _the_arena_ "
title_text_3 	;.text" __worlord__ " ; it's not stored, actually
title_text_4	.text " __worlord__ "
title_text_5	.text " ___radar___ "
title_text_6	.text " __escaped__ "
title_text_7	.text " ___worluk__ "
title_text_8	.text "wizard_of_wor"
title_text_9	.text "double__score"

title_text_tbl	.lo_tbl title_text_0,title_text_1,title_text_2,title_text_3,title_text_4,title_text_5,title_text_6,title_text_7,title_text_8,title_text_9

title_color_tbl	.byte $02,$02,$02,$06,$07,$02,$07,$07,$07,$07

.pend

; -----------------------------------------

check_hitbox_of_current_actor .proc

	hitbox_ptr = tmp_0014_ptr
	tmp_hitbox_char_no = tmp_000d
	tmp_hitbox_offset = tmp_000e

	store_a = tmp_000a
	store_y = tmp_0009
	store_x = tmp_0008


	; print all bullets
	LDX #MAX_ACTORS-1
_print_bullet
	PTR_SET_TBL_X hitbox_ptr, bullet_pos
	LDA bullet_char,X
	LDY #$00
	STA (hitbox_ptr),Y
	DEX
	BPL _print_bullet

	; check the current actor's hitbox (a 3x3 char block) for anything that may kill them

	;   first get a pointer to the center - unless it's dead/dying, then skip the rest
	LDX actor_sprite_pos_offset
	LDA VIC_S0X,X
	STA tmp_sprite_x
	LDA VIC_S0Y,X
	STA tmp_sprite_y
	LDX actual_actor
	LDA actor_type_tbl,X
	BEQ _return ; it's dying
	BMI _return ; it's dead
	LDX #$01
	JSR sprite_pos_to_char_ptr ; sets hitbox_ptr to the beggining of the line where the center is, tmp_0008 is the X position in that line
	PTR_ADD hitbox_ptr, tmp_0008 ; hitbox_ptr now points to the center

	;   move pointer to the top-left corner of the hitbox
	SEC
	SBC #$29
	STA hitbox_ptr
	BCS +
	DEC hitbox_ptr+1
+

	;   check the hitbox - go through all 9 chars of it
	LDX #$08
_check_hitbox
	STX tmp_hitbox_char_no
	LDY draw_dungeon.block_offsets,X
	LDA (hitbox_ptr),Y
	CMP #$10
	BCS _some_collision

	;   it was just floor or wall
_continue_check
	LDX tmp_hitbox_char_no
	DEX
	BPL _check_hitbox

	; all checked, no collision, bye
	RTS


_some_collision
	; now we need to find out if we are checking a player or a monster as different things can hurt them
	STY tmp_hitbox_offset
	TAY
	LDX actual_actor
	CPX #MAX_PLAYERS
	BCC _check_players

	; we're checking a monster: it can pass through the following items
	CMP #MONSTER_BULLET_V
	BEQ _continue_check
	CMP #MONSTER_BULLET_H
	BEQ _continue_check
	CMP #MONSTER_CENTER
	BEQ _continue_check
	CMP #MONSTER_HEAD
	BEQ _continue_check
	; if it was none of the above then it must have been a bullet
	BNE _bullet_hit ; always branch


_check_players
	; we are checking a player

	; for players only check four chars of the hitbox:
	; .X.
	; X.X
	; .X.
	LDA tmp_hitbox_offset
	LSR A
	BCC _continue_check

	; ignore collisions during launch
	LDA launch_status,X
	BPL _continue_check

	LDX #MAX_ACTORS ; this does two things: 1. it is the initialization of the bullet owner search loop 2. it sets the "bullet owner" for monster head collisions
	; check if it has collided with a monster head (only the head of the monsters is deadly)
	CPY #MONSTER_HEAD
	BEQ _monster_head_hit

_bullet_hit
	; it was not a monster head so it must be a bullet or a monster center
	PTR_ADD2 hitbox_ptr, tmp_hitbox_offset
	DEX
_find_bullet_owner
	LDA bullet_direction,X
	BNE _bullet_is_moving
	LDA firing_status,X
	AND #FIRING_BULLET_ACTIVE
	BEQ _next_actor
_bullet_is_moving
	LDA bullet_pos.lo,X
	CMP hitbox_ptr
	BEQ _first_byte_checks
_next_actor
	DEX
	BPL _find_bullet_owner
_return
	RTS ; it is noone's bullet so it must be a monster center - this quits the collision check early

_first_byte_checks
	LDA bullet_pos.hi,X
	CMP hitbox_ptr+1
	BNE _next_actor

_monster_head_hit
	JMP + ; unnecessary - perhaps something got patched out here in the last minute?
+
	; we have the owner of the bullet (or monster head) in X
	CPX actual_actor
	BEQ _no_score_increase ; it's our own, false alarm - this quits the collision check early
	LDY actual_actor
	; check if it's a player
	CPY #MAX_PLAYERS
	BCC _no_monster_head_removal

	; remove the marker char for the monster head
	PTR_SET_TBL_Y hitbox_ptr, monster_head_ptr_tbl
	LDY #$00
	LDA (hitbox_ptr),Y
	CMP #MONSTER_HEAD
	BNE _no_monster_head_removal
	LDA #FLOOR
	STA (hitbox_ptr),Y
_no_monster_head_removal

	LDY actual_actor
	; save original actor type
	LDA actor_type_tbl,Y
	STA actor_type_before_dying_tbl,Y
	; remove bullet that killed this actor
	LDA #$00
	STA bullet_direction,X
	; set actor type to "dying"
	STA actor_type_tbl,Y
	; remove actor's bullet
	STA bullet_direction,Y
	CPY #MAX_PLAYERS
	BCC _not_monster_is_hit ; no immediate boom sprite for players

	; it's a monster that dies: set next_sfx_idx and set its sprite to an explosion
	LDA #SFX_MONSTER_HIT
	STA next_sfx_idx
	; set monster's sprite to BOOM1
	LDA #BOOM1
	STA SPRITE_PTR,Y
_not_monster_is_hit

	LDA #$04
	CPY #MAX_PLAYERS
	BCS _not_player

	; it's a player that dies: set next_sfx_idx and use MV
	LDA #SFX_PLAYER_HIT
	STA next_sfx_idx
	LDA #$84
	; save A, X, Y
	STX store_x
	STY store_y
	STA store_a

	; say something appropriate
	LDY #$0A
	JSR magic_voice.say

	; restore A, X, Y
	LDA store_a
	LDY store_y
	LDX store_x
_not_player

	; this part is common again for players and monsters
	STA animation_counter_tbl,Y
	LDA #$0F
	STA animation_timer_tbl,Y
	LDA #$07
	STA VIC_D027,Y			; set sprite color
	CPX #MAX_PLAYERS		; if this actor was killed by a player
	BCS _no_score_increase		; increase the player's score
	LDA actor_type_before_dying_tbl,Y	; get actor's original type
	TAY
	LDA scores_tbl,Y		; get score value
	CPX #$00
	BEQ _player2
	JSR score.add_to_p1
	JMP _no_score_increase
_player2
	JSR score.add_to_p2
_no_score_increase

	LDX actor_sprite_pos_offset
	LDA VIC_S0X,X
	STA tmp_sprite_x
	LDA VIC_S0Y,X
	STA tmp_sprite_y
	LDX #$01
	JSR sprite_pos_to_char_ptr
	LDA #FLOOR
	STA (hitbox_ptr),Y
	RTS

scores_tbl
	.byte 0,10,10,1,2,5,0,10,25 ; score values (/100) of different types of actors (type 0 and 6 is not used)

.pend

; -----------------------------------------


actor_is_dying .proc

	LDA animation_counter_tbl,X
	BMI _flash_player

	INC VIC_D027,X
	DEC animation_timer_tbl,X
	BPL _quit
	; prime timer again
	LDA #$1E
	STA animation_timer_tbl,X
	; cycle between BOOM1 and BOOM2 sprites
	LDA SPRITE_PTR,X
	EOR #$01
	STA SPRITE_PTR,X
	DEC animation_counter_tbl,X
	BPL _quit

	; dying is over, it's dead
	CPX #MAX_PLAYERS
	BCC _player_is_dead
	JMP monster_is_dead ; monsters

_player_is_dead
	DEC lives_player2,X
	CPX #$00
	BEQ _player_2

	; player 1
	LDA #PLAYER1
	STA actor_type_tbl,X
	JSR draw_player1_lives
	JMP (gameplay_ptr)

_player_2
	; player 2
	LDA #PLAYER2
	STA actor_type_tbl,X
	JSR draw_player2_lives
_quit	JMP (gameplay_ptr)

_flash_player
	; flashing the player sprite before changing it to the boom sprite
	LDA animation_timer_tbl,X
	BPL _quit

	; this is unnecessary, we will overwrite it in a few lines
	LDA #$05
	STA animation_timer_tbl,X

	; flash sprite color
	LDA VIC_D027,X
	EOR #$01
	STA VIC_D027,X

	; reprime timer
	LDA #$09
	STA animation_timer_tbl,X

	DEC animation_counter_tbl,X
	BMI _quit

	; OK, enough flashing, go to the BOOM part
	LDA #$07
	STA VIC_D027,X
	LDA #$04
	STA animation_counter_tbl,X
	LDA #BOOM1
	STA SPRITE_PTR,X
	BNE _quit
.pend

; -----------------------------------------

check_keyboard .proc
	; this handles the pause and the easter egg activation

	; activate easter egg if the right keys are pressed at the same time
	; there are a few combinations e.g. left Shift, S, A is a valid one, Run/Stop, C=, Control is another one and you can mix these two sets (e.g. R/S, S, Ctrl)
	LDA #%01111101
	STA CIA1_JOY_KEY1
	LDA CIA1_JOY_KEY2
	CMP #%01011011
	BNE _no_easter_egg
	LDY #$14
	JSR magic_voice.say
	LDA #$01
	STA is_easter_egg_activated
_no_easter_egg
	; if run/stop is pressed, pause game
	LDA #%01111111
	LDA #%01111111 ; seems like an unintended duplication
	STA CIA1_JOY_KEY1
	LDA CIA1_JOY_KEY2
	CMP #%01111111
	BNE _no_runstop

	; pause game: stop IRQ, SID volume to 0
	SEI
	LDA #$00
	STA SID_FltMod_Vol
_pause
	; game continues if space, '1', '2', '<-' or Control is pressed (perhaps it's a typo and only space was meant)
	LDA CIA1_JOY_KEY2
	AND #%00011111
	CMP #%00011111
	BEQ _pause
	; resume game: restore SID volume and IRQs
	LDA #$0F
	STA SID_FltMod_Vol
	CLI

_no_runstop
	RTS
.pend

; -----------------------------------------

draw_monster_head .proc
	;

	screen_ptr = tmp_0014_ptr
	screen_offset = tmp_0008

	tmp_offset = tmp_0090


	; first check if it's actually a monster
	LDA is_monster
	BEQ _dont_draw_monster_head ; not monster

	; get position to center
	PTR_ADD screen_ptr, screen_offset
	LDY #$00
	LDX actual_actor
	LDA actor_heading_x_tbl,X
	BEQ _check_y_heading ; monster does not look horizontally
	TAX
	INX
	LDA direction_x_offset,X ; X can be either 0 or 2
	BMI _negative_offset
_positive_offset
	CLC
	ADC screen_ptr
	STA screen_ptr
	BCC +
	INC screen_ptr+1
	+
_put_monster_head
	; put monster head only if there's floor on its intended place
	LDA (screen_ptr),Y
	CMP #FLOOR
	BNE _dont_draw_monster_head
	LDA #MONSTER_HEAD
	STA (screen_ptr),Y
	; save monster head's position
	LDX actual_actor
	LDA screen_ptr
	STA monster_head_ptr_tbl.lo,X
	LDA screen_ptr+1
	STA monster_head_ptr_tbl.hi,X
	RTS

_negative_offset
	AND #$7F
	STA tmp_offset
	LDA screen_ptr
	SEC
	SBC tmp_offset
	STA screen_ptr
	BCS _put_monster_head
	DEC screen_ptr+1
	BNE _put_monster_head ; always branch

_check_y_heading
	LDA actor_heading_y_tbl,X
	BEQ _dont_draw_monster_head ; monster does not look anywhere, i.e. it's not active
	TAX
	INX
	LDA direction_y_offset,X ; X can be either 0 or 2
	BMI _negative_offset
	BPL _positive_offset ; always branch

_dont_draw_monster_head

	; store $0400 as the head position
	LDX actual_actor
	LDA #$04
	STA monster_head_ptr_tbl.hi,X
	LDA #$00
	STA monster_head_ptr_tbl.lo,X

	RTS

; since both tables have a hole in the middle we can pack them together: A1,?,A2 + B1,?,B2 -> A1,B1,A2,B2
direction_x_offset	.byte $81,?,$01
	* = *-2
direction_y_offset	.byte $A8,?,$28

.pend

; -----------------------------------------

monster_is_dead
	; TODO: called only for monsters

	; remove monster markers from dungeon
	LDX actual_actor
	LDA #$00
	STA monster_head_ptr_tbl.lo,X
	LDA #$04
	STA monster_head_ptr_tbl.hi,X

	; find out if this monster needs a replacement and what is that
	LDA actor_type_before_dying_tbl,X
	CMP #BURWOR
	BNE + ; not burwor, further type check needed
	; this was a burwor, bring in a garwor if dungeon number is equal or more than the number of remaining burwors
	DEC burwors_alive
	LDY current_dungeon
	CPY burwors_alive
	BCC _no_new_monster
	BNE +
	; this was the last burwor, say something appropriate
	LDA random_number
	AND #$01
	TAX
	LDY MV_last_burwor,X
	JSR magic_voice.say
	LDX actual_actor
	LDA actor_type_before_dying_tbl,X
+
	CMP #THORWOR
	BEQ _no_new_monster ; thorwors are never replaced

	; this was a burwor that should be replaced with a garwor or
	; this was a garwor, they are always replaced with a thorwor
	TAY
	INY
	TYA
	STA actor_type_tbl,X
	LDA #NO_SPRITE
	STA SPRITE_PTR,X
	LDA VIC_D015
	ORA power_of_2_tbl,X
	STA VIC_D015
	JSR spawn_monster

	JMP normal_gameplay_loop

_no_new_monster
	DEC normal_monsters_on_screen
	BMI _all_normal_monsters_killed
	DEC actor_type_tbl,X
	LDA #$FF
	LDX actor_sprite_pos_offset
	STA VIC_S0X,X
	STA VIC_S0Y,X
	JMP normal_gameplay_loop

_all_normal_monsters_killed
	JMP enter_worluk
MV_last_burwor	.byte $08,$0B

; -----------------------------------------

calculate_monster_heading .proc
	; determine new heading for the actual actor (it's used only for monsters) based on the monster_dest_x and monster_dest_y variables
	; it sets the appropriate new_heading_x_tbl and new_heading_y_tbl entries

	; determine X heading
	; if X stays the same it's still marked as left ($FF) heading
	;   first just look at if the 9th bit is different
	;   set up A so that 0. bit is the destination 9th bit and 1. bit is the current 9th bit
	LDY actual_actor
	LDX actor_sprite_pos_offset
	LDA power_of_2_tbl,Y
	AND VIC_D010
	BEQ +
	LDA #$02
+	ORA monster_dest_9th
	;   use this as an index to a table to determine new heading if possible
	TAY
	LDA ninth_bit_heading_tbl,Y
	TAY
	BNE _set_x_heading
	;   the 9th bit is the same: just look at the lower 8 bits and check that
	LDA VIC_S0X,X
	CMP monster_dest_x
	BCS _not_right
	LDY #$01
	BNE _set_x_heading ; always branches
_not_right
	LDY #$FF
_set_x_heading
	LDX actual_actor
	TYA
	STA new_heading_x_tbl,X

	; determine Y heading
	; simply calculate by comparing the new Y pos to the one in the VIC
	; if Y stays the same it's still marked as upward ($FF) heading
	TXA
	ASL A
	TAX
	LDA VIC_S0Y,X
	CMP monster_dest_y
	BCS _not_down ; old Y is greater than or equal to the new one
	LDY #$01
	BNE + ; always branches
_not_down
	LDY #$FF
+	LDX actual_actor
	TYA
	STA new_heading_y_tbl,X
	RTS

.pend

; -----------------------------------------

sprite_pos_to_char_ptr .proc
	; convert a sprite's position to a character position on the screen and return a pointer to that (it will be a position roughly in the middle of the sprite)
	; it serves as the starting point of bullets and also as the center of the sprite's hitbox which is 3x3 char
	;  X: exact position within the central 8x8 block of the sprite (1: center, 2-5: the four corners)
	;  tmp_sprite_x: sprite X pos
	;  tmp_sprite_y: sprite Y pos
	;
	; result:
	;   tmp_0014_ptr: screen pointer to the line where the center is, serves as Y position
	;   tmp_0008: char pos of the center in the line, serves as X position
	;   Y: the same as tmp_0008
	;   A: current char at this position

	screen_ptr = tmp_0014_ptr
	screen_offset = tmp_0008

	pos_offset = tmp_001b

	; get Y
	LDA tmp_sprite_y
	; subtract offset (border + some lines in sprites)
	CLC
	ADC sprite_y_offset_tbl-1,X
	; divide by 8
	LSR A
	LSR A
	LSR A
	; we have the line number, conver it to a pointer
	TAY
	PTR_SET_TBL_Y2 screen_ptr,screen_line_ptr

	; get X
	LDA #$00
	STA pos_offset
	LDA tmp_sprite_x
	; subtract offset (border + some rows in sprites)
	SEC
	SBC sprite_x_offset_tbl-1,X
	; if the result is too low then the 9th bit of the X position must have been set so calculate that way
	CMP #$18
	BCS _not_over_255
	LDY #$20
	STY pos_offset
_not_over_255

	; divide by 8
	LSR A
	LSR A
	LSR A
	; correct with msb-offset
	CLC
	ADC pos_offset
	TAY
	; store
	STY screen_offset
	; load char at pos
	LDA (screen_ptr),Y
	RTS

sprite_x_offset_tbl	.byte $13,$17,$10,$17,$10
sprite_y_offset_tbl	.byte $D6,$D3,$D3,$DA,$DA

.pend

; -----------------------------------------

check_if_game_is_started .proc
	; run this check for about 5 seconds
	; return:
	;   tmp_0090: number of starting extra lives for player2 (game not started: 0, 1 player game: $ff, 2 player game: STARTING_EXTRA_LIVES)
	LDA #$05
	STA irq_timer_sec ; let this check run for 5 seconds
_check
	; check fire button on port2
	LDA CIA1_JOY_KEY1
	LDX #STARTING_EXTRA_LIVES
	AND #$10
	BEQ _fire_pressed

	; check fire button on port2
	LDA CIA1_JOY_KEY2
	LDX #$FF
	AND #$10
	BEQ _fire_pressed

	; check if timer still runs
	LDA irq_timer_sec
	BNE _check
	LDX #$00
_fire_pressed
	STX tmp_0090
	RTS
.pend

; -----------------------------------------

spawn_monster .proc
	; spawns a new monster in one of a predefined locations
	; returns:
	;  index of X pos in tmp_0090

_find_x_pos
	; pick a random X position
	LDA VIC_D012
	EOR random_number
	AND #$07
	TAX
	LDA spawn_pos_x,X
	; check if it's on the same row as player1...
	SEC
	SBC VIC_S0X
	CMP #$16
	BCC _find_x_pos
	CMP #$E9
	BCS _find_x_pos
	; ...or player 2
	LDA spawn_pos_x,X
	SEC
	SBC VIC_S1X
	CMP #$16
	BCC _find_x_pos
	CMP #$E9
	BCS _find_x_pos
	; X position is OK, write it to the VIC
	STX tmp_0090 ; index of X position to be returned
	LDA spawn_pos_x,X
	LDX actor_sprite_pos_offset
	STA VIC_S0X,X

_find_y_pos
	; do the same for Y
	LDA VIC_D012
	AND #$07
	TAX
	LDA spawn_pos_y,X
	SEC
	SBC VIC_S0Y
	CMP #$16
	BCC _find_y_pos
	CMP #$E9
	BCS _find_y_pos
	LDA spawn_pos_y,X
	SEC
	SBC VIC_S1Y
	CMP #$16
	BCC _find_y_pos
	CMP #$E9
	BCS _find_y_pos
	; Y is OK
	LDA spawn_pos_y,X
	LDX actor_sprite_pos_offset
	STA VIC_S0Y,X

	; set the 9th bit of the X position to 0 (all possible spawn locations are in the first 256 pixels)
	LDX actual_actor
	LDA power_of_2_tbl,X
	EOR #$FF
	AND VIC_D010
	STA VIC_D010
	RTS

spawn_pos_x	.byte $67,$7F,$97,$AF,$AF,$C7,$DF,$F7
spawn_pos_y	.byte $35,$4D,$65,$7D,$95,$AD,$35,$95

.pend

; -----------------------------------------


enter_worluk
	LDA current_dungeon
	BNE _bring_in_worluk

	; no Worluk at the end of the first dungeon
	JMP start_dungeon


_bring_in_worluk
	; warp doors close and will open 4 seconds after worluk appers
	JSR warp_door_handler.close
	LDA #$04
	STA irq_timer_sec

	; switch off radar
	LDA #$00
	JSR draw_playfield.fill_radar_chars

	LDX #$07 ; worluk
	JSR print_radar_title

	PTR_SET gameplay_ptr, worluk_gameplay_loop

	; switch on worluk's sprite and switch off all other monsters
	LDA VIC_D015
	AND #$07
	ORA #$04
	STA VIC_D015

	; set char common multi color #2 to red
	LDA #$02
	STA VIC_D023

	; actually spawn worluk
	STA actual_actor
	LDA #$04
	STA actor_sprite_pos_offset
	JSR spawn_monster

	; set the destination for the worluk: it's one of the warp doors
	;   set 9th bit of destination's X (i.e. select which warp door it tries to exit)
	LDX tmp_0090 ; this is the index of the spawn point X coord
	LDY #$00
	CPX #$04     ; if this is greater than or equal to 4, the 9th bit 1, otherwise 0
	BCS +
	INY
+	STY monster_dest_9th

	LDA #$2F
	STA monster_dest_x
	LDA #$64
	STA monster_dest_y

	; set char common multi color #1 to black
	LDA #$00
	STA VIC_D022

	; clear bullets
	LDX #$07
-	LDA #$00
	STA bullet_direction,X
	DEX
	BPL -


	LDA #WORLUK
	STA monster_type_tbl
	LDA #$04
	STA VIC_D01C
	STA monster_anim_counter_tbl

	; wait approx 0,1 sec
	LDY #$5A
_busy_wait
	DEX
	BNE _busy_wait
	DEY
	BNE _busy_wait

worluk_gameplay_loop
	INC actual_actor

	; keep actual actor in 0-3 range and skip 3
	LDA actual_actor
	AND #$03
	CMP #$03
	BEQ worluk_gameplay_loop
	STA actual_actor

	; set up variables
	TAX
	AND #$FE
	STA is_monster
	TXA
	ASL A
	STA actor_sprite_pos_offset

	; move bullets
	JSR move_bullets

	; check game over
	LDA game_status
	CMP #STATUS_GAME_OVER
	BNE _not_game_over
	JSR game_over_screen
	JMP high_score.set
_not_game_over

	; switch on worluk's sprite
	LDA VIC_D015
	ORA #$04
	STA VIC_D015

	; red-black flash of the walls
	LDA VIC_D022
	EOR #$02
	STA VIC_D022
	LDA VIC_D023
	EOR #$02
	STA VIC_D023

	; check if actor is dying or dead
	LDX actual_actor
	LDA actor_type_tbl,X
	BEQ _is_worluk_dying ; it's dying
_check_death
	LDA actor_type_tbl,X
	BMI worluk_gameplay_loop ; it's dead, go to next actor
	BNE _its_alive  ; it's alive
	JMP actor_is_dying  ; it's dying
_its_alive
	JSR check_hitbox_of_current_actor
	JSR check_keyboard
	BNE _movement ; always branch

_is_worluk_dying
	CPX #$02
	BNE _check_death ; no, it's not worluk who's dying

	; yes: Worluk is killed
	LDA #$FF
	STA game_status
	LDA #$00
	STA VIC_D005
	LDA #SFX_WORLUK_KILLED
	STA next_sfx_idx
	LDX #$09 ; double score
	JSR print_radar_title

	; Bring in the Wizard if the numbers says so
	; 1-in-4 chance of Wizard of Wor after Worluk is killed
	LDA random_number
	AND #$03
	BNE _no_wizard
	JMP enter_wizard_of_wor

_no_wizard
	; no wizard this time - flash the screen and start the next dungeon
	JSR flashing_after_worluk
	JMP start_dungeon


	; move around actors
_movement
	LDX actual_actor
	CPX #MAX_PLAYERS
	BEQ _move_worluk
	LDA animation_timer_tbl,X
	BMI _move_player
	JMP worluk_gameplay_loop

_move_player
	LDA #$00
	STA animation_timer_tbl,X
	BEQ _set_sfx ; always branch

_move_worluk
	DEC animation_timer_tbl + MAX_PLAYERS
	BPL _end_of_moving
	LDA #$02
	STA animation_timer_tbl + MAX_PLAYERS
	LDA monster_anim_counter_tbl
	EOR #$04
	STA monster_anim_counter_tbl
	LDA new_heading_y_tbl,X
	STA actor_heading_y
	LDA new_heading_x_tbl,X
	STA actor_heading_x

_set_sfx
	; keep sfx going
	LDA snd_sfx_dur_cnt
	BNE +
	LDA #SFX_WORLUK_MOVING
	STA next_sfx_idx
+

	; move actor
	JSR move_actor

	; at every 40th frame head towards the warp door
	LDA random_number
	BNE +
	LDA #$28
	STA random_number
	JSR calculate_monster_heading
+

	; if worluk is stopped (hit a wall) set a new heading for it (it also runs for the players but has no effect as move_actor overwrites its results)
	LDA actor_heading_x
	ORA actor_heading_y
	BNE _end_of_moving
	LDA VIC_D012
	AND #$01
	TAY
	LDA heading_tbl,Y
	LDX actual_actor
	STA new_heading_y_tbl,X
	LDA random_number
	LSR A
	AND #$01
	TAY
	LDA heading_tbl,Y
	STA new_heading_x_tbl,X
_end_of_moving

	JSR warp_door_handler
	BNE _no_escape ; actor did not went through the warp door
	JSR open_warp_door
	LDX actual_actor
	CPX #MAX_PLAYERS
	BNE _no_escape ; it was a player who went through the warp door

	; worluk escaped
	LDA #$01
	STA game_status
	LDA #SFX_WORLUK_ESCAPED
	STA next_sfx_idx
	; TODO: BUG: there should be a cycle for checking all actors - as it is, if a player is dying when worluk escapes it will not actually lose a life
	LDA actor_type_tbl,X
	BMI _dying_or_dead ; it's dead
	BNE _alive ; it's alive
_dying_or_dead
	DEC lives_player2,X
_alive

	; hide sprite
	LDA #$00
	STA VIC_D005
	; print 'escaped' on the radar
	LDX #$06 ; escaped
	JSR print_radar_title
	; wait a little
	LDX #$01
	JSR wait_x_seconds
	JMP _decide_if_wizard_comes
_no_escape
	JMP worluk_gameplay_loop


_decide_if_wizard_comes
	; wizard comes with a 1-in-8 chance after worluk escapes
	LDA random_number
	AND #$07
	BEQ enter_wizard_of_wor
	JMP start_dungeon

enter_wizard_of_wor
	; hide wizard's sprite
	LDA VIC_D015
	AND #$FB
	STA VIC_D015

	LDX #$08 ; wizard of wor
	JSR print_radar_title

	PTR_SET gameplay_ptr, wizard_gameplay_loop

	; show wizard's sprite
	LDA VIC_D015
	AND #$07
	ORA #$04
	STA VIC_D015

	; walls are uniform dark blue
	LDA #$06
	STA VIC_D023
	STA VIC_D022

	; actually spawn the wizard
	STA actual_actor ; BUG: actual_actor should be MAX_PLAYERS (2), not 6
	LDA #$04
	STA actor_sprite_pos_offset
	JSR spawn_monster

	; this is probably to counteract the bug above - spawn monster should set D010 correctly
	LDA VIC_D010
	AND #$FB
	STA VIC_D010

	LDA #$00 ; this seems to be unnecessary

	; reset bullets
	LDX #$07
-	LDA bullet_pos.lo,X
	STA tmp_0014_ptr
	LDA bullet_pos.hi,X
	STA tmp_0014_ptr+1
	LDA #FLOOR
	LDY #$00
	STA (tmp_0014_ptr),Y
	TYA
	STA bullet_direction,X
	STA firing_status,X
	DEX
	BPL -

	; set up variables
	LDA #WIZARD
	STA monster_type_tbl
	LDA #$00
	STA VIC_D01C ; wizard's sprite is hires
	STA monster_anim_counter_tbl
	LDA #$00 ; this seems to be unnecessary
	STA animation_timer_tbl
	STA animation_timer_tbl+1

wizard_gameplay_loop
	INC actual_actor

	; keep actual actor in 0-3 range and skip 3
	LDA actual_actor
	AND #$03
	CMP #$03
	BEQ wizard_gameplay_loop
	STA actual_actor

	; set up variables
	TAX
	AND #$FE
	STA is_monster
	TXA
	ASL A
	STA actor_sprite_pos_offset

	; move bullets
	JSR move_bullets

	; show wizard's sprite
	LDA VIC_D015
	ORA #$04
	STA VIC_D015

	; check if actor is dying / dead
	LDX actual_actor
	LDA actor_type_tbl,X
	BEQ _is_wizard_dying ; it's dying
_check_player_dead
	LDA actor_type_tbl,X
	BMI wizard_gameplay_loop ; it's dead
	BNE _player_alive  ; it's alive
	JMP _wizard_escaped ; a player is killed (dying) so the wizard escaped

_player_alive
	JSR check_hitbox_of_current_actor
	JSR check_keyboard
	BNE _movement ; always branch


_is_wizard_dying
	CPX #MAX_PLAYERS
	BNE _check_player_dead ; no, it's a player dying

	; wizard is shot
	LDA #$00
	STA game_status
	; walls are black and white checkered
	STA VIC_D022
	LDA #$01
	STA VIC_D023

	; hide wizard's sprite
	LDA VIC_D015
	AND #$03
	STA VIC_D015

	; print double score on the radar title
	LDX #$09 ; double score
	JSR print_radar_title

	; set sfx
	LDA #SFX_WIZARD_KILLED
	STA next_sfx_idx

	; black and white noise after wizard of wor is killed for 256 frames
	LDX #$00
_bw_noise
	TXA
	; for 6 frames out of every 36 frames, switch off the screen
	LDY #$1B
	AND #$1F
	CMP #$1A
	BCC _screen_on
	LDY #$0B ; screen off
_screen_on
	STY VIC_D011
	; on every 4th frame invert the black-white colors
	TXA
	AND #$03
	BNE _keep_color
	LDA VIC_D022
	EOR #$01
	STA VIC_D022
	LDA VIC_D023
	EOR #$01
	STA VIC_D023
_keep_color
	; wait a frame
-	LDA VIC_D011
	BPL -
-	LDA VIC_D011
	BMI -

	; more frames?
	DEX
	BNE _bw_noise

	; switch back screen
	LDA #$1B
	STA VIC_D011
	JMP start_dungeon

_movement
	LDX actual_actor
	CPX #MAX_PLAYERS
	BEQ _handle_wizard
	LDA animation_timer_tbl,X
	BMI _move_player
	JMP wizard_gameplay_loop

_move_player
	LDA #$00
	STA animation_timer_tbl,X
	BEQ _actually_move ; always branch

_handle_wizard
	; decide if wizard shoots
	LDA random_number
	AND #$1F
	BNE _dont_shoot
	LDA firing_status+2
	BMI _dont_shoot ; FIRING_BULLET_ACTIVE is set
	LDA bullet_direction,X
	BNE _dont_shoot

	; fire
	JSR fire_bullet

	; set bullet type
	LDA bullet_char,X
	CLC
	ADC #$02
	STA bullet_char,X

	; set sfx
	LDA #SFX_MONSTER_SHOOTS
	STA next_sfx_idx

	; set wizard's heading toward a randomly chosen player
	LDA VIC_D012
	AND #$02
	TAX
	LDA VIC_S0X,X
	STA monster_dest_x
	LDA VIC_S0Y,X
	STA monster_dest_y
	LDA VIC_D012
	AND #$01
	STA monster_dest_9th
	JSR calculate_monster_heading
_dont_shoot

	DEC animation_timer_tbl + MAX_PLAYERS
	BPL _end_movement

	; reset animation timer
	LDA #$04
	STA animation_timer_tbl + MAX_PLAYERS
	INC monster_anim_counter_tbl
	LDA new_heading_y_tbl,X
	STA actor_heading_y
	LDA new_heading_x_tbl,X
	STA actor_heading_x

	; teleport the wizard every 160th frame
	LDA random_number
	BNE _no_teleport
	LDA #$A0
	STA random_number

	; clear wizard's marker
	LDA VIC_D004
	STA tmp_sprite_x
	LDA VIC_D005
	STA tmp_sprite_y
	LDX #$01
	JSR sprite_pos_to_char_ptr
	LDA #$0F
	STA (tmp_0014_ptr),Y

	; spawn wizard at a random place
	LDX actual_actor
	JSR spawn_monster
_no_teleport

_actually_move
	JSR move_actor


	; set random heading on a more or less random condition (TODO: is it really random?)
	LDA bullet_pos.lo+MAX_PLAYERS
	CMP #$01
	BEQ _set_random_heading

	LDA actor_heading_x
	ORA actor_heading_y
	BNE _end_movement

_set_random_heading
	LDA VIC_D012
	AND #$01
	TAY
	LDA heading_tbl,Y
	LDX actual_actor
	STA new_heading_y_tbl,X
	LDA random_number
	LSR A
	AND #$01
	TAY
	LDA heading_tbl,Y
	STA new_heading_x_tbl,X
_end_movement

	JSR warp_door_handler
	JSR open_warp_door ; keep the warp door open
	JMP wizard_gameplay_loop

_wizard_escaped
	; wizard killed a player and so it has escaped
	LDA #SFX_WIZARD_ESCAPED
	STA next_sfx_idx
	LDA #$00
	STA VIC_D015
	LDX #$06 ; escaped
	JSR print_radar_title
	JSR flashing_after_worluk
	LDX actual_actor
	DEC lives_player2,X
	JSR draw_player2_lives
	LDA game_status
	CMP #STATUS_GAME_OVER
	BNE _not_game_over

	; game over
	JSR game_over_screen
	JMP high_score.set

_not_game_over
	JMP start_dungeon

; -----------------------------------------

double_score_dungeon_screen .proc
	; prevent warp door opening or launch happening while this screen is shown
	LDA #$1E
	STA irq_timer_sec
	STA launch_counters+1
	STA launch_counters
	; print "DOUBLE SCORE DUNGEON"
	LDX #$00
	JSR big_letters.print_word
	LDX #$01
	JSR big_letters.print_word
	LDX #$02
	JSR big_letters.print_word
	; start double score dungeon music
	LDA #$02
	STA snd_pattern_no
	RTS
.pend

; -----------------------------------------

big_word_0	.big_text "double"
big_word_1	.big_text "score"
big_word_2	.big_text "dungeon"

; -----------------------------------------

game_over_screen .proc
	; hide all sprites
	LDA #$00
	STA VIC_D015
	; prevent warp door opening or launch happening while this screen is shown
	LDA #$1E
	STA irq_timer_sec
	STA launch_counters+1
	STA launch_counters
	; print "GAME OVER"
	LDX #$06
	JSR big_letters.print_word
	LDX #$07
	JSR big_letters.print_word
	LDX #$08
	JSR big_letters.print_word

	; start first pattern of game over music
	LDA #$03
	STA snd_pattern_no

	; wait a second and then until pattern finished
	LDX #$01
	JSR wait_x_seconds

_wait_for_end_of_pattern
	LDA snd_pattern_pos
	BNE _wait_for_end_of_pattern

	; start second pattern of game over music (it's the "get ready" music)
	LDA #$01
	STA snd_pattern_no

	; wait four seconds
	LDX #$04
	JSR wait_x_seconds

	; all sprites visible
	LDA #$FF
	STA VIC_D015

	; randomly select a game over sentence and say it on Magic Voice
	LDA random_number
	AND #$03
	TAX
	LDY game_over_mv_sentences,X
	JSR magic_voice.say
	RTS
.pend

; -----------------------------------------

big_word_6	.big_text "gam"
big_word_8	.big_text "over"
big_word_7	.big_text "e"

; -----------------------------------------

game_over_mv_sentences	.byte $10,$11,$12,$11

; -----------------------------------------

get_ready_go_screen .proc
	; hide all sprites
	LDA #$00
	STA VIC_D015
	; prevent warp door opening or launch happening while this screen is shown
	LDA #$1E
	STA launch_counters+1
	STA launch_counters
	STA irq_timer_sec

	; set dungeon title to "worlord" for dungeons above 8
	LDA current_dungeon
	CMP #$07
	BCC _not_worlord
	LDX #$04 ; worlord (in yellow)
	JSR print_radar_title
_not_worlord

	; start 'get ready' music
	LDA #$01
	STA snd_pattern_no
	; print "GET READY"
	LDX #$03
	JSR big_letters.print_word
	LDX #$04
	JSR big_letters.print_word
	; wait a second
	LDX #$01
	JSR wait_x_seconds
	; print "GO"
	LDX #$05
	JSR big_letters.print_word
	; wait for end of music
_wait_for_end_of_pattern
	LDA snd_pattern_pos
	BNE _wait_for_end_of_pattern
	; show all sprites
	LDA #$FF
	STA VIC_D015
	RTS

.pend

; -----------------------------------------

big_word_3	.big_text "get"
big_word_4	.big_text "ready"
big_word_5	.big_text "go"

; -----------------------------------------

;============================================================

high_score	.block

	high_score_ptr = tmp_text_hi_ptr
	screen_ptr = tmp_0014_ptr

; -----------------------------------------

print .proc
	; print high scores
	line_color = tmp_00e9
	colorram_ptr = tmp_000b

	; set up the constanst
	LDA #$0E
	STA line_color
	LDA #$02
	STA high_score_ptr+1
	LDX #$04

_print_score
	; set up pointers for the current high score
	LDA screen_pos.lo,X
	STA screen_ptr
	STA colorram_ptr
	LDA screen_pos.hi,X
	STA screen_ptr+1
	CLC
	ADC #$D4
	STA colorram_ptr+1
	LDA high_score_ptr_tbl.lo,X
	STA high_score_ptr

	; actually print high score
	LDY #$00
-	LDA (high_score_ptr),Y
	JSR print_2x1_letter
	INY
	CPY #$06
	BNE -

	; is there more to print?
	DEX
	BPL _print_score

	RTS

screen_pos .lohi_tbl ($0578,$05C8,$0618,$0668,$06B8)

.pend

; -----------------------------------------

high_score_ptr_tbl	.lo_tbl high_score_1, high_score_2, high_score_3, high_score_4, high_score_5

; -----------------------------------------

set	.proc
	; this is called via JMP, not JSR, as it's part of the game's main loop
	; so not RTS at the end

	; player 1
	LDA #<player1_score_string
	JSR try_to_add_current_score_to_high_scores

	; player 2
	LDA #<player2_score_string
	JSR try_to_add_current_score_to_high_scores

	; go further in the loop
	JMP display_high_scores_and_enemies

try_to_add_current_score_to_high_scores

	next_high_score_ptr = tmp_0008
	pos_on_high_score_list = tmp_0090

	; set up constant pointers
	STA screen_ptr
	LDA #>player1_score_string
	STA screen_ptr+1
	STA high_score_ptr+1
	STA next_high_score_ptr+1

	LDX #$00

_check_next_high_score
	; set up constanst for the current high score
	LDA high_score_ptr_tbl.lo,X
	STA high_score_ptr

	; go through the digits of the current score
	LDY #$00
_check_next_digit
	LDA (screen_ptr),Y
	; convert spaces to zeroes
	CMP #$25
	BNE _not_space
	LDA #$00
_not_space
	SEC
	SBC (high_score_ptr),Y
	BEQ _tie
	CMP #$DB     ; this is the result of subtracting space from 0 - it should be also treated as equality
	BEQ _tie
	CMP #$F7
	BCC _new_high_score
	; the current score is lower then the current high score - move down to the next one if there's one
	INX
	CPX #$05
	BNE _check_next_high_score
	RTS
_tie
	INY
	CPY #$05
	BNE _check_next_digit
	; if the current score is exactly the same as an existing highscore, it should be still considered as a new highscore
_new_high_score
	STX pos_on_high_score_list

	; go through the high scores from the bottom up
	LDX #$04
_rearrange_list
	CPX pos_on_high_score_list
	BEQ _insert_new_high_score
	; if it's below the new score's position, overwrite it with the one above
	LDA high_score_ptr_tbl.lo,X
	STA next_high_score_ptr
	DEX
	LDA high_score_ptr_tbl.lo,X
	STA high_score_ptr
	LDY #$05
-	LDA (high_score_ptr),Y
	STA (next_high_score_ptr),Y
	DEY
	BPL -

	BMI _rearrange_list ; always branches

_insert_new_high_score
	LDY #$05
-	LDA (screen_ptr),Y
	STA (high_score_ptr),Y
	DEY
	BPL -
	RTS
.pend

; -----------------------------------------


.bend ; high_score

;============================================================

; -----------------------------------------

check_double_score_and_bonus_life .proc
	; as the title says

	wait_secs = tmp_0090

	line_color = tmp_00e9
	screen_ptr = tmp_0014_ptr
	colorram_ptr = tmp_000b

	; no sprite is visible
	LDX #$00
	STX VIC_D015

	LDA game_status
	BPL + ; no double score

	JSR double_score_dungeon_screen
	LDX #$04 ; wait 4 seconds
+
	STX wait_secs

	; check if it's a bonus life dungeon
	LDA current_dungeon
	CMP #$03 ; Arena
	BEQ _bonus_life
	CMP #$0C ; first Pit
	BNE _no_bonus_life

_bonus_life
	LDA #$04
	STA wait_secs

	; print "bonus  player"
	LDA #$07
	STA line_color
	LDA #$2D
	STA screen_ptr
	STA colorram_ptr
	LDA #$07
	STA screen_ptr+1
	LDA #$DB
	STA colorram_ptr+1
	LDY #$00
-	LDA txt_bonus_player,Y
	JSR print_2x1_letter
	INY
	CPY #$0D
	BNE -

	LDA lives_player1
	BMI _no_player1_bonus_life
	; add bonus life to player1
	INC lives_player1
	; draw a player1 from chars
	LDX #$08
-	LDY draw_dungeon.block_offsets,X
	LDA block_player1,X
	STA SCR_073C,Y
	LDA #$07
	STA COL_DB3C,Y
	DEX
	BPL -

_no_player1_bonus_life
	LDA lives_player2
	BMI _no_bonus_life
	; add bonus life to player2
	INC lives_player2
	; draw a player2 from chars
	LDX #$08
-	LDY draw_dungeon.block_offsets,X
	LDA block_player2,X
	STA SCR_0728,Y
	LDA #$06
	STA COL_DB28,Y
	DEX
	BPL -
_no_bonus_life
	LDX wait_secs
	BEQ _no_wait
	JSR wait_x_seconds
_no_wait
	; all sprites are visible
	LDA #$FF
	STA VIC_D015
	RTS

txt_bonus_player
	.enc "2x1"
	.text "bonus  player"
.pend

; -----------------------------------------

print_easter_egg .proc

	LDA is_easter_egg_activated
	BEQ _no_easter_egg

	; display two lines of text over the first copyright message
	LDX #$17
-
	LDA text_1,X
	STA $0407,X

	LDA #$0E
	STA COL_D807,X ; set color for the highest line

	LDA text_2,X
	STA $042F,X

	LDA #$00
	STA $0457,X ; to delete the lower line of the copyright message
	DEX
	BPL -

_no_easter_egg
	RTS

	.enc "charrom"
text_1	.text "authored by jeff bruette"
text_2	.text "dedicated to mom and dad"

.pend

; -----------------------------------------

wait_x_seconds .proc
	; wait for X * 60 screen refreshes which is a second on NTSC machines but it's 1.2 seconds on PAL machines
	;  X: seconds to wait

	LDY #60

	; wait while actual raster line is > 255
-	LDA VIC_D011
	BPL -

	; wait while actual raster line is < 255
-	LDA VIC_D011
	BMI -

	; vertical retrace  ended, check if a second has elapsed
	DEY
	BPL --

	; check if we have to wait more seconds
	DEX
	BNE wait_x_seconds
	RTS

.pend

; --------------------------------------------------------------

copy_nmi_hander_to_ram .proc
	; copy NMI handler to RAM
	LDX #$14
-
	LDA nmi_handler_rom_copy,X
	STA nmi_handler,X
	DEX
	BPL -
	RTS
.pend

; --------------------------------------------------------------

nmi_handler_rom_copy .proc
	; NMI handler - this will be copied to ram
	LDA is_MV_missing
	BNE _no_magic_voice
	JSR MV_RESET
_no_magic_voice
	; reset stack
	LDX #$FF
	TXS
	; switch off sfx
	JSR sfx.end_of_sfx
	JMP init_stuff
.pend

; -----------------------------------------


;============================================================

big_letters .block

	; aliases
	screen_ptr = tmp_0014_ptr
	block_offsets = tmp_0008
	char_counter = tmp_0090
	word_color = tmp_00e9

; --------------------------------------------------------------

print_letter .proc
	; print a big letter by copying characters into a 4x5 character block
	; letter's code is in X

	src_ptr = tmp_text_hi_ptr

	; get offset to char data
	PTR_SET_LOTBL_X src_ptr, letter_ptr_tbl

	LDA #$13
	STA char_counter
_put_char
	; get screen offset
	TAX
	LDA screen_offset_tbl,X
	STA block_offsets
	; get character to be printed
	; data is packed into nybbles - so get the right nybble (high for even X, low for odd)
	TXA
	LSR A ; here we set C
	TAY
	LDA (src_ptr),Y
	BCS _odd
	LSR A
	LSR A
	LSR A
	LSR A
_odd	AND #$0F
	BEQ _skip_char ; 0 characters are empty, simply don't print them
	; the characters we want to use are actually in the $64-$73 range, so transpose A
	CLC
	ADC #$63
	LDY block_offsets
	; and actually print the character
	STA (screen_ptr),Y
	; and set the character's color too
	; set the pointer to the color ram
	LDA screen_ptr+1
	CLC
	ADC #$D4
	STA screen_ptr+1
	; set color
	LDA word_color
	STA (screen_ptr),Y
	; move pointer back to screen ram
	LDA screen_ptr+1
	SEC
	SBC #$D4
	STA screen_ptr+1
_skip_char
	DEC char_counter
	LDA char_counter
	BPL _put_char
	RTS
.pend

; --------------------------------------------------------------

print_word .proc
	; prints predefined words with predefined position and color
	; word is selected by X
	; 0 - double
	; 1 - score
	; 2 - dungeon
	; 3 - get
	; 4 - ready
	; 5 - go
	; 6 - gam
	; 7 - e
	; 8 - over

	; aliases
	src_ptr = tmp_0009

	; set up pointers
	PTR_SET_TBL_X screen_ptr, screen_ptr_tbl

	PTR_SET_TBL_X src_ptr, src_ptr_tbl

	LDA word_color_tbl,X
	STA word_color

	LDA word_len_tbl,X
	STA word_len_cnt

_print_letters
	LDY word_len_cnt
	LDA (src_ptr),Y
	TAX
	JSR print_letter

	; next letter will be 4 characters to the right
	PTR_ADD screen_ptr, #4

	DEC word_len_cnt
	BPL _print_letters
	RTS
.pend

; --------------------------------------------------------------

letter_ptr_tbl .lo_tbl letter_00, letter_01, letter_02, letter_03, letter_04, letter_05, letter_06, letter_07, letter_08, letter_09, letter_10, letter_11, letter_12, letter_13, letter_14, letter_15

screen_offset_tbl
	.byte $00,$01,$02,$03,$28,$29,$2A,$2B
	.byte $50,$51,$52,$53,$78,$79,$7A,$7B
	.byte $A0,$A1,$A2,$A3

letter_00	.byte $21,$30,$10,$10,$11,$10,$10,$10,$10,$10
letter_01	.byte $11,$30,$10,$10,$11,$30,$10,$10,$11,$40
letter_02	.byte $21,$30,$10,$00,$10,$00,$10,$00,$51,$40
letter_03	.byte $11,$30,$10,$10,$10,$10,$10,$10,$11,$40
letter_04	.byte $11,$10,$10,$00,$11,$00,$10,$00,$11,$10
letter_05	.byte $21,$30,$10,$00,$10,$10,$10,$10,$51,$40
letter_06	.byte $10,$00,$10,$00,$10,$00,$10,$00,$11,$10
letter_07	.byte $13,$21,$15,$41,$10,$01,$10,$01,$10,$01
letter_08	.byte $13,$10,$11,$10,$15,$10,$10,$10,$10,$10
letter_09	.byte $21,$30,$10,$10,$10,$10,$10,$10,$51,$40
letter_10	.byte $11,$30,$10,$10,$11,$40,$15,$30,$10,$10
letter_11	.byte $21,$30,$10,$00,$51,$30,$00,$10,$51,$40
letter_12	.byte $11,$10,$01,$00,$01,$00,$01,$00,$01,$00
letter_13	.byte $10,$10,$10,$10,$10,$10,$10,$10,$51,$40
letter_14	.byte $10,$10,$10,$10,$10,$10,$51,$40,$01,$00
letter_15	.byte $10,$10,$10,$10,$51,$40,$01,$00,$01,$00

screen_ptr_tbl	.lohi_tbl $0408, $04FA, $05E6, $04F3, $0501, $05F0, $051A, $0527, $052F

src_ptr_tbl	.lohi_tbl big_word_0, big_word_1, big_word_2, big_word_3, big_word_4, big_word_5, big_word_6, big_word_7, big_word_8

word_color_tbl	.byte $06,$07,$02,$07,$07,$07,$02,$02,$02

word_len_tbl	.byte $05,$04,$06,$02,$04,$01,$02,$00,$03

.bend ; big_letters

;============================================================

	; unused bytes
	.byte $FF,$0C,$CB
