; Z80 simple BIOS for Z80 computer
; Frank van der Niet
; 15-5-2021
;
; ---------------- Z80 computer design --------------------------------------------------
;
; 1. Components:
; - Z80 CPU 4.5Mhz
; - Z80 PIO (parallel input, output)
; - 32kB AT28C256 ROM
; - 32kB KM62256 RAM
; - 74LS04 (inverter) and 1 x 74LS08 (AND) for control logic ROM and RAM
; - Arduino nano as clock
; - NE555 (astable multi vibrator) as a slow clock
; 
;
; 2. Memorymap (32kB RAM and 32kB ROM):
; ------ FFFF ------ RAM
; ------      ------ RAM
; ------ 8000 ------ RAM
; ------ 7FFF ------ ROM
; ------      ------ ROM
; ------ 0000 ------ ROM
;
; 2. Z80 PIO:
; PORT A (address 0x00): connected to a two line HD44780 LCD
; Z80PIO D7 D6 D5 D4 D3 D2 D1 D0
; LCD    RS EN NC NC D7 D6 D5 D4
;        RS = Register Select, EN = Enable, NC = Not Connected, Dx = Data x
;
; PORT B (address 0x01): connected to a switch
; Z80PIO D7 D6 D5 D4 D3 D2 D1 D0
; Switch NC NC NC NC NC NC NC Sw
; 	 Sw = Switch with pull down resistor to ground (1 is on, 0 is off)
;
; ---------------- BIOS design ----------------------------------------------------------
;
; This BIOS contains the following routines:
;
; 1. pioa_init:		Initialize port A of the Z80 PIO
; 2. piob_init:		Initialize port B of the Z80 PIO
; 3. lcd_init:		Initialize the LCD in 4 bit mode
; 4. lcd_clear:		Clear the LCD
; 5. lcd_line2:		Goto line 2 on the LCD
; 6. lcd_char:		Write a character to the LCD
; 7. print_string:	Write strings to the LCD
; 7. read_switch:	Read the input from 1 switch
; 
; ---------------- The program ----------------------------------------------------------
;
; 1. Sends some text to the LCD 
; 2. Then copies text (64 bits) to RAM
; 3. Reads the text from memory and sends it to the LCD
; 4. Copies 32K from 0x000 (ROM) to 0x8000 (RAM)
;
; ---------------- Setup of constants ----------------------------------------------------

						; PIO 
		.equ CNTLA, 0b00000001		; PIO Control mode port A
		.equ CNTLB, 0b00000011		; PIO Control mode port B
		.equ MODE1, 0b01001111		; Set to mode 1 (input)
		.equ MODE3, 0b11001111		; Set to mode 3 (control)
		.equ PORTA, 0b00000000		; Address of Port A
		.equ PORTB, 0b00000010		; Address of Port B

						; LCD
		.equ LCDEN, 0b01000000		; LCD enable bit (1 for enable write, 0 not enable write)
		.equ LCDRS, 0b10000000		; LCD Register Select Bit (1 for instruction, 0 for data)

						; Other
		.equ RAMTOP, 0xFFFF		; Top of RAM
		.equ RAMBTM, 0x8000		; Bottom of RAM
		.equ ROMTOP, 0x7FFF		; Top of ROM
		.equ ROMBTM, 0x0000		; Bottom of ROM

; ---------------- Start of program ------------------------------------------------------

		LD SP, RAMTOP			; Stack pointer to top of RAM

		CALL pioa_init			; Initialize PIO Port A (drives LCD)
		CALL piob_init			; Initialize PIO Port B (reads input)
		CALL lcd_init			; Initialize LCD
	
