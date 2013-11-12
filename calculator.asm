; ******************************************************************************
; *
; * Title:		8051 Assembly Serial Calculator
; *
; *	Author:		Michael Vartan <admin@mvartan.com>
; * Student ID:	010628161
; * Date:		1 November, 2013
; *
; * Details:	This software is a calculator which is controlled via serial
; * 			communications at 9600 baud. It can add, subtract, divide, 
; *				and multiply any two numbers from -255 to 255. Input is as 
; *				follows: "250*100". Sending a line break signifies to the
; * 			program that the operands and operator have been typed and 
; *				the result should be calculated.
; *				
; ******************************************************************************




		STR_OUT EQU 30h						; location of our string
		STR_PTR EQU R0						; RAM pointer to the string
				org 0h
				
				jmp 40h					; jump to our starting location
				
				
				
; ******************************************************************************
; *
; *	Function:	Initialize Serial
; * 
; * Details:	Sets up serial communication at a 9600 baud rate.
; *
; ******************************************************************************
				org 40h
initSerial:		MOV TMOD, #20H
				MOV TH1, #-3
				MOV SCON, #50H
				SETB TR1
				
			
			
; ******************************************************************************
; *
; *	Function:	Super loop
; * 
; * Details:	Does the following repeatedly:
; *					* Asks for user input via serial
; *					* Parses input into two signed operators and an operand
; *					* Performs math operation and converts it to ASCII decimal
; *					* Sends this back via serial.
; *
; ******************************************************************************				
superloop:		
				mov STR_PTR, #30H			; Reset string pointer to string location
				acall receiveLine			; Receive a line of ASCII to the string buffer
				jnb F0, continueLoop
sendError:		mov STR_PTR, #30H
				mov DPTR, #ERROR_MSG;
				
				acall moveStringToRAM
				mov STR_PTR, #30H
				acall beginTransfer
				
				sjmp superLoop
				clr F0
continueLoop:	mov DPTR, #YOU_ENTERED;		; load datapointer to message
				mov STR_PTR, #70H;			; move RAM pointer
				acall moveStringToRAM		; load message into RAM
				
				mov STR_PTR, #70H			; reset RAM pointer
				acall beginTransfer			; transfer message
				
				mov STR_PTR, #30H			; Reset string pointer to string location
				acall beginTransfer			; echo back the line received.

				MOV STR_PTR, #70H
				mov DPTR, #THE_SOLUTION_IS
				acall moveStringToRAM
				mov STR_PTR, #70H
				
				acall beginTransfer
				mov STR_PTR, #30H			; Reset string pointer to string location

											; GET FIRST NUMBER
				acall getSign				; get sign (negative)

				clr 00h
				jnb F0, notNegative0		; if not negative, continue 
				setb 00h;					; else, set flag.
notNegative0:	clr F0
				acall pullNumFromStr 				
				mov R3, A					; load our first number into R3
				jb F0, sendError
				acall getOperation			; GET OPERATION
				mov R4, A					; load our operation into R4

				acall getSign				; get sign (negative)
				clr 04h
				jnb F0, notNegative1		; if not negative, continue 
				setb 04h;					; else, set flag.
				clr F0
notNegative1:	acall pullNumFromStr 
				jb F0, sendError
				mov R5, A					; load our second number into R5

				;MOV B, R3
				acall performOperatn		; perform math operation
				jnb 29h, goodOperatn
				mov STR_PTR, #30H
				mov DPTR, #ERROR_MSG;
				
				acall moveStringToRAM
				mov STR_PTR, #30H
				acall beginTransfer
				
				sjmp superLoop
goodOperatn:	;MUL AB
				JNB F0, printNum			; if negative
				push ACC
				mov A, #'-'					; temp. put '-' sign in accumulator
				acall transferChar			; to transfer it serially
				pop ACC
				
