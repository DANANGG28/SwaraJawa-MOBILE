@echo off
if not exist D:\tmp mkdir D:\tmp
set TMP=D:\tmp
set TEMP=D:\tmp
cd /d D:\sjmobile
C:\src\flutter\bin\flutter.bat build apk --debug ^
  --dart-define=SJ_BASE_URL=https://sinau-app.my.id/api ^
  --dart-define=SJ_GOOGLE_SERVER_CLIENT_ID=915311225235-hkpo6fcudhk8gq6dqg4dtd7lb51amr03.apps.googleusercontent.com
