@echo off
set REPO=C:\Users\Egor\Desktop\projects\GameplayFootball-of_port
set TMP=C:\Users\Egor\AppData\Local\Temp\opencode
set BUILD=%TMP%\gpf-build
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 2

cl /nologo /std:c++17 /EHsc /MD /O2 /Ob2 /GR /Zi /W1 /WX- /DNDEBUG ^
 /D_MBCS /DWIN32 /D_WINDOWS ^
 /DBOOST_FILESYSTEM_NO_LIB /DBOOST_FILESYSTEM_DYN_LINK=1 ^
 /DBOOST_THREAD_NO_LIB /DBOOST_THREAD_DYN_LINK /DBOOST_THREAD_USE_DLL ^
 /DBOOST_ATOMIC_NO_LIB /DBOOST_ATOMIC_DYN_LINK ^
 /DBOOST_CHRONO_NO_LIB /DBOOST_CHRONO_DYN_LINK ^
 /DBOOST_CONTAINER_NO_LIB /DBOOST_CONTAINER_DYN_LINK ^
 /DBOOST_DATE_TIME_NO_LIB /DBOOST_DATE_TIME_DYN_LINK ^
 /I"%REPO%\src" ^
 /I"%REPO%\build-x64\vcpkg_installed\x64-windows\include" ^
 /I"%REPO%\build-x64\vcpkg_installed\x64-windows\include\AL" ^
 /Fo:"%TMP%\skindump.obj" /c "%TMP%\skindump.cpp"
if errorlevel 1 exit /b 3

link /nologo /DEBUG /INCREMENTAL:NO /PDB:"%TMP%\skindump.pdb" /OUT:"%TMP%\skindump.exe" "%TMP%\skindump.obj" ^
 "%BUILD%\determinism_runner.dir\Release\dbquery.obj" ^
 "%BUILD%\determinism_runner.dir\Release\gamedefines.obj" ^
 "%BUILD%\determinism_runner.dir\Release\gametask.obj" ^
 "%BUILD%\determinism_runner.dir\Release\hungarian.obj" ^
 "%BUILD%\determinism_runner.dir\Release\perlin.obj" ^
 "%BUILD%\determinism_runner.dir\Release\utils.obj" ^
 "%BUILD%\Release\gamelib.lib" ^
 "%BUILD%\Release\hidlib.lib" ^
 "%BUILD%\Release\menulib.lib" ^
 "%BUILD%\Release\datalib.lib" ^
 "%BUILD%\Release\leaguelib.lib" ^
 "%BUILD%\Release\gamecontextlib.lib" ^
 "%BUILD%\Release\blunted2.lib" ^
 ws2_32.lib synchronization.lib ^
 "%REPO%\build-x64\vcpkg_installed\x64-windows\lib\boost_filesystem-vc143-mt-x64-1_92.lib" ^
 "%REPO%\build-x64\vcpkg_installed\x64-windows\lib\boost_thread-vc143-mt-x64-1_92.lib" ^
 "%REPO%\build-x64\vcpkg_installed\x64-windows\lib\boost_atomic-vc143-mt-x64-1_92.lib" ^
 "%REPO%\build-x64\vcpkg_installed\x64-windows\lib\boost_chrono-vc143-mt-x64-1_92.lib" ^
 "%REPO%\build-x64\vcpkg_installed\x64-windows\lib\boost_date_time-vc143-mt-x64-1_92.lib" ^
 "%REPO%\build-x64\vcpkg_installed\x64-windows\lib\boost_container-vc143-mt-x64-1_92.lib" ^
 "%REPO%\build-x64\vcpkg_installed\x64-windows\lib\sqlite3.lib" ^
 "%REPO%\build-x64\vcpkg_installed\x64-windows\lib\SDL3_image.lib" ^
 "%REPO%\build-x64\vcpkg_installed\x64-windows\lib\SDL3_ttf.lib" ^
 "%REPO%\build-x64\vcpkg_installed\x64-windows\lib\SDL3.lib" ^
 "%REPO%\build-x64\vcpkg_installed\x64-windows\lib\OpenAL32.lib" ^
 opengl32.lib glu32.lib dbghelp.lib kernel32.lib user32.lib gdi32.lib winspool.lib shell32.lib ole32.lib oleaut32.lib uuid.lib comdlg32.lib advapi32.lib
exit /b %errorlevel%

