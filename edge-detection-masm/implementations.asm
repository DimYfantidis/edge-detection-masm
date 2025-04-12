; Program description:
;   The program below implements three C functions, declared externally.
;   These functions are used for edge detection in an image stored as a .bmp 
;	file format. Their declarations are:
;
;		- WORD bmptogray_conversion(WORD height, WORD width, WORD input_color[2048][2048], WORD output_gray[2048][2048]) 
;		- WORD sobel_detection(WORD height, WORD width, WORD input_gray_image[2048][2048], BYTE output_ee_image[2048][2048])
;		- WORD border_pixel_calculation(WORD height, WORD width, BYTE ee_image[2048][2048])
;
;	Each of these functions is a step required for computing the edges in the 
;	image using Sobel detecion algorithm
;
; Author: Yfantidis Dimitrios
; Creation Date: 25/01/2024
; Revisions:
;   - 25/01/2024: Implemented first function
;   - 26/01/2024: Implemented second function
;   - 29/01/2024: Implemented third function
;	- 01/02/2024: Extended the second function (sobel_detection) to include a REAL8 parameter for the threshold value
;   - 03/02/2024: Extended comments
;	- 12/02/2024: Validated the project
; Date: 12/02/2024



.model flat, C
.stack 1024


.code
; 1. ---------------------------------------- FIRST FUNCTION ---------------------------------------- 
; -------------- coverting the input RGB bmp to grayscale image (not black and white) ---------------
; Input:
;	- arg1: integer @[EBP + 8] -- height of the bitmap file in pixels
;	- arg2: integer @[EBP + 12] -- width of the bitmap file in pixels
;	- arg3: RGBQUAD 2D static array @[EBP + 16] -- the input array containing the RGB pixels of the bitmap file
; Output:
;	- arg4: integer 2D static array @[EBP + 20] -- the output array containing the grayscale pixels of the bitmap file
;	- returns: 0 on success, 1 on error
bmptogray_conversion PROC
	; Prologue
	PUSH	EBP
	MOV		EBP, ESP
	SUB		ESP, 4*6	; 6 locals: x, y counters + r, g, b values + next pixel memory offset 
	
	; Save registers
	PUSH	EBX
	PUSH	ECX
	PUSH	EDX
	PUSH	ESI
	PUSH	EDI
	PUSHFD

	; Check for wrong input
	MOV		EAX, 1				; return 1 on error
	MOV		EDX, [EBP + 8]		; EDX = height
	CMP		EDX, 0
	JLE		exit_tag_f1			; height <= 0
	CMP		EDX, 2048
	JG		exit_tag_f1			; height > 2048
	MOV		EDX, [EBP + 12]		; EDX = width
	CMP		EDX, 0
	JLE		exit_tag_f1			; width <= 0
	CMP		EDX, 2048
	JG		exit_tag_f1			; width > 2048

	CLD
	
	MOV		ECX, [EBP + 8]		; Fetch height value
	XOR		EAX, EAX		
	MOV		[EBP - 4], EAX		; Initialize y = 0
	MOV		[EBP - 8], EAX		; Initialize x = 0
