@echo off
setlocal enabledelayedexpansion

:: log file
set "LOG=%~dp0curata_log.txt"
echo === Curatare start: %date% %time% > "%LOG%"

:: ---------------------
:: Self-elevate if needed
:: ---------------------
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo Not running as admin, requesting elevation... >> "%LOG%"
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
echo Running as administrator. >> "%LOG%"

:: ---------------------
:: Paths to clean
:: ---------------------
set "PATHS[1]=%TEMP%"
set "PATHS[2]=%USERPROFILE%\AppData\Local\Temp"
set "PATHS[3]=C:\Windows\SoftwareDistribution\Download"

:: Close common apps that may lock temp files (best-effort)
echo Killing common locking processes... >> "%LOG%"
taskkill /IM chrome.exe /F >nul 2>&1
taskkill /IM msedge.exe /F >nul 2>&1
taskkill /IM firefox.exe /F >nul 2>&1
timeout /t 1 >nul

:: Function-like loop for each path
for /L %%i in (1,1,3) do (
    set "P=!PATHS[%%i]!"
    if exist "!P!" (
        echo --------------------------------------------- >> "%LOG%"
        echo Working on: !P! >> "%LOG%"
        echo Taking ownership: takeown /F "!P!" /R /D Y >> "%LOG%"
        takeown /F "!P!" /R /D Y >> "%LOG%" 2>&1
        echo Granting full control: icacls "!P!" /grant %USERNAME%:F /T /C >> "%LOG%"
        icacls "!P!" /grant %USERNAME%:F /T /C >> "%LOG%" 2>&1

        echo Trying rd /s /q "!P!" >> "%LOG%"
        rd /s /q "!P!" >> "%LOG%" 2>&1

        if exist "!P!" (
            echo rd failed or some files remained; trying PowerShell Remove-Item >> "%LOG%"
            powershell -NoProfile -Command ^
              "try { Remove-Item -LiteralPath '%P%' -Recurse -Force -ErrorAction Stop; Exit 0 } catch { Write-Error \$_.Exception.Message; Exit 1 }" >> "%LOG%" 2>&1
            if exist "!P!" (
                echo Still exists after PowerShell: "!P!" >> "%LOG%"
                echo Possible cause: proces care blocheaza, antivirus sau Controlled Folder Access. >> "%LOG%"
            ) else (
                echo Removed successfully with PowerShell. >> "%LOG%"
                md "!P!" >> "%LOG%" 2>&1
            )
        ) else (
            echo Removed successfully with rd. Recreating folder... >> "%LOG%"
            md "!P!" >> "%LOG%" 2>&1
        )
    ) else (
        echo Path does not exist: !P! >> "%LOG%"
    )
)

:: ---------------------
:: Clear Recycle Bin (PowerShell)
:: ---------------------
echo Clearing Recycle Bin via PowerShell... >> "%LOG%"
powershell -NoProfile -Command "try { Clear-RecycleBin -Force -ErrorAction Stop; Exit 0 } catch { Write-Error \$_.Exception.Message; Exit 1 }" >> "%LOG%" 2>&1
if %errorlevel% EQU 0 (
    echo Recycle Bin cleared. >> "%LOG%"
) else (
    echo Recycle Bin clear failed. >> "%LOG%"
)

:: ---------------------
:: Final notes and exit
:: ---------------------
echo. >> "%LOG%"
echo Curatarea s-a terminat la %date% %time% >> "%LOG%"
echo. Done. Vezi %LOG% pentru detalii.
type "%LOG%"

pause
endlocal
exit /b
