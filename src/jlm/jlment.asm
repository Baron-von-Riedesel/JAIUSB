
; jlment.asm - header of JAIxCORE.DLL

	.386
	.MODEL FLAT, stdcall
	option casemap:none

	include jlm.inc
	include winapi.inc

DLL_PROCESS_ATTACH equ 1
DLL_PROCESS_DETACH equ 0   

DEVICE_ID equ 3D34h

ifdef _DEBUG
CStr macro text:vararg
local sym
	.const
sym db text,0
	.code
	exitm <offset sym>
endm
kprintf proto fastcall :ptr, :vararg
@dprintf equ <invoke kprintf, >
else
@dprintf equ <;>
endif

;--- these settings must match those in jlmstor.asm
KQV86     equ 0
POLLV86   equ 0
IRQV86    equ 0
INT15V86  equ 1	;must be 1, 0 not impl.
I13BIOSV86 equ 0;1=handle disks mounted by BIOS in v86

DISKCHANGE equ 1

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

if IRQ0 or IRQ1 or IRQ12 or IRQPM or I13BIOSV86
cb  dd 0
endif

ife I13BIOSV86
wbm      winbiosmap <>
 if DISKCHANGE
bStat db -1
 endif
i13stat  db WIN_MAXBIOSDISKS dup (0)   ;last status, returned by int13, ah=
endif

	.code

if 1
plat_disk_change proc c idx:dword, stat:byte
	@dprintf CStr("plat_disk_change(idx=%d, stat=%u)",10), idx, stat
	mov eax, idx
	inc eax
	mov ecx, WIN_MAXBIOSDISKS
@@:
	mov edx, offset wbm.disk
	cmp al, [edx]
	jz found
	inc edx
	loop @B
	ret
found:
	sub edx, offset wbm.disk
	cmp stat,0
	jnz @F
	btr dword ptr bStat, edx
	ret
@@:
	bts dword ptr bStat, edx
	ret
plat_disk_change endp
endif

ife I13BIOSV86

int13 proc uses ebx esi edi
        @VMMCall Simulate_Iret
        @dprintf CStr("int13(ax=%X)",10), [ebp].Client_Reg_Struc.Client_EAX
        mov ah, byte ptr [ebp].Client_Reg_Struc.Client_EAX+1
        movzx esi, byte ptr [ebp].Client_Reg_Struc.Client_EDX
        and esi, 7Fh
        cmp ah, 02h
        je is_chs
        cmp ah, 03h
        je is_chs
        cmp ah, 42h
        je is_ext
        cmp ah, 43h
        je is_ext
        cmp ah, 08h
        je is_geom
        cmp ah, 15h
        je is_type
if 0;DISKCHANGE
        cmp ah, 16h
        je is_querychange
endif
        cmp ah, 41h
        je is_edd
        cmp ah, 48h
        je is_params
        cmp ah, 01h
        je is_status
        mov edi, offset okfns
        mov ecx, okfns_n
@@:     cmp ah, [edi]
        je is_ok
        inc edi
        loop @B
        mov al, 01h                     ; invalid function
        jmp is_err

;--- AH=01: return last status
is_status:
        mov al, [i13stat+esi]
        test al, al
        jnz is_err
is_ok:  xor al, al
is_err:  ; AL = status
        mov [i13stat+esi], al
        mov byte ptr [ebp].Client_Reg_Struc.Client_EAX+1, al
        and [ebp].Client_Reg_Struc.Client_EFlags, not 1	; CF=0
        test al, al
        jz is_ret
        or  [ebp].Client_Reg_Struc.Client_EFlags, 1
is_ret:
        ret

