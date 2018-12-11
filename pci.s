%include "general.sh"
%include "made/pci.out.s.h"
%include "made/pci.in.s.h"
BITS 64
SECTION .text

%define PCI_C 0xCF8
%define PCI_D 0xCFC
%define PCI_SIZE 0x100
%define PCI_FIND_SLOTS 4


%macro PCI_READ 1 ;expects base in ecx and offset as parameter
	mov eax, ecx 
	add eax, %1
	mov  dx, PCI_C
	out  dx, eax 
	mov  dx, PCI_D
	in  eax, dx
%endmacro

PciReadAll:		;expects base in ecx and dest in R8
	mov rbx, 0	;counts through offsets
.loop:	
	PCI_READ ebx
	mov [R8+rbx], eax
	add rbx, 4
	cmp rbx, 0x100
	jle .loop
	mov [R8+0x38], ecx	;the base address overwrites some reserved field
	add R8, rbx
	ret

PciFind:	;EXPORT
	mov R8, PciSearchResults
	mov R9, PciSearchResultsEnd
	; Top bit enables, middle is bus and slot:function, low byte is register
	mov ecx, 0x80000000
.loop:
	; read 0th register
	PCI_READ 0 ;Vendor
	mov ebp, eax 
	PCI_READ 0x40 ;Subsystem
	mov esi, eax 
	PCI_READ 8 ;Class
	mov ebx, eax 
	and eax, 0xff000000
	cmp eax, 0x01000000 ; I just care about disks right now
	jne .irrel
	;mov eax, ebp
	;and eax, 0x0000ffff
	;cmp eax, 0x00001AF4
	;jne .irrel
.relevant:	
	call PciReadAll
	cmp R8, R9
	je .done
.irrel:
	; next slot
	add ecx, 0x100
	cmp ecx, 0x80ffff00
	jne .loop
.done:
	sub R8, PciSearchResults
	shr R8, 8
	mov [PciSearchResultsCount], R8
	ret

%macro sayanother 1
	mov eax, [PciSearchResults+rbx]
	call sayHex
	mov al, %1
	call say 
	add rbx, 4
%endmacro

PciPrintFound:	;EXPORT
	mov rcx, 4 ; bytes to print per call to sayHex
	mov rdx, [PciSearchResultsCount]
	shl rdx, 8	;total size of memory to print
	mov rbx, 0
.loop:	
	cmp rbx, rdx
	je .done

	sayanother ' '
	sayanother ' '
	sayanother ' '
	sayanother ' '
	sayanother ' '
	sayanother ' '
	sayanother ' '
	sayanother 0x0A

	jmp .loop
.done:
	ret


SECTION .data

PciSearchResultsCount:
	dq 0
PciSearchResults:
	times 0x100*PCI_FIND_SLOTS dq 0
PciSearchResultsEnd:

