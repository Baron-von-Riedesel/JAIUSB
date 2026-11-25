; jlmstor.asm - JAIUSB.SYS: DOS block device driver front end of the
; 32-bit JLM JAIUCORE.DLL
;
; Resident part: device header, strategy/interrupt, control block (CB)
;
; Build: jwasm -mz -D?MZ -DJLM -DPKG_USB -FoJAIUSB.SYS jlmstor.asm

;--- segment definitions BEFORE .model to allow another alignment setting
_TEXT segment para public 'CODE'  ; resident code
_TEXT ends
_RDATA segment para public 'CODE' ; resident data
_RDATA ends
ifdef _DEBUG
_DStrings segment byte public 'CODE' ; resident debug strings
_DStrings ends
endif
_ITEXT segment para public 'CODE' ; non-resident code
resident_end label byte
_ITEXT ends
_DATA segment dword public 'DATA' ; non-resident data
_DATA ends

	.model tiny
	option dotname
	option casemap:none
	.386

;--- these 5 settings must match those in jlment.asm!
KQV86    equ 0	;1=process kbd queue in v86-mode (irq 1/12 handler)
POLLV86  equ 0	;1=poll in v86-mode, 0=poll in PL0
IRQV86   equ 0	;1=handle USB interrupts in v86-mode
INT15V86 equ 1	;1=handle int 15h, ah=C2h in v86-mode, 0=not impl yet!
I13BIOSV86 equ 0;1=take over disks mounted by BIOS