;--- AH=02/03
;--- in: AL sectors
;---     CH cylinder low
;---     CL bits 7-6 cylinder high, 5-0 sector
;---     DH head
is_chs:
        mov edi, esi
        shl edi, 2
        mov eax, cb
        lea edi, [edi+eax+wincb.biosgeom]
        movzx eax, byte ptr [ebp].Client_Reg_Struc.Client_ECX
        shl eax, 2
        ; EAX = cylinder (bits 9-8 from CL 7-6)
        mov al, byte ptr [ebp].Client_Reg_Struc.Client_ECX+1
        and eax, 3FFh
        movzx ebx, [edi].wingeom.heads
        mul ebx                         ; * heads
        movzx ebx, byte ptr [ebp].Client_Reg_Struc.Client_EDX+1
        add eax, ebx
        movzx ebx, [edi].wingeom.spt
        mul ebx                         ; * sectors per track
        movzx ebx, byte ptr [ebp].Client_Reg_Struc.Client_ECX
        and bl, 3Fh
        jz is_badsec
        dec ebx
        add eax, ebx
        movzx ecx, byte ptr [ebp].Client_Reg_Struc.Client_EAX
        push ecx                        ;[esp].SecsLeft
        pushd 0                         ;[esp].lba high
        push eax                        ;[esp].lba low
        movzx eax, word ptr [ebp].Client_Reg_Struc.Client_ES
        shl eax, 16
        mov ax, word ptr [ebp].Client_Reg_Struc.Client_EBX
        push eax                        ;[esp].lpBuffer
        call i13xfer
        jc is_err
        mov byte ptr [ebp].Client_Reg_Struc.Client_EAX, cl     ; AL=sectors read/write
        jmp is_ok
is_badsec:
        mov al, 04h
        jmp is_err

DAP struct
bSize       db ?    ;+0 size of structure
bRes        db ?    ;+1 reserved
wNumSec     dw ?    ;+2 sectors to transfer
dwBuffer    dd ?    ;+4 transfer buffer SSSS:OOOO (or -1)
union
dqStartSec  dq ?    ;+8
struct
dwStartLow  dd ?    ;+8 start sector low
dwStartHigh dd ?    ;+12 start sector high
ends
ends
;dqAddr     dq ?    ;+16 EDD 3.0: 64bit flat transfer buffer address if dwBuffer is FFFF:FFFF
DAP ends

;--- AH=42h/43h
;--- in: DS:SI -> packet

is_ext:
        movzx ebx, word ptr [ebp].Client_Reg_Struc.Client_ESI
        movzx eax, word ptr [ebp].Client_Reg_Struc.Client_DS
        shl eax, 4
        add ebx, eax
        cmp [ebx].DAP.dwBuffer, -1           ; 64-bit flat buffer: not supported
        je is_inval
        movzx eax, [ebx].DAP.wNumSec
        push eax                             ;[esp].SecsLeft
        push [ebx].DAP.dwStartHigh           ;[esp].lba high
        push [ebx].DAP.dwStartLow            ;[esp].lba low
        push [ebx].DAP.dwBuffer              ;[esp].lpBuffer
        @dprintf CStr("jlment: AH=42/43, disk=%u start=%u secs=%u buffer=%X",10), esi, [ebx].DAP.dwStartLow, eax, [ebx].DAP.dwBuffer
        call i13xfer
        jc is_err
        mov [ebx].DAP.wNumSec, cx
        jmp is_ok
is_inval: mov al, 01h
        jmp is_err

;--- AH=08h
;--- the BIOS geometry recorded at the start
;--- out: CL= 0-5: max sector#; 6-7: max cyl# [8-9]
;---      CH= max cyl# bits [0-7]
;---      DL= #drives
;---      DH= max head#
;---      BL= drive type (0-6 floppies); floppies only?

is_geom:  mov edi, esi
        @dprintf CStr("jlment: AH=08, disk=%u",10), esi
        shl edi, 2
        mov eax, cb
        lea edi, [edi+eax+wincb.biosgeom]
        mov cx, [edi].wingeom.cyls  ; cylinders
        dec cx
        xchg cl, ch
        ror cl, 2
        and cl, 0C0h
        or cl, [edi].wingeom.spt
        mov word ptr [ebp].Client_Reg_Struc.Client_ECX, cx
        mov dh, [edi].wingeom.heads
        dec dh
        mov dl, [eax].wincb.nbios
        mov word ptr [ebp].Client_Reg_Struc.Client_EDX, dx
        mov byte ptr [ebp].Client_Reg_Struc.Client_EAX, 0
        jmp is_ok

;--- AH=15h
;--- out: AH=disk type
;---      CX:DX=sectors

is_type: mov edi, esi
        shl edi, 2
        mov ax, word ptr [wbm.sectors+edi+2]
        mov word ptr [ebp].Client_Reg_Struc.Client_ECX, ax          ; CX:DX sectors
        mov ax, word ptr [wbm.sectors+edi+0]
        mov word ptr [ebp].Client_Reg_Struc.Client_EDX, ax
        mov [i13stat+esi], 0
