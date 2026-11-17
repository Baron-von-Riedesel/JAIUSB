@echo off
if not exist bjlm\NUL mkdir bjlm
set WATCOM=\ow20
rem HXRT installed to run OW's Win32 binaries
set PATH=%WATCOM%\binnt;%PATH%
set INCLUDE=%WATCOM%\h;src/inc
if not exist bjlm\tools\NUL mkdir bjlm\tools

wcc -q -ml -bt=dos -ox -wx -Iinc -Itools -fo=bjlm/tools/ src/tools/wininfo.c
wcc -q -ml -bt=dos -ox -wx -Iinc -Itools -fo=bjlm/tools/ src/tools/winfmt.c
wcc -q -ml -bt=dos -ox -wx -Iinc -Itools -fo=bjlm/tools/ src/tools/winfs.c
wcc -q -ms -bt=dos -ox -wx -Iinc -Itools -fo=bjlm/tools/ src/tools/dskbench.c
wlink @jaiinfo.lnk
wlink system dos name bjlm/tools/DSKBENCH.EXE file bjlm/tools/dskbench.obj op q,m=bjlm/tools/dskbench.map,stack=4096
