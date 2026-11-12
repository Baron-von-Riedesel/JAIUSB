@echo off
rem create jaiusb.sys with jwasm
tools\h2incx.exe -b -y -o src/jlm src/inc/winapi.h
rem jwasm -q -bin -Flbjlms/JAIUSB.lst -D?KD -DPKG_USB -Fobjlm/JAIUSB.SYS src/jlm/winstor.asm
jwasm -q -mz -D?MZ -Flbdos/JAIUSB.lst -D?KD -DPKG_USB -Fobjlm/JAIUSB.SYS src/jlm/winstor.asm