printNum:		mov STR_PTR, #30h			; reset string pointer
				acall resultsToASCII		; put operation contents in string
				mov STR_PTR, #30h			; reset string pointer
				acall beginTransfer			; to transfer contents serially.
				
				mov A, R7					; put remainder in accumulator
				JZ superloop				; if no remainder, restart loop
				
				mov B, #0					; clear B (MSB of our ascii number)
				mov STR_PTR, #30h			; reset string pointer
				acall resultsToASCII		; convert remainder to ascii
				mov A, #'r';				; get 'r' character
				acall transferChar			; transfer it serially
				mov STR_PTR, #30h			; reset string pointer
				acall beginTransfer			; transfer remainder serially.
				
				mov R7, #00h				; reset remainder
				
				ljmp superloop				; restart superloop
				

				
; ******************************************************************************
; *
; *	Function: 	ReceiveLine
; *
; * Details:	Takes user input until a carriage return is received.
; *				Loads them to a string buffer pointed to by STR_PTR
; * 			
; ******************************************************************************
				
receiveLine:	clr F0

getNextChar:	acall receiveChar			; receive a character from serial
				mov @STR_PTR, A				; move recieved char to str pointer
				inc STR_PTR					; move str pointer to next char
				CJNE A, #13, getNextChar	; if not return char, get next char
				
				mov @STR_PTR, #13;			; else, add a carriage return
				inc STR_PTR
				mov @STR_PTR, #10			; and a new line character.
				inc STR_PTR
				mov @STR_PTR, #0			; add null terminator character.			
				ret
		
		
		
; ******************************************************************************
; *
; *	Function:	Begin (serial) transfer
; *
; * Details:	Serially transfers the STR_PTR until it reachers a null termin.
; *
; ******************************************************************************		
				
beginTransfer:	push 0
transfer:		mov A, @STR_PTR
				jnz remainTransfer 			; if char is not null terminator,
											; remain transferring.
				pop 0						; else, pop back and
				RET							; return since our data is null.
remainTransfer:		
				acall transferChar
				inc STR_PTR					; increment our string pointer
				sjmp transfer;



; ******************************************************************************
; *
; *	Function:	Transfer Character
; *
; * Details:	Transfers accumulator serially
; *
; ******************************************************************************		
				
transferChar:	mov SBUF, A					; move accumulator to sbuf
				JNB TI, $					; stay until transfer interrupt
				CLR TI						; reset interrupt flag
				ret



; ******************************************************************************
; *
; *	Function:	Receive Character
; *
; *	Details:	Receives one byte from SBUF and stores it in the accumulator
; *
; ******************************************************************************

receiveChar:
				jnb RI, $					; while received flag is zero, stay
				mov A, SBUF					; then, move SBUF into accumulator
				CLR RI						; and clear received flag.
				acall transferChar
				CJNE A, #40H, nextLine2
nextLine2:		jb CY, isLess
				setb F0
isLess:			ret
				
				
			
; ******************************************************************************
; *
; *	Function:	Move String to RAM
; * 
; * Details:	Transfers String of characters from ROM to RAM. Begins at DPTR 
; * 			and STR_PTR, continues transmitting to RAM until a null
; *				terminator is read from ROM
; *
; ******************************************************************************

moveStringToRAM:mov A, #0					; clear the accumulator	
				movc A, @A+DPTR				; move char at dptr to accumulator
				mov @STR_PTR, A				; move new char to string
				inc STR_PTR					; increment pointer
				inc DPTR					; increment pointer
				jnz moveStringToRAM			; if not zero, continue.
				ret							; note: transfers the null terminator
				

				
; ******************************************************************************
; *
; *	Function:	Pull Number from String
; *
; *	Details:	Aggregates and converts all of the decimal numbers in front of 
; *				STR_PTR into the accumulator.
; *
; ******************************************************************************

pullNumFromStr:	mov R2, #0					; reset R2, which we will use to 
											; keep track of our value
getNextNumChar: 
				mov A, @STR_PTR				; load our next ASCII value
				cjne A, #'0', isValidNum	; otherwise, if it's equal to or
isValidNum: 	jnb CY, continueNum			; less than '0', we are done

leave0:			mov A, R2					; store R2 back in the accumulator 
				ret							; before returning
				