WINAWARE equ 0	;1=check Win3/Win9x startup/exit and support int 33h
WIN30    equ 0	;1=support for Win 3.0 DOSX
?STKRQ   equ 0	;1=stack switch on DOS request (no switch if stack's in use)
?STKIRQ  equ 0	;1=stack switch on IRQs (disables reentrancy)
DEFERRED equ 0	;1=defer IRQs if status is unsafe
TPMODE   equ 0	;1=support touchpad mode for irq 12
PROTI13  equ 0	;1=protect int 13h

MODDPB   equ 0	;1=modify device driver header in DPB for BIOS disks [untested]
MODDDT   equ 0	;1=modify dos disk table

ifdef PKG_USB
WIN_USB equ <>	;needed by winapi.inc
endif
	include winapi.inc

ifdef PKG_USB
DRVNAME    equ  'JAIUSB'
HDRNAME    equ  'JAIUSB '
BANNER     equ  'JAIUSB 1.2 - USB driver for DOS with Jemm'
COREFILE   equ  'JAIUCORE.DLL'
VXDFILE    equ  'JAIUSB.386'
DOSACTIVE  equ  'USB active'
;MPLEXID    equ 0D4h
DEFSLOTS   equ 2
CORE_POOL  equ 3584 * 1024             ; camera frames and their isochronous buffers (core window: 4 MB)
elseifdef PKG_AUDIO ; pretty useless for DOS since no port trapping
DRVNAME    equ  'JAIAUDIO'
BANNER     equ  'JAIAUDIO 1.2 - HD Audio / AC97 sound driver'
COREFILE   equ  'JAIACORE.DLL'
VXDFILE    equ  'JAIAUDIO.386'
DOSACTIVE  equ  'sound active in DOS / standard mode'
;MPLEXID    equ 0D5h
DEFSLOTS   equ 0
CORE_POOL  equ 1536 * 1024
else
PKG_DISK   equ <>
DRVNAME    equ  'JAIDISK'
HDRNAME    equ  'JAIDISK'
BANNER     equ  'JAIDISK 1.2 - IDE/AHCI/NVMe disk driver for DOS'
COREFILE   equ  'JAIDCORE.DLL'
VXDFILE    equ  'JAIDISK.386'
DOSACTIVE  equ  'active'
;MPLEXID    equ 0D3h
DEFSLOTS   equ 0
CORE_POOL  equ 1536 * 1024
endif

DDT struct	;DOS disk table
pNext    dd ?	;+0 far16 format
bPhysU   db ?	;+4 physical unit (80h=hd0, ... )
bLogU    db ?	;+5 logical unit (0=A:, ... )
;--- BPB
bps      dw ?	;+6 bytes/sector
spc      db ?	;+8 sectors/cluster
rsvdsec  dw ?	;+9 reserved sectors
nFats    db ?	;+11 number of FATs
nrootdir dw ?	;+12 number of root dir entries (0 for FAT32)
nSectors dw ?	;+14 number of sectors (FAT12)
md       db ?	;+16 media descriptor
secfat   dw ?	;+17 sectors/fat
sectrk   dw ?	;+19 sectors/track
heads    dw ?	;+21 heads
hidden   dd ?	;+23 hidden sectors
;...
DDT ends


FN_INIT         equ 0
FN_DOS          equ 1
FN_POLL         equ 2
FN_IRQ          equ 3
FN_API          equ 4
FN_SHUTDOWN     equ 5
FN_RESUME       equ 6
FN_FILEDONE     equ 7

@idata macro
ifdef ?MZ
	.data
else
	.code _ITEXT
endif
endm

	.code
; ---------------------------------------------------------------------------
; device header
hdr     dd -1
ifdef PKG_AUDIO
        dw 8000h                ; character device
        dw strategy
        dw interrupt
hdr_units:
        db 'WINAUD$ '
else
        dw 08C2h                ; block, 32-bit sectors, generic IOCTL, IOCTL query, removable
        dw strategy
        dw interrupt
hdr_units db 1
        db HDRNAME
endif

	.code _RDATA
; ---------------------------------------------------------------------------
; resident data
reqptr          dd 0	;DOS request header

;--- oldvecs must match order of hooks
OVENT = 0
@DefOV macro name_
	dd 0
name_ equ OVENT
OVENT = OVENT+1
endm

oldvecs label dword
ifdef PKG_USB
 if POLLV86
	@DefOV OLD08
	@DefOV OLD28
 endif
 if KQV86
	@DefOV OLD09
 endif
 if TPMODE or KQV86
	@DefOV OLD74
 endif
 if INT15V86
	@DefOV OLD15
 endif
 if PROTI13
	@DefOV OLD13
 endif
	@DefOV OLD2F
else
	@DefOV OLD08
	@DefOV OLD28
	@DefOV OLD13
 ifdef PKG_DISK
	@DefOV OLD13d
 endif
	@DefOV OLD2F
endif

if IRQV86
oldirq          dd 16 dup(0)
irqchain        dd 0	;core's return value for FN_IRQ
endif
jlmentry        dd 0
if KQV86
pkq_drain       dw offset kq_drain
endif
if WINAWARE
handover        db 0	; Windows enhanced mode owns the hardware
endif
;dos_usb         db 0	;USB in DOS? Always active!
;mplex           db WIN_MPLEX
;tickdiv         db 0	;

if WINAWARE
; INT 33h mouse driver state (the standard DOS mouse API, used by DOS programs and by the
; "Microsoft Mouse" driver of Windows 1.0x / 2.x). Position is tracked from the USB mouse
; mailbox the core fills; the resident provider needs no hook inside Windows.
m33_on          db 0            ; INT 33h provider installed
old33           dd 0
m33_x           dw 320
m33_y           dw 100
m33_btn         db 0
m33_lastbtn     db 0
m33_show        dw 0FFFFh       ; cursor visibility count, < 0 = hidden
m33_xmin        dw 0
m33_xmax        dw 639
m33_ymin        dw 0
m33_ymax        dw 199
m33_mickx       dw 0            ; motion counters for function 0Bh
m33_micky       dw 0
m33_pcnt        dw 0, 0, 0      ; button press counts
m33_rcnt        dw 0, 0, 0      ; button release counts
m33_px          dw 0, 0, 0      ; cursor x/y at the last press / release of each button
m33_py          dw 0, 0, 0
m33_rx          dw 0, 0, 0
m33_ry          dw 0, 0, 0
m33_hand        dd 0            ; function 0Ch event handler
m33_mask        dw 0
m33_wheel       db 0            ; accumulated wheel counter (CuteMouse API)
m33_wmode       db 0            ; a client enabled the wheel API (function 11h)
endif

if WINAWARE
; Win386 startup information structure
sis             db 3, 0
sis_next        dd 0
sis_path        dd 0
sis_ref         dd 0
sis_inst        dd 0
endif
                align 16
cb              wincb <>
; cbx must follow cb: the PS/2 touchpad's bytes caught on IRQ 12 for the
; core, and the packets the core makes for the pointing device BIOS callback of the DOS
; mouse driver (no 8042 round trip while the touchpad speaks its own protocol)
cbx             wincbx <>

	align 4

ifdef PKG_DISK
old4b           dd 0
vds_ret         dd 0
vds_active      db 0
ebda_saved      db 0
ebda_buf        db 6Ch dup (0)
endif ;PKG_DISK

if DEFERRED
irq_deferred    dw 0            ; IRQs masked until the next safe poll
endif
if PROTI13
in13            db 0            ; nesting of BIOS disk calls
endif
if TPMODE or POLLV86
auxdeliv        db 0
endif
if ?STKIRQ
irq_onstk       db 0
endif
if ?STKRQ
rq_onstk        db 0
endif
                align 4
if DEFERRED or TPMODE
indos_ptr       dd 0            ; DOS InDOS flag (critical error flag at -1)
endif
if ?STKRQ
rq_stack        db 1024 dup (0)
rq_stack_top  equ $
rq_sp           dw 0
rq_ss           dw 0
endif
if ?STKIRQ
irq_stack       db 1024 dup (0)
irq_stack_top equ $
irq_sp          dw 0
irq_ss          dw 0
endif

	.code
; ---------------------------------------------------------------------------
strategy:
        mov word ptr [cs:reqptr+0], bx
        mov word ptr [cs:reqptr+2], es
        retf

ifdef _DEBUG
DGROUP group _DStrings
@dprintf equ <invoke dprintf, >
CStr macro text:vararg
local sym
_DStrings segment
sym db text,0
_DStrings ends
	exitm <offset sym>
endm
        include dprintf.inc
else
@dprintf equ <;>
endif

RP struct
RPHLen	db ?	;+0 Header byte count.
RPSubU	db ?	;+1 Subunit number.
RPOp	db ?	;+2 Opcode.
RPStat	dw ?	;+3 Status word.
		db 8 dup (?)	;(Unused by us).
RPUnit	db ?	;+13 Number of units found.
RPLen	dw ?	;+14 Resident driver 32-bit length.
RPSeg	dw ?	;+16 (Segment must ALWAYS be set!).
RPCL	dd ?	;+18 Command-line and BPB pointer.
RPDN	db ?	;+22 Drive number (0 = A: etc.).
RP ends

interrupt proc
if ?STKRQ        
        pushf
        cli
        cmp [cs:rq_onstk], 0
        jne .ownstk
        mov [cs:rq_onstk], 1
        mov [cs:rq_sp], sp
        mov [cs:rq_ss], ss
        push cs
        pop ss
        mov sp, offset rq_stack_top
        call .body
        lss sp, dword ptr [cs:rq_sp]
        mov [cs:rq_onstk], 0
        popf
        retf
.ownstk:
        call .body
        popf
        retf
.body:
        sti
endif
        push es
        push bx
        les bx, [cs:reqptr]
        cmp [es:bx].RP.RPOp, 0
        jne .notinit
        jmp do_init
.notinit:
ifndef PKG_USB
        test word ptr [cs:cb.flags], CBF_CHARDEV
        jz .blockreq
        mov [es:bx].RP.RPStat, 8103h       ; character device without functions
        jmp .done
.blockreq:
endif
        mov [es:bx].RP.RPStat, 0100h
if WINAWARE
        test byte ptr [cs:cb.flags], CBF_VXD
        jnz .vxd
        cmp [cs:handover], 0
        jne .fail
endif
        push eax
        push ebx
        mov ax, es
        movzx eax, ax
        shl eax, 4
        movzx ebx, bx
        add ebx, eax
        mov ax, FN_DOS
        call callcore
        pop ebx
        pop eax
        jc .fail
        jmp .done
if WINAWARE
.vxd:
        push ax
        xor ax, ax
        call [cs:cb.vxd_entry]
        cmp ax, 0FFFFh
        pop ax
        je .fail
        jmp .done
endif
.fail:
        les bx, [cs:reqptr]
        mov [es:bx].RP.RPStat, 810Ch       ; error, done, general failure
.done:
if KQV86
        call [cs:pkq_drain]	;DOS driver interrupt proc
endif        
        pop bx
        pop es
if ?STKRQ
        ret
else
        retf
endif
interrupt endp

; ---------------------------------------------------------------------------
; callcore: EAX = function index, EBX = argument. Returns EAX (-1 if busy/unavailable).
callcore proc
        test byte ptr [cs:cb.flags], CBF_BUSY
        jne .busy
;        or byte ptr [cs:cb.flags], CBF_BUSY
        call [cs:jlmentry]
;        and byte ptr [cs:cb.flags], not CBF_BUSY
        ret
.busy:
        stc
        ret

callcore endp

if KQV86
; ---------------------------------------------------------------------------
; 8042 injection queue drain (USB keyboard/mouse in DOS and standard mode)
; no register modified.
kq_drain proc
        push ax
        push bx
        push cx
        mov bl, [cs:cb.kq_tail]
        cmp bl, [cs:cb.kq_head]
        je .x
        in al, 64h
        test al, 03h
        jnz .x
        xor bh, bh
        shl bx, 1
        mov ax, cs:[bx+cb.kq]
        xchg al, ah
        out 64h, al
        mov cx, 10000
.w:     in al, 64h
        test al, 02h
        loopnz .w
        mov al, ah
        out 60h, al
        mov al, [cs:cb.kq_tail]
        inc al
;        cmp al, WIN_KQLEN
        cmp al, lengthof wincb.kq
        jb .s
        xor al, al
.s:     mov [cs:cb.kq_tail], al
.x:     pop cx
        pop bx
        pop ax
        ret
kq_drain endp
endif

if INT15V86
; ---------------------------------------------------------------------------
; INT 15h: track the BIOS pointing device state, so mouse packets are injected into
; the aux port only while a DOS mouse driver consumes them
int15 proc
        pushf
        cmp ah, 0C2h
        jne .chain
 ifdef PKG_USB
        cmp al, 07h
        jne .n7
        mov word ptr [cs:cbx.cbfn+0], bx
        mov word ptr [cs:cbx.cbfn+2], es
.n7:    cmp al, 05h
        jne .n5
        mov [cs:cbx.psize], bh
.n5:
 endif
        cmp al, 00h
        je .enab
        cmp al, 01h                     ; reset and initialize leave the device disabled
        je .off
        cmp al, 05h
        jne .dev
.off:
;        and word ptr [cs:cb.flags], ~CBF_AUXBIOS
        and word ptr [cs:cb.flags], NOT CBF_AUXBIOS
        jmp .dev
.enab:  and word ptr [cs:cb.flags], NOT CBF_AUXBIOS
        test bh, bh
        jz .dev
        or word ptr [cs:cb.flags], CBF_AUXBIOS
.dev:
 ifdef PKG_USB
        ; a touchpad of ours: the BIOS talks to it itself (its answers go to the BIOS), the
        ; core programs it again afterwards
        test [cs:cbx.mode], 1
        jz .chain
        inc [cs:cbx.bios]
        call [cs:oldvecs+OLD15*4]
        push bp
        mov bp,sp
        rcr word ptr [bp+6],1
        rol word ptr [bp+6],1
        pop bp
        dec [cs:cbx.bios]
        inc [cs:cbx.bioscnt]
        iret
 endif
.chain: popf
        jmp [cs:oldvecs+OLD15*4]
int15 endp

endif

; ---------------------------------------------------------------------------
; INT 2Fh: API, Windows enhanced mode startup/exit
if WIN30
	include win30x.inc
win30on           db 0            ; this driver hooks XMS for Windows 3.0 standard mode
endif

int2f proc
if WIN30
        cmp [cs:win30on], 0
        je .now30
        WIN30_INT2F old2f
.now30:
endif
;        cmp ah, [cs:mplex]
        cmp ah, WIN_MPLEX
        je .ours
if WINAWARE
        cmp ax, 1605h
        je .winstart
        cmp ax, 1606h
        je .winexit
endif        
        jmp [cs:oldvecs+OLD2F*4]
.ours:
        cmp al, 00h
        jne .n1
        mov al, 0FFh
        mov bx, lowword WIN_MAGIC
        push cs
        pop es
        mov di, offset cb
        iret
.n1:    cmp al, 01h
        jne .n3
        push ds
        push ebx
if WINAWARE
        test byte ptr [cs:cb.flags], CBF_VXD
        jz .apicore
        mov ax, 1
        call [cs:cb.vxd_entry]
        jmp .apiret
endif        
.apicore:
;--- core API: address of struct winapireq in ES:BX
        mov ax, es
        movzx eax, ax
        shl eax, 4
        movzx ebx, bx
        add ebx, eax
        mov ax, FN_API
        call callcore
.apiret:
        pop ebx
        pop ds
        iret
.n3:
        cmp al, 03h                     ; BL bit 0: 4-byte wheel packets, bit 1: WINMOUSE reads the aux
        jne .n4                         ; port, bit 2: WINMOUSE reads the mouse mailbox
        and word ptr [cs:cb.flags], not (CBF_WHEEL4 or CBF_AUXWIN or CBF_MBOX)
if WINAWARE
        test bl, 4
        jz .r3a
        or word ptr [cs:cb.flags], CBF_MBOX
.r3a:
endif
        test bl, 1
        jz .r3
        or word ptr [cs:cb.flags], CBF_WHEEL4
.r3:
if WINAWARE
        test bl, 2
        jz .r3b
        or word ptr [cs:cb.flags], CBF_AUXWIN
.r3b:
endif
        xor ax, ax
        iret
.n4:    mov ax, 0FFFFh
        iret

if WINAWARE
.winstart
        test dx, 1                      ; standard mode (DOSX): keep the DOS core
        jnz .chain
        pushf
        call [cs:oldvecs+OLD2F*4]
        test cx, cx
        jnz .wsret
;        cmp [cs:is_busy], 0
;        jne .wsret
        pushad
        mov ax, FN_SHUTDOWN
        xor ebx, ebx
        call callcore
        mov [cs:handover], 1
        popad
        test word ptr [cs:cb.opts], OPT_NOVXD
        jnz .wsret
 ifndef PKG_DISK
        cmp byte ptr [cs:cb.dosver+1], 7 ; Windows 95/98 load their Plug and Play VxD themselves
        jae .wsret
 endif
        mov word ptr [cs:sis_next+0], bx
        mov word ptr [cs:sis_next+2], es
        push cs
        pop es
        mov bx, offset sis
.wsret: iret

.winexit:
        test dx, 1
        jnz .chain
        cmp [cs:handover], 0
        je .chain
        mov [cs:handover], 0
        pushad
        mov ax, FN_RESUME
        xor ebx, ebx
        call callcore
        popad
.chain: jmp [cs:oldvecs+OLD2F*4]
endif
int2f endp

if WINAWARE
; ---------------------------------------------------------------------------
; INT 33h: the standard DOS mouse API, backed by the USB mouse. Position is kept up to date
; from the mouse mailbox the core fills (CBF_MBOX), so the same provider serves DOS programs
; and the Microsoft Mouse driver of Windows 1.0x / 2.x without any hook inside Windows.

; fold the accumulated mailbox motion into the absolute position and button state. CS = resident.
m33_pull proc
        push ax
        push bx
        push cx
        push dx
        push si
        mov ax, word ptr [cs:cb+304]             ; mb_dx
        mov bx, word ptr [cs:cb+306]             ; mb_dy
        mov word ptr [cs:cb+304], 0
        mov word ptr [cs:cb+306], 0
        add [cs:m33_mickx], ax
        add [cs:m33_micky], bx
        mov dl, [cs:cb+308]             ; mb_dz (wheel)
        mov byte ptr [cs:cb+308], 0
        add [cs:m33_wheel], dl
        mov cx, [cs:m33_x]
        add cx, ax
        mov ax, [cs:m33_xmin]
        cmp cx, ax
        jge .xh
        mov cx, ax
.xh:    mov ax, [cs:m33_xmax]
        cmp cx, ax
        jle .xo
        mov cx, ax
.xo:    mov [cs:m33_x], cx
        mov cx, [cs:m33_y]
        add cx, bx
        mov ax, [cs:m33_ymin]
        cmp cx, ax
        jge .yh
        mov cx, ax
.yh:    mov ax, [cs:m33_ymax]
        cmp cx, ax
        jle .yo
        mov cx, ax
.yo:    mov [cs:m33_y], cx
        ; buttons: bit0 left, bit1 right, bit2 middle
        mov al, [cs:cb+309]             ; mb_btn
        and al, 7
        mov ah, [cs:m33_lastbtn]
        mov [cs:m33_btn], al
        mov [cs:m33_lastbtn], al
        mov dl, al
        xor dl, ah                      ; changed buttons
        xor si, si                      ; button index
.bl:    mov bx, si
        mov cl, bl
        mov ch, 1
        shl ch, cl
        test dl, ch
        jz .bn
        shl bx, 1
        test al, ch
        jz .brel
        inc [cs:m33_pcnt+bx]       ; press
        mov cx, [cs:m33_x]
        mov [cs:m33_px+bx], cx
        mov cx, [cs:m33_y]
        mov [cs:m33_py+bx], cx
        jmp .bn
.brel:  inc [cs:m33_rcnt+bx]       ; release
        mov cx, [cs:m33_x]
        mov [cs:m33_rx+bx], cx
        mov cx, [cs:m33_y]
        mov [cs:m33_ry+bx], cx
.bn:    inc si
        cmp si, 3
        jb .bl
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        ret
m33_pull endp

int33 proc
        cmp [cs:m33_on], 0
        je .chain
        push ds
        push si
        push bp
        push cs
        pop ds
        cmp ax, 0
        je .reset
        cmp ax, 1
        je .show
        cmp ax, 2
        je .hide
        cmp ax, 3
        je .getpos
        cmp ax, 4
        je .setpos
        cmp ax, 5
        je .press
        cmp ax, 6
        je .release
        cmp ax, 7
        je .xrange
        cmp ax, 8
        je .yrange
        cmp ax, 0Bh
        je .motion
        cmp ax, 0Ch
        je .sethand
        cmp ax, 11h
        je .wheel
        cmp ax, 24h
        je .version
        ; unhandled: return harmless
        pop bp
        pop si
        pop ds
        iret
.reset:
        or word ptr [cs:cb.flags], CBF_MBOX
        mov [m33_x], 320
        mov [m33_y], 100
        mov [m33_btn], 0
        mov [m33_lastbtn], 0
        mov [m33_show], 0FFFFh
        mov [m33_xmin], 0
        mov [m33_xmax], 639
        mov [m33_ymin], 0
        mov [m33_ymax], 199
        mov [m33_hand], 0
        mov ax, 0FFFFh                  ; mouse installed
        mov bx, 2                       ; two buttons
        jmp .out
.show:  inc [m33_show]
        jmp .ok
.hide:  dec [m33_show]
        jmp .ok
.getpos:
        call m33_pull
        mov cx, [m33_x]
        mov dx, [m33_y]
        xor bx, bx
        mov bl, [m33_btn]
        cmp [m33_wmode], 0
        je .out
        mov bh, [m33_wheel]             ; CuteMouse wheel delta in BH, then cleared
        mov [m33_wheel], 0
        jmp .out
.setpos:
        mov [m33_x], cx
        mov [m33_y], dx
        jmp .ok
.press:
        call m33_pull
        and bx, 1                       ; button number (0 left, 1 right)
        mov si, bx
        shl si, 1
        mov cx, [m33_px+si]             ; x at the last press
        mov dx, [m33_py+si]             ; y at the last press
        mov bx, [m33_pcnt+si]           ; press count since the last call
        mov [m33_pcnt+si], 0
        xor ax, ax
        mov al, [m33_btn]               ; current button state
        jmp .out
.release:
        call m33_pull
        and bx, 1
        mov si, bx
        shl si, 1
        mov cx, [m33_rx+si]
        mov dx, [m33_ry+si]
        mov bx, [m33_rcnt+si]
        mov [m33_rcnt+si], 0
        mov ax, word ptr [m33_btn]
        and ax, 7
        jmp .out
.xrange:
        mov [m33_xmin], cx
        mov [m33_xmax], dx
        jmp .ok
.yrange:
        mov [m33_ymin], cx
        mov [m33_ymax], dx
        jmp .ok
.motion:
        call m33_pull
        mov cx, [m33_mickx]
        mov dx, [m33_micky]
        mov [m33_mickx], 0
        mov [m33_micky], 0
        jmp .out
.sethand:
        mov word ptr [m33_hand+0], dx
        mov word ptr [m33_hand+2], es
        mov [m33_mask], cx
        jmp .ok
.wheel:
        ; CuteMouse wheel API: declare wheel support and let the client read it itself,
        ; so the wheel-to-keys fallback in the core stops for this client.
        mov [m33_wmode], 1
        or word ptr [cs:cb+300], 1          ; CB_WHEELCTL bit 0
        mov ax, 574Dh                   ; 'WM'
        xor bx, bx
        mov cx, 1                        ; wheel present
        jmp .out
.version:
        mov bx, 0631h                   ; report version 6.31
        mov cx, 0400h                   ; CH = type 4 (PS/2), CL = 0
        jmp .out
.ok:    pop bp
        pop si
        pop ds
        iret
.out:   pop bp
        pop si
        pop ds
        iret
.chain: jmp [cs:old33]
int33 endp
endif
; ---------------------------------------------------------------------------
if POLLV86
; timer: drive the DOS-mode USB stack
int08 proc
        pushf
        call [cs:oldvecs+OLD08*4]
        call do_poll
        iret
int08 endp

; DOS idle: DOS is waiting for console input and may be interrupted safely
int28 proc
        pushf
        call [cs:oldvecs+OLD28*4]
        call do_poll
        iret
int28 endp
endif
if PROTI13
; BIOS disk calls must not be interrupted by a mode switch: count them
int13 proc
        inc [cs:in13]
        pushf
        call [cs:oldvecs+OLD13*4]
        push bp
        mov bp,sp
        rcr word ptr [bp+6],1
        rol word ptr [bp+6],1
        pop bp
        dec [cs:in13]
        iret
int13 endp
endif
; CF clear when the interrupted code may be suspended for a poll: DOS is not inside
; a function (InDOS, critical error) and no BIOS disk call is in progress. DOS calls
; HIMEM and the BIOS from inside its functions; a mode switch in the middle of those
; (A20 handling, block moves, BIOS 32-bit transitions) is not safe.
if DEFERRED or TPMODE
dos_safe proc
        cmp [cs:in13], 0
        jne .no
        push ds
        push bx
        lds bx, [cs:indos_ptr]
        cmp word ptr [bx-1], 0
        pop bx
        pop ds
        jne .no
        clc
        ret
.no:    stc
        ret
dos_safe endp
endif

if POLLV86
; poll the core;
; all registers must be preserved.
; called by 1) int08, 2) int28
do_poll proc
 if WINAWARE
        cmp [cs:handover], 0
        jne .x
        test byte ptr [cs:cb.flags], CBF_VXD
        jnz .x
 endif
        cmp [cs:in13], 0
        jne .x
