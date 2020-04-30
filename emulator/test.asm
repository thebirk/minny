start:
	ld r0, 0x1000
	ld r1, memcpy

	.hlt
	jmp .hlt


; Basic memcpy test example
; r0 - dst, r1 - src, r2 - bytes
memcpy:
	push r3

	ld r3, bytes
	jz end ; jump if zero flag is set
	ld r3, 0

	.loop: ; '.' means local label, actually named 'memcpy.loop'
	ld (r0), (r1)
	inc r0
	inc r1
	inc r3
	sub r3, bytes
	jnz .loop:

	end:
	pop r3
	ret