height_loop_f1:
	PUSH	ECX
	MOV		ECX, [EBP + 12]		; Fetch width value
	XOR		EBX, EBX
	MOV		[EBP - 8], EBX		; Set x = 0
	width_loop_f1:
		MOV		ESI, [EBP + 16]	; Source array address (input_color)
		MOV		EBX, [EBP - 8]	; Get row index, EBX = x
		SHL		EBX, 11			; Compute EBX = 2048 * x, where 2048 = n_columns
		ADD		EBX, [EBP - 4]	; Add column index, EBX = 2048 * x + y
		SHL		EBX, 2			; Scale by sizeof(int) = sizeof(RGBQUAD) = 4, EBX = 4 * (2048 * x + y)
		MOV		[EBP - 12], EBX	; Save memory offset
		ADD		ESI, EBX		; ESI = &A[x][y] = A + 4 * (2048 * x + y)

		; Red Channel
		XOR		EBX, EBX		; EBX = 0
		MOV		BL, [ESI + 2]	; EBX = RGBQUAD.rgbRed
		MOV		EAX, 2989		; EAX = 2989
		MUL		EBX				; EAX = 2989 * RGBQUAD.rgbRed
		MOV		[EBP - 16], EAX	; Red value x10000
		
		; Green Channel
		XOR		EBX, EBX		; EBX = 0
		MOV		BL, [ESI + 1]	; EBX = RGBQUAD.rgbGreen
		MOV		EAX, 5870		; EAX = 5870
		MUL		EBX				; EAX = 5870 * RGBQUAD.rgbGreen
		MOV		[EBP - 20], EAX	; Green value x10000

		; Blue Channel
		XOR		EBX, EBX		; EBX = 0
		MOV		BL, [ESI]		; EBX = RGBQUAD.rgbBlue
		MOV		EAX, 1140		; EAX = 1140
		MUL		EBX				; EAX = 1140 * RGBQUAD.rgbBlue
		MOV		[EBP - 24], EAX	; Blue value x10000

		; Sum the results (colors by their corresponding factors)
		MOV		EAX, [EBP - 16]	
		ADD		EAX, [EBP - 20]
		ADD		EAX, [EBP - 24]
		
		XOR		EDX, EDX		; EDX:EAX = 0000:(GrayscaleValue x10000)
		MOV		EBX, 100		; EBX = 100
		DIV		EBX				; Divide EAX by 100. Result in EAX, remainder in EDX
		MUL		EBX				; Multiply EAX by 100. Now EAX contains its initial value rounded to the previous hundred

		; Check for rounding up
		CMP		EDX, 50			; Compare remainder with 50
		JL		no_round_up_f1	; If less, jump to no_round_up
		ADD		EAX, 100		; Else add 100 to EAX

		no_round_up_f1:
		; Now EAX was rounded up if necessary, else it remained rounded down
		XOR		EDX, EDX		; EDX:EAX = 0000:(RoundedGraysvaleValue x10000)
		MOV		EBX, 10000		; EBX = 10000
		DIV		EBX				; EAX = RoundedGrayScaleValue
		; Now EAX contains the pixel value in [0, 255] approximated with accuracy of 2 decimals

		MOV		EDI, [EBP + 20]	; Destination array address (output_gray)	
		ADD		EDI, [EBP - 12]	; Add offset, EDI = &A[x][y] = A + 4 * (2048 * x + y)
		MOV		[EDI], EAX
		
		INC		DWORD PTR [EBP - 8]	; x++
		LOOP	width_loop_f1
	POP		ECX					; Fetch current height iterations
	INC		DWORD PTR [EBP - 4]	; y++
	DEC		ECX
	CMP		ECX, 0
	JNZ		height_loop_f1		; The LOOP operation has a byte limit (??????)
	
	; return 0
	XOR		EAX, EAX

exit_tag_f1:
	; Restore registers
	POPFD
	POP		EDI
	POP		ESI
	POP		EDX
	POP		ECX
	POP		EBX

	; Epilogue
	ADD		ESP, 4*6
	POP		EBP
	RET
bmptogray_conversion ENDP




; 2. ---------------------------------------- SECOND FUNCTION ---------------------------------------- 
; ------------------------------------- Edge Detection with Sobel ------------------------------------
; Input:
;	- arg1: integer @[EBP + 8] -- height of the bitmap file in pixels
;	- arg2: integer @[EBP + 12] -- width of the bitmap file in pixels
;	- arg3: RGBQUAD 2D static array @[EBP + 16] -- the input array containing the grayscale pixels of the bitmap file
;	- arg5: REAL8 @[EBP + 24] -- threshold for sobel detection algorithm
; Output:
;	- arg4: byte 2D static array @[EBP + 20] -- the output array containing the edge detection annotations
;	- returns: 0 on success, 1 on error
sobel_detection PROC
	PUSH	EBP
	MOV		EBP, ESP
	SUB		ESP, 3*4	; Three WORD local variables to hold the x, y counters and the memory offset
	SUB		ESP, 2*8	; Two REAL8 local variables to hold Gx^2 and Gy^2
	
	; Save registers
	PUSH	EBX
	PUSH	EDX
	PUSH	ESI
	PUSH	EDI
	PUSHFD

	; Check for wrong input
	MOV		EAX, 1				; return 1 on error
	MOV		EDX, [EBP + 8]		; EDX = height
	CMP		EDX, 1
	JLE		exit_tag_f2			; height <= 1
	CMP		EDX, 2048
	JG		exit_tag_f2			; height > 2048
	MOV		EDX, [EBP + 12]		; EDX = width
	CMP		EDX, 1
	JLE		exit_tag_f2			; width <= 1
	CMP		EDX, 2048
	JG		exit_tag_f2			; width > 2048


	DEC		DWORD PTR [EBP + 8]		; Set height = heigth - 1
	DEC		DWORD PTR [EBP + 12]	; Set width = width - 1
	MOV		ESI, [EBP + 16]		; ESI = &gray_array[0][0]
	MOV		EDI, [EBP + 20]		; EDI = &ee_array[0][0]

	; "gray_array" will be abreviated as "G" for short

	MOV		EAX, 1
	MOV		[EBP - 4], EAX	; Initialize x = 1

