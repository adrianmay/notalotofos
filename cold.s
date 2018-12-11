%include "general.sh"
%include "made/cold.out.s.h"
%include "made/cold.in.s.h"
EXTERN Stack
EXTERN Pml4
EXTERN doSomethingInC
%define CODE_SEG     0x0008
%define DATA_SEG     0x0010

;Tidy this up...

%macro outserial 2
	mov al, %2
	mov dx, 0x3f8+%1
	out dx,al
%endmacro

%macro sayserial 1
	outserial 0, %1
%endmacro

%macro saynum 0
	add al, '0'
	mov dx, 0x3f8
	out dx, al
%endmacro

BITS 16 

ALIGN 8

SECTION .text

start:
	cli
;	sayserial 'A'
	mov ax, 0
	mov es, ax
	mov ds, ax
	mov ss, ax
	mov esp, Stack
	call EnableA20
	call RemapInterrupts
	call InitSerial
	call GetMemoryMap
	call MakePagesCoarse

	lidt [idt_ptr]                        ; Load a zero length IDT so that any NMI causes a triple fault.
	; Enter long mode.
	mov eax, 10100000b                ; Set the PAE and PGE bit.
	mov cr4, eax
	mov edi, Pml4
	mov edx, edi                      ; Point CR3 at the PML4.
	mov cr3, edx
	mov ecx, 0xC0000080               ; Read from the EFER MSR. 
	rdmsr    
	or eax, 0x00000100                ; Set the LME bit.
	wrmsr
	mov ebx, cr0                      ; Activate long mode -
	or ebx,0x80000001                 ; - by enabling paging and protection simultaneously.
	mov cr0, ebx                    
	lgdt [GDT64.Pointer]                ; Load GDT.Pointer defined below.
	jmp 8:LongMode             ; Load CS with 64 bit segment and flush the instruction cache

 
EnableA20:
  call    .a20wait
  mov     al,0xAD
  out     0x64,al

  call    .a20wait
  mov     al,0xD0
  out     0x64,al

  call    .a20wait2
  in      al,0x60
  push    eax

  call    .a20wait
  mov     al,0xD1
  out     0x64,al

  call    .a20wait
  pop     eax
  or      al,2
  out     0x60,al

  call    .a20wait
  mov     al,0xAE
  out     0x64,al

  call    .a20wait
  ret

.a20wait:
  in      al,0x64
  test    al,2
  jnz     .a20wait
  ret


.a20wait2:
  in      al,0x64
  test    al,1
  jz      .a20wait2
  ret

RemapInterrupts:
  mov al, 11h
  out 020h, al ;reset
  out 0A0h, al
  mov al, 20h
  out 021h, al
  mov al, 28h
  out 0A1h, al
  mov al, 4
  out 021h, al
  mov al, 2
  out 0A1h, al
  mov al, 1
  out 021h, al
  out 0A1h, al
  mov al, 0
  out 021h, al
  out 0A1h, al	

  ;100Hz clock
  mov al, 34h
  out 0x43, al
  mov al, 9Ch ; low byte and ...
  out 0x40, al
  mov al, 2eh ; ... high byte of reload value. Use 1 for fastest and 0 for slowest
  out 0x40, al
  ret

InitSerial:
	outserial 1,1      ;Disable interrupts
	outserial 3,0x80   ;Enable DLAB
	outserial 0,1      ;Fast
	outserial 1,0      ;Fast
	outserial 3,3      ;8N1
	outserial 2,0xc7   ;Enable FIFO
	outserial 4,0x0b   ;Enable IRQ, RTS/DSR set
	ret

MemoryMapSize:
	dw 0
MemoryMap: ;EXPORT
	times 5 dq 0,0,0
GetMemoryMap:
	mov edi, MemoryMap
	xor ebx, ebx		; ebx must be 0 to start
	xor bp, bp		; keep an entry count in bp
	mov edx, 0x0534D4150	; Place "SMAP" into edx
	mov eax, 1
	mov [es:edi + 20], eax	; force a valid ACPI 3.X entry
	mov eax, 0xe820
	mov ecx, 24		; ask for 24 bytes
	int 0x15
	jc short .no	; carry set on first call means "unsupported function"
	mov edx, 0x0534D4150	; Some BIOSes apparently trash this register?
	cmp eax, edx		; on success, eax must have been reset to "SMAP"
	jne short .no
	test ebx, ebx		; ebx = 0 implies list is only 1 entry long (worthless)
	je short .no
	jmp short .jmpin
