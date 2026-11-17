;--- include file created by h2incx v1.0 (Public Domain, written by Andreas Grech)
;--- source file: C:\PROJECTS\JAIUSB\SRC\INC\winapi.h, last modified: 11/16/2026 19:31
;--- cmdline used for creation:  -b -y -o src/jlm src/inc/winapi.h

ifndef WINAPI_H
WINAPI_H	EQU	<>
;#pragma pack ( push , 1 ) 
WIN_MAGIC	EQU	42433357h
WIN_VERSION	EQU	0100h
WIN_MAXUNITS	EQU	16
WIN_KQLEN	EQU	20
WIN_MPLEX_DISK	EQU	0D3h
WIN_MPLEX_USB	EQU	0D4h
WIN_VXD_DISK	EQU	3D33h
WIN_VXD_USB	EQU	3D34h
WIN_MPLEX_AUDIO	EQU	0D5h
WIN_VXD_AUDIO	EQU	3D35h
ifndef defined
defined macro x
ifdef x
  exitm <1>
else
  exitm <0>
endif
endm
endif
if 0 eq defined(WIN_USB) AND  0 eq defined(WIN_AUDIO) AND  0 eq defined(WIN_DISK)
WIN_DISK	EQU	<>
endif 
if defined(WIN_USB)
WIN_MPLEX	EQU	<WIN_MPLEX_USB>
WIN_VXD_ID	EQU	<WIN_VXD_USB>
elseif defined(WIN_AUDIO)
WIN_MPLEX	EQU	<WIN_MPLEX_AUDIO>
WIN_VXD_ID	EQU	<WIN_VXD_AUDIO>
else 
WIN_MPLEX	EQU	<WIN_MPLEX_DISK>
WIN_VXD_ID	EQU	<WIN_VXD_DISK>
endif 
WIN_BPBXSIZE	EQU	25 + 28
UT_NONE	EQU	0
UT_FIXED	EQU	1
UT_SLOT	EQU	2
US_PRESENT	EQU	01h
US_CHANGED	EQU	02h
US_WPROT	EQU	04h
US_EJECTED	EQU	08h
US_FOREIGN	EQU	10h
US_TAKEN	EQU	20h
bpb_s	struct 
bps	WORD	?
spc	BYTE	?
ressecs	WORD	?
nfats	BYTE	?
rootent	WORD	?
secsfat12	WORD	?
media	BYTE	?
spf	WORD	?
spt	WORD	?
trks	WORD	?
hidden	DWORD	?
secsfat16	DWORD	?
bpb_s	ends

extbpb_s	struct 
sectors_fat	DWORD	?
extflags	WORD	?
fsversion	WORD	?
startroot	DWORD	?
fsinfo_sec	WORD	?
bootbackup_sec	WORD	?
extbpb_s	ends

winunit	struct 
type_	BYTE	?
state	BYTE	?
disk	BYTE	?
part	BYTE	?
key	DWORD	?
key2	DWORD	?
lba	DWORD	?
sectors	DWORD	?
serial	DWORD	?
media	BYTE	?
ptype	BYTE	?
gen	BYTE	?
lba_hi	BYTE	?
bpb	BYTE 25+28 dup (?)
label_	BYTE 11 dup (?)
winunit	ends

CBF_VXD	EQU	0001h
CBF_DOSCORE	EQU	0002h
CBF_REINIT	EQU	0004h
CBF_USB	EQU	0008h
CBF_BUSY	EQU	0010h
CBF_VCPI	EQU	0020h
CBF_NOCORE	EQU	0040h
CBF_KICK	EQU	0080h
CBF_WHEEL4	EQU	0100h
CBF_PS2INJ	EQU	0200h
CBF_AUXWIN	EQU	0400h
CBF_AUXBIOS	EQU	0800h
CBF_MBOX	EQU	1000h
CBF_HAVEDISK	EQU	2000h
CBF_CHARDEV	EQU	4000h
CBF_FWREQ	EQU	8000h
winfw	struct 
name_	SBYTE 13 dup (?)
state	BYTE	?
emb	WORD	?
phys	DWORD	?
size_	DWORD	?
winfw	ends

