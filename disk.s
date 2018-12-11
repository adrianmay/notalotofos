%include "general.sh"
%include "made/disk.out.s.h"
%include "made/disk.in.s.h"
BITS 64

BAR0	equ	0x1F0
BAR1	equ	0x3F6
BAR2	equ	0x170
BAR3	equ	0x376

%define ATA_REG_DATA	0x00
%define ATA_REG_ERROR	0x01
%define ATA_REG_FEATURES	0x01
%define ATA_REG_SECCOUNT0	0x02
%define ATA_REG_LBA0	0x03
%define ATA_REG_LBA1	0x04
%define ATA_REG_LBA2	0x05
%define ATA_REG_HDDEVSEL	0x06
%define ATA_REG_COMMAND	0x07
%define ATA_REG_STATUS	0x07
%define ATA_REG_SECCOUNT1	0x08
%define ATA_REG_LBA3	0x09
%define ATA_REG_LBA4	0x0A
%define ATA_REG_LBA5	0x0B
%define ATA_REG_CONTROL	0x0C
%define ATA_REG_ALTSTATUS	0x0C
%define ATA_REG_DEVADDRESS	0x0D
%define ATA_SR_BSY	0x80    
%define ATA_SR_DRDY	0x40    
%define ATA_SR_DF	0x20    
%define ATA_SR_DSC	0x10    
%define ATA_SR_DRQ	0x08    
%define ATA_SR_CORR	0x04    
%define ATA_SR_IDX	0x02    
%define ATA_SR_ERR	0x01    
%define ATA_CMD_READ_PIO	0x20
%define ATA_CMD_READ_PIO_EXT	0x24
%define ATA_CMD_READ_DMA	0xC8
%define ATA_CMD_READ_DMA_EXT	0x25
%define ATA_CMD_WRITE_PIO	0x30
%define ATA_CMD_WRITE_PIO_EXT	0x34
%define ATA_CMD_WRITE_DMA	0xCA
%define ATA_CMD_WRITE_DMA_EXT	0x35
%define ATA_CMD_CACHE_FLUSH	0xE7
%define ATA_CMD_CACHE_FLUSH_EXT	0xEA
%define ATA_CMD_PACKET	0xA0
%define ATA_CMD_IDENTIFY_PACKET	0xA1
%define ATA_CMD_IDENTIFY	0xEC

SECTION .data
align 8
PRDT:
	dd DiskBuffer
	dw 512
	dw 0x8000

SECTION .bss
DiskBuffer:
resb (512*DISKSECTORS) 

SECTION .text

%macro outb 2
	mov dx, %1
	mov al, %2
	out dx, al
%endmacro

%macro outd 2
	mov dx, %1
	mov eax, %2
	out dx, eax
%endmacro

%macro inb 1
	mov dx, %1
	in al, dx
%endmacro

ReadDisk:	;EXPORT
	outb (BAR1+2),2	;Polling
	outb (BAR0+ATA_REG_HDDEVSEL),0xE0
	outb (BAR0+ATA_REG_SECCOUNT0),DISKSECTORS
	outb (BAR0+ATA_REG_LBA0),0
	outb (BAR0+ATA_REG_LBA1),0
	outb (BAR0+ATA_REG_LBA2),0
	outb (BAR0+ATA_REG_COMMAND),ATA_CMD_READ_PIO
	mov rbx, DISKSECTORS
	mov rdi, DiskBuffer
.loop:	
	call WaitDisk
	mov rdx, BAR0
	mov rcx, 256
	rep insw 
	dec rbx
	jne .loop
	ret

WriteDisk:	;EXPORT
	outb (BAR1+2),2	;Polling
	outb (BAR0+ATA_REG_HDDEVSEL),0xE0
	outb (BAR0+ATA_REG_SECCOUNT0),DISKSECTORS
	outb (BAR0+ATA_REG_LBA0),0
	outb (BAR0+ATA_REG_LBA1),0
	outb (BAR0+ATA_REG_LBA2),0
	outb (BAR0+ATA_REG_COMMAND),ATA_CMD_WRITE_PIO
	mov rbx, DISKSECTORS
	mov rsi, DiskBuffer
.loop:	
	call WaitDisk
	mov rdx, BAR0
	mov rcx, 256
	rep outsw 
	dec rbx
	jne .loop
	outb (BAR0+ATA_REG_COMMAND),ATA_CMD_CACHE_FLUSH
	call WaitDisk
	ret

WaitDisk:
	inb (BAR1+2)
	inb (BAR1+2)
	inb (BAR1+2)
	inb (BAR1+2)
.loop:	inb (BAR0+ATA_REG_STATUS)
	and al, ATA_SR_BSY
	jnz .loop
	ret

ShowDisk:	;EXPORT
	mov rcx, 8
	mov rax, [DiskBuffer]
	call sayHex
	ret

MutateDisk:	;EXPORT
	mov rbx, DISKSECTORS
	sal rbx, 9
	sub rbx, 8
	add rbx, DiskBuffer
	mov rax, [rbx]
	add rax, [Ones]
	mov [rbx], rax
	ret

SECTION .data
Ones:	dq 	0x0101010101010101

