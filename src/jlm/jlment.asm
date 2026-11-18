
; jlment.asm - header of JAIxCORE.DLL

	.386
	.MODEL FLAT, stdcall
	option casemap:none

	include jlm.inc
	include winapi.inc

DLL_PROCESS_ATTACH equ 1
DLL_PROCESS_DETACH equ 0   

DEVICE_ID equ 3D34h

;--- these 4 settings must match those in jlmstor.asm
KQV86     equ 0
POLLV86   equ 0
IRQV86    equ 0
INT15V86  equ 1	;must be 1, 0 not impl.

externdef c ent_init:near
externdef c ent_dos:near
externdef c ent_poll:near
externdef c ent_irq:near
externdef c ent_api:near
externdef c ent_shutdown:near
externdef c ent_resume:near

FN_INIT         equ 0
FN_DOS          equ 1
FN_POLL         equ 2
FN_IRQ          equ 3
FN_API          equ 4
FN_SHUTDOWN     equ 5
FN_RESUME       equ 6

IRQ0   equ 1-POLLV86
IRQ1   equ 1-KQV86
IRQ12  equ 1-KQV86
IRQPM  equ 1-IRQV86
YIELD  equ 1	;call Yield instead of just pause

	.data

	public export ddb

ddb VxD_Desc_Block <0,0,DEVICE_ID,1,0,0,"JAIUSB",0, ctrlproc, v86_dispatch>

vectors label dword
if IRQ0 or IRQ1 or IRQ12 or IRQPM
	dd my_init
else
	dd ent_init
endif
	dd ent_dos
	dd ent_poll
	dd ent_irq
	dd ent_api
if IRQ0 or IRQ1 or IRQ12 or IRQPM
	dd my_shutdown
else
	dd ent_shutdown
endif
	dd ent_resume

if YIELD
dwInYield dd 0
endif

	.CODE

v86_dispatch proc

	@VMMCall Simulate_Far_Ret	;emulate a RETF in v86
	and [ebp].Client_Reg_Struc.Client_EFlags,not 1  ;clear Carry flag
	movzx eax, word ptr [ebp].Client_Reg_Struc.Client_EAX
	cmp ax, 16
	jz get_version
	cmp ax, FN_RESUME
	jbe is_valid
	or  [ebp].Client_Reg_Struc.Client_EFlags, 1  ;set Carry flag
	ret
get_version:
	mov word ptr [ebp].Client_Reg_Struc.Client_EAX, 0100h
	ret
is_valid:
	push [ebp].Client_Reg_Struc.Client_EBX
	call [eax*4+vectors]
	add esp, 4
	mov [ebp].Client_Reg_Struc.Client_EAX, eax
	ret
v86_dispatch endp

ctrlproc proc
	clc
	ret
ctrlproc endp

PageReserve proc c p1:dword, p2:dword, p3:dword
	push p3
	push p2
	push p1
	@VMMCall _PageReserve
	add esp,3*4
	ret
PageReserve endp

PageCommitPhys proc c p1:dword, p2:dword, p3:dword, p4:dword
	push p4
	push p3
	push p2
	push p1
	@VMMCall _PageCommitPhys
	add esp,4*4
	ret
PageCommitPhys endp

Yield proc c
if YIELD
	add dwInYield, 1
endif
	push ebx
	push ebp
	@VMMCall Get_Cur_VM_Handle
	mov ebp, [ebx].cb_s.CB_Client_Pointer
	@VMMCall Yield
	pop ebp
	pop ebx
if YIELD
	sub dwInYield, 1
endif
	ret
Yield endp

	.data

IRQS struct
intno  db ?	;int# or irq#
irq    db ?
type_  db ?
rsvd   db ?
cb     dd ?
oldvec dd ?
IRQS ends

cbprocs label dword
	dd cbirqproc
	dd cbppproc
	dd cbppproc

if IRQ0 or IRQ1 or IRQ12
specialcbs label dword
	dd ?
	dd ?
endspecialcbs equ $
endif

vecs IRQS IRQPM*8+IRQ0+IRQ1+IRQ12 dup (<>)
endvecs equ $

if IRQ0 or IRQ1 or IRQ12 or IRQPM
cb  dd 0
endif

	.code

if IRQPM

; unmask IRQ in PICs