WFW_REQ	EQU	1
WFW_OK	EQU	2
WFW_MISSING	EQU	3
WIN_MAXFW	EQU	16
CB_FWTAB	EQU	448
OPT_USB	EQU	0001h
OPT_NOAHCI	EQU	0002h
OPT_NONVME	EQU	0004h
OPT_ALL	EQU	0008h
OPT_VERBOSE	EQU	0010h
OPT_DEBUG	EQU	0020h
OPT_NOVXD	EQU	0040h
OPT_NOHID	EQU	0080h
OPT_NOMSC	EQU	0100h
OPT_COM1	EQU	0200h
OPT_NOKBC	EQU	0400h
OPT_NVME	EQU	0800h
OPT_NOIDE	EQU	1000h
OPT_PIO	EQU	2000h
OPT_WINONLY	EQU	4000h
OPT_ISA	EQU	8000h
OPT_SCREEN	EQU	00010000h
OPT_POLL	EQU	00020000h
OPT_NOXHCI	EQU	00040000h
OPT_NOEHCI	EQU	00080000h
OPT_NOOHCI	EQU	00100000h
OPT_NOUHCI	EQU	00200000h
OPT_NOROUTE	EQU	00400000h
OPT_NOHDA	EQU	00800000h
OPT_NOAC97	EQU	01000000h
OPT_INVEAPD	EQU	02000000h
OPT_NOGENERIC	EQU	04000000h
OPT_HDAIMM	EQU	08000000h
OPT_NOSYNTH	EQU	10000000h
OPT_POSBUF	EQU	20000000h
OPT_HDAGPIO	EQU	40000000h
OPT_NOI2C	EQU	80000000h
OPT2_NOTB	EQU	0001h
OPT2_NOTBPCIE	EQU	0002h
OPT2_NOTBUSB	EQU	0004h
OPT2_PCIHP	EQU	0008h
OPT2_DOSDISK	EQU	0010h
OPT2_NODISK	EQU	0020h
OPT2_DSP	EQU	0080h
OPT2_DMIC	EQU	0100h
OPT2_NODSP	EQU	0200h
OPT2_NORELOC	EQU	0040h
OPT2_ALL4G	EQU	0800h
OPT2_NOPS2	EQU	0400h
OPT2_NOTP	EQU	1000h
OPT2_NOSMB	EQU	2000h
OPT2_NOPOLL	EQU	4000h
winmount	struct 
biosdrv	BYTE	?
letter	BYTE	?
rsv	WORD	?
start	DWORD	?
winmount	ends

wingeom	struct 
cyls	WORD	?
heads	BYTE	?
spt	BYTE	?
wingeom	ends

wincb	struct 
magic	DWORD	?
version	WORD	?
size_	WORD	?
vxd_entry	DWORD	?
flags	DWORD	?
nunits	BYTE	?
firstdrive	BYTE	?
nfixed	BYTE	?
nslots	BYTE	?
opts	DWORD	?
core_phys	DWORD	?
core_size	DWORD	?
irqmask	WORD	?
drvseg	WORD	?
mplex	WORD	?
dosver	WORD	?
biosmbr	DWORD 8 dup (?)
biosgeom	wingeom 8 dup (<>)
nbios	BYTE	?
nmounted	BYTE	?
slotreq	BYTE	?
kbcstat	BYTE	?
mounted	winmount 16 dup (<>)
bpbptr	WORD WIN_MAXUNITS dup (?)
cb_lin	DWORD	?
ticks	DWORD	?
pollcnt	DWORD	?
irqcnt	DWORD	?
wheel_ctl	WORD	?
shirq	WORD	?
mb_dx	SWORD	?
mb_dy	SWORD	?
mb_dz	SBYTE	?
mb_btn	BYTE	?
mb_seq	BYTE	?
mb_flags	BYTE	?
ideown	WORD 8 dup (?)
hcbdf	WORD 8 dup (?)
hcirq	BYTE 8 dup (?)
tsc_khz	DWORD	?
if 0
vxdpath	SBYTE 92 dup (?)
endif 
units	winunit WIN_MAXUNITS dup (<>)
nvmeown	WORD 8 dup (?)
kq_head	BYTE	?
kq_tail	BYTE	?
kq	WORD WIN_KQLEN dup (?)
mb_absx	WORD	?
mb_absy	WORD	?
opts2	WORD	?
wincb	ends

