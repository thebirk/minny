@echo off
cl /nologo /c utf8proc.c /DUTF8PROC_STATIC
lib /nologo utf8proc.obj /out:utf8proc.lib
del utf8proc.obj