	AREA interrupts, CODE, READWRITE
	EXPORT lab6
	EXPORT FIQ_Handler
	EXPORT pin_connect_block_setup
	EXPORT interrupt_init
	EXPORT timer_init
	EXTERN uart_init
	EXTERN read_character
	EXTERN read_string
	EXTERN output_character
	EXTERN output_string
	EXTERN div_and_mod


	
game_string = 			 	"|---------------|\r\n",0
game_string1 = 			  	"|               |\r\n",0
game_string2 = 			  	"|               |\r\n",0
game_string3 = 				"|               |\r\n",0
game_string4 = 				"|               |\r\n",0
game_string5 = 				"|               |\r\n",0
game_string6 = 				"|               |\r\n",0
game_string7 = 				"|               |\r\n",0
game_string8 = 				"|               |\r\n",0
game_string9 = 				"|               |\r\n",0
game_stringA = 				"|               |\r\n",0
game_stringB = 				"|               |\r\n",0
game_stringC =				"|               |\r\n",0
game_stringD = 				"|               |\r\n",0
game_stringE = 				"|               |\r\n",0
game_stringF = 				"|               |\r\n",0
game_stringG = 				"|---------------|\r\n",0
    
	ALIGN

lab6
		STMFD sp!, {lr}
		BL read_character
		;BL output_character
		BL rng
		MOV r0, r0, LSR #1
		MOV r2, #0x2A					;Ascii for '*'
		CMP r0, #0
		BEQ	compute_place 
		MOV r2, #0x23					;Ascii for '#'
		CMP r0, #1
		BEQ	compute_place
		MOV r2, #0x40					;Ascii for '@'
		CMP r0, #2
		BEQ	compute_place
		MOV r2, #0x58					;Ascii for 'X'
		;ascii stored in r2
compute_place
		BL rng							;Row
		MOV r1, r0
		BL rng
		ADD r0, r0, r1
		ADD r3, r0 , #1					;Gives random row from 1-15	with higher priority of being in the center
		;row # stored in r3
		BL rng							;Repeat for column
		MOV r1, r0
		BL rng
		ADD r0, r0, r1
		ADD r5, r0 , #1					;Gives random column from 1-15 with higher priority of being in the center

		MOV r0, r3, LSL #4
		ADD r0, r0, r5					;Puts row in upper bits 4-7, column in lower 4
		MOV r1, r2
		LDR r4, =0x40004000				;Position of the symbol 
		STR r0, [r4]					;store location in memory
		BL insert_symbol
		BL output_screen
initial_direction
		BL rng
		ADD r0, r0, #1
		CMP r0, #4						;check if the random should be modified
		BLE direction
		SUB r0, r0, #4