continueNum:	clr CY
				mov A, R2					; move R2 into accumulator
				MOV B, #10					; In order to shift left one digit,
				MUL AB						; multiply it by ten
				mov R2, B
				CJNE R2, #0, badNum
goodNum:		mov R2, A					; and store it back in R2
				mov A, @STR_PTR	 
				ANL A, #0CFH				; convert hex to value
				ADD A, R2					; add it to our old value
				jnb CY, noOverflow
badNum:			SETB F0
				ret
noOverflow:		mov R2, A					; and store it in the accumulator
				inc STR_PTR					; increment the string pointer
				sjmp getNextNumChar			; continue looking for next char.
				
				
				
; ******************************************************************************
; *
; *	Function:	Get operation
; *
; * Details:	Intended for pulling an operator out of the string, it loads
; *				the next char into the accumulator and increments the pointer.
; *
; ******************************************************************************				
				
getOperation:	mov A, @STR_PTR
				INC STR_PTR
				ret
		
		
		
; ******************************************************************************
; *
; *	Function:	Get Sign
; *	
; *	Details:	If the next char is a negative symbol, this function increments 
; * 			the STR_PTR and sets F0. Otherwise, F0 is cleared.
; *
; ******************************************************************************

getSign:		CLR F0						; clear return flag
				mov A, @STR_PTR				; load char to accumulator						
				cjne A, #'-', endGetSign	; if not negative char, end
				inc STR_PTR					; otherwise, increment past char
				SETB F0						; and set return flag
				CLR CY						; clear carry flag
endGetSign:		ret



; ******************************************************************************
; *
; *	Function:	Result to ASCII
; *	
; *	Details:	Converts the value located in B&ACC to the string buffer in 
; *				ASCII.
; *
; ******************************************************************************
resultsToASCII:	acall storeNibbleWise		; start by storing AB nibblewise.
				mov A, #0
				push ACC
				mov A, #10
				push ACC
				mov A, #13
				push ACC

keepDividing:	acall divideBy10			; divide R3-R6 by ten.
				MOV A, #30H					; convert to ascii
				ORL A, B					; by logical OR.
				push ACC
				mov A, R6					; check if bits are zero
				ORL A, R5
				ORL A, R4
				ORL A, R3
				JNZ keepDividing			; if not, keep dividing.
keepPopping:	pop ACC
				mov @STR_PTR, A
				inc STR_PTR
				jnz keepPopping
				ret



; ******************************************************************************
; *
; *	Function:	Divide By Ten
; *	
; *	Details:	Divides nibblewise registers by ten.
; *
; ******************************************************************************

divideBy10:
				MOV A, R3					; move MSB into the accumulator
				MOV B, #10					; Set denominator to 10
				DIV AB						; divide
				MOV R3, A					; store result back into register
				MOV A, #16
				MUL AB						; multiply B by ten, store into A
				
				ADD A, R4
				MOV B, #10					; Set denominator to 10
				DIV AB						; divide
				MOV R4, A					; store result back into register				
				MOV A, #16
				MUL AB						; multiply B by ten, store into A
				
				ADD A, R5
				MOV B, #10					; Set denominator to 10
				DIV AB						; divide
				MOV R5, A					; store result back into register
				MOV A, #16
			

MUL AB						; multiply B by ten, store into A
				
				ADD A, R6
				MOV B, #10					; Set denominator to 10
				DIV AB						; divide
				MOV R6, A					; store result back into register
											; remainder stays in B.
				ret
				
				

; ******************************************************************************
; *
; *	Function:	Store Nibble Wise
; *	
; *	Details:	Stores the value of A and B one nibble at a time in R3-R6
; *
; ******************************************************************************

storeNibbleWise:mov R6, A					; store the results from B/A
				
				swap A						; move upper byte of A to R5
				ANL A, #0x0F
				mov R5, A
				mov A, R6					; move lower byte of A to R6
				ANL A, #0x0F
				mov R6, A
				
				mov A, B					; move upper byte of B to R3
				swap A
				ANL A, #0x0F
				mov R3, A
				mov A, B					; move lower byte of B to R4
				ANL A, #0x0F
				MOV R4, A
				
				ret
				
				
				