.e820lp:
	mov eax,1
	mov [es:edi + 20], eax	; force a valid ACPI 3.X entry
	mov eax, 0xe820		; eax, ecx get trashed on every int 0x15 call
	mov ecx, 24		; ask for 24 bytes again
	int 0x15
	jc short .yes		; carry set means "end of list already reached"
	mov edx, 0x0534D4150	; repair potentially trashed register
.jmpin:
	jcxz .skipent		; skip any 0 length entries
	cmp cl, 20		; got a 24 byte ACPI 3.X response?
	jbe short .notext
	test byte [es:edi + 20], 1	; if so: is the "ignore this data" bit clear?
	je short .skipent
.notext:
	mov ecx, [es:edi + 8]	; get lower uint32_t of memory region length
	or ecx, [es:edi + 12]	; "or" it with upper uint32_t to test for zero
	jz .skipent		; if length uint64_t is 0, skip entry
	mov ecx, [es:edi + 16]	; get main mode
	cmp ecx, 1		; is it usable
	jnz .skipent	; only want usables
	inc bp			; got a good entry: ++count, move to next storage spot
	add di, 24
.skipent:
	test ebx, ebx		; if ebx resets to 0, list is complete
	jne short .e820lp
.yes:
	mov edi, MemoryMapSize
	mov [es:edi], bp	; store the entry count
	clc			; there is "jc" on end of list to this point, so the carry must be cleared
	ret
.no:
	stc			; "function unsupported" error exit
	ret

%define PAGE_PRESENT    (1 << 0)
%define PAGE_WRITE      (1 << 1)
%define PAGE_GIANT      (1 << 7)

MakePagesCoarse:
	mov di, Pml4
	mov ecx, 0x1000
	xor eax, eax
	cld
	rep stosd
	
	; One Pml4 entry pointing at Pml3
	mov di, Pml4
	lea eax, [es:di + 0x1000]         
	or eax, PAGE_PRESENT | PAGE_WRITE 
	mov [es:di], eax                 

	;Fill Pml3 with 1G pages
	lea di, [es:di + 0x1000]             
	mov eax, PAGE_PRESENT | PAGE_WRITE | PAGE_GIANT
	mov ecx, 0
.LoopPageTable:
	mov [es:di], eax
	add eax, 0x40000000
	add di, 8
	inc ecx
	cmp ecx, 4                 ; If we did all 512GiB, end.
	jb .LoopPageTable
	ret

MakePagesNoddy:
	;Zero 4096 dwords
	mov di, Pml4
	mov ecx, 0x1000
	xor eax, eax
	cld
	rep stosd

	mov di, Pml4
	; Build the Page Map Level 4.
	; es:di points to the Page Map Level 4 table.
	lea eax, [es:di + 0x1000]         ; Put the address of the Page Directory Pointer Table in to EAX.
	or eax, PAGE_PRESENT | PAGE_WRITE ; Or EAX with the flags - present flag, writable flag.
	mov [es:di], eax                  ; Store the value of EAX as the first PML4E.


	; Build the Page Directory Pointer Table.
	lea eax, [es:di + 0x2000]         ; Put the address of the Page Directory in to EAX.
	or eax, PAGE_PRESENT | PAGE_WRITE ; Or EAX with the flags - present flag, writable flag.
	mov [es:di + 0x1000], eax         ; Store the value of EAX as the first PDPTE.


	; Build the Page Directory.
	lea eax, [es:di + 0x3000]         ; Put the address of the Page Table in to EAX.
	or eax, PAGE_PRESENT | PAGE_WRITE ; Or EAX with the flags - present flag, writeable flag.
	mov [es:di + 0x2000], eax         ; Store to value of EAX as the first PDE.


	push di                           ; Save DI for the time being.
	lea di, [di + 0x3000]             ; Point DI to the page table.
	mov eax, PAGE_PRESENT | PAGE_WRITE    ; Move the flags into EAX - and point it to 0x0000.
 
 
    ; Build the Page Table.
.LoopPageTable:
	mov [es:di], eax
	add eax, 0x1000
	add di, 8
	cmp eax, 0x200000                 ; If we did all 2MiB, end.
	jb .LoopPageTable

	pop di                            ; Restore DI.
	ret

BITS 64

GDT64:
.Null:
    dq 0x0000000000000000             ; Null Descriptor - should be present.
.Code:
    dq 0x00209A0000000000             ; 64-bit code descriptor (exec/read).
    dq 0x0000920000000000             ; 64-bit data descriptor (read/write).
ALIGN 4
    dw 0                              ; Padding to make the "address of the GDT" field aligned on a 4-byte boundary
.Pointer:
    dw $ - GDT64 - 1                    ; 16-bit Size (Limit) of GDT.
    dd GDT64                              ; 32-bit Base Address of GDT. (CPU will zero extend to 64-bit)
 