;        cmp [cs:is_busy], 0
;        jne .x
 if ?STKIRQ        
        cmp [cs:irq_onstk], 0
        jne .x
        mov [cs:irq_onstk], 1
        mov [cs:irq_sp], sp
        mov [cs:irq_ss], ss
        push cs
        pop ss
        mov sp, offset irq_stack_top
 else
        sti
 endif        
        push eax
        push ebx
        push ecx
 if DEFERRED
;--- interrupts that arrived at an unsafe moment first;
;--- irq_deferred is modified by USB controller irqs ( hence never if /POLL is set )
        xor cx, cx
        xchg cx, [cs:irq_deferred]
        jcxz .poll
        xor ebx, ebx
.dirq:  shr cx, 1
        jnc .dnext
        mov ax, FN_IRQ
        call callcore
        call irq_unmask
.dnext: inc bx
        test cx, cx
        jnz .dirq
.poll:
 endif        
        mov ax, FN_POLL
        xor ebx, ebx
        call callcore
;--- kq_drain called here or in the core (platjlm.c, ent_poll())
;       call [cs:pkq_drain]	;inside do_poll proc
        pop ecx
        pop ebx
        pop eax
 if ?STKIRQ
        lss sp, dword ptr [cs:irq_sp]
        mov [cs:irq_onstk], 0
 endif        
 ifdef PKG_USB
        call aux_deliver
 endif
.x:     ret
do_poll endp
endif

if DEFERRED
; BL = IRQ: unmask it in the PIC
irq_unmask proc
        push ax
        push cx
        movzx cx, bl
        cmp cl, 8
        jae .hi
        in al, 21h
        btr ax, cx
        out 21h, al
        jmp .x
.hi:    sub cx, 8
        in al, 0A1h
        btr ax, cx
        out 0A1h, al
.x:     pop cx
        pop ax
        ret
irq_unmask endp
endif

if KQV86
; keyboard / aux interrupts: after the owner read port 60h, push the next queued byte
int09 proc
        pushf
        call [cs:old09]
        call [cs:pkq_drain]	;int09 proc (KQV86)
        iret
int09 endp
endif

ifdef PKG_USB

 if TPMODE or KQV86

; IRQ 12: while JAIUSB drives a PS/2 touchpad its bytes are queued for the core (decoded at
; once when the moment is safe, else at the next poll); the BIOS gets them during its own
; pointing device calls
int74 proc
  if TPMODE
        test [cs:cbx.mode], 1   ;touchpad mode? let BIOS handle IRQ12?
        jz .bios
        cmp [cs:cbx.bios], 0    ;inside int 15h, ah=C2h?
        jne .bios
        push ax
        in al, 64h
        and al, 21h
        cmp al, 21h    ; mouse data available?
        jne .notaux
        in al, 60h
        push bx
        xor bh, bh
        mov bl, [cs:cbx.qhead]
        mov [cs:cbx.q+bx], al
        inc bl
        and bl, WIN_AUXQ - 1
        cmp bl, [cs:cbx.qtail]
        je .full
        mov [cs:cbx.qhead], bl
.full:  pop bx
        mov al, 20h
        out 0A0h, al
        out 20h, al
        pop ax
        call aux_core
        iret
.notaux:
        pop ax
.bios:
  endif
        pushf
        call [cs:old74]
  if KQV86
        call [cs:pkq_drain]	;int74 proc (KQV86, USB)
  endif
        iret
int74 endp

 endif ; TPMODE or KQV86

 if TPMODE
; the core decodes the queued aux bytes now if DOS may be interrupted, then the packets go
; to the DOS mouse driver; all registers kept
aux_core proc
  if WINAWARE
        cmp [cs:handover], 0
        jne .x
  endif
;        cmp [cs:is_busy], 0
;        jne .x
        call dos_safe
        jc .x
  if ?STKIRQ        
        cmp [cs:irq_onstk], 0
        jne .x
        mov [cs:irq_onstk], 1
        mov [cs:irq_sp], sp
        mov [cs:irq_ss], ss
        push cs
        pop ss
        mov sp, offset irq_stack_top
  endif
        push eax
        push ebx
        mov ax, FN_IRQ
        mov ebx, 12
        call callcore
        pop ebx
        pop eax
  if ?STKIRQ        
        lss sp, dword ptr [cs:irq_sp]
        mov [cs:irq_onstk], 0
  endif        
.x:     call aux_deliver
        ret
aux_core endp

 endif

if TPMODE or POLLV86
; packets of the core to the pointing device BIOS callback, as the BIOS's IRQ 12 handler
; would call it: status, X, Y, Z pushed as words, far call
; no register modified
aux_deliver proc
        cmp [cs:auxdeliv], 0
        jne .r
        push ds
        push cs
        pop ds
        mov [auxdeliv], 1
        push ebx
.l:     mov bh, 0
        mov bl, [cbx.ptail]
        cmp bl, [cbx.phead]
        je .done
        shl bx, 2
        mov ebx, dword ptr [cbx.pk+bx]
        inc [cbx.ptail]
        and [cbx.ptail], 15
        test word ptr [cb.flags], CBF_AUXBIOS
        jz .l
        cmp word ptr [cbx.cbfn+2], 0
        je .l
        pusha
        mov ah, 0
        mov al, bl
        push ax
        mov al, bh
        push ax
        shr ebx,16
        mov al, bl
        push ax
        mov al, bh
        push ax
        call [cbx.cbfn]
        add sp, 8
        popa
        jmp .l
.done:
        mov [auxdeliv], 0
        pop ebx
        pop ds
.r:     ret
aux_deliver endp
endif

else ;PKG_USB

int74 proc
        pushf
        call far [cs:old74]
  if KQV86
        call [cs:pkq_drain]	;int74 proc (KQV86, Non-USB)
  endif
        iret
int74 endp

endif

if IRQV86
; USB host controller IRQs
IRQNO = 0
irqs0:
	rept 16
	push IRQNO
	jmp irq_common
if IRQNO eq 0
size_irqstubs equ $ - irqs0
endif
IRQNO = IRQNO + 1
	endm

irq_common proc
        sub sp,2
        push bp
        mov bp,sp
        push bx
        push ax
        mov bx,[bp+2*2]      ;get IRQ#
if WINAWARE
        cmp [cs:handover], 0
        jne .chain
endif        
;        cmp [cs:is_busy], 0
;        jne .chain
if ?STKIRQ        
        cmp [cs:irq_onstk], 0
        jne .chain
endif        
if DEFERRED
        call dos_safe
        jnc .now
        ; A line shared with another device is never masked: its driver (e.g. the BIOS disk
        ; code in the middle of INT 13h) may wait for that interrupt. Our controllers stop
        ; asserting it (PCI command register: INTx disable) and the interrupt is passed on;
        ; the core serves them and switches INTx back on at the next safe poll.
        bts [cs:irq_deferred], bx
        bt [cs:cb.shirq], bx
        jnc .mask
        call intx_off
        jmp .chain
.mask:
        ; unsafe moment: mask the line, acknowledge it and service it at the next poll
        cmp bl, 8
        jae .mhi
        in al, 21h
        bts ax, bx
        out 21h, al
        mov al, 20h
        out 20h, al
        jmp .mdone
.mhi:   in al, 0A1h
        sub bx, 8
        bts ax, bx
        out 0A1h, al
        mov al, 20h
        out 0A0h, al
        out 20h, al
.mdone:
        pop ax
        pop bx
        pop bp
        add sp,2+2
        iret
.now:
endif
if ?STKIRQ
        mov [cs:irq_onstk], 1
        mov [cs:irq_sp], sp
        mov [cs:irq_ss], ss
        push cs
        pop ss
        mov sp, offset irq_stack_top
endif        
        push eax
        push ebx
        movzx ebx, bx
        mov ax, FN_IRQ
        call callcore
        mov [cs:irqchain], eax
if KQV86
        call [cs:pkq_drain]	;inside USB host controller IRQ proc
endif        
        pop ebx
        pop eax
if ?STKIRQ        
        lss sp, dword ptr [cs:irq_sp]
        mov [cs:irq_onstk], 0
endif        
ifdef PKG_USB
        call aux_deliver
endif
        cmp [cs:irqchain], 1
        jne .chain
        cmp bl, 8
        mov al, 20h
        jb .m
        out 0A0h, al
.m:
        out 20h, al
        pop ax
        pop bx
        pop bp
        add sp,2+2
        iret
.chain:
		shl bx, 2
		mov ax,word ptr cs:[bx+oldirq+0]
		mov bx,word ptr cs:[bx+oldirq+2]
		mov [bp+1*2],ax
		mov [bp+2*2],bx
		pop ax
		pop bx
		pop bp
		retf
irq_common endp
endif

if DEFERRED
; AL = IRQ: set INTx disable in the PCI command register of our controllers on that line
intx_off proc
        push eax
        push cx
        push dx
        push si
        mov cl, al
        mov dx, 0CF8h
        in eax, dx
        push eax                        ; the interrupted code may be between CF8h and CFCh
        xor si, si
.n:     cmp [cs:cb.hcirq+si], cl
        jne .nx
        push si
        shl si, 1
        movzx eax, word ptr cs:[cb.hcbdf+si]
        pop si
        shl eax, 8
        or eax, 80000004h
        mov dx, 0CF8h
        out dx, eax
        mov dx, 0CFCh
        in ax, dx
        or ax, 0400h
        out dx, ax
.nx:    inc si
        cmp si, 8
        jb .n
        pop eax
        mov dx, 0CF8h
        out dx, eax
        pop si
        pop dx
        pop cx
        pop eax
        ret
intx_off endp
endif

ifdef PKG_DISK
; ---------------------------------------------------------------------------
; Intel AHCI option ROM bugs with VDS (EMM386 and other DOS memory managers), the DOS
; part of what AHCIFIX.386/AHCIFIXD.SYS do: the ROM unlocks DMA regions with the
; descriptor in DS:DI instead of ES:DI, and uses the first bytes of the EBDA (pointing
; device data) as a DMA area. While a BIOS disk call runs, INT 4Bh goes through
; vds_filter. In Windows enhanced mode WINDISK.386 does the same in protected mode.
int13d proc
if WINAWARE
        cmp [cs:handover], 0
        jne .pass
endif        
        cmp [cs:vds_active], 0
        jne .pass
        push ax
        push es
        mov ax, 40h
        mov es, ax
        test byte ptr [es:7Bh], 20h         ; VDS services present?
        pop es
        pop ax
        jz .pass
        mov [cs:vds_active], 1
        push eax
        push es
        xor ax, ax
        mov es, ax
        mov eax, [es:4Bh*4]
        mov [cs:old4b], eax
        mov word ptr es:[4Bh*4+0], offset vds_filter
        mov word ptr es:[4Bh*4+2], cs
        pop es
        pop eax
        pushf
        call [cs:old13d]
        push eax
        push es
        push 0
        pop es
        mov eax, [cs:old4b]
        mov es:[4Bh*4], eax
        pop es
        pop eax
        mov [cs:vds_active], 0
        retf 2    ;!!! copy C flag to stack frame and use IRET! 
.pass:  jmp [cs:old13d]
int13d endp

;--- this is our VDS ( int 4Bh ) hook while int 13h is running

vds_filter proc
        cmp ah, 81h
        jne .pass
        cmp al, 03h                     ; lock DMA region
        je .lock
        cmp al, 05h                     ; scatter/gather lock
        je .lock
        cmp al, 04h                     ; unlock DMA region
        je .unlock
        cmp al, 06h                     ; scatter/gather unlock
        jne .pass
.unlock:
        cmp dword ptr [es:di+12], 0     ; no physical address: not the locked descriptor
        jne .unl2
        push ax                         ; swap ES and DS for the memory manager ..
        mov ax, es
        push ds
        pop es
        mov ds, ax
        pop ax
        pop word ptr [cs:vds_ret+0]     ; .. and back on the way out
        pop word ptr [cs:vds_ret+2]
        push cs
        push offset vds_unswap
.unl2:  call vds_in_ebda
        jne .pass
        cmp [cs:ebda_saved], 0
        je .pass
        push si                         ; the region is free again: restore the EBDA
        push di
        push cx
        push ds
        push es
        push cs
        pop ds
        mov si, offset ebda_buf
        push ax
        mov ax, 40h
        mov es, ax
        mov es, [es:0Eh]
        pop ax
        xor di, di
        mov cx, 6Ch / 4
        cld
        rep movsd
        pop es
        pop ds
        pop cx
        pop di
        pop si
        mov [cs:ebda_saved], 0
        jmp .pass
.lock:  call vds_in_ebda
        jne .pass
        push si
        push di
        push cx
        push ds
        push es
        push ax
        mov ax, 40h
        mov ds, ax
        mov ds, [ds:0Eh]
        pop ax
        push cs
        pop es
        xor si, si
        mov di, offset ebda_buf
        mov cx, 6Ch / 4
        cld
        rep movsd
        pop es
        pop ds
        pop cx
        pop di
        pop si
        mov [cs:ebda_saved], 1
.pass:  jmp [cs:old4b]

vds_unswap:                             ; the memory manager returned here (flags restored)
        push ax
        mov ax, es
        push ds
        pop es
        mov ds, ax
        pop ax
        jmp [cs:vds_ret]

; ZF set when the DMA region of the descriptor at ES:DI starts in the first 6Ch bytes
; of the EBDA
vds_in_ebda:
        push ax
        push ds
        mov ax, 40h
        mov ds, ax
        mov ax, [ds:0Eh]
        pop ds
        cmp [es:di+8], ax
        jne .x
        cmp dword ptr [es:di+4], 6Ch
        jae .no
        cmp ax, ax
        jmp .x
.no:    or al, 1                        ; ZF clear (AL restored below)
.x:     pop ax
        ret

vds_filter endp

endif ;PKG_DISK

; ===========================================================================
; initialization (discarded after INIT)
; ===========================================================================

	@idata

; core_init parameters
; 1) lin adr, 2) phys adr, 3) size of pool
; 4) lin adr cb, 5) mode (1=DOS,2=VxD), 6) flags, 7) lin adr mbrs
params core_params <0, 0, 0, 0, 1, 0, 0>

drv_lin         dd 0	;linear address of driver header
xmsentry        dd 0	;XMS driver entry
emb_handle      dw 0
ifdef PKG_AUDIO
fhandle         dw 0
endif

HOOKS struct
intno	db ?
ofs		dw ?
HOOKS ends

HKENT = 0
@DefHK macro intno, ofs
	HOOKS <intno, ofs>
HKENT = HKENT+1
endm
;--- hook order must match order of oldvecs
hooks label HOOKS
ifdef PKG_USB
 if POLLV86
    @DefHK  8h, offset int08
    @DefHK 28h, offset int28
 endif
 if KQV86
    @DefHK  9h, offset int09
 endif
 if TPMODE or KQV86
    @DefHK 74h, offset int74
 endif
 if INT15V86
    @DefHK 15h, offset int15
 endif
 if PROTI13
    @DefHK 13h, offset int13
 endif
    @DefHK 2Fh, offset int2f
else
    @DefHK  8h, offset int08
    @DefHK 28h, offset int28
    @DefHK 13h, offset int13
 ifdef PKG_DISK
    @DefHK 13h, offset int13d
 endif
    @DefHK 2Fh, offset int2f
endif
end_hooks equ $

	.errnz HKENT - OVENT, <hook definition invalid>