; ******************************************************************************
; *
; *	Function: 	Peform operation
; *
; * Details:	Operator 1 stored in R3, sign stored in 00h,
; *				Operand stored in R4
; *				Operator 2 stored in R5, sign stored in 04h
; * 			
; ******************************************************************************

performOperatn:	clr F0						; default return not negative
				clr 29h						; error flag
				mov A, R4					; load operator into accumulator
				CJNE A, #'-', notMinus		; if operator is minus
				sjmp subtractNums			; jump to subtraction
				
notMinus:		CJNE A, #'+', notPlus		; if operator is plus
				sjmp addNums				; jump to addition
				
notPlus:		acall xorSigns				; sets negative flag if odd num of
											; negative numbers

				MOV B, R5					; load B into second value

				CJNE A, #'*', notMul		; if operator is asterisk
				sjmp mulNums				; multiply numbers

notMul:			CJNE A, #'/', endOperatn	; if operator is slash
				sjmp divNums				; divide numbers
				setb 29h
endOperatn:		RET							; return


;*******************************************; Begin Addition/Subtraction
				
subtractNums:	acall toggle04h				; subtraction is addition with 
addNums:									; flipped sign on second number

				MOV A, R3					; load first operator into A
				CJNE A, 5, nextLine			; check if first is smaller num
nextLine:		JB CY, goodOrder			; if so, swap the operators

				push 3						; Reverse absolute values by 
				push 5						; pushing
				pop 3						; and popping them backwards
				pop 5				
				mov A, 20h					; for signs, 20h holds bitwise 0/4
				swap A						; swapping them swaps 
				mov 20h, A					; the position of the flags.
			
				
goodOrder:		clr CY						; clear the carry flag
				MOV B, #0					; clear B

				mov R6, 20h					; load sign flags into R6 and
				mov A, 20h					; into a. We want both flags 
				swap A						; in the same bit, so we swap A.
				XRL A, R6					; XOR to see if they're different
				ANL A, #0FH					; and chop off the MSNibble.
				jnz subtract				; if they are diff, subtract.
				
				mov A, R3					; load R3 into accumulator
				ADD A, R5					; add R5
				jnb 00h, notNeg				; if values are negative,
				setb F0						; set negative flag
notNeg:			JNB CY, endOperatn			; if carry flag is set
				mov B, #1;					; carry the one to B

				RET
				
subtract:		setb F0						; negative by default
				mov A, R5					; load larger value into A
				SUBB A, R3					; subtract smaller value
				jz isPos					; if zero, force positive
				jb 04h, endOperatn			; if subtracting a negative
isPos:			clr F0						; then result is positive.
				RET

			
;*******************************************; Begin Multiplication/Division
			
mulNums:		MOV A, R3					; load A
				MUL AB						; multiply A*B
				RET
				
divNums:		MOV A, R3					; load A
				DIV AB						; Divide B/A
				mov R7, B					; move remainder to R7
				MOV B, #0					; clear B
				RET
				
xorSigns:		jb 00h, noToggleFirst		; if first negative
				acall toggleF0				; toggle negative flag
noToggleFirst:	jb 04h, noToggleSecond		; if second negative
				acall toggleF0				; toggle negative flag.
noToggleSecond: RET

;*******************************************; Begin Bitwise Toggling


toggleF0:		jnb F0, turnOnF0			; if flag set
				clr F0						; clear flag
				ret
turnOnF0:		setb F0						; otherwise set flag
				ret
toggle04h:		jnb 04h, turnOn04h			; if flag set
				clr 04h						; clear flag
				ret
turnOn04h:		setb 04h					; otherwise set flag
				ret	
				
				
				
; ******************************************************************************
; *
; *				Raw data below.
; *
; ******************************************************************************

YOU_ENTERED:	DB "You entered: ", 0
THE_SOLUTION_IS:DB "The solution is: ", 0
ERROR_MSG:		DB "ERROR          ",10, 13, 0

end