loop:		LD HL,message_hel1		; Print hello 1 to the LCD
		CALL lcd_clear			; Clear LCD
		CALL print_string		; Print string
		CALL read_switch		; Wait for a key press

		LD HL,message_hel2		; Print hello 2 to the LCD 
		CALL lcd_clear			; Clear LCD
		CALL print_string		; Print string
		CALL lcd_line2			; Go to line 2 on LCD
		LD HL,message_hel3		; Print hello 3 to the LCD
		CALL print_string		; Print string
		CALL read_switch		; Read the switch

		LD HL,message_menu		; Print Menu to the LCD
		CALL lcd_clear
		CALL print_string
		CALL lcd_line2
		LD HL,message_men1		; Print Menu item 1 to the LCD (not a choice yet)
		CALL print_string
		CALL read_switch

		LD HL,message_mts1		; Print memory test 1 to the LCD
		CALL lcd_clear
		CALL print_string
		CALL lcd_line2
		LD HL,message_mts2		; Print memory test 2 to the LCD
		CALL print_string
		CALL read_switch

						; Now we copy the data to memory to read from it later
		LD HL,message_memt1		; Start address in ROM to copy data from
		LD DE,0x8000			; First address in RAM to copy data to
		LD BC,0x0040			; Number of bytes to copy (64 bytes)
		LDIR				; Copy data from ROM to RAM

		LD HL,message_mts3		; Print memory test 3 to the LCD
		CALL lcd_clear
		CALL print_string
		CALL lcd_line2
		LD HL,message_mts4		; Print memory test 4 to the LCD
		CALL print_string
		CALL read_switch
		
						; Now display text from RAM
		LD HL,0x8000			; Start address of line 1 in RAM of text
		CALL lcd_clear
		CALL print_string
		CALL lcd_line2
		LD HL,0x8010			; Start address of line 2 in RAM of text
		CALL print_string
		CALL read_switch

		LD HL,0x8020			; Start address of line 3 in RAM of text
		CALL lcd_clear
		CALL print_string
		CALL lcd_line2
		LD HL,0x8030			; Start address of line 4 in RAM of text
		CALL print_string
		CALL read_switch

						; Now display text for copying 32K to RAM
		LD HL,message_menu		
		CALL lcd_clear
		CALL print_string
		CALL lcd_line2
		LD HL,message_men2
		CALL print_string
		CALL read_switch
						; Now we copy 32K of ROM to RAM
		LD HL,0x0000			; Start address to copy data from
		LD DE,0x8000			; First address to copy data to
		LD BC,0x7F00			; Number bytes to copy (32k), leave some space for SP
		LDIR				; Copy data

						; Now display text that copy to RAM is completed
		LD HL,message_mts3
		CALL lcd_clear
		CALL print_string
		CALL read_switch

		JP loop
; ---------------- End of program --------------------------------------------------------

; ---------------- Start of BIOS ---------------------------------------------------------

read_switch:	IN A, (PORTB)			; Read PIO port B
		AND 0b00000001			; Filter bit D0
		CP 0b00000001			; Is bit D0 1?
		RET Z				; If yes return to program (zero flag is set)
		JR read_switch			; If no go back to read PIO port B

						; Initialize PIO Port A
pioa_init:	LD A,MODE3			; Set IO ports in mode 3
		OUT (CNTLA),A			; Write control bits
		LD A, 0b00000000		; Set all ports to output
		OUT (CNTLA),A			; Write control bits
		RET				; Return

piob_init:	LD A,MODE3			; Set IO ports in mode 3, 
		OUT (CNTLB),A			; Write control bits
		LD A, 0b00000001		; Set first bit to input
		OUT (CNTLB),A			; Write control bits
		RET				; Return

						; Pins Z80 PIO -> LCD:
						; D7 D6 D5 D4 D3  D2  D1  D0
						; RS EN NC NC DB7 DB6 DB5 DB4
						; RS=Register Select, EN=Enable, NC=Not Connected, DBx=Data Bus

						; Function to write instructions to LCD
lcd_instr:	OUT (PORTA),A			; Write to LCD
		OR LCDEN			; Set enable bit high
		OUT (PORTA),A			; Write to LCD
		XOR LCDEN			; Set enable bit low
		OUT (PORTA),A			; Write to LCD
		RET				; Return

						; Begin init display