;INTERRUPTS

%macro isr_frontline_pushdummy 1 
isr_head_%1:
  push QWORD 0x55
  push QWORD %1 ;room for rax
  xchg rax, [rsp]
  xchg rbx, [rsp+8]
  call isr_common
  pop rax
  pop rbx
  iretq
%endmacro

%macro isr_frontline_nopushdummy 1 
isr_head_%1:
  push QWORD %1 ;room for rax
  xchg rax, [rsp]
  xchg rbx, [rsp+8]
  call isr_common
  pop rax
  iretq
%endmacro

isr_common:
  ; acknowledge whichever PICs: 32-39 inclusive, just master (0x20,0x20), 40-47 also slave A0, 20
  cmp eax, 32
  jl .no_more_acks
  cmp eax,48
  jnl .no_more_acks
  cmp al, 40
  jl .ack_master
  push rax
  mov al, 020h
  out 0a0h, al
  pop rax
.ack_master:
  push rax
  mov al, 20h
  out 20h, al
  pop rax
.no_more_acks:    
  jmp [Handlers+rax*8]

Handlers:
  times 32 dq HandlerDefault
  dq HandlerNothing  ;32
  times 3 dq HandlerDefault
  dq HandlerSerial ;36
  times 10 dq HandlerDefault
  ;;dq DiskInt ;46
  times 216 dq HandlerDefault

HandlerNothing:
  ret

HandlerDefault:
  push rax
  mov al, 'I'
  call say
  pop rax
  call sayN100
  ret

HandlerSerial:
  call sayN100
  push rdx
.serialloop:
  mov dx, 0x3f8+2
  in al, dx
  test al, 1
  jnz .serialdone
  mov rdx, 0x3f8+0
  in al, dx
  ;mov rdx, 0x3f8+6
  ;in al, dx
  jmp .serialloop
.serialdone:  
  pop rdx
  ret

  ; These functions are what the IDT entries point at...

  %assign i 0

  %rep 8
  isr_frontline_pushdummy i    	;0-7
  %assign i i+1
  %endrep

  isr_frontline_nopushdummy i 	;8
  %assign i i+1
  isr_frontline_pushdummy i	;9
  %assign i i+1

  %rep 5
  isr_frontline_nopushdummy i	;10-14
  %assign i i+1
  %endrep

  isr_frontline_pushdummy i 	;15
  %assign i i+1
  isr_frontline_pushdummy i 	;16
  %assign i i+1
  isr_frontline_nopushdummy i 	;17
  %assign i i+1
  isr_frontline_pushdummy i	;18
  %assign i i+1
  isr_frontline_pushdummy i	;19
  %assign i i+1

  ; hardware interrputs to end
  %rep 236
  isr_frontline_pushdummy i	;20-255
  %assign i i+1
  %endrep


  ; The IDT...
;  SECTION .data

; Interrupt gate to ring 0...
%macro idt_entry_ring0 1
  dw isr_head_%1
  dw 8
  db 0
  db 08eh
  dw 0
  dq 0
%endmacro

ALIGN 16
idt:
  %assign i 0
  %rep 256
  idt_entry_ring0 i
  %assign i i+1 
  %endrep
idt_end: 

idt_ptr:
  dw idt_end - idt - 1; IDT limit
  dq idt ; start of IDT

EnableSse:
	mov rax, cr0
	and ax, 0xFFFB		;clear coprocessor emulation CR0.EM
	or ax, 0x2			;set coprocessor monitoring  CR0.MP
	mov cr0, rax
	mov rax, cr4
	or ax, 3 << 9		;set CR4.OSFXSR and CR4.OSXMMEXCPT at the same time
	mov cr4, rax
	ret

TestC:
	xorpd   xmm0, xmm0
	mov	rdi, 20
	mov	rsi, 2
	mov	rdx, Somewhere
	call 	doSomethingInC
DoneTestingC:	
	ret

LongMode:
	mov ax, DATA_SEG
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	mov rsp, Stack
	sti
	
	mov rsi, helloworld
	call sayString
	mov rcx, 4
	mov rax, 0x01234567
	call sayHex
	mov rax, 10
	call say
	call EnableSse
	call TestC
	jmp Nirv
	call PciFind
	call PciPrintFound
	call ReadDisk
;	call ShowDisk
	call MutateDisk
	call WriteDisk
Nirv:	
	hlt
	jmp Nirv
 
SECTION .data
helloworld:	
	db	'Hello, World!',10,0
Somewhere:	dq	0
align 32
SomeFloat:	dq	1.0

