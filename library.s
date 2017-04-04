	AREA	lib, CODE, READWRITE 
	EXPORT div_and_mod
	EXPORT uart_init
	EXPORT read_character
	EXPORT read_string
	EXPORT output_character
	EXPORT output_string
	EXPORT illuminateLEDs
	EXPORT illuminate_RGB_LED
	EXPORT read_from_push_btns
	EXPORT display_digit_on_7_seg
	EXPORT digits_SET
	EXPORT rgb_SET

U0LSR EQU 0x14
digits_SET	
		DCD 0x00001F80  ; 0
 		DCD 0x00000300  ; 1
		DCD 0x00002D80	; 2
		DCD 0x00002780	; 3
		DCD 0x00003300	; 4
		DCD 0x00003680	; 5
		DCD 0x00003E80	; 6
		DCD 0x00000380	; 7
		DCD 0x00003F80	; 8
		DCD 0x00003780	; 9				
		DCD 0x00003B80	; A
		DCD 0x00003E00	; B
		DCD 0x00001C80	; C
		DCD 0x00002F00	; D
		DCD 0x00003C80	; E
		DCD 0x00003880  ; F
rgb_SET
		DCD 0x00020000	; r
		DCD 0x00200000	; g
		DCD 0x00040000	; b
		DCD 0x00220000	; y
		DCD 0x00060000	; p
		DCD 0x00240000	; c
		DCD 0x00260000	; w


	ALIGN



div_and_mod										;takes a dividend in r0 and a divisor in r1 and returns the quotient and the remainder
				STMFD sp!, {r2-r12, lr}
										 		;r0 is dividend, r1 is divisor
			
												;BEGIN FIRST PART OF SUBROUTINE: SIGN DETECTION FOR INPUTS
												;r2, 3, and 4 will be temporary registers for the first part of this subroutine
				MOV r2, r0, ASR #31				;gives the sign of dividend
				EOR r0, r0, r2			   		;if temp register had negative sign of dividend(ie -1), this will flip all bits in dividend, else does nothing
				SUB r0, r0, r2					;if temp register had -1 this will add 1 completing 2's comp, otheriwise its zero and nothing happens
				MOV r3, r1, ASR #31				;complete same process below with the divisor and store sign again in another temp variable
				EOR r1, r1, r3
				SUB r1, r1, r3					
				MOV r2, r2, LSR #31				;store signs as either 0 or 1 in two temporary registers so sign can be adjusted at the end
				MOV r3, r3, LSR #31				
				EOR r2, r2, r3					;gives the sign that the output should be changed to, 1 for negative, 0 for positive
												;END ROUTINE FOR DETECTING INPUT SIGNS
												;BEGIN MAIN BODY OF DIVISION/MOD ROUTINE
				MOV r3, #0						;Initialize quotient with 0
				MOV r4, r0						;Initialize remander with dividend
				MOV r1, r1, LSL #16				;Store divisor in upper 16 bits of another variable
				MOV r5, #16						;Store counter as 15
	
DIVLOOP			SUB r4, r4, r1					;Remainder = remainder - divisor
				CMP r4, #0
				BLT	restore_remain				;Branch if less than 0 to RESTORE label
				MOV r3, r3, LSL #1				;Otherwise shift quotient 1 space left and make LSB 1
				ADD r3, r3, #1					
				B div_check						;Branch to counter check label
restore_remain	ADD r4, r4, r1					;Restore remainder by adding back the divisor
				MOV r3, r3, LSL #1				;Left shift the divisor by 1 and leave the LSB as 0

div_check		MOV r1, r1, LSR #1				;Right Shift The divisor by 1
				CMP r5, #0						;Test if counter is greater than 0.
				SUB r5, r5, #1					;Decrement counter
				BGT DIVLOOP						;If counter was greater than 0, branch back to DIVLOOP and do it again until counter=0
												;otherwise end this part and store quotient and remainder in r0 and r1
				MOV r0, r3
				MOV r1, r4						

				CMP r2, #0						;compare to see if sign needs to be changed
				BEQ div_done					;If equal to 0 then do nothing to results and finish
												;otherwise do 2s compliment in order to change sign of quotient
				MOV r2, #-1						;Make contents of a register 0xFFFFFFFF
				EOR r0, r0, r2					;XOR of quotient with this number to flip all bits
				ADD r0, r0, #1					;add 1 to complete 2s compliment
			 
	
