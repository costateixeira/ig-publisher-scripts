@ECHO OFF
setlocal

SET dlurl=https://github.com/HL7/fhir-ig-publisher/releases/latest/download/publisher.jar
SET publisher_jar=publisher.jar
SET input_cache_path=%CD%\input-cache\
SET skipPrompts=false
set upper_path=..\
SET scriptdlroot=https://raw.githubusercontent.com/HL7/ig-publisher-scripts/main
SET build_bat_url=%scriptdlroot%/_build.bat
SET build_sh_url=%scriptdlroot%/_build.sh

IF "%~1"=="/f" SET skipPrompts=y

ECHO.
ECHO Checking internet connection...
PING tx.fhir.org -4 -n 1 -w 4000 | FINDSTR TTL && GOTO isonline
ECHO We're offline, can only run the publisher without TX...
SET txoption=-tx n/a

GOTO end

:isonline
ECHO We're online


:checkPublisher
SET "publisher_missing=false"
SET input_cache_path=%CD%\input-cache\
SET publisher_jar=publisher.jar
SET upper_path=..\

IF NOT EXIST "%input_cache_path%%publisher_jar%" (
    IF NOT EXIST "%upper_path%%publisher_jar%" (
        SET "publisher_missing=true"
    )
)


CLS

IF "%publisher_missing%"=="true" (
    SET "default_choice=1"
) ELSE (
    SET "default_choice=2"
)

echo Please select an option:
echo 1. Download or upload publisher
echo 2. Build IG
echo 3. Build IG - force no TX server
echo 4. Build IG continuously
echo 5. Jekyll build
echo 6. Clean up temp directories
echo 7. Exit
echo [Press Enter for default (%default_choice%) or type an option number:]

set /p userChoice="Your choice (press Enter for default): "
if not defined userChoice set userChoice=%default_choice%

echo You selected: %userChoice%

IF "%userChoice%"=="1" GOTO downloadpublisher
IF "%userChoice%"=="2" GOTO publish_once
IF "%userChoice%"=="3" GOTO publish_notx
IF "%userChoice%"=="4" GOTO publish_continuous
IF "%userChoice%"=="5" GOTO debugjekyll
IF "%userChoice%"=="6" GOTO clean
IF "%userChoice%"=="7" EXIT /B



:debugjekyll
    echo Running Jekyll build...
    jekyll build -s temp/pages -d output
GOTO end


:clean
    echo Cleaning up directories...
    if exist ".\input-cache\publisher.jar" (
        echo Preserving publisher.jar and removing other files in .\input-cache...
        move ".\input-cache\publisher.jar" ".\"
        rmdir /s /q ".\input-cache"
        mkdir ".\input-cache"
        move ".\publisher.jar" ".\input-cache"
    ) else (
        if exist ".\input-cache\" (
            rmdir /s /q ".\input-cache"
        )
    )
    if exist ".\temp\" (
        rmdir /s /q ".\temp"
        echo Removed: .\temp
    )
    if exist ".\output\" (
        rmdir /s /q ".\output"
        echo Removed: .\output
    )
    if exist ".\template\" (
        rmdir /s /q ".\template"
        echo Removed: .\template
    )

GOTO end





:downloadpublisher

:processflags
SET ARG=%1
IF DEFINED ARG (
	IF "%ARG%"=="-f" SET FORCE=true
	IF "%ARG%"=="--force" SET FORCE=true
	SHIFT
	GOTO processflags
)

FOR %%x IN ("%CD%") DO SET upper_path=%%~dpx

ECHO.
IF NOT EXIST "%input_cache_path%%publisher_jar%" (
	IF NOT EXIST "%upper_path%%publisher_jar%" (
		SET jarlocation="%input_cache_path%%publisher_jar%"
		SET jarlocationname=Input Cache
		ECHO IG Publisher is not yet in input-cache or parent folder.
		REM we don't use jarlocation below because it will be empty because we're in a bracketed if statement
		GOTO create
	) ELSE (
		ECHO IG Publisher FOUND in parent folder
		SET jarlocation="%upper_path%%publisher_jar%"
		SET jarlocationname=Parent folder
		GOTO upgrade
	)
) ELSE (
	ECHO IG Publisher FOUND in input-cache
	SET jarlocation="%input_cache_path%%publisher_jar%"
	SET jarlocationname=Input Cache
	GOTO upgrade
)

:create
IF DEFINED FORCE (
	MKDIR "%input_cache_path%" 2> NUL
	GOTO download
)

IF "%skipPrompts%"=="y" (
	SET create=Y
) ELSE (
	SET /p create="Download? (Y/N) "
)
IF /I "%create%"=="Y" (
	ECHO Will place publisher jar here: %input_cache_path%%publisher_jar%
	MKDIR "%input_cache_path%" 2> NUL
	GOTO download
)
GOTO done