width_loop_f2:
	MOV		EAX, 1
	MOV		[EBP - 8], EAX	; Initialize y = 1
	height_loop_f2:
		MOV		EAX, [EBP - 4]		; EAX = x
		SHL		EAX, 11				; EAX = 2048 * x
		ADD		EAX, [EBP - 8]		; EAX = 2048 * x + y
		SHL		EAX, 2				; EAX = 4 * (2048 * x + y)
		MOV		[EBP - 12], EAX		; Save offset = 4 * (2048 * x + y)

		; Computation of Gx:
		MOV		EBX, [EBP-12]		; EBX = offset
		MOV		EAX, [ESI+EBX-8188]	; EAX = G[x-1][y+1]
		SUB		EAX, [ESI+EBX-8196]	; EAX = -G[x-1][y-1] + G[x-1][y+1]
		MOV		EDX, [ESI+EBX+4]	; EDX = G[x][y+1]
		SUB		EDX, [ESI+EBX-4]	; EDX = -G[x][y-1] + G[x][y+1]
		SHL		EDX, 1				; EDX = -2 * G[x][y-1] + 2 * G[x][y+1]
		ADD		EAX, [ESI+EBX+8196]	; EAX += G[x+1][y+1]
		SUB		EAX, [ESI+EBX+8188]	; EAX -= G[x+1][y-1]
		ADD		EAX, EDX			; EAX += EDX, thus now EAX = Gx
		IMUL	EAX					; EAX = Gx^2
		
		XOR		EDX, EDX
		MOV		[EBP-16], EDX		; Upper bits = 0
		MOV		[EBP-20], EAX		; Lower bits = Gx^2

		; Computation of Gy
		MOV		EAX, [ESI+EBX+8192]	; EAX = G[x+1][y]
		SHL		EAX, 1				; EAX = 2 * G[x+1][y]
		ADD		EAX, [ESI+EBX+8188]	; EAX = 2*G[x+1][y] + G[x+1][y-1]
		ADD		EAX, [ESI+EBX+8196]	; EAX = 2*G[x+1][y] + G[x+1][y-1] + G[x+1][y+1]
		MOV		EDX, [ESI+EBX-8192]	; EDX = G[x-1][y]
		SHL		EDX, 1				; EDX = 2*G[x-1][y]
		ADD		EDX, [ESI+EBX-8188]	; EDX = 2*G[x-1][y] + G[x-1][y+1]
		ADD		EDX, [ESI+EBX-8196]	; EDX = 2*G[x-1][y] + G[x-1][y+1] + G[x-1][y-1]
		SUB		EAX, EDX			; EAX -= EDX, thus now EAX = Gy
		IMUL	EAX					; EAX = Gy^2

		XOR		EDX, EDX
		MOV		[EBP-24], EDX		; Upper bits = 0
		MOV		[EBP-28], EAX		; Lower bits = Gy^2
		
		SHR		EBX, 2				; EBX = offset / 4 = 2048 * x + y because sizeof(out[x][y]) = sizeof(G[x][y]) / 4

		FILD	REAL8 PTR [EBP-20]	; ST(0) = (double)Gx^2
		FILD	REAL8 PTR [EBP-28]	; ST(0) = (double)Gy^2, ST(1) = (double)Gx^2
		FADDP						; ST(0) = Gx^2 + Gy^2
		FSQRT						; ST(0) = e = sqrt(Gx^2 + Gy^2)
		FCOMP	REAL8 PTR [EBP+24]	; Compare ST(0) and threshold

		FSTSW	AX					; Store FPU status word in AX
		SAHF						; Store AH into EFLAGS
		
		JBE		if_body_f2
		; Here  e > threshold
		MOV		EAX, 255
		MOV		[EDI+EBX], AL		; Set out[x][y] = 255
		JMP		endif_tag_f2
		if_body_f2:
		; Here e <= threshold
		XOR		EAX, EAX
		MOV		[EDI+EBX], AL		; Set out[x][y] = 0
		endif_tag_f2:

		INC		DWORD PTR [EBP - 8]	; y++
		MOV		EAX, [EBP - 8]		; EAX = y
		CMP		EAX, [EBP + 8]		; Compare y and height - 1
		JL		height_loop_f2
	INC		DWORD PTR [EBP - 4]	; x++
	MOV		EAX, [EBP - 4]		; EAX = x
	CMP		EAX, [EBP + 12]		; Compare x and width - 1
	JL		width_loop_f2
	
	; return 0
	XOR		EAX, EAX

