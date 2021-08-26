@ECHO OFF
ECHO building android
call flutter build apk --no-sound-null-safety
ECHO android done
ECHO building windows
call flutter build windows --no-sound-null-safety
ECHO windows done