msg_banner      db BANNER
msg_crlf        db 13, 10, '$'
msg_drvname     db DRVNAME, ': $'
msg_no386       db '386 or later required', 13, 10, '$'
msg_notsc       db 'CPU without time stamp counter (Pentium or later required)', 13, 10, '$'
msg_noxms       db 'XMS driver (HIMEM.SYS) not loaded', 13, 10, '$'
msg_noemb       db 'cannot allocate extended memory', 13, 10, '$'
msg_nojlm       db COREFILE, ' not responding', 13, 10, '$'
msg_units1      db 'drives $'
msg_units2      db ':$'
msg_nounits     db 'no drive letters assigned', 13, 10, '$'
ifdef PKG_DISK
msg_nodisk      db 'no disk found, not installed (/S shows the full probe log)', 13, 10, '$'
msg_chrdev      db 'no drive letters; resident for Windows', 13, 10, '$'
endif
ifdef PKG_DISK
chrname         db 'WINDISK$'
endif
msg_usb         db DOSACTIVE, 13, 10, '$'
ifdef PKG_AUDIO
msg_nosnd       db 'no sound hardware found, not installed (/S shows the probe log)', 13, 10, '$'
endif
if WINAWARE
vxdname         db VXDFILE, 0
endif

    .code _ITEXT

printdn proc
        push dx
        mov dx, offset msg_drvname
        call print
        pop dx
printdn endp   ;fall thru

print proc
        mov ah, 09h
        int 21h
        ret
print endp

ifndef PKG_AUDIO

	.code _RDATA

old13s   dd 0
 if I13BIOSV86
wbm      winbiosmap <>
i13req   winapireq <>
i13stat  db 8 dup (0)   ;last status, returned by int13, ah=
 else
i13entry dd 0
 endif
 
	.code

 ife I13BIOSV86

int13s proc
        cmp dl, 80h
        jb .pass
        cmp dl, 80h+WIN_MAXBIOSDISKS
        jae .pass
        push bx
        movzx bx, dl
        and bl,7Fh
        bt word ptr [cs:cb.kbcstat], bx
        pop bx
        jc .ours
.pass:  jmp [cs:old13s]
.ours:
        jmp [cs:i13entry]
int13s endp

 else

int13s proc
        cmp dl, 80h
        jb .pass
        cmp dl, 80h+WIN_MAXBIOSDISKS
        jae .pass
        push bx
        movzx bx, dl
        cmp [cs:wbm.disk+bx-80h], 0
        pop bx
        jne .ours
.pass:  jmp [cs:old13s]

; BP frame

I13FR struct
	org -14
lpBuffer dd ?
lba      dd ?,?
SecsLeft dw ?
rDi    dw ?,?
rSi    dw ?,?
rBp    dw ?,?
       dw ?,?
rBx    dw ?,?
union
rDx    dw ?,?
struct
rDl    db ?
rDh    db ?
ends
ends
union
rCx    dw ?,?
rCl_   db ?
ends
union
rAx    dw ?,?
struct
rAl    db ?
rAh    db ?
ends
ends
rIp    dw ?
rCs    dw ?
rFlags dw ?
I13FR ends

.ours:
        pushad
        mov bp,sp
        sti
        movzx si, dl
        sub si, 80h                     ; SI = k
        cmp ah, 02h
        je .chs
        cmp ah, 03h
        je .chs
        cmp ah, 42h
        je .ext
        cmp ah, 43h
        je .ext
        cmp ah, 08h
        je .geom
        cmp ah, 15h
        je .type_
        cmp ah, 41h
        je .edd
        cmp ah, 48h
        je .params
        cmp ah, 01h
        je .status
        mov di, offset okfns
        mov cx, okfns_n
.f:     cmp ah, [cs:di]
        je .ok
        inc di
        loop .f
        mov al, 01h                     ; invalid function
        jmp .err_

;--- AH=01: return last status
.status:
        mov al, [cs:i13stat+si]
        test al, al
        jnz .err_
.ok:    xor al, al
.err_:  ; AL = status
        mov [cs:i13stat+si], al
        mov [bp].I13FR.rAh, al          ; AH of the caller
        and [bp].I13FR.rFlags, not 1	; CF=0
        test al, al
        jz .ret
        or  [bp].I13FR.rFlags, 1
.ret:
        mov sp,bp
        popad
        iret

;--- AH=02/03
;--- in: AL sectors
;---     CH cylinder low
;---     CL bits 7-6 cylinder high, 5-0 sector
;---     DH head
.chs:
        movzx ax, al
        push ax                         ; [bp].SecsLeft
        mov di, si
        shl di, 2
        movzx eax, cl
        shl eax, 2
        mov al, ch                      ; EAX = cylinder (bits 9-8 from CL 7-6)
        and eax, 3FFh
        movzx ebx, [cs:cb.biosgeom+di].heads
        mul ebx                         ; * heads
        movzx ebx, [bp].I13FR.rDh
        add eax, ebx
        movzx ebx, [cs:cb.biosgeom+di].spt
        mul ebx                         ; * sectors per track
        movzx ebx, [bp].I13FR.rCl_ 
        and bl, 3Fh
        jz .badsec
        dec ebx
        add eax, ebx
        pushd 0                         ;[bp].lba high
        push eax                        ;[bp].lba low
        push es
        push [bp].I13FR.rBx             ;[bp].lpBuffer
        call i13xfer
        jc .err_
        mov [bp].I13FR.rAl, cl          ; AL=sectors read/write
        jmp .ok
.badsec:
        mov al, 04h
        jmp .err_

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

.ext:
        mov bx, [bp].I13FR.rSi
        cmp [bx].DAP.dwBuffer, -1            ; 64-bit flat buffer: not supported
        je .inval
        push [bx].DAP.wNumSec                ;[bp].SecsLeft
        push [bx].DAP.dwStartHigh            ;[bp].lba high
        push [bx].DAP.dwStartLow             ;[bp].lba low
        push [bx].DAP.dwBuffer               ;[bp].lpBuffer
        call i13xfer
        jc .err_
        mov [bx].DAP.wNumSec, cx
        jmp .ok
.inval: mov al, 01h
        jmp .err_

;--- AH=08h
;--- the BIOS geometry recorded at the start
;--- out: CL= 0-5: max sector#; 6-7: max cyl# [8-9]
;---      CH= max cyl# bits [0-7]
;---      DL= #drives
;---      DH= max head#
;---      BL= drive type (0-6 floppies); floppies only?

.geom:  mov di, si
        shl di, 2
        mov cx, [cs:cb.biosgeom+di].cyls  ; cylinders
        dec cx
        xchg cl, ch
        ror cl, 2
        and cl, 0C0h
        or cl, [cs:cb.biosgeom+di].spt
        mov [bp].I13FR.rCx, cx
        mov dh, [cs:cb.biosgeom+di].heads
        dec dh
        mov dl, [cs:cb.nbios]
        mov [bp].I13FR.rDx, dx
;        mov byte ptr [bp].I13FR.rBx, 0    ; BL?
        mov [bp].I13FR.rAl, 0
        jmp .ok

;--- AH=15h
;--- out: AH=disk type
;---      CX:DX=sectors

.type_: mov di, si
        shl di, 2
        mov ax, word ptr [cs:wbm.sectors+di+2]
        mov [bp].I13FR.rCx, ax            ; CX:DX sectors
        mov ax, word ptr [cs:wbm.sectors+di+0]
        mov [bp].I13FR.rDx, ax
        mov [cs:i13stat+si], 0
        mov [bp].I13FR.rAh, 03h           ; AH = 3: fixed disk
        and [bp].I13FR.rFlags, not 1
        jmp .ret

;--- AH=41h
;--- BX=55AAh
;--- out:
;--- AH=major version of extension
;--- CX=API bitmap support subset
;---  b0: 42h-44h
;---  b1: removable functions (45h/46h)
;---  b2: EDD (48h,4Eh)

.edd:   cmp bx, 55AAh
        jne .inval
        mov [bp].I13FR.rBx, 0AA55h
        mov [bp].I13FR.rCx, 1 or 4        ; 42,43,48
        mov [cs:i13stat+si], 0
        mov [bp].I13FR.rAh, 21h           ; AH: EDD 1.1
        and [bp].I13FR.rFlags, not 1
        jmp .ret

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

.params:
        mov bx, [bp].I13FR.rSi
        cmp [bx].EDD.wSize, sizeof EDD
        jb .inval
        mov [bx].EDD.wSize, sizeof EDD
        mov [bx].EDD.wFlags, EDDF_GEOMVALID or EDDF_REMOVABLE
        mov di, si
        shl di, 2
        movzx eax, [cs:cb.biosgeom+di].cyls
        mov [bx].EDD.dwCyl, eax
        movzx eax, [cs:cb.biosgeom+di].heads
        mov [bx].EDD.dwHeads, eax
        movzx eax, [cs:cb.biosgeom+di].spt
        mov [bx].EDD.dwSecs, eax
        mov eax, [cs:wbm.sectors+di]
        mov [bx].EDD.dwNSecsL, eax
        mov eax, [cs:wbm.sectorshi+di]
        mov [bx].EDD.dwNSecsH, eax
        mov [bx].EDD.wSecSiz, 512
        jmp .ok
int13s endp

	.code _RDATA

okfns    db 00h, 04h, 09h, 0Ch, 0Dh, 10h, 11h, 14h, 44h, 47h
okfns_n  equ $ - okfns

	.code

; transfer [bp].SecsLeft sectors at [bp].lba to/from [bp].lpBuffer;
; out: NC = ok, then CX = sectors
;       C = error, then AL = error code
; DS, BX and SI must be preserved
i13xfer proc
        push bx
        xor cx, cx
.lp:    cmp [bp].I13FR.SecsLeft, 0
        je .done
        ; normalize [bp].lpBuffer (the core reads at most 64K - 16 at a time)
        mov ax, word ptr [bp].I13FR.lpBuffer+0
        mov dx, word ptr [bp].I13FR.lpBuffer+2
        mov bx, ax
        shr ax, 4
        add dx, ax
        shl edx, 16
        and bx, 0Fh
        mov dx, bx
        movzx bx, [bp].I13FR.rDl
        movzx eax, [cs:wbm.disk+bx-80h]
        dec eax
        test [bp].I13FR.rAh, 1   ;02/03/42/43
        je .rd
        or eax, 80000000h
.rd:    mov [cs:i13req.fn], WINF_RAWIO
        mov [cs:i13req.status], 0FFFFh
        mov [cs:i13req.arg0], eax
        mov eax, [bp].I13FR.lba+0
        mov [cs:i13req.arg1], eax
        mov eax, [bp].I13FR.lba+4
        mov [cs:i13req.arg2], eax
        movzx eax, [bp].I13FR.SecsLeft
        cmp eax, 127
        jbe .n
        mov eax, 127
.n:     shl eax, 9
        mov [cs:i13req.buflen], eax 
        mov [cs:i13req.retlen], 0
        mov [cs:i13req.buf], edx        ; buf seg:off

; the request i13req to the core: the DOS core, or the VxD while Windows runs

        mov ebx, offset i13req
  if WINAWARE
        test word [cs:cb+CB_FLAGS], CBF_VXD
        jz .core
        mov ax, 1
        call [cs:cb.vxd_entry]
        jmp .calldone
  endif        
.core:  mov ax, cs
        movzx eax, ax
        shl eax, 4
        add ebx, eax
        mov ax, FN_API
        call callcore
