@echo off
setlocal

set files=sokol_app sokol_gfx sokol_time sokol_audio

(for %%a in (%files%) do (
echo Compiling %%a...
cl /nologo /O2 /I..\c /Z7 /c ..\c\%%a.c &&^
lib /nologo %%a.obj /OUT:%%a.lib &&^
del %%a.obj
))