if 0;DISKCHANGE
        mov byte ptr [ebp].Client_Reg_Struc.Client_EAX+1, 2         ; AH = 2: removable with change line support
else
        mov byte ptr [ebp].Client_Reg_Struc.Client_EAX+1, 3         ; AH = 3: fixed disk
endif
        and [ebp].Client_Reg_Struc.Client_EFlags, not 1
        jmp is_ret

if 0;DISKCHANGE

;--- AH=16h
;--- out: AH=0, NC : no change
;---      AH=6, C : change

is_querychange:
        @dprintf CStr("jlment: AH=16h, disk=%u",10), esi
        btr dword ptr bUnplugged, esi
        mov al, 6
        jc is_err
        jmp is_ok
endif

;--- AH=41h
;--- BX=55AAh
;--- out:
;--- AH=major version of extension
;--- CX=API bitmap support subset
;---  b0: 42h-44h
;---  b1: removable functions (45h/46h)
;---  b2: EDD (48h,4Eh)

is_edd:   
        cmp word ptr [ebp].Client_Reg_Struc.Client_EBX, 55AAh
        jne is_inval
        mov word ptr [ebp].Client_Reg_Struc.Client_EBX, 0AA55h
        mov word ptr [ebp].Client_Reg_Struc.Client_ECX, 1 or 4        ; 42,43,48
        mov [i13stat+esi], 0
        mov byte ptr [ebp].Client_Reg_Struc.Client_EAX+1, 21h         ; AH: EDD 1.1
        and [ebp].Client_Reg_Struc.Client_EFlags, not 1
        jmp is_ret

EDD struct ;v1.0
wSize	dw ?	;+0
wFlags	dw ?	;+2
dwCyl	dd ?	;+4
dwHeads	dd ?	;+8
dwSecs	dd ?	;+12
dwNSecsL dd ?	;+16
dwNSecsH dd ?	;+20
wSecSiz	dw ?	;+24
EDD ends

EDDF_DMATP      equ 000001b  ; DMA handled transparently
EDDF_GEOMVALID  equ 000010b
EDDF_REMOVABLE  equ 000100b
EDDF_VERIFY     equ 001000b
EDDF_CHANGELINE equ 010000b  ; if bit 2=1
EDDF_LOCKABLE   equ 100000b  ; if bit 2=1

;--- AH=48h
;--- in: DS:SI -> EDD

is_params:
        @dprintf CStr("jlment: AH=48h, disk=%u",10), esi
        movzx ebx, word ptr [ebp].Client_Reg_Struc.Client_ESI
        movzx eax, word ptr [ebp].Client_Reg_Struc.Client_DS
        shl eax, 4
        add ebx, eax
        cmp [ebx].EDD.wSize, sizeof EDD
        jb is_inval
        mov [ebx].EDD.wSize, sizeof EDD
        mov [ebx].EDD.wFlags, EDDF_GEOMVALID or EDDF_REMOVABLE
        mov edi, esi
        shl edi, 2
        mov eax, cb
        lea edi, [edi+eax+wincb.biosgeom]
        movzx eax, [edi].wingeom.cyls
        mov [ebx].EDD.dwCyl, eax
        movzx eax, [edi].wingeom.heads
        mov [ebx].EDD.dwHeads, eax
        movzx eax, [edi].wingeom.spt
        mov [ebx].EDD.dwSecs, eax
        mov eax, [wbm.sectors+esi*4]
        mov [ebx].EDD.dwNSecsL, eax
        mov eax, [wbm.sectorshi+esi*4]
        mov [ebx].EDD.dwNSecsH, eax
        mov [ebx].EDD.wSecSiz, 512
        jmp is_ok
int13 endp

	.data

okfns    db 00h, 04h, 09h, 0Ch, 0Dh, 10h, 11h, 14h, 44h, 47h
okfns_n  equ $ - okfns

	.code

; transfer [bp].SecsLeft sectors at [bp].lba to/from [bp].lpBuffer;
; out: NC = ok, then CX = sectors
;       C = error, then AL = error code
; EBX and ESI must be preserved

I13FR struc
         dd ?    ;EBX
i13req   winapireq <>
         dd ?    ;return addr
lpBuffer dd ?    ;real mode addr
lba      dd ?,?
SecsLeft dd ?
I13FR ends

i13xfer proc
        sub esp, sizeof winapireq
        push ebx