unmask proc
	cmp ecx, 8
	jb m1
	in al, 0A1h
	push ecx
	sub ecx, 8
	btr eax, ecx
	pop ecx
	out 0A1h, al
	in al, 21h
	and al, not 4
	out 21h, al
	ret
m1:
	in al, 21h
	btr eax, ecx
	out 21h, al
	ret
unmask endp

cbirqproc proc uses edi
	mov edi, edx
	movzx eax, [edi].IRQS.irq
	push eax
	call ent_irq
	add esp,4
	cmp eax, 1
	jnz chain
	mov al, 20h
	cmp [edi].IRQS.irq, 8
	jb @F
	out 0A0h, al
@@:
	out 20h, al
	@VMMCall Simulate_Iret
	clc
	ret
chain:
	mov eax, [edi].IRQS.oldvec
	mov word ptr [ebp].Client_Reg_Struc.Client_EIP, ax
	shr eax, 16
	mov [ebp].Client_Reg_Struc.Client_CS, eax
	clc
	ret
cbirqproc endp

endif

kq_drain proto c

if IRQ0 or IRQ1 or IRQ12

cbppproc proc

	movzx eax, [edx].IRQS.type_
	mov eax, [eax*4-4+specialcbs]
	mov word ptr [ebp].Client_Reg_Struc.Client_EIP, ax
	shr eax, 16
	mov [ebp].Client_Reg_Struc.Client_CS, eax
	movzx ecx, word ptr [edx].IRQS.oldvec+2
	movzx edx, word ptr [edx].IRQS.oldvec+0
	@VMMCall Build_Int_Stack_Frame
	clc
	ret
cbppproc endp

 if IRQ0
cbtmrproc proc
  if YIELD
	cmp [dwInYield],0
	jnz @F
  endif
	push 0
	call ent_poll
	add esp, 4
@@:
	@VMMCall Simulate_Iret
	clc
	ret
cbtmrproc endp
 endif

 if IRQ1 or IRQ12
cbps2proc proc
	call kq_drain
	@VMMCall Simulate_Iret
	clc
	ret
cbps2proc endp
 endif

endif

if IRQ0 or IRQ1 or IRQ12

specialcb proc
 if IRQ0
	cmp [edi].IRQS.type_, 1		;timer cb
	jz istmr
 endif
 if IRQ1 or IRQ12
	cmp [edi].IRQS.type_, 2
	jz isps2
 endif
	clc
	ret
 if IRQ0
istmr:
	mov esi, offset cbtmrproc
	mov edx, 0
	@VMMCall Allocate_V86_Call_Back
	jc error
	mov specialcbs+0*4, eax
	ret
 endif
 if IRQ1 or IRQ12
isps2:
	mov esi, offset cbps2proc
	mov edx, 0
	@VMMCall Allocate_V86_Call_Back
	jc error
	mov specialcbs+1*4, eax
	ret
 endif
error:
	stc
    ret
specialcb endp

endif

if IRQ0 or IRQ1 or IRQ12 or IRQPM

my_init proc
	push [esp+4]
	call ent_init
	add esp, 4

	push esi
	push edi

	mov eax, [ebp].Client_Reg_Struc.Client_EBX
	mov esi, [eax].core_params.cb_lin
	mov cb, esi

	mov edi, offset vecs
 if IRQPM
	xor ecx, ecx
nextirq:
	bt [esi].wincb.irqmask, cx
	jnc skipirq
	mov [edi].IRQS.irq, cl	;store the irq
	lea eax, [ecx+8]
	cmp ecx, 8
	jb @F
	add eax, 70h-10h
@@:
	mov [edi].IRQS.intno, al
	mov [edi].IRQS.type_, 0
	add edi, sizeof IRQS
skipirq:
	inc ecx
	cmp ecx,16
	jb nextirq
 endif
 if IRQ0 or IRQ1 or IRQ12
	test [esi].wincb.opts, OPT_NOKBC
	jnz step2
  if IRQ0
	mov [edi].IRQS.intno, 8
	mov [edi].IRQS.type_, 1
	add edi, sizeof IRQS
  endif
  if IRQ1
	mov [edi].IRQS.intno, 9
	mov [edi].IRQS.irq, 1
	mov [edi].IRQS.type_, 2
	add edi, sizeof IRQS
  endif
  if IRQ12
	mov [edi].IRQS.intno, 74h
	mov [edi].IRQS.irq, 12
	mov [edi].IRQS.type_, 2
	add edi, sizeof IRQS
  endif
