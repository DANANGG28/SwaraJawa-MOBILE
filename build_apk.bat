@echo off
if not exist D:\tmp mkdir D:\tmp
set TMP=D:\tmp
set TEMP=D:\tmp
cd /d D:\sjmobile
C:\src\flutter\bin\flutter.bat build apk --debug