:upgrade
IF "%skipPrompts%"=="y" (
	SET overwrite=Y
) ELSE (
	SET /p overwrite="Overwrite %jarlocation%? (Y/N) "
)

IF /I "%overwrite%"=="Y" (
	GOTO download
)
GOTO done

:download
ECHO Downloading most recent publisher to %jarlocationname% - it's ~100 MB, so this may take a bit

FOR /f "tokens=4-5 delims=. " %%i IN ('ver') DO SET VERSION=%%i.%%j
IF "%version%" == "10.0" GOTO win10
IF "%version%" == "6.3" GOTO win8.1
IF "%version%" == "6.2" GOTO win8
IF "%version%" == "6.1" GOTO win7
IF "%version%" == "6.0" GOTO vista

ECHO Unrecognized version: %version%
GOTO done

:win10
CALL POWERSHELL -command if ('System.Net.WebClient' -as [type]) {(new-object System.Net.WebClient).DownloadFile(\"%dlurl%\",\"%jarlocation%\") } else { Invoke-WebRequest -Uri "%dlurl%" -Outfile "%jarlocation%" }

GOTO done

:win7
rem this may be triggering the antivirus - bitsadmin.exe is a known threat
rem CALL bitsadmin /transfer GetPublisher /download /priority normal "%dlurl%" "%jarlocation%"

rem this didn't work in win 10
rem CALL Start-BitsTransfer /priority normal "%dlurl%" "%jarlocation%"

rem this should work - untested
call (New-Object Net.WebClient).DownloadFile('%dlurl%', '%jarlocation%')
GOTO done

:win8.1
:win8
:vista
GOTO done



:done




ECHO.
ECHO Updating scripts
IF "%skipPrompts%"=="y" (
	SET updateScripts=Y
) ELSE (
	SET /p updateScripts="Update scripts? (Y/N) "
)
IF /I "%updateScripts%"=="Y" (
	GOTO scripts
)
GOTO end


:scripts

REM Download all batch files (and this one with a new name)

SETLOCAL DisableDelayedExpansion



:dl_script_1
ECHO Updating _build.sh
call POWERSHELL -command if ('System.Net.WebClient' -as [type]) {(new-object System.Net.WebClient).DownloadFile(\"%build_sh_url%\",\"_build.new.sh\") } else { Invoke-WebRequest -Uri "%build_sh_url%" -Outfile "_build.new.sh" }
if %ERRORLEVEL% == 0 goto upd_script_1
echo "Errors encountered during download: %errorlevel%"
goto dl_script_2
:upd_script_1
start copy /y "_build.new.sh" "_build.sh" ^&^& del "_build.new.sh" ^&^& exit


:dl_script_2
ECHO Updating _build.bat
call POWERSHELL -command if ('System.Net.WebClient' -as [type]) {(new-object System.Net.WebClient).DownloadFile(\"%build_sh_url%\",\"_build.new.bat\") } else { Invoke-WebRequest -Uri "%build_sh_url%" -Outfile "_build.new.bat" }
if %ERRORLEVEL% == 0 goto upd_script_2
echo "Errors encountered during download: %errorlevel%"
goto dl_script_2
:upd_script_2
start copy /y "_build.new.bat" "_build.bat" ^&^& del "_build.new.bat" ^&^& exit


IF "%skipPrompts%"=="true" (
  PAUSE
)

GOTO end





:publish_once

SET JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8

IF EXIST "%input_cache_path%\%publisher_jar%" (
	JAVA -jar "%input_cache_path%\%publisher_jar%" -ig . %txoption% %*
) ELSE If exist "..\%publisher_jar%" (
	JAVA -jar "..\%publisher_jar%" -ig . %txoption% %*
) ELSE (
	ECHO IG Publisher NOT FOUND in input-cache or parent folder.  Please run _updatePublisher.  Aborting...
)

GOTO end


:publish_notx
SET txoption=-tx n/a

SET JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8

IF EXIST "%input_cache_path%\%publisher_jar%" (
	JAVA -jar "%input_cache_path%\%publisher_jar%" -ig . %txoption% %*
) ELSE If exist "..\%publisher_jar%" (
	JAVA -jar "..\%publisher_jar%" -ig . %txoption% %*
) ELSE (
	ECHO IG Publisher NOT FOUND in input-cache or parent folder.  Please run _updatePublisher.  Aborting...
)

GOTO end




:publish_continuous

SET JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8

IF EXIST "%input_cache_path%\%publisher_jar%" (
	JAVA -jar "%input_cache_path%\%publisher_jar%" -ig . %txoption% -watch %*
) ELSE If exist "..\%publisher_jar%" (
	JAVA -jar "..\%publisher_jar%" -ig . %txoption% -watch %*
) ELSE (
	ECHO IG Publisher NOT FOUND in input-cache or parent folder.  Please run _updatePublisher.  Aborting...
)

GOTO end


:end