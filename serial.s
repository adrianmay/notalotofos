%include "general.sh"
%include "made/serial.out.s.h"
%include "made/serial.in.s.h"
BITS 64
SECTION .text
say: 	;EXPORT	;expect char in al
	push rdx
	mov dx, 0x3fd
	push rax
.loop:	
	in al, dx
	and al, 0x20
	je .loop
	pop rax
	mov dx, 0x3f8
	out dx, al
	pop rdx
	ret

sayN100: ;EXPORT ;expect ah=0, al=val up to 100
	push rax
	push rbx
	mov bl,10
	idiv bl
	add al, '0'
	call say
	shr ax, 8
	add al, '0'
	call say
	mov al, ' '
	call say
	pop rbx
	pop rax
	ret

sayHex:	;EXPORT ;expect val in rax, bytes in rcx	
	push rax
	push rbx
	push rcx
	push rsi
	mov rsi, Chars
	shl rcx, 3
	mov rbx, rax
	ror rbx, cl
	jmp .nocomma
.loop:
	cmp rcx,0
	je .done
	test rcx, 31
	jne .nocomma
	push rax
	mov rax, '~'
	call say
	pop rax
.nocomma:	
	cmp rcx,0
	je .done
	rol rbx, 4
	mov rax, rbx
	and rax, 0xf
	mov rax, [rsi+rax]
	call say
	sub rcx,4
	jmp .loop
.done:	
	mov al, ' '
	call say
	pop rsi
	pop rcx
	pop rbx
	pop rax
	ret

sayString:	;EXPORT	;expect zero terminated string in rsi
	mov al, [rsi]
	cmp al, 0
	je .done
	call say
	inc rsi
	jmp sayString
.done:
	ret

SECTION .data
Chars:
	db '0123456789ABCDEF'