if 1
        bt dword ptr bStat, esi
        jnc is_err
endif
        xor ecx, ecx
is_lp:  cmp [esp].I13FR.SecsLeft, 0
        je is_done
        ; normalize [bp].lpBuffer (the core reads at most 64K - 16 at a time)
        mov ax, word ptr [esp].I13FR.lpBuffer+0
        mov dx, word ptr [esp].I13FR.lpBuffer+2
        mov bx, ax
        shr ax, 4
        add dx, ax
        shl edx, 16
        and bx, 0Fh
        mov dx, bx     ; EDX=normalized address

        movzx ebx, byte ptr [ebp].Client_Reg_Struc.Client_EDX
        and ebx, 7Fh
        movzx eax, [wbm.disk+ebx]  ; this is the 1-based index for disks[] in blk.c
        dec eax
        test [ebp].Client_Reg_Struc.Client_EAX+1, 1   ;02/03/42/43
        je is_rd
        or eax, 80000000h
is_rd:  mov [esp].I13FR.i13req.fn, WINF_RAWIO
        mov [esp].I13FR.i13req.status, 0FFFFh
        mov [esp].I13FR.i13req.arg0, eax
        mov eax, [esp].I13FR.lba+0
        mov [esp].I13FR.i13req.arg1, eax
        mov eax, [esp].I13FR.lba+4
        mov [esp].I13FR.i13req.arg2, eax
        mov eax, [esp].I13FR.SecsLeft
        cmp eax, 127
        jbe is_n
        mov eax, 127
is_n:   shl eax, 9
        mov [esp].I13FR.i13req.buflen, eax 
        mov [esp].I13FR.i13req.retlen, 0
        mov [esp].I13FR.i13req.buf, edx        ; buf seg:off

; the request i13req to the core: the DOS core, or the VxD while Windows runs

        lea ebx, [esp].I13FR.i13req
        push ebx
        call ent_api
        add esp, 4

        cmp [esp].I13FR.i13req.status, 0
        jne is_ioerr
        mov eax, [esp].I13FR.i13req.retlen     ; bytes done
        shr eax, 9
        jz is_ioerr
        add ecx, eax
        sub [esp].I13FR.SecsLeft, eax
        add [esp].I13FR.lba+0, eax
        adc [esp].I13FR.lba+4, 0
        shl ax, 5                       ; sectors -> paragraphs
        add word ptr [esp].I13FR.lpBuffer+2, ax
        jmp is_lp
is_ioerr:
        mov al,080h                     ; timeout (drive not ready)
        cmp byte ptr [esp].I13FR.i13req.status, WINE_NODEV
        jz is_x
is_err:        
        mov al, 04h                     ; sector not found / read error
        test [ebp].Client_Reg_Struc.Client_EAX+1, 1          ; read or write?
        je is_x
        mov al, 0CCh                    ; write fault
is_x:
        stc
is_done:
        pop ebx
        lea esp, [esp+sizeof winapireq]
        ret 4*4  ;skip lpBuffer, lba and SecsLeft
i13xfer endp

api_biosmap proto c :ptr

;--- get bios map and set cb.kbcstat

get_biosmap proc uses esi
        invoke api_biosmap, addr wbm
        cmp eax, WINE_OK
        jne is_nobm
        @dprintf CStr("get_biosmap: disks=%u %u %u %u %u %u %u %u",10), wbm.disk, wbm.disk+1, wbm.disk+2, wbm.disk+3,
        	wbm.disk+4, wbm.disk+5, wbm.disk+6, wbm.disk+7
        xor esi, esi
        xor al,al
is_ci:  cmp [wbm.disk+esi], 0
        je is_hki13
        bts eax, esi
is_hki13:
        inc esi
        cmp esi, WIN_MAXBIOSDISKS
        jb is_ci
        and al, al
        jz is_nobm
        mov edx, cb
        mov [edx].wincb.kbcstat, al     ;cb.kbcstat misused
        ret
is_nobm:
        stc
        ret
get_biosmap endp
endif

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

ife I13BIOSV86
	call get_biosmap
	jc @F
	mov esi, offset int13
	mov edx, 0
	@VMMCall Allocate_V86_Call_Back
	jc failed
	mov edx, cb
	mov [edx].wincb.vxd_entry, eax	  ;vxd_entry misused
@@:
endif

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
