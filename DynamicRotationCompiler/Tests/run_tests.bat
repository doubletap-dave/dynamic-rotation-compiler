@echo off
REM Test runner for DRC Storage module tests
REM Requires Lua to be installed and in PATH

echo Running DRC Storage Module Tests...
echo.

lua Tests\Storage_Tests.lua

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Tests completed successfully!
    exit /b 0
) else (
    echo.
    echo Tests failed!
    exit /b 1
)