.calldone:
        cmp [cs:i13req.status], 0
        jne .ioerr
        mov eax, [cs:i13req.retlen]     ; bytes done
        shr eax, 9
        jz .ioerr
        add cx, ax
        sub [bp].I13FR.SecsLeft, ax
        add [bp].I13FR.lba+0, eax
        adc [bp].I13FR.lba+4, 0
        shl ax, 5                       ; paragraphs
        add word ptr [bp].I13FR.lpBuffer+2, ax
        jmp .lp
.ioerr:
        mov al,0AAh                     ; disk not ready
        cmp byte ptr cs:[i13req.status], WINE_NODEV
        jz .x
        mov al, 04h                     ; sector not found / read error
        test [bp].I13FR.rAh, 1          ; read or write?
        je .x
        mov al, 0CCh                    ; write fault
.x:
        stc
.done:
        pop bx
        ret
i13xfer endp

 endif
 
	.code _ITEXT

 if I13BIOSV86
;--- get BIOS map;
;--- this code runs after the core init call
;--- the BIOS disks on controllers the core took over: their INT 13h is served here

get_biosmap proc
        mov [i13req.fn], WINF_BIOSMAP
        mov [i13req.status], 0FFFFh
        mov [i13req.buflen], sizeof winbiosmap
        mov ax, cs
        shl eax, 16
        mov ax, offset wbm
        mov [i13req.buf], eax   ; SSSS:OOOO format
        mov bx, cs
        movzx ebx, bx
        shl ebx, 4
        add ebx, offset i13req
        mov ax, FN_API
        call callcore
        cmp [i13req.status], 0
        jne .noi13
        mov al,0
        xor bx, bx
.ci:    cmp [wbm.disk+bx], 0
        jz @F
        bts ax,bx
@@:
        inc bx
        cmp bx, 8
        jb .ci
        ret
.noi13:
        mov al,0
        ret
get_biosmap endp

 endif
endif

; 386 check: FLAGS bits 12-15 behave differently on 8086/286

is386 proc
        pushf
        pop ax
        or ax, 7000h
        push ax
        popf
        pushf
        pop ax
        test ax, 7000h
        jnz .is386
        mov dx, offset msg_no386
        call printdn
        stc
.is386:
        ret
is386 endp

;--- expects stack frame from interrupt proc, that is
;--- [sp]   -> BX, ES
;--- [sp+4] -> caller (near or far)
;--- ES:BX  -> RP

do_init proc
        push ds
        push cs
        pop ds
        mov [es:bx].RP.RPUnit, 0
        mov [es:bx].RP.RPLen, 0
        mov [es:bx].RP.RPSeg, cs
        mov [es:bx].RP.RPStat, 810Ch
        push ax
        call is386
        pop ax
        jnc @F
        jmp .init_exit
@@:
        cld
        pushad
        mov [cb.drvseg], cs
        mov dx, offset msg_banner
        call print
        ; CB defaults
        mov [cb.magic], 42433357h
        mov [cb.version], 0101h
;        mov byte ptr [cb.flags], CBF_BUSY
        mov [cb.size_], sizeof wincb
        mov byte ptr [cb.mplex], WIN_MPLEX
        mov [cb.slotreq], DEFSLOTS or 80h  ; default: grows with the partitions found
        mov al, [es:bx].RP.RPDN
        mov [cb.firstdrive], al
        les si, [es:bx].RP.RPCL
        mov ah, 30h
        int 21h                ;modifies BX
        xchg al, ah
        mov [cb.dosver], ax
        mov ax, cs
        movzx eax, ax
        shl eax, 4
        mov [drv_lin], eax
        add eax, offset cb
        mov [cb.cb_lin], eax
        call parse_cmdline
if 0;def PKG_USB
        ; MS-DOS 7 (Windows 95/98): the Plug and Play VxD and its port driver give the disks
        ; their letters; DOS letters only with /DOSDISK
        cmp byte ptr [cb.dosver+1], 7
        jb .dosdisk
        test [cb.opts2], OPT2_DOSDISK
        jnz .dosdisk
        or [cb.opts2], OPT2_NODISK
        mov [cb.slotreq], 0
.dosdisk:
endif
if KQV86
        test [cb.opts], OPT_NOKBC
        jz .nokbc
        mov [pkq_drain], offset _ret
.nokbc:
endif
ifndef PKG_DISK
        or word ptr [cb.opts], OPT_USB   ; core in DOS and standard mode unless /WIN
 if WINAWARE
        test word ptr [cb.opts], OPT_WINONLY
        jz .optdone
        and word ptr [cb.opts], not OPT_USB
.optdone:
 endif
else
        and word ptr [cb.opts], not OPT_USB
endif
        ; CPUID / TSC
        pushfd
        pop eax
        mov ecx, eax
        xor eax, 200000h
        push eax
        popfd
        pushfd
        pop eax
        push ecx
        popfd
        xor eax, ecx
        test eax, 200000h
        jz .notsc
        mov eax, 1
        .586
        cpuid
        .386
        test dl, 10h
        jnz .tscok
.notsc: mov dx, offset msg_notsc
        call printdn
        jmp .init_fail
.tscok:
        ; XMS
        mov ax, 4300h
        int 2Fh
        cmp al, 80h
        je .xms
        mov dx, offset msg_noxms
        call printdn
        jmp .init_fail
.xms:   mov ax, 4310h
        int 2Fh
        mov word ptr [xmsentry+0], bx
        mov word ptr [xmsentry+2], es
        push cs
        pop es

        call load_core
        jc .init_fail
        call read_bios_mbrs
        call read_bds    ; fill cb.mounted[] array
;        mov byte ptr [cb.flags], CBF_DOSCORE

        ; core_init(params)
        mov ax, FN_INIT
        mov ebx, [drv_lin]
        add ebx, offset params
        call callcore
ifdef PKG_AUDIO
        ; firmware files the core asked for (Intel audio DSP): loaded into XMS, then the
        ; core goes on with the sound devices
.fwloop:
        test word ptr [cb.flags], CBF_FWREQ
        jz .fwdone
        and word ptr [cb.flags], not CBF_FWREQ
        call load_fw
        mov ax, FN_FILEDONE
        xor ebx, ebx
        call callcore
        jmp .fwloop
.fwdone:
endif

ifndef PKG_USB
 ifdef PKG_DISK
        ; No drive letters to serve. With disks found the driver stays for Windows (VxD:
        ; 32-bit disk access, AHCI BIOS fix) as a character device: DOS reads the device
        ; attributes after INIT, so the header is turned into a character device header.
        cmp [cb.nunits], 0
        jne .serve
        test word ptr [cb.flags], CBF_HAVEDISK
        jz .unload
        mov word ptr [hdr+4], 8000h
        mov si, offset chrname
        mov di, offset hdr_units
        push cs
        pop es
        mov cx, 8
        rep movsb
        or word ptr [cb.flags], CBF_CHARDEV
        mov dx, offset msg_chrdev
        call printdn
        jmp .serve
 else
        ; sound devices found: resident as the character device WINAUD$
        test word ptr [cb.flags], CBF_HAVEDISK
        jz .unload
        or word ptr [cb.flags], CBF_CHARDEV
        jmp .serve
 endif
.unload:
        mov ax, FN_SHUTDOWN
        xor ebx, ebx
        call callcore
        or byte ptr [cb.flags], CBF_BUSY
 ifdef PKG_AUDIO
        call free_fw
 endif
 ifdef PKG_DISK
        mov dx, offset msg_nodisk
 else
        mov dx, offset msg_nosnd
 endif
        call printdn
        jmp .init_fail
.serve:
endif

ifndef PKG_AUDIO
 ifdef _DEBUG
        xor cx, cx
        lea si, [cb.mounted]
@@:
        cmp [si].winmount.biosdrv,0
        jz .dispdsk_done
        movzx dx, [si].winmount.letter
        add dl,'A'
        @dprintf CStr("mounted[%u]: %c:, hd=%X, start=%lu",10), cx, dx, [si].winmount.biosdrv, [si].winmount.start
        add si, sizeof winmount
        inc cx
        cmp cx,16
        jb @B
.dispdsk_done:
 endif
 if I13BIOSV86
        call get_biosmap
        cmp al,0
        jz @F
 else
        cmp cb.kbcstat, 0       ;kbcstat abused for int13 flags
        jz @F
        mov eax, cb.vxd_entry   ;vxd_entry abused for int13 callback
        mov i13entry, eax
        mov al, cb.kbcstat
 endif
 if MODDPB
        call moddpb
 elseif MODDDT
        call modddt
 endif
        mov al, 13h
        mov di, offset old13s
        mov dx, offset int13s
        call hook
@@:        
endif

        ; DOS-mode? (always true) 
;        test word ptr [cb.opts], OPT_USB
;        jz .nousb
;        mov [dos_usb], 1
        or byte ptr [cb.flags], CBF_USB
if DEFERRED or TPMODE
        push es
        push bx
        mov ah, 34h                     ; InDOS flag address
        int 21h
        mov word ptr [indos_ptr+0], bx
        mov word ptr [indos_ptr+2], es
        pop bx
        pop es
endif
if IRQV86
        call hook_irqs                  ; before INT 08h can poll (INTx goes on at the first poll)
endif
        mov dx, offset msg_usb
        call printdn
        mov si, offset hooks
        mov di, offset oldvecs
.nexthook:
        lodsb
        mov cl, al
        lodsw
        cmp cl, -1
        jz @F
        mov dx, ax
        mov al, cl
        call hook
@@:
        add di, 4
        cmp si, offset end_hooks
        jnz .nexthook

ifdef PKG_USB
 if WINAWARE
        ; INT 33h (DOS mouse API): provide the USB mouse to INT 33h clients (DOS programs and
        ; the Microsoft Mouse driver of Windows 1.0x / 2.x). A real DOS mouse driver loaded
        ; afterwards hooks INT 33h ahead of this and keeps priority.
        mov al, 33h
        mov di, offset old33
        mov dx, offset int33
        call hook
        mov [m33_on], 1
 endif
endif
;.nousb:
if WINAWARE
        ; SIS for Windows enhanced mode
        mov word ptr [sis_path+0], offset cb.vxdpath
        mov [sis_path+2], cs
        mov word ptr [sis_ref+0], offset cb
        mov [sis_ref+2], cs
endif
        test word ptr [cb.flags], CBF_CHARDEV
        jz .block
        les bx, [reqptr]
        mov [es:bx].RP.RPUnit, 0
        jmp .init_ok
.block:
        ; at least one unit, otherwise DOS discards the driver
        cmp [cb.nunits], 0
        jne .haveunits
        mov [cb.nunits], 1
        mov [cb.units.type_], 2       ; UT_SLOT
        mov dx, offset msg_nounits
        call printdn
.haveunits:
        ; BPB pointer array
        movzx cx, [cb.nunits]
        mov di, offset cb.bpbptr
        mov ax, offset cb.units + winunit.bpb
