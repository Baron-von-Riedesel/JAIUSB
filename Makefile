
# OW Makefile to create JAIUCORE.DLL, JAIUSB.SYS, JAIINFO.EXE and DSKBENCH.EXE.
#
# WATCOM:  root directory of Open Watcom 
# JEMMINC: directory where to find files jlm.inc & jlm.h
#
!ifndef WATCOM
WATCOM=\ow20
!endif
!ifndef JEMMINC
JEMMINC=inc
!endif

INCDIR=$(WATCOM)\h
OUTD=bjlm

!ifdef DEBUG
COPTD=-D_DEBUG
!endif

COPT=-q -mf -zl -ox -wx -we -zp4 -ei -DJLM -DWIN_USB -DPKG_USB -Isrc\core -fo$(OUTD)\ -Isrc\inc 

NAME1=JAIUCORE.DLL
NAME2=JAIUSB.SYS
NAME3=JAIINFO.EXE
NAME4=DSKBENCH.EXE

ALL: $(OUTD) $(OUTD)\$(NAME1) $(OUTD)\$(NAME2) $(OUTD)\tools\$(NAME3) $(OUTD)\tools\$(NAME4)

$(OUTD):
	@mkdir $(OUTD)

$(OUTD)\Tools:
	@mkdir $(OUTD)\Tools

COREMODS = &
	.\winlib.obj	.\pci.obj	.\acpi.obj	.\blk.obj	.\corent.obj &
	.\usb.obj		.\uhci.obj	.\ohci.obj	.\ehci.obj	.\xhci.obj &
	.\hub.obj		.\hid.obj	.\ptp.obj	.\ps2tp.obj	.\kbc.obj &
	.\smbtp.obj		.\i2c.obj	.\dwi2c.obj	.\gpio.obj	.\msc.obj &
	.\uvc.obj	.\synth.obj	.\nvme.obj &
	.\nhi.obj		.\tbt.obj	.\icm.obj	.\pcihp.obj	.\cdrom.obj

COREOBJS=$(COREMODS:.\=bjlm\)

{src\core\}.c{$(OUTD)}.obj:
	@$(WATCOM)\binnt\wcc386 -bt=windows $(COPT) $(COPTD) -I$(INCDIR) $<

{src\tools\}.c{$(OUTD)\Tools}.obj:
	@$(WATCOM)\binnt\wcc -q -ml -bt=dos -DJLM -ox -wx -Isrc/inc -Isrc/tools -fo=$(OUTD)/tools/ -I$(INCDIR) $<

$(OUTD)\$(NAME1): $(OUTD)\core.lib $(OUTD)\jlment.obj $(OUTD)\platjlm.obj
	@jwlink name $(OUTD)/JAIUCORE.DLL @<<
format win pe hx dll runtime native
option nodefaultlibs, quiet, map=$(OUTD)\core.map
library $(WATCOM)\lib386\dos\clib3r.lib
file $(OUTD)\jlment.obj
file $(OUTD)\platjlm.obj
lib  $(OUTD)\core.lib
<<

$(OUTD)\core.lib: $(COREOBJS)
	@$(WATCOM)\binnt\wlib -n -b -q $(OUTD)\core.lib $(COREOBJS)

$(OUTD)\platjlm.obj: src\jlm\platjlm.c
	@$(WATCOM)\binnt\wcc386 -bt=windows $(COPT) $(COPTD) -I$(JEMMINC) src\jlm\platjlm.c

$(OUTD)\jlment.obj: src\jlm\jlment.asm src\jlm\winapi.inc
	@jwasm -q -I$(JEMMINC) -Fo$(OUTD)/jlment.obj src/jlm/jlment.asm

$(OUTD)\$(NAME2): src\jlm\jlmstor.asm src\jlm\winapi.inc
	@jwasm -q -mz -D?MZ -DJLM -DPKG_USB -Fl$(OUTD)/JAIUSB.lst -Fo$(OUTD)/JAIUSB.SYS src/jlm/jlmstor.asm

src\jlm\winapi.inc: src\inc\winapi.h
	@tools\h2incx.exe -b -y -o src/jlm src/inc/winapi.h

$(OUTD)\Tools\$(NAME3): $(OUTD)\Tools\wininfo.obj $(OUTD)\tools\winfmt.obj $(OUTD)\tools\winfs.obj
	@$(WATCOM)\binnt\wlink @<<
format dos
name $(OUTD)/tools/$(NAME3)
file $(OUTD)/tools/wininfo.obj
file $(OUTD)/tools/winfmt.obj
file $(OUTD)/tools/winfs.obj
libpath $(WATCOM)\lib286\dos
libpath $(WATCOM)\lib286
option q, m=$(OUTD)/tools/jaiinfo.map, stack=8192
<<

$(OUTD)\Tools\$(NAME4): $(OUTD)\Tools\dskbench.obj
	@$(WATCOM)\binnt\wlink @<<
format dos
name $(OUTD)/tools/$(NAME4)
file $(OUTD)/tools/dskbench.obj
libpath $(WATCOM)\lib286\dos
libpath $(WATCOM)\lib286
option q, m=$(OUTD)/tools/dskbench.map, stack=4096
<<

$(OUTD)\Tools\dskbench.obj: src\tools\dskbench.c
	@$(WATCOM)\binnt\wcc -q -ms -bt=dos -DJLM -ox -wx -Isrc/inc -Isrc/tools -fo=$*.obj -I$(INCDIR) src\tools\dskbench.c

clean: .SYMBOLIC
	@del $(OUTD)\*.obj
	@del $(OUTD)\$(NAME1)
	@del $(OUTD)\core.lib
	@del $(OUTD)\$(NAME2)
	@del $(OUTD)\tools\*.exe
	@del $(OUTD)\tools\*.obj
