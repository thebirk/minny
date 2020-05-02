%offset 0 ; The offset the code is expected to be loaded from, all subsequent labels will be calculated according to this
; %include "other.inc"
%define IVT_BASE  0x1000
%define STACK_TOP 0xFF00

mov r0, 0
mov [r0], 0xDEAD ; Just in case we ever read a null pointer, it will be "garbage"
jsr setup_ivt
jmp start

; Macros would be cool
; Not textual, .local labels only exists within the macro
; %macro macro_add a b 
; 	mov r0, a          
; 	mov r1, b          
; 	add r0, r1         
; %endmacro            

ivt_stub:
	reti

int_0_entry:
	; Save the registers we use
	push r0

	; Do some work
	mov r2, 0z10 ; Dozenal support
	mov r0, 0o10 ; octal support
	shl r0, 4

	; Restore registered we used
	pop r0
	reti ; handles restoration of flags(r7), to-be-implemented!!

setup_ivt:
	mov r0, IVT_BASE
	mov [r0], int_0_entry
	
	mov r0, IVT_BASE+2
	mov r1, 254
.loop:
	add r0, 0b10
	mov [r0], ivt_stub
	dec r1
	jnz .loop

	ret

string:     %ascii "Hello, world!"
string_len: %db 13

start:
	mov sp, STACK_TOP ; All the stack space!

	mov r0, 0x0F00
	mov r1, string
	mov r2, [string_len]
	jsr memcpy

.end:
	hlt
	jmp end


; memcpy - r0 dst, r1 src, r2 bytes
memcpy:
.loop:
	mov [r0], [r1]
	inc r0
	inc r1

	dec r2
	jz .end
	jmp .loop
.end:
	ret

calling_test:
	push 4
	jsr stack_calling_test
	pop                     ; Pops a word by default

	; r0 should be 8
	ret

; stack calling test; 1 arg, r0 holds the return value
stack_calling_test:
	push sp ; save stack pointer

	push r1 ; don't clobber r1

	pop r0 ; pop arg
	mul r0, 2
	pop r1

	pop sp ; restore stack
	ret