div_done		LDMFD sp!, {r2-r12, lr}
				BX lr      ; Return to the C program

uart_init							;suburoutine that initializes the serial portion of the UART0 properly
		STMFD sp!, {lr};these C language commands need to be changed into assembly language, basically taking these values and storing them in these addresses
		LDR r4, =0xE000C00C
		MOV r0, #131
		STRB r0,[r4]
		LDR r4, =0xE000C000
		MOV r0, #120
		STRB r0, [r4]
		LDR r4, =0XE000C004
		MOV r0, #0
		STRB r0, [r4]
		LDR r4, =0xE000C00C
		MOV r0, #3
		STRB r0, [r4]
		LDMFD SP!, {lr} 
		BX lr
;end uart_init subroutine

read_character					 	;reads data from the UART0 register buffer once there is something waitin there, returns value in r0.
			STMFD SP!, {r1, r9, lr}
			
read_c		
			LDR r0, =0xE000C014		;load register byte to test if RDR is 0 or 1	
			LDRB r1, [r0]			
			AND r1, r1, #1			;and 1 and RDR to limit result to the LSB
			CMP r1, #0				;compare result to 0
			BEQ read_c				;if 0 repreat loop
			LDR r1, =0xE000C000		;if not, retrieve the information that was stored in that buffer register
			LDRB r0, [r1]			;	in return register r0
			
			LDMFD SP!, {r1, r9, lr}
			BX lr
;end read_character subroutine

read_string							;subroutine that reads characters one at a time until enter is encountered
										;and stores them as a null terminated ascii string in memory location given in r4			  
			STMFD SP!, {r0,r6,lr}
			MOV r6, #0				;initialize	offset for storage location
read_s_loop
			BL read_character		;these lines
			BL output_character		
			STRB r0, [r4, r6]		;store characetr read from subroutine returned in r0 into memory location r4 with our offset
			ADD r6, r6, #1			;increment offset
			CMP r0, #13	   			;check if enter has been pressed
			BNE read_s_loop
			MOV r0, #0				;put 0 into r0(also known as null)
			SUB r6, r6, #1			;decrement to overwrite the entered 'enter key'
			STRB r0, [r4, r6]		;overwrite the enter that was stored to memory so we create a null terminated string in its place
			
			LDMFD sp!, {r0, r6, lr}
			BX LR
;end read_string subroutine

output_character					;will output a character store in r0 to the UART0 register buffer
			STMFD SP!, {r1, r2, r3, lr}
output_c
			LDR r1, =0xE000C014		;load register byte to test if THRE is 0 or 1
			LDRB r2, [r1]
			LSR r2, #5				;get THRE as LSB in register
			AND r2, r2, #1			;and 1 and THRE to see limit result to the LSB
			CMP r2, #0				;compare result to 0
			BEQ output_c			;if 0 repreat loop
			LDR r3, =0xE000C000 	
			STRB r0, [r3]			;and store byte from r0 regiter into buffer register
			
			LDMFD SP!, {r1, r2, r3, lr}
			BX lr
;end outout_character subroutine

output_string						;subroutine that prints the null terminated ascii string stored in memory location in r4
			STMFD SP!, {r0, r6, lr}
			
			MOV r6, #0				;initialize offset offset
output_s_loop
			LDRB r0, [r4, r6]		;load first character
			BL output_character		;push to UART buffer
			ADD r6, r6, #1			;increment offset
			CMP r0, #0	   			;check if NULL
			BNE output_s_loop
			
			LDMFD sp!, {r0, r6,lr}
			BX LR
;end output_string subroutine