step2:
 endif
	push ebx
	mov ebx, edi
	mov edi, offset vecs
nextalloc:
	cmp edi, ebx
	jz allocdone
	movzx eax, [edi].IRQS.type_
	mov esi, [eax*4+cbprocs]
	mov edx, edi
	@VMMCall Allocate_V86_Call_Back
	jc failed
	mov [edi].IRQS.cb, eax
 if IRQ0 or IRQ1 or IRQ12
	call specialcb
	jc failed
 endif
	movzx eax, [edi].IRQS.intno
	@VMMCall Get_V86_Int_Vector
	mov word ptr [edi].IRQS.oldvec+0,dx
	mov word ptr [edi].IRQS.oldvec+2,cx
	add edi, sizeof IRQS
	jmp nextalloc
allocdone:
	mov edi, offset vecs
nextset:
	cmp edi, ebx
	jz setdone
	movzx edx, word ptr [edi].IRQS.cb+0
	movzx ecx, word ptr [edi].IRQS.cb+2
	movzx eax, [edi].IRQS.intno
	@VMMCall Set_V86_Int_Vector
	cmp [edi].IRQS.type_, 0
	jnz @F
	movzx ecx, [edi].IRQS.irq
	call unmask
@@:
	add edi, sizeof IRQS
	jmp nextset
setdone:
	pop ebx
	pop edi
	pop esi
	xor eax, eax
	ret
failed:
	call my_shutdown
	pop ebx
	pop edi
	pop esi
	mov eax, -1
	ret
my_init endp

my_shutdown proc
	cmp cb, 0
	jz done
	push 0
	call ent_shutdown
	add esp, 4
	push esi
	xor esi, esi
	xchg esi, cb
	or byte ptr [esi].wincb.flags, CBF_BUSY
	mov esi, offset vecs
nextitem:
	mov eax, [esi].IRQS.cb
	and eax, eax
	jz done1
	@VMMCall Free_V86_Call_Back
	mov eax, [esi].IRQS.oldvec
	or eax, eax
	jz @F
	mov dx, ax
	shr eax, 16
	mov ecx, eax
	movzx eax, [esi].IRQS.intno
	@VMMCall Set_V86_Int_Vector
@@:
	add esi, sizeof IRQS
	cmp esi, offset endvecs
	jb nextitem
done1:
 if IRQ0 or IRQ1 or IRQ12
	mov esi, offset specialcbs
nextsp:
	lodsd
	and eax, eax
	jz skipsp
	@VMMCall Free_V86_Call_Back
skipsp:
	cmp esi, offset endspecialcbs
	jnz nextsp
 endif
	pop esi
done:
	ret
my_shutdown endp

endif

install proc
	mov eax, 1
	ret
install endp

;--- since JAIUCORE had to replace Hook_V86_Int_Chain by
;--- Allocate_V86_Call_Back combined with Set_V86_Int_Vector,
;--- uninstall is possible only if none of the modified IVT vectors
;--- has been modified - which is rather unlikely.

uninstall proc uses esi
if IRQ0 or IRQ1 or IRQ12 or IRQPM
	mov esi, offset vecs
nextentry:
	cmp [esi].IRQS.cb, 0
	jz done
	movzx eax, [esi].IRQS.intno
	@VMMCall Get_V86_Int_Vector
	mov eax, ecx
	shl eax, 16
	mov ax, dx
	cmp eax, [esi].IRQS.cb
	jnz nouninst
	add esi, sizeof IRQS
	cmp esi, offset endvecs
	jnz nextentry
done:
	pushad
	call my_shutdown
	popad
endif
	mov eax,1
	ret
nouninst:
	xor eax, eax
	ret
uninstall endp

DllMain PROC stdcall hModule:dword, dwReason:dword, dwRes:dword

	mov eax, dwReason
	cmp eax, DLL_PROCESS_ATTACH
	jnz @F
	call install
	jmp exit
@@:
	cmp eax,DLL_PROCESS_DETACH
	jnz @F
	call uninstall
@@:
exit:
	ret
DllMain endp

	END DllMain