WIN_AUXQ	EQU	64
WIN_AUXPK	EQU	16
wincbx	struct 
mode	BYTE	?
bios	BYTE	?
qhead	BYTE	?
qtail	BYTE	?
bioscnt	BYTE	?
phead	BYTE	?
ptail	BYTE	?
psize	BYTE	?
cbfn	DWORD	?
q	BYTE WIN_AUXQ dup (?)
pk	BYTE WIN_AUXPK*4 dup (?)
wincbx	ends

core_params	struct 
pool_lin	DWORD	?
pool_phys	DWORD	?
pool_size	DWORD	?
cb_lin	DWORD	?
mode	DWORD	?
flags	DWORD	?
mbr_lin	DWORD	?
rsv	DWORD 2 dup (?)
core_params	ends

WINF_INFO	EQU	0001h
WINF_USBTREE	EQU	0010h
WINF_USBDESC	EQU	0011h
WINF_USBEJECT	EQU	0012h
WINF_TBTREE	EQU	0013h
WINF_DISKS	EQU	0020h
WINF_RAWREAD	EQU	0021h
WINF_CDREQ	EQU	0023h
WINF_RAWIO	EQU	0024h
WINF_UNITS	EQU	0022h
WINF_LOG	EQU	0030h
WINF_SETOPT	EQU	0040h
WINF_FLUSH	EQU	0041h
WINF_AUD_DEVS	EQU	0050h
WINF_AUD_OPEN	EQU	0051h
WINF_AUD_CTL	EQU	0052h
WINF_AUD_MIX	EQU	0053h
WINF_AUD_MIDI	EQU	0054h
WINF_CAM_DEVS	EQU	0060h
WINF_CAM_MODES	EQU	0061h
WINF_CAM_START	EQU	0062h
WINF_CAM_STOP	EQU	0063h
WINF_CAM_FRAME	EQU	0064h
WINE_OK	EQU	0
WINE_BADFN	EQU	1
WINE_NODEV	EQU	2
WINE_IO	EQU	3
WINE_SMALL	EQU	4
WINE_BUSY	EQU	5
WINE_NOCORE	EQU	6
winapireq	struct 
fn	WORD	?
status	WORD	?
arg0	DWORD	?
arg1	DWORD	?
arg2	DWORD	?
buflen	DWORD	?
retlen	DWORD	?
buf	DWORD	?
rsv	DWORD	?
winapireq	ends

WINRING_MAGIC	EQU	47523357h
winring	struct 
magic	DWORD	?
size_	DWORD	?
wr	DWORD	?
rd	DWORD	?
pos	DWORD	?
flags	DWORD	?
rsv	DWORD 2 dup (?)
winring	ends

RF_UNDERRUN	EQU	0001h
RF_OVERRUN	EQU	0002h
RF_GONE	EQU	0004h
WINAC_OUT	EQU	01h
WINAC_IN	EQU	02h
WINAC_MIDI	EQU	04h
WINAC_SYNTH	EQU	08h
AS_MIC	EQU	01h
AS_LINE	EQU	02h
AS_CD	EQU	04h
AS_AUX	EQU	08h
AS_MIX	EQU	10h
MX_MASTER	EQU	0
MX_WAVE	EQU	1
MX_SYNTH	EQU	2
MX_INGAIN	EQU	3
MX_CD	EQU	4
MX_LINE	EQU	5
MX_COUNT	EQU	6
MX_SRC	EQU	100h
MX_MUTE	EQU	101h
AC_START	EQU	1
AC_PAUSE	EQU	2
AC_RESET	EQU	3
AC_CLOSE	EQU	4
AC_VOLUME	EQU	5
winauddev	struct 
id	BYTE	?
type_	BYTE	?
caps	BYTE	?
insrcs	BYTE	?
rate	DWORD	?
vid	WORD	?
pid	WORD	?
insrc	BYTE	?
hwvol	BYTE	?
gone	BYTE	?
rsv	BYTE	?
name_	SBYTE 48 dup (?)
winauddev	ends