display_digit_on_7_seg						;displays a hex-digit on the 7-segment display passed through r0
	 		STMFD sp!, {lr}
			LDR r1, =0xE0028004 			; Base address
			LDR r2, =0x00003F80				;Clear all pins 7-13
			STR r2, [r1, #8]				;store in clear register for port 0
			 
  			LDR r3, =digits_SET 
  			MOV r0, r0, LSL #2  			; Each stored value is 32 bits 
  			LDR r2, [r3, r0]   				; Load IOSET pattern for digit in r0 
  			STR r2, [r1]    			; Display (0x4 = offset to IOSET
			LDMFD sp!, {lr}
			BX lr
;end display_digit_on_7_seg subroutine

read_from_push_btns							;reads from momentary push buttons, and returns the decimal value in r0
			STMFD sp!, {r1-r5, lr}
			LDR r4, =0xE0028010				;read register for port 1
			LDR r1, [r4]					;load states of all ports in port 1
			MOV r2, #-1
			EOR r1, r1, r2					;flip all bits
			MOV r1, r1, LSR #20				;Right shift to get pin 20's value as LSB
			MOV r2, #1
			MOV r3, #0						;initialize r3 counter
			MOV r0, #0						;"  " r0 to 0
push_loop	AND r5, r1, r2					;Takes value of LSB, ie port 20 and stores in r0
			ADD r0, r0, r5
			
			MOV r1, r1, LSR #1				;right shift to get value of the next push button
			CMP r3, #3
			BGE push_end
			ADD r3, r3, #1					;increment the counter
			MOV r0, r0, LSL #1				;Left shift output
			B push_loop
push_end	LDMFD SP!, {r1-r5,lr}
			BX lr
;end read_from_push_btns subroutine

illuminateLEDs 								;illuminates a set of LEDS, the pattern indicated based on value in r0
			STMFD sp!, {r1-r5, lr}
			LDR r1, =0x000F0000				;Sets pins to 1 being "off" for LEDs
			LDR r4, =0xE0028014				;Port 1 set register
			STR r1, [r4]

			MOV r3, #0						;initialize r3 counter
			MOV r2, #0						;"  " r2 to 0
led_loop	AND r5, r0, #1					;Takes value of LSB, ie port 20 and stores in r0
			ADD r2, r2, r5
			
			MOV r0, r0, LSR #1				;right shift to get value of the next push button
			CMP r3, #3
			BGE led_end
			ADD r3, r3, #1					;increment the counter
			MOV r2, r2, LSL #1				;Left shift output
			B led_loop
led_end		LDR r4, =0xE002801C				;Port 1 clear register
			MOV r2, r2, LSL #16
			STR r2, [r4]					;clear bits we want to light up
			LDMFD sp!, {r1-r5, lr}
			BX lr
;end illuminateLEDs subroutine

illuminate_RGB_LED							;illuminates the RGB LED based on the information stored in r0, decoded as follows:											;	
			STMFD sp!, {r1-r4, lr}
			LDR r1, =0x00260000				;Sets pins to 1 being "off" for LEDs
			LDR r4, =0xE0028004				;Port 0 set register
			STR r1, [r4]					;turn off RGB LED

			MOV r1, #0
			CMP r0, #0x72					;compare 'r'
			BEQ decode
			ADD r1, r1, #1
			CMP r0, #0x67					;compare 'g'
			BEQ decode
			ADD r1, r1, #1
			CMP r0, #0x62					;compare 'b'
			BEQ decode
			ADD r1, r1, #1
			CMP r0, #0x79					;compare 'y'
			BEQ decode
			ADD r1, r1, #1
			CMP r0, #0x70					;compare 'p'
			BEQ decode
			ADD r1, r1, #1
			CMP r0, #0x63					;compare 'c'
			BEQ decode
			ADD r1, r1, #1
			CMP r0, #0x77					;compare 'w'
decode		LDR r3, =rgb_SET 
  			MOV r1, r1, LSL #2  			; Each stored value is 32 bits 
  			LDR r2, [r3, r1]   				; Load IOSET pattern for digit in r0
			LDR r4, =0xE002800C				;Port 0 clear register 
  			STR r2, [r4]    				;turn on certain color requested
							
			LDMFD sp!, {r1-r4, lr}
			BX lr
;end illuminate_RGB_LED subroutine

	END
