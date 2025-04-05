@echo off
set "BASE_DIR=C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\MyExperts"
set "BASE_URL=https://raw.githubusercontent.com/HashiraBR/mql/main/MyExperts"
set "BASE_URL_CONFIGS=https://raw.githubusercontent.com/HashiraBR/mql/main/Analysis"
set "LAST_CONFIG=out24-mar25"

:: Cria o diretório MyExperts, se não existir
if not exist "%BASE_DIR%" mkdir "%BASE_DIR%"

:: Define um array com os nomes dos EAs
set "EAs=CandleWaveEA PullbackMaster PrismEA TrendPulseEA"

:: Percorre o array e baixa os arquivos
for %%E in (%EAs%) do (
    rem Implementação correta do caminho baseado no exemplo fornecido
    call :DownloadAndOrganize "%%E" "%BASE_URL%/%%E/%%E.ex5" "%BASE_URL_CONFIGS%/%%E/%LAST_CONFIG%/Configs/%%E_%LAST_CONFIG%.set"
)

:: Finaliza o script
exit /b

:DownloadAndOrganize
set "EA_NAME=%~1"
set "EA_FILE_URL=%~2"
set "EA_CONFIG_URL=%~3"
set "EA_DIR=%BASE_DIR%\%EA_NAME%"

:: Cria o diretório do EA, se não existir
if not exist "%EA_DIR%" mkdir "%EA_DIR%"

:: Baixa o arquivo EA
powershell -Command "& {Invoke-WebRequest -Uri '%EA_FILE_URL%' -OutFile '%EA_DIR%\%EA_NAME%.ex5'}"

:: Baixa o arquivo de configuração do EA
powershell -Command "& {Invoke-WebRequest -Uri '%EA_CONFIG_URL%' -OutFile '%EA_DIR%\%EA_NAME%_Config.set'}"

exit /b
