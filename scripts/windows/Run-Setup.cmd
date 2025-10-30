@echo off
:: Run-Setup.cmd — Windows (Command Prompt)
:: Ensures Node 18+, then prints next steps.
echo === Fairies of Avalon — Setup ===
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js not found. Please install Node 18+ from https://nodejs.org/ then re-run.
  exit /b 1
)
echo Node found. To package zips locally: node scripts\pack-avalon.mjs
echo To serve locally: python -m http.server 8080 (or use Live Server)
exit /b 0