.bpb:   stosw
        add ax, sizeof winunit
        loop .bpb
        call show_units
        les bx, [reqptr]
        mov al, [cb.nunits]
        mov [es:bx].RP.RPUnit, al
        mov [hdr_units], al
        mov word ptr [es:bx].RP.RPCL+0, offset cb.bpbptr
        mov word ptr [es:bx].RP.RPCL+2, cs
.init_ok:
        mov [es:bx].RP.RPLen, offset resident_end
        mov [es:bx].RP.RPStat, 0100h
;        jmp .init_ret
.init_fail:
        ; nothing to do, request packet fields set already
.init_ret:
        popad
.init_exit:
        pop ds
        pop bx
        pop es
if ?STKRQ
        ret
else
        retf
endif
do_init endp

; AL = vector, DI = old vector slot, DX = new handler
hook proc
        push es
        push bx
        push ax
        mov ah, 35h
        int 21h
        mov [di+0], bx
        mov [di+2], es
        pop ax
        mov ah, 25h
        int 21h
        pop bx
        pop es
        ret
hook endp

if IRQV86
;--- hook irqs 0-15 depending on irqmask
;--- modifies ax, cx, dx, di

hook_irqs proc
        mov cx, 0
.l:
        bt [cb.irqmask], cx
        jnc .n
;--- di = address stored old irq
        mov di, cx
        shl di, 2
        add di, offset oldirq
;--- ds:dx = address new irq
        mov ax, size_irqstubs
        mul cx
        mov dx, offset irqs0
        add dx, ax

        mov al, cl
        add al, 08h
        cmp cx, 8
        jb .lo
        add al, 70h - 10h
.lo:
        call hook
        ; unmask in the PIC
        cmp cx, 8
        jb .m1
        in al, 0A1h
        push cx
        sub cx, 8
        btr ax, cx
        pop cx
        out 0A1h, al
        in al, 21h
        and al, not 4
        out 21h, al
        jmp .n
.m1:    in al, 21h
        btr ax, cx
        out 21h, al
.n:     inc cx
        cmp cx, 16
        jb .l
        ret
hook_irqs endp

endif

if MODDPB

;--- adjust device driver headers in DPBs
;--- in: BIOS disk bits (80h-87h) in AL
;--- a) get the DOS drive letter - scan cb.mount[].biosdsk
;--- b) get the DPB for that drive
;--- c) the DPB has the device driver header

moddpb proc uses si di

local disks:word
local dpblist:dword
local ddofs:word

        mov ah,0
        mov disks,ax

        mov ah,52h
        int 21h
        les bx,es:[bx+0]  ;get start of DPB list
        mov word ptr dbplist+0,bx
        mov word ptr dbplist+2,es
        mov cx,24
        cmp cb.dosver+1,4
        jb @F
        inc cx
@@:
        mov ddofs,cx

        mov cx, 0
nextdisk:
        bt disks, cx
        jnc skipdisk
        mov al,cl
        call getdosdisk; get DOS drive from BIOS disk
        jc skipdisk
        call getdpb    ; get DPB in ES:BX for DOS drive in AL
        jc skipdisk
        call moddpb    ; modify DPB in driver header
skipdisk:
        inc cx
        cmp cx, 8
        jb nextdisk

        inc di
        cmp di,8
        jb nextdisk
done:
        ret

;--- scan the cb.mounted[] array to get the dos drive (letter)
;--- in: AL=BIOS disk
;--- out: AL=DOS drive
getdosdisk:
        push cx
        lea si, cb.mounted
        mov cx, 16
        mov dl, al
nextmount:
        mov al, [si].winmount.letter
        cmp dl, [si].winmount.biosdrv
        jz foundmnt
        add si, sizeof winmount
        loop nextmount
        stc
foundmnt:
        pop cx
        retn

;--- get DPB of DOS drive
;--- in: DOS drive in AL (0=A, 1=B, ...)

getdpb:        
        les bx, dbplist
        cmp word ptr es:[bx+0], -1
        jz endoflist
        cmp al,es:[bx+0]
        jz found
        add bx, ddofs
        les bx, es:[bx]
        jmp nextdpb
endoflist:
        stc
found:
        retn

moddpb endp
elseif MODDDT

modddt proc uses ds
local disks:word
        mov ah,0
        mov disks,ax
        mov ax, 803h
        int 2Fh
        mov ax,ds
        mov cx,cs
        cmp ax,cx
        jz .x

.l:     cmp di, -1
        je .x
        mov al, [di].DDT.bPhysU
        cmp al, 80h
        jb .nx
        and al,7Fh
        cmp al,8
        jae .x
        mov ah,0
        bt disks, ax
        jnc .nx
        and byte ptr [di+3Fh],not 1    ;reset bit 0; offset is 3Fh for DOS 7.1 only!
.nx:    lds di, [di].DDT.pNext
        jmp .l
.x:
        ret
modddt endp

endif

; ---------------------------------------------------------------------------
; es:si -> cmdline

parse_cmdline proc

        ; skip the driver path
        ; todo: if WINAWARE is active, store the path in pathbuf
.p:     lodsb es:[si]
        cmp al, ' '
        jbe .pe
        cmp al, '/'
        je .pe
        jmp .p
.pe:
        dec si
if WINAWARE
        push si   ;save end of exe path
endif
;--- options
.o:     lodsb es:[si]
        cmp al, 13
        je .done
        cmp al, 10
        je .done
        test al, al
        jz .done
        cmp al, '/'
        je .opt
        cmp al, '-'
        je .opt
        jmp .o

;--- token -> tok (upper case)
.opt:   
        xor di, di
.tk:    mov al, [es:si]
        cmp al, ' '
        jbe .te
        cmp al, '/'
        je .te
        cmp al, 'a'
        jb .tu
        cmp al, 'z'
        ja .tu
        sub al, 20h
.tu:    cmp di, 15   ;sizeof tok - 1
        jae .tn
        mov [tok+di], al
        inc di
.tn:    inc si
        jmp .tk
.te:    mov [tok+di], 0

        cmp word ptr [tok], ':R'
        jne .tab
        mov ax, word ptr [tok+2]
        sub al, '0'
        cmp al, 9
        ja .o
        sub ah, '0'
        cmp ah, 9
        ja .one
        shl al, 1   ;*2
        mov bl, al
        shl al, 2   ;*8
        add al, bl  ;*10
        add al, ah
.one:   cmp al, WIN_MAXUNITS
        jbe .st
        mov al, WIN_MAXUNITS
.st:    mov [cb.slotreq], al
        jmp .o

.tab:   push si
        mov si, offset optab
        mov bx, offset cb.opts
.t:     lodsd                     ;<--- check next option
        mov edx, eax
        test edx, edx
        jnz .t1
        cmp bx, offset cb.opts
        pop si
        jne .o
        push si
        mov si, offset optab2
        mov bx, offset cb.opts2
        jmp .t
.t1:    xor di, di
.cmp:   lodsb
        cmp al, [tok+di]
        jne .ne
        test al, al
        jz .eq
        inc di
        jmp .cmp
.ne:
        dec si
.sk:
        lodsb
        cmp al, 0
        jne .sk
        jmp .t
.eq:
        or [bx], edx
        pop si
        jmp .o
.done:
if WINAWARE
;--- this code hasn't been tested yet!
        mov bx, word ptr [cs:reqptr]
        mov si, word ptr es:[bx].RP.RPCL
        pop cx
        sub cx, si
        mov di, offset cb.vxdpath
        rep movsb
        mov si, offset vxdname
.c2:    lodsb
        stosb
        test al, al
        jnz .c2
endif        
        ret
parse_cmdline endp

	@idata

; option bit, name (second table: bits of the second option word)

optab2 label byte
ifdef PKG_USB
        dd OPT2_NOTB
        db 'NOTB', 0
        dd OPT2_NOTBPCIE
        db 'NOTBPCIE', 0
        dd OPT2_NOTBUSB
        db 'NOTBUSB', 0
        dd OPT2_PCIHP
        db 'PCIHP', 0
;        dd OPT2_DOSDISK	;obsolete
;        db 'DOSDISK', 0
;        dd OPT2_NOPS2		;windows-only option
;        db 'NOPS2', 0
        dd OPT2_NOTP
        db 'NOTP', 0
        dd OPT2_NOSMB
        db 'NOSMB', 0
        dd OPT2_NOPOLL		;JAIUSB: added to force IRQ mode
        db 'NOPOLL', 0
endif
ifdef PKG_AUDIO
        dd OPT2_DSP
        db 'DSP', 0
        dd OPT2_DMIC
        db 'DMIC', 0
        dd OPT2_NODSP
        db 'NODSP', 0
endif
        dd OPT2_NORELOC
        db 'NORELOC', 0
        dd OPT2_ALL4G
        db 'ALL4G', 0
        dd 0
optab label byte
ifdef PKG_USB
 if WINAWARE
        dd OPT_WINONLY
        db 'WIN', 0
 endif
        dd OPT_NOHID
        db 'NOHID', 0
        dd OPT_NOMSC
        db 'NOMSC', 0
        dd OPT_NOKBC
        db 'NOKBC', 0
        dd OPT_POLL
        db 'POLL', 0
        dd OPT_NOXHCI
        db 'NOXHCI', 0
        dd OPT_NOEHCI
        db 'NOEHCI', 0
        dd OPT_NOOHCI
        db 'NOOHCI', 0
        dd OPT_NOUHCI
        db 'NOUHCI', 0
        dd OPT_NOROUTE
        db 'NOROUTE', 0
        dd OPT_NOI2C
        db 'NOI2C', 0
        dd OPT_NONVME
        db 'NONVME', 0
        dd OPT_NVME
        db 'NVME', 0
elseifdef PKG_AUDIO
        dd OPT_WINONLY
        db 'WIN', 0
        dd OPT_NOHDA
        db 'NOHDA', 0
        dd OPT_NOAC97
        db 'NOAC97', 0
        dd OPT_INVEAPD
        db 'EAPD', 0
        dd OPT_NOGENERIC
        db 'NOGEN', 0
        dd OPT_HDAIMM
        db 'IMM', 0
        dd OPT_NOSYNTH
        db 'NOSYNTH', 0
        dd OPT_POSBUF
        db 'POSBUF', 0
        dd OPT_HDAGPIO
        db 'GPIO', 0
else
        dd OPT_NOIDE
        db 'NOIDE', 0
        dd OPT_PIO
        db 'PIO', 0
        dd OPT_ISA
        db 'ISA', 0
        dd OPT_NOAHCI
        db 'NOAHCI', 0
        dd OPT_NONVME
        db 'NONVME', 0
        dd OPT_ALL
        db 'ALL', 0
        dd OPT_NVME
        db 'NVME', 0
endif
if WINAWARE
        dd OPT_NOVXD
        db 'NOVXD', 0
