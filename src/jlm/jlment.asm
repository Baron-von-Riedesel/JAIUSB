
; jlment.asm - header of JAIxCORE.DLL

	.386
	.MODEL FLAT, stdcall

	include jlm.inc

DLL_PROCESS_ATTACH equ 1
DLL_PROCESS_DETACH equ 0   

DEVICE_ID equ 3D34h

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

	.data

	public export ddb

ddb VxD_Desc_Block <0,0,DEVICE_ID,1,0,0,"JAIUSB",0, ctrlproc, v86_dispatch>

vectors label dword
	dd ent_init
	dd ent_dos
	dd ent_poll
	dd ent_irq
	dd ent_api
	dd ent_shutdown
	dd ent_resume

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

if 0
Yield proc c
	@VMMCall Yield
	ret
Yield endp
endif

install proc
	ret
install endp

uninstall proc
	ret
uninstall endp

DllMain PROC stdcall hModule:dword, dwReason:dword, dwRes:dword

	mov eax, dwReason
	cmp eax, DLL_PROCESS_ATTACH
	jnz @F
	push ebp
	call install
	pop ebp
	mov eax,1
	jmp exit
@@:
	cmp eax,DLL_PROCESS_DETACH
	jnz @F
	push ebp
	call uninstall
	pop ebp
	mov eax,1
@@:
exit:
	ret
DllMain endp

	END DllMain