wininfo	struct 
version	WORD	?
mode	WORD	?
flags	DWORD	?
ndisks	BYTE	?
nunits	BYTE	?
firstdrive	BYTE	?
nhc	BYTE	?
nusbdev	BYTE	?
ncd	BYTE	?
rsv	BYTE 2 dup (?)
poolfree	DWORD	?
uptime_ms	DWORD	?
build	SBYTE 32 dup (?)
wininfo	ends

windiskinfo	struct 
index	BYTE	?
kind	BYTE	?
present	BYTE	?
shared	BYTE	?
sectors_lo	DWORD	?
sectors_hi	DWORD	?
ssize	DWORD	?
key	DWORD	?
reads	DWORD	?
writes	DWORD	?
errors	DWORD	?
model	SBYTE 41 dup (?)
serial	SBYTE 21 dup (?)
letters	SBYTE 10 dup (?)
usbdev	WORD	?
windiskinfo	ends

CAM_YUY2	EQU	1
CAM_MJPEG	EQU	2
CAM_NV12	EQU	3
wincamdev	struct 
id	BYTE	?
nmodes	BYTE	?
gone	BYTE	?
active	BYTE	?
usbdev	WORD	?
name_	SBYTE 42 dup (?)
wincamdev	ends

wincammode	struct 
fmt	BYTE	?
frame	BYTE	?
type_	BYTE	?
rsv	BYTE	?
w	WORD	?
h	WORD	?
interval	DWORD	?
maxsize	DWORD	?
wincammode	ends

winframe	struct 
seq	DWORD	?
size_	DWORD	?
w	WORD	?
h	WORD	?
type_	BYTE	?
rsv	BYTE 3 dup (?)
winframe	ends

TN_HOST	EQU	1
TN_ROUTER	EQU	2
TN_ADAPTER	EQU	3
TN_TUNNEL	EQU	4
TN_ICMDEV	EQU	5
TNF_USB4	EQU	01h
TNF_ACTIVE	EQU	02h
TNF_FIRMWARE	EQU	04h
TNF_APPROVED	EQU	08h
TNF_MODE macro f
	exitm <( ( ( f )  shr  4 )  and  3 ) >
	endm
wintbnode	struct 
type_	BYTE	?
depth	BYTE	?
port	BYTE	?
flags	BYTE	?
vendor	WORD	?
device	WORD	?
route_lo	DWORD	?
route_hi	DWORD	?
tunnel	BYTE	?
src	BYTE	?
dst	BYTE	?
nhops	BYTE	?
bw_up	DWORD	?
bw_down	DWORD	?
name_	SBYTE 36 dup (?)
wintbnode	ends

UN_HC	EQU	1
UN_DEV	EQU	2
UN_PORT	EQU	3
UD_NONE	EQU	0
UD_HUB	EQU	1
UD_KBD	EQU	2
UD_MOUSE	EQU	3
UD_BOT	EQU	4
UD_UAS	EQU	5
UD_HIDOTHER	EQU	6
UD_AUDIO	EQU	7
UD_MIDI	EQU	8
UD_TABLET	EQU	9
UD_VIDEO	EQU	10
winusbnode	struct 
type_	BYTE	?
depth	BYTE	?
speed	BYTE	?
port	BYTE	?
id	WORD	?
parent	WORD	?
vid	WORD	?
pid	WORD	?
bcd	WORD	?
bcdusb	WORD	?
cls	BYTE	?
sub_	BYTE	?
proto_	BYTE	?
addr_	BYTE	?
nports	BYTE	?
driver	BYTE	?
hctype	BYTE	?
config	BYTE	?
maxpower	WORD	?
iface_count	WORD	?
portstatus	DWORD	?
errors	DWORD	?
xfers	DWORD	?
pciloc	DWORD	?
mmio	DWORD	?
irq	BYTE	?
luns	BYTE	?
slot	BYTE	?
rsv	BYTE	?
letters	SBYTE 8 dup (?)
manuf	SBYTE 32 dup (?)
product	SBYTE 40 dup (?)
serial	SBYTE 24 dup (?)
winusbnode	ends

;#pragma pack ( pop ) 
endif 

;--- errors: 0
;--- end of file ---