lcd_init:	LD A, 0b00000010		; Function set, sets to 4-bit operation
		CALL lcd_instr			; Send instruction to LCD
        	LD A, 0b00000010		; Function set has to be written twice
		CALL lcd_instr			; Send instruction to LCD
		LD A, 0b00001100		; More bits for function set
		CALL lcd_instr			; Send instruction to LCD

       		LD A, 0b00000000		; Display on high bits
		CALL lcd_instr			; Send instruction to LCD
 		LD A, 0b00001111                ; Display on low bits
		CALL lcd_instr			; Send instruction to LCD

        	LD A, 0b00000000		; Clear display high bits
		CALL lcd_instr			; Send instruction to LCD
        	LD A, 0b00000001		; Clear display low bits
		CALL lcd_instr			; Send instruction to LCD

     		LD A, 0b00000000		; Entry mode high bits
		CALL lcd_instr			; Send instruction to LCD
       		LD A, 0b00000110		; Entry mode low bits
		CALL lcd_instr			; Send instruction to LCD
		RET				; Return

lcd_clear:      LD A, 0b00000000		; Clear LCD screen high bits
		CALL lcd_instr			; Send instruction to LCD
                LD A, 0b00000001		; Clear LCD screen low bits
		CALL lcd_instr			; Send instruction to LCD
		RET				; Return

lcd_line2:	LD A, 0b00001100		; Set cursor to line 2 of display (DDRAM 0x40) high bits
		CALL lcd_instr			; Send instruction to LCD
		LD A, 0b00000000		; Set cursor to line 2 of display (DDRAM 0x40) low bits
		CALL lcd_instr			; Send instruction to LCD
		RET				; Return

						; Write high bits to the LCD
print_char:	LD C,A				; Write content of A to C
						; Process high 4 bits
		RR A				; Shift bits to the right
		RR A				; Shift bits to the right
		RR A				; Shift bits to the right
		RR A				; Shift bits to the right
		SET 7,A				; Set bit 7 to a 1 to write a character to the lcd
		AND 0b10001111			; Mask to write with the enable bit low to the lcd
		OUT (PORTA),A			; Write to LCD

						; Flip enable bit and write to lcd
		OR 0b01000000			; Set enable bit high
		OUT (PORTA),A			; Write to LCD
		XOR 0b01000000			; Set enable bit low
		OUT (PORTA),A			; Write to LCD

						; Write low bits to the LCD
		LD A,C				; Copy contents of C back to A
		SET 7,A                         ; Set bit 7 to a 1 to write a character to the lcd
     		AND 0b10001111                  ; Mask to write with the enable bit low to the lcd
      		OUT (PORTA),A                   ; Write to LCD

                	                        ; Flip enable bit and write to lcd
        	OR 0b01000000                   ; Set enable bit high
    		OUT (PORTA),A                   ; Write to LCD
        	XOR 0b01000000                  ; Set enable bit low
       		OUT (PORTA),A                   ; Write to LCD

		RET				; Return

print_string:  	LD A,(HL)			; Load A with memory of address HL
       		INC HL				; Increment HL
        	CP 0x00				; Is A zero?
       		RET Z				; If yes, end of string, return
        	CALL print_char			; If no, print character
        	JR print_string			; Go back to start of loop
		RET				; Return

; ---------------- End of BIOS ----------------------------------------------------------


; ---------------  Text lines (end a line with 0x00) ------------------------------------

message_hel1:	.byte "Z80 Computer", 0x00 
message_hel2:	.byte "Designed by:", 0x00
message_hel3:	.byte "Frank vd Niet", 0x00

message_menu:	.byte "MENU", 0x00
message_men1:	.byte "1. Check memory", 0x00
message_men2:	.byte "2. Copy 32K to RAM", 0x00

message_mts1:	.byte "Copy data to", 0x00
message_mts2:	.byte "memory 8000H", 0x00
message_mts3:	.byte "Copied to RAM", 0x00
message_mts4:	.byte "Read from RAM", 0x00

message_next:	.byte "(1=Next)", 0x00
message_nextok:	.byte "(1=Next, 2=OK)", 0x00

message_memt1:	.byte "Mem test 0: OK ", 0x00
message_memt2:	.byte "Mem test 1: OK ", 0x00
message_memt3:	.byte "Mem test 2: OK ", 0x00
message_memt4:	.byte "Mem test 3: OK ", 0x00