direction		
		LDR r4, =0x40004008				;Position of the direction, offset by 8 from symbol 
		STR r0, [r4]					;save direction into memory, 1 up, 2 right, 3 down, 4 left.

		BL interrupt_init

		LDR r0, =0xE0004000
		MOV r1, #0x2
		STR r1, [r0,#4]		;reset the clock

		LDR r0, =0xE000401C		;Match Register value
		LDR r1, =0x00023280		;Clock will reset at this value
		STR r1, [r0]
		LDMFD sp!, {lr}
		BX lr 

timer_init
		STMFD SP!, {r0-r1, lr}   ; Save registers
		LDR r0, =0xE0004014		; Match Control Register
		LDR r1, [r0]
		ORR r1, r1, #0x18		;Change bits 5 and 3 to 1 (Bit 4 stop counter, Bit 3 generates interrupt
		STR r1, [r0]			
		LDR r0, =0xE0004004		;Timer 0 Control Register
		LDR r1, [r0]
		ORR r1, r1, #1
		STR r1, [r0]
		LDMFD SP!, {r0-r1, lr}
		BX lr

interrupt_init       
		STMFD SP!, {r0-r1, lr}   ; Save registers 
		
		; Push button setup		 
		LDR r0, =0xE002C000
		LDR r1, [r0]
		ORR r1, r1, #0x20000000
		BIC r1, r1, #0x10000000		;PINSEL0 bits 29:28 = 10
		ORR r1, r1, #5
		BIC r1, r1, #0xA	 		;UART0 = 1010
		STR r1, [r0]
		
		;Enable UART0 Interrupts
		LDR r0, =0xE000C004
		LDR r1, [r0]
		ORR r1, r1, #1				;RDA enabled with 1
		STR r1, [r0]  

		; Classify sources as IRQ or FIQ
		LDR r0, =0xFFFFF000
		LDR r1, [r0, #0xC]
		ORR r1, r1, #0x8000 ; External Interrupt 1
		ORR r1, r1, #0x40	; UART0 Interrupt
		ORR r1, r1, #0x10	; Timer 0 Interupt
			; Timer 0 Interupt
		STR r1, [r0, #0xC]

		; Enable Interrupts
		LDR r0, =0xFFFFF000
		LDR r1, [r0, #0x10] 
		ORR r1, r1, #0x8000 ; External Interrupt 1
		ORR r1, r1, #0x40	; UART0 Interrupt
		ORR r1, r1, #0x10	; Timer 0 Interrupt
		STR r1, [r0, #0x10]

		; External Interrupt 1 setup for edge sensitive
		LDR r0, =0xE01FC148
		LDR r1, [r0]
		ORR r1, r1, #2  ; EINT1 = Edge Sensitive
		STR r1, [r0]

		; Enable FIQ's, Disable IRQ's
		MRS r0, CPSR
		BIC r0, r0, #0x40
		ORR r0, r0, #0x80
		MSR CPSR_c, r0
 

		LDMFD SP!, {r0-r1, lr} ; Restore registers
		BX lr             	   ; Return



FIQ_Handler
		STMFD SP!, {r0-r12, lr}   ; Save registers 

EINT1			; Check for EINT1 interrupt
		LDR r0, =0xE01FC140
		LDR r1, [r0]
		TST r1, #2
		BEQ TIMER
	 
		  ;EINT code here
		LDR r0, =0xE01FC140
		LDR r1, [r0]
		ORR r1, r1, #2		; Clear Interrupt
		STR r1, [r0]
		B FIQ_Exit

TIMER	LDR r0, =0xE0004000
		LDR r1, [r0]
		TST r1, #2
		BEQ UART0
		
			;TIMER code here
		LDR r0, =0xE0004000
		MOV r1, #0x10
		STR r1, [r0,#4]		;reset the clock
		LDR r1, [r0]
		ORR r1, r1, #2		; Clear Interrupt
		B FIQ_Exit

UART0	;UART0 code here
		LDR r0, =0xE000C008
		LDR r1, [r0]
		AND r1, #0		;Check for UART interupt
		BNE FIQ_Exit	;not the UART then exit
		BL read_character	;Otherwise read from buffer
		MOV r1, r0
	    CMP r1, #0x2B
		BEQ increment_speed
		CMP r1, #0x2D
		BEQ decrement_speed
		
decrement_speed
		LDR r0, =0xE000401C		;Match Register value
		LDR r1, [r0]
		ADD r1, r1, r1			;double the value
		STR r1, [r0]
		B FIQ_Exit
increment_speed		
		LDR r0, =0xE000401C		;Match Register value
		LDR r1, [r0]
		MOV r0, r1
		MOV r1, #2
		BL div_and_mod			;Cut the match time in half
		LDR r1, =0xE000401C		;Match Register value
		STR r0, [r1]
		
FIQ_Exit

		LDMFD SP!, {r0-r12, lr}
		SUBS pc, lr, #4

;BEGIN rng SUBROUTINE
rng		   						;random number generated from 32 bit value passed through r0, and returned in r0 between 0-7
	STMFD sp!, {r1,lr}
	LDR	r4, =0xE0004008
	LDR r0, [r4] 				;get number from timer
	MOV r1, #-1
	LSL r1, #8
	BIC r0, r0, r1 				;clear everything but lower 8 bits
	MOV r1, r0
	BIC r1, r1, #0xF0
	MOV r0, r0, LSR #4
	CMP r1, #0
	BEQ rng
	BL div_and_mod
	MOV r0, r1					;return mod as the result of rng
	LDMFD sp!, {r1, lr}
	BX lr

;END rng SUBROUTINE

insert_symbol
	STMFD sp!, {lr}			;r0 column and row lower 4 bits is column, upper 4 bits is row, r1 is symbol
	AND r2, r0, #0xF		;extract column # into r2

	MOV r0, r0, LSR #4		;extract row # into r0
	AND r0, r0, #0xF
	LDR r4, =game_string
	MOV r3, r0, LSL #4		;offset for memory is equal to 19*#rows + # of columns
	ADD r3, r0, r3
	ADD r3, r0, r3
	ADD r3, r0, r3
	ADD r3, r0, r3			;Multiply # of rows by 19
	ADD r3, r2, r3			;Add # of columns
	STRB r1, [r4, r3]		;Store the ascii in memory

	LDMFD sp!, {lr}
	BX lr
get_symbol

	STMFD sp!, {r3, r4, lr}			;r0 column and row lower 4 bits is column, upper 4 bits is row, r1 is symbol
	AND r2, r0, #0xF		;extract column # into r2

	MOV r0, r0, LSR #4		;extract row # into r0
	AND r0, r0, #0xF
	LDR r4, =game_string
	MOV r3, r0, LSL #4		;offset for memory is equal to 19*#rows + # of columns
	ADD r3, r0, r3
	ADD r3, r0, r3
	ADD r3, r0, r3
	ADD r3, r0, r3			;Multiply # of rows by 19
	ADD r3, r2, r3			;Add # of columns
	ADD r1, r4, r3		;Store the ascii in memory

	LDMFD sp!, {r3, r4, lr}
	BX lr
	
output_screen
	STMFD sp!, {r0, lr}
	MOV r0, #0xC
	BL output_character			
	LDR r4, =game_string
	MOV r0, #0				;Counter initialized to 0
output_screen_loop
	BL output_string
	ADD r4, r4, #20
	CMP r0, #16
	ADD r0, r0, #1
	BLE output_screen_loop

	LDMFD sp!, {r0, lr}
	BX lr
	
update_screen
	;code for moving the symbol to a new place on the board
	STMFD sp!{lr}
	LDR r4, =0x40004008			;direction,  1 up, 2 right, 3 down, 4 left.
	LDR r4, [r4]
	CMP r4, #1
	BEQ move_up
	CMP r4, #2
	BEQ move_right
	CMP r4, #3
	BEQ move_down
	CMP r4, #4
	BEQ move_left
move_up
	MOV r3, #0x20
	LDR r4, =0x40004000			;location of symbol
	LDR r0, [r4]
	BL get_symbol
	SWP r3, r3, [r1]				;r0 will be the symbols location in the string in memory
	LDR r4, =0x40004000			;location of symbol
	LDR r0, [r4]
	AND r5, r0, #0xF0
	CMP r5, #0x10
	BEQ bounce_down
	SUB r0, r0, #0x10			;Move the symbol location up
	STR r0, [r4]
	BL insert_symbol
	BL output_screen
	B update_done 
bounce_down
	ADD r0, r0, #0x10			;Move the symbol location down
	STR r0, [r4] 	
	BL insert_symbol
	LDR r4, =0x40004008
	MOV r3, #3
	STR r3, [r4]
	B update_done
move_right
	MOV r3, #0x20
	LDR r4, =0x40004000			;location of symbol
	LDR r0, [r4]
	BL get_symbol
	SWP r3, r3, [r1]				;r0 will be the symbols location in the string in memory
	LDR r4, =0x40004000			;location of symbol
	LDR r0, [r4]
	AND r5, r0, #0xF
	CMP r5, #0xF
	BEQ	bounce_left
	ADD r0, r0, #0x1			;Move the symbol location up
	STR r0, [r4]
	BL insert_symbol
	B update_done
bounce_left
	SUB r0, r0, #0x1			;Move the symbol location left
	STR r0, [r4] 	
	BL insert_symbol
	LDR r4, =0x40004008
	MOV r3, #4
	STR r3, [r4]
	B update_done	
move_down
	MOV r3, #0x20
	LDR r4, =0x40004000			;location of symbol
	LDR r0, [r4]
	BL get_symbol
	SWP r3, r3, [r1]				;r0 will be the symbols location in the string in memory
	LDR r4, =0x40004000			;location of symbol
	LDR r0, [r4]
	AND r5, r0, #0xF0
	CMP r5, #0xF0
	BEQ bounce_up
	SUB r0, r0, #0x10			;Move the symbol location down
	STR r0, [r4]
	BL insert_symbol
bounce_up
	SUB r0, r0, #0x10			;Move the symbol location down
	STR r0, [r4] 	
	BL insert_symbol
	LDR r4, =0x40004008
	MOV r3, #1
	STR r3, [r4]
	B update_done
move_left
	MOV r3, #0x20
	LDR r4, =0x40004000			;location of symbol
	LDR r0, [r4]
	BL get_symbol
	SWP r3, r3, [r1]				;r0 will be the symbols location in the string in memory
	LDR r4, =0x40004000			;location of symbol
	LDR r0, [r4]
	AND r5, r0, #0xF
	BEQ bounce_right
	CMP r5, #0x1
	SUB r0, r0, #0x1			;Move the symbol location up
	STR r0, [r4]
	BL insert_symbol
	B update_done
bounce_right
	ADD r0, r0, #0x1			;Move the symbol location left
	STR r0, [r4] 	
	BL insert_symbol
	LDR r4, =0x40004008
	MOV r3, #2
	STR r3, [r4]
	B update_done
update_done
	LDMFD sp!{lr}
	BX lr
	
pin_connect_block_setup
	STMFD sp!, {r0, r1, r2, lr}
	LDR r0, =0xE002C000  		;PINSEL0
	LDR r1, [r0]
	ORR r1, r1, #5
	BIC r1, r1, #0xA	 		;UART0
;	ORR r1, r1, #0x50
;	BIC r1, r1, #0xA0			;Match Timer 0 and Catch Timer 0
;	ORR r1, r1, #0x500
;	BIC r1, r1, #0xA00			;Match .1 Timer 0 and Catch Timer .1 0

	STR r1, [r0]
	LDMFD sp!, {r0, r1, r2, lr}
	BX lr
	END