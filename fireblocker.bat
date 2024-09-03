@echo off
setlocal EnableDelayedExpansion

:menu
cls
echo ====================
echo  Fireblocker Menu
echo ====================
echo  [1] Start Fireblocker
echo  [2] Stop Fireblocker
echo  [3] Run Low-Intensity Scan
echo  [4] Run Deep Scan
echo  [5] Exit
echo ====================
echo.
set /p choice=Please select an option [1-5]: 

if "%choice%"=="1" goto start_fireblocker
if "%choice%"=="2" goto stop_fireblocker
if "%choice%"=="3" goto scan_low
if "%choice%"=="4" goto scan_deep
if "%choice%"=="5" goto exit

goto menu

:start_fireblocker
echo Starting Fireblocker...
fireblocker.bat start
pause
goto menu

:stop_fireblocker
echo Stopping Fireblocker...
fireblocker.bat stop
pause
goto menu

:scan_low
echo Running Low-Intensity Scan...
fireblocker.bat scan-low
pause
goto menu

:scan_deep
echo Running Deep Scan...
fireblocker.bat scan-deep
pause
goto menu

:exit
exit
