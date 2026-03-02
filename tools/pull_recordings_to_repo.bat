@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0pull_recordings_to_repo.ps1" %*