endif
        dd OPT_COM1
        db 'COM1', 0
        dd OPT_VERBOSE
        db 'V', 0
        dd OPT_DEBUG
        db 'D', 0
        dd OPT_SCREEN
        db 'S', 0
        dd 0

	.code _ITEXT

; ---------------------------------------------------------------------------

ifdef PKG_AUDIO
; clear the init buffer (BX = bytes)
clrbuf:
        push es
        push cs
        pop es
        mov di, offset initbuf
        mov cx, bx
        xor al, al
        rep stosb
        pop es
        ret

; buffer far pointer for XMS moves
bufptr: mov esi, cs
        shl esi, 16
        mov si, offset initbuf
        ret

;---------------------------------------------------------------------------
; load_fw: every firmware entry of the control block in state WFW_REQ is read from the
; driver directory into its own XMS block (locked, 4K aligned start)
fwpath          db 128 dup(0)
fwsub           db 'WINDRVFW\', 0
fwname          dw 0
fwent           dw 0
fwhandle        dw 0
fwemb           dw 0
fwphys          dd 0
fwoff           dd 0
fwsize          dd 0

load_fw proc
        pushad
        mov [fwent], cb+CB_FWTAB
.next:  cmp [fwent], cb+CB_FWTAB+WIN_MAXFW*24
        jae .x
        mov bx, [fwent]
        cmp byte ptr [bx+13], 1
        jne .skip
        ; path: directory of the driver (as in the VxD path) + file name
        mov si, offset cb.vxdpath
        mov di, offset fwpath
        mov dx, offset fwpath
.c:     lodsb
        mov [di], al
        inc di
        cmp al, '\'
        jne .c1
        mov dx, di
.c1:    test al, al
        jnz .c
        ; first the WINDRVFW subdirectory (where the installer puts the firmware)
        mov di, dx
        mov [fwname], dx
        mov si, offset fwsub
.c2:    lodsb
        mov [di], al
        inc di
        test al, al
        jnz .c2
        dec di
        call .name
        mov dx, offset fwpath
        mov ax, 3D00h
        int 21h
        jnc .opened
        ; then the driver directory itself
        mov di, [fwname]
        call .name
        mov dx, offset fwpath
        mov ax, 3D00h
        int 21h
        jc .miss
.opened:
        mov [fhandle], ax
        mov bx, ax
        mov ax, 4202h
        xor cx, cx
        xor dx, dx
        int 21h
        jc .close
        mov [fwsize], ax
        mov [fwsize+2], dx
        mov bx, [fhandle]
        mov ax, 4200h
        xor cx, cx
        xor dx, dx
        int 21h
        mov eax, [fwsize]
        cmp eax, 10h
        jb .close
        cmp eax, 1000000h
        jae .close
        ; XMS block: size + 4K for the alignment, in KB
        add eax, 2000h - 1
        shr eax, 10
        mov dx, ax
        mov ah, 09h
        call [xmsentry]
        cmp ax, 1
        jne .close
        mov [fwemb], dx
        mov ah, 0Ch
        call [xmsentry]
        cmp ax, 1
        jne .freeemb
        mov [fwphys], bx
        mov [fwphys+2], dx
        mov eax, [fwphys]
        add eax, 0FFFh
        and eax, 0FFFFF000h
        mov ecx, eax
        sub ecx, [fwphys]
        mov [fwoff], ecx
        mov [fwphys], eax
        ; the file in 16K pieces
        mov edi, [fwoff]
.rd:    mov bx, [fhandle]
        mov ah, 3Fh
        mov cx, 4000h
        mov dx, offset initbuf
        int 21h
        jc .unlock
        test ax, ax
        jz .eof
        movzx ecx, ax
        inc ecx
        and ecx, not 1
        push edi
        push ecx
        call bufptr        ; get far16 ptr initbuf into ESI
        mov ax, [emb_handle]
        push ax
        mov ax, [fwemb]
        mov [emb_handle], ax
        call xms_to_emb    ; copy ecx bytes from esi to edi
        pop ax
        mov [emb_handle], ax
        pop ecx
        pop edi
        jc .unlock
        add edi, ecx
        jmp .rd
.eof:   mov bx, [fhandle]
        mov ah, 3Eh
        int 21h
        mov bx, [fwent]
        mov eax, [fwphys]
        mov [bx+16], eax
        mov eax, [fwsize]
        mov [bx+20], eax
        mov ax, [fwemb]
        mov [bx+14], ax
        mov byte [bx+13], 2
        jmp .skip
.unlock:
        mov dx, [fwemb]
        mov ah, 0Dh
        call [xmsentry]
.freeemb:
        mov dx, [fwemb]
        mov ah, 0Ah
        call [xmsentry]
.close: mov bx, [fhandle]
        mov ah, 3Eh
        int 21h
.miss:  mov bx, [fwent]
        mov byte ptr [bx+13], 3
.skip:  add [fwent], 24
        jmp .next
.x:     popad
        ret

; the file name of the entry [fwent] to [di] (NUL included)
.name:  mov si, [fwent]
.n1:    lodsb
        mov [di], al
        inc di
        test al, al
        jnz .n1
        ret

load_fw endp

; free_fw: the XMS blocks of the firmware files (driver not staying resident)
free_fw proc
        pushad
        mov bx, offset cb+CB_FWTAB
.f:     cmp bx, offset cb+CB_FWTAB+WIN_MAXFW*24
        jae .fx
        cmp byte ptr [bx+13], 2
        jne .fn
        push bx
        mov dx, [bx+14]
        mov ah, 0Dh
        call [xmsentry]
        pop bx
        push bx
        mov dx, [bx+14]
        mov ah, 0Ah
        call [xmsentry]
        pop bx
        mov byte ptr [bx+13], 3
.fn:    add bx, 24
        jmp .f
.fx:    popad
        ret
free_fw endp
endif

;--- check if the JLM has been loaded;
;--- if yes, alloc memory for "core pool".

load_core proc
        xor ax,ax
        mov es,ax
        mov bx,3D34h
        mov ax,1684h
        int 2Fh
        cmp al,0
        jnz .nojlm
        mov ax,es
        cmp ax,0
        jz .nojlm
        mov word ptr jlmentry+0,di
        mov word ptr jlmentry+2,es

        mov dx, (CORE_POOL + 4*1024) shr 10
        mov ah, 09h
        call [xmsentry]
        dec ax
        jne .noemb
        mov [emb_handle], dx
        mov ah, 0Ch
        call [xmsentry]
        dec ax
        jne .noemb
        push dx
        push bx
        pop eax
        add eax, 0C00h
        and ax, 0F000h
        mov [params.pool_phys], eax
        mov [params.pool_size], CORE_POOL
        mov eax, [cb.cb_lin]
        mov [params.cb_lin], eax
        clc
        ret
.nojlm:
        mov dx, offset msg_nojlm
        jmp .failed
.noemb: mov dx, offset msg_noemb
.failed:
        call printdn
        stc
        ret
load_core endp

; MBR of every BIOS hard disk (for detecting disks DOS already uses)
read_bios_mbrs proc
        mov ah, 08h
        mov dl, 80h
        int 13h
        jc .none
        cmp dl, WIN_MAXBIOSDISKS
        jbe .n
        mov dl, WIN_MAXBIOSDISKS
.n:     mov [cb.nbios], dl
        movzx cx, dl
        jcxz .none
        mov dl, 80h
        mov bx, offset mbrbuf
.l:     push cx
        push bx
        push dx
        push cs
        pop es
        mov ax, 0201h
        mov cx, 0001h
        mov dh, 0
        int 13h
        pop dx
        call bios_geom
        pop bx
        pop cx
        add bx, 512
        inc dl
        loop .l
        mov eax, [drv_lin]
        add eax, offset mbrbuf
        mov [params.mbr_lin], eax
.none:  ret
read_bios_mbrs endp

; DL = disk, 80h - max. 87h
; INT 13h AH=08h geometry into cb.biosgeom (for the FastDisk of the VxD)
bios_geom proc
        push dx
        push dx
        mov ah, 08h
        int 13h
        pop bx
        jc .x
        and bx, 7Fh
        shl bx, 2     ;4 = sizeof struct wingeom
        mov al, cl
        and al, 3Fh
        mov [cb.biosgeom.spt+bx], al   ; sectors per track
        inc dh
        mov [cb.biosgeom.heads+bx], dh ; heads
        mov al, cl
        shr al, 6
        xchg al, ah
        mov al, ch
        inc ax
        mov [cb.biosgeom.cyls+bx], ax  ; cylinders
.x:
        pop dx
        ret
bios_geom endp

; partitions DOS already mounted from BIOS disks (INT 2Fh AX=0803h drive data tables)

read_bds proc uses ds
        ; FreeDOS has no drive data table list; every FAT partition of
        ; a BIOS disk is taken as one of its drives (0FFh: unknown)
        mov ax, 3000h
        int 21h
        cmp bh, 0FDh	;DOS OEM number FreeDOS?
        jne .ms
        mov [cs:cb.nmounted], 0FFh
        ret
.ms:
        mov ax, 803h
        int 2Fh
        ; DS:DI = first table
        xor bx, bx
.l:     cmp di, -1
        je .x
        mov al, [di].DDT.bPhysU
        cmp al, 80h
        jb .nx
        cmp bx, sizeof wincb.mounted   ;end of array?
        jae .x
        mov [cs:cb.mounted.biosdrv+bx], al
        mov al, [di].DDT.bLogU
        mov [cs:cb.mounted.letter+bx], al
        mov eax, [di].DDT.hidden
        mov [cs:cb.mounted.start+bx], eax
        add bx, sizeof winmount  ;=8
        inc [cs:cb.nmounted]
.nx:    lds di, [di].DDT.pNext
        jmp .l
.x:
        ret
read_bds endp

show_units proc
        mov dx, offset msg_units1
        call printdn
        movzx cx, [cb.nunits]
        mov bl, [cb.firstdrive]
        add bl, 'A'
.l:     mov dl, bl
        mov ah, 02h
        int 21h
        mov dx, offset msg_units2
        call print
        mov dl, ' '
        mov ah, 02h
        int 21h
        inc bl
        loop .l
        mov dx, offset msg_crlf
        call print
        ret
show_units endp

ifdef ?MZ
startlbl textequ <_start>
    .stack 128
    .dosseg
_start:
    push cs
    pop ds
    mov dx,offset startmsg
    mov ah,9
    int 21h
    mov ax,4c00h
    int 21h

    @idata
startmsg db "JAIUSB.SYS must be launched by a DEVICE= line in CONFIG.SYS",13,10,'$'

_BSS segment para public 'BSS'
_BSS ends
	.data?
tok     db 16 dup (?)
mbrbuf  db WIN_MAXBIOSDISKS * 512 dup (?)
initbuf db 4096 dup (?)
else
startlbl textequ <>
        align 16
tok     db 16 dup (0)
mbrbuf  db WIN_MAXBIOSDISKS * 512 dup (0)
initbuf label byte
endif

	end startlbl