exit_tag_f2:
	; Restore registers
	POPFD
	POP		EDI
	POP		ESI
	POP		EDX
	POP		EBX

	ADD		ESP, 28
	POP		EBP
	RET
sobel_detection ENDP




; 3. ----------------------------------------  THIRD FUNCTION ---------------------------------------- 
; --------------------------- Calculating the border pixels with replication -------------------------
; Input:
;	- arg1: integer @[EBP + 8] -- height of the bitmap file in pixels
;	- arg2: integer @[EBP + 12] -- width of the bitmap file in pixels
;	- arg3: byte 2D static array @[EBP + 16] -- the output array containing the edge detection annotations (pre border edit)
; Output:
;	- arg3: byte 2D static array @[EBP + 16] -- the output array containing the edge detection annotations (post border edit)
;	- returns: 0 on success, 1 on error
border_pixel_calculation PROC
	PUSH	EBP
	MOV		EBP, ESP

	; Save registers
	PUSH	EBX
	PUSH	ECX
	PUSH	EDX
	PUSH	ESI
	PUSH	EDI
	PUSHFD

	; Check for wrong input
	MOV		EAX, 1				; return 1 on error
	MOV		EDX, [EBP + 8]		; EDX = height
	CMP		EDX, 0
	JLE		exit_tag_f3			; height <= 0
	CMP		EDX, 2048
	JG		exit_tag_f3			; height > 2048
	MOV		EDX, [EBP + 12]		; EDX = width
	CMP		EDX, 0
	JLE		exit_tag_f3			; width <= 0
	CMP		EDX, 2048
	JG		exit_tag_f3			; width > 2048

	CLD

	MOV		EAX, [EBP + 8]		; EAX = height
	MOV		ECX, EAX			; ECX = height
	SHR		ECX, 4				; ECX = floor(height / 16)
	CMP		EAX, 2048
	JZ		avoid_memory_violation_f3
	; If the initial width is less than 2048 then we can tolarate 
	; moving another octuple of bytes to and from the XMM registers.
	; (in order to cover the leftover bytes in case that height % 16 != 0)
	INC		ECX
avoid_memory_violation_f3:
	; But if the initial width is exactly 2048, then height % 16 = 0 and if 
	; we were to fetch another octuple of bytes, then a memory violation would occur.

	MOV		EDI, [EBP + 16]		; EDI = &ee_image[0][0]
	MOV		ESI, EDI		
	ADD		ESI, 2048			; ESI = &ee_image[1][0]
	MOV		EBX, [EBP + 12]		; EBX = width
	DEC		EBX 				; EBX = width - 1
	SHL		EBX, 11				; EBX = 2048 * (width - 1), offset
height_loop_f3:
	MOVDQU 	XMM0, [ESI]				; XMM0 = ee_image[1][y : y+15]
	MOVDQU	XMM1, [ESI+EBX-4096]	; XMM1 = ee_image[width-2][y : y+15]
	MOVDQU	[EDI], XMM0				; ee_image[0][y : y+15] = XMM0
	MOVDQU	[EDI+EBX], XMM1			; ee_image[width-1][y : y+15] = XMM1
	ADD		ESI, 16					; y += 16
	ADD		EDI, 16					; Same as ESI and EDI keep track of y independently
	LOOP	height_loop_f3

	MOV		ECX, [EBP + 12]		; ECX = width
	MOV		EDI, [EBP + 16]		; EDI = &ee_image[0][0]
	MOV		ESI, EDI
	INC		ESI					; ESI = &ee_image[0][1]
	MOV		EBX, [EBP + 8]		; EBX = height
	DEC		EBX					; EBX = height - 1, offset
width_loop_f3:
	MOV		AL, [ESI]			; AL = ee_image[x][1]
	MOV		[EDI], AL			; ee_image[x][0] = AL
	MOV		AL, [ESI+EBX-2]		; AL = ee_image[x][height-2]
	MOV		[EDI+EBX], AL		; ee_image[x][height-1] = AL
	ADD		ESI, 2048			; x++
	ADD		EDI, 2048			; Same as ESI and EDI keep track of x independently
	LOOP	width_loop_f3	
	
	; return 0
	XOR		EAX, EAX

exit_tag_f3:
	; Restore registers
	POPFD
	POP		EDI
	POP		ESI
	POP		EDX
	POP		ECX
	POP		EBX
	
	POP		EBP
	RET
border_pixel_calculation ENDP

END