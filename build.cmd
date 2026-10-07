@echo off
REM build placebo: needs GNAT + gprbuild in PATH (Alire toolchains work)
if not exist obj mkdir obj
if not exist bin mkdir bin
windres assets/icon.rc obj/icon.o
if errorlevel 1 exit /b 1
gprbuild -P ada_clicker.gpr
