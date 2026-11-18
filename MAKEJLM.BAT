@echo off
if not exist bjlm\NUL mkdir bjlm
set WATCOM=\ow20
rem HXRT installed to run OW's Win32 binaries
set PATH=%WATCOM%\binnt;%PATH%
set INCLUDE=%WATCOM%\h
rem set directory where jwasm is to find jlm.inc
set JEMMINC=\projects\jemm\include
rem set CDEF=-q -mf -zl -ox -wx -we -zp4 -ei -DJLM -DWIN_USB -DPKG_USB -D_DEBUG -Isrc\core -Isrc\inc -fobjlm\
set CDEF=-q -mf -zl -ox -wx -we -zp4 -ei -DJLM -DWIN_USB -DPKG_USB -Isrc\core -Isrc\inc -fobjlm\

wcc386 -bt=windows %CDEF% src\core\winlib.c
wcc386 -bt=windows %CDEF% src\core\pci.c
wcc386 -bt=windows %CDEF% src\core\acpi.c
wcc386 -bt=windows %CDEF% src\core\blk.c
wcc386 -bt=windows %CDEF% src\core\corent.c

wcc386 -bt=windows %CDEF% src\core\usb.c
wcc386 -bt=windows %CDEF% src\core\uhci.c
wcc386 -bt=windows %CDEF% src\core\ohci.c
wcc386 -bt=windows %CDEF% src\core\ehci.c
wcc386 -bt=windows %CDEF% src\core\xhci.c
wcc386 -bt=windows %CDEF% src\core\hub.c
wcc386 -bt=windows %CDEF% src\core\hid.c
wcc386 -bt=windows %CDEF% src\core\ptp.c
wcc386 -bt=windows %CDEF% src\core\ps2tp.c
wcc386 -bt=windows %CDEF% src\core\kbc.c
wcc386 -bt=windows %CDEF% src\core\smbtp.c
wcc386 -bt=windows %CDEF% src\core\i2c.c
wcc386 -bt=windows %CDEF% src\core\dwi2c.c
wcc386 -bt=windows %CDEF% src\core\gpio.c
wcc386 -bt=windows %CDEF% src\core\msc.c
wcc386 -bt=windows %CDEF% src\core\uaudio.c
wcc386 -bt=windows %CDEF% src\core\uvc.c
wcc386 -bt=windows %CDEF% src\core\aeng.c
wcc386 -bt=windows %CDEF% src\core\synth.c
wcc386 -bt=windows %CDEF% src\core\nvme.c
wcc386 -bt=windows %CDEF% src\core\nhi.c
wcc386 -bt=windows %CDEF% src\core\tbt.c
wcc386 -bt=windows %CDEF% src\core\icm.c
wcc386 -bt=windows %CDEF% src\core\pcihp.c
wcc386 -bt=windows %CDEF% src\core\cdrom.c

wcc386 -bt=windows %CDEF% -I\projects\jemm\include src\jlm\platjlm.c

wlib -n -b -q bjlm\core.lib @corejlm.lbc
jwasm -q -I%JEMMINC% -Fobjlm/jlment.obj src/jlm/jlment.asm
jwlink name bjlm/JAIUCORE.DLL @corejlm.lnk

tools\h2incx.exe -b -y -o src/jlm src/inc/winapi.h
jwasm -q -mz -D?MZ -DJLM -Flbjlm/JAIUSB.lst -DPKG_USB -Fobjlm/JAIUSB.SYS src/jlm/jlmstor.asm

if not exist bjlm\tools\NUL mkdir bjlm\tools

wcc -q -ml -bt=dos -DJLM -ox -wx -Isrc/inc -Itools -fo=bjlm/tools/ src/tools/wininfo.c
wcc -q -ml -bt=dos -DJLM -ox -wx -Isrc/inc -Itools -fo=bjlm/tools/ src/tools/winfmt.c
wcc -q -ml -bt=dos -DJLM -ox -wx -Isrc/inc -Itools -fo=bjlm/tools/ src/tools/winfs.c
wcc -q -ms -bt=dos -DJLM -ox -wx -Isrc/inc -Itools -fo=bjlm/tools/ src/tools/dskbench.c
wlink @jaiinfo.lnk
wlink system dos name bjlm/tools/DSKBENCH.EXE file bjlm/tools/dskbench.obj op q,m=bjlm/tools/dskbench.map,stack=4096
