param(
    [string]$Arg1,
    [string]$Arg2
)

$ErrorActionPreference = "Stop"

# =========================
# Path & Directory 설정
# =========================
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$ExtDir     = "Common\"
$ProjectDir = "cpp\"
$TempDir    = "$Arg2" + "cpp_temp\"
$IDLDir     = "..\$ExtDir" + "idl_cpp\"

# 경로를 합친다. <기준경로> <하위경로>
$TempFull    = Join-Path $ScriptRoot $TempDir
$ProjectFull = Join-Path $ScriptRoot $ProjectDir
$IDLFull     = Join-Path $ScriptRoot $IDLDir

# =========================
# 카운터
# =========================
$DeleteFile = 0
$UpdateFile = 0
$NewFile    = 0

# =========================
# 기존 Temp 폴더 삭제
# =========================
if (Test-Path $TempFull) {
    Remove-Item $TempFull -Recurse -Force
}

# =========================
# flatc 실행
# =========================
$errorValue = 0
$flatcExe = Join-Path $ScriptRoot "flatc.exe"

Get-ChildItem -Path $ScriptRoot -Recurse -Filter "*.fbs" | ForEach-Object {
    & $flatcExe `
        -c `
        --cpp-std c++17 `
        --gen-object-api `
        --gen-compare `
        --natural-utf8 `
        -o $TempFull `
        $_.FullName

    if ($LASTEXITCODE -ne 0) {
        Write-Host "================================================================"
        Write-Host "error occurred while processing $($_.FullName)"
        Write-Host ""
        $errorValue = 1
    }
}

if ($errorValue -ne 0) {
    Write-Host "`n`n`nfailed to generate file.`n"

    if ($Arg1 -eq "msbuild") {
        exit $errorValue
    }

    Read-Host "Press Enter to continue..."
    return
}

# =========================
# STEP 1 : 삭제된 파일 제거
# =========================
Write-Host "================================================================"
Write-Host "STEP : delete removed files."
Write-Host "================================================================"

Get-ChildItem $ProjectFull -Recurse -File | ForEach-Object {
    $tempFile = Join-Path $TempFull $_.Name
    if (-not (Test-Path $tempFile)) {
        Remove-Item $_.FullName -Force
        Write-Host "$($_.FullName) deleted"
        $DeleteFile++
    }
}

Write-Host "`n`n"

# =========================
# STEP 2 : 변경된 파일 복사
# =========================
Write-Host "================================================================"
Write-Host "STEP : apply updated files."
Write-Host "================================================================"

Get-ChildItem $ProjectFull -Recurse -File | ForEach-Object {
    $tempFile = Join-Path $TempFull $_.Name
    if (Test-Path $tempFile) {
        if ((Get-FileHash $_.FullName).Hash -ne (Get-FileHash $tempFile).Hash) {
            Copy-Item $tempFile $_.FullName -Force
            Write-Host "$($_.FullName) updated"
            $UpdateFile++
        }
    }
}

Write-Host "`n`n"

# =========================
# STEP 3 : 신규 파일 추가
# =========================
Write-Host "================================================================"
Write-Host "STEP : add new files."
Write-Host "================================================================"

Get-ChildItem $TempFull -Recurse -File | ForEach-Object {
    $destFile = Join-Path $ProjectFull $_.Name
    if (-not (Test-Path $destFile)) {
        Copy-Item $_.FullName $ProjectFull -Force
        Write-Host "$($_.FullName) new file copied."
        $NewFile++
    }
}

Write-Host "`n`n"

# =========================
# Temp 디렉토리 제거
# =========================
Write-Host "================================================================"
Write-Host "STEP : remove temp directory."
Write-Host "================================================================"
Remove-Item $TempFull -Recurse -Force

Write-Host "`n`n"

# =========================
# Common(IDL) 디렉토리 복사
# =========================
Write-Host "================================================================"
Write-Host "STEP : copy common directory."
Write-Host "================================================================"

if (Test-Path $IDLFull) {
    Remove-Item $IDLFull -Recurse -Force
}

Copy-Item "$ProjectFull*" $IDLFull -Recurse -Force

Write-Host "`n`n"

# =========================
# 결과 출력
# =========================
Write-Host "================================================================"
Write-Host "delete file : $DeleteFile"
Write-Host "update file : $UpdateFile"
Write-Host "New file    : $NewFile"
Write-Host "================================================================"
Write-Host "`n`n"

# =========================
# 종료 처리
# =========================
if ($Arg1 -eq "msbuild") {
    exit
}

Start-Sleep -Seconds 3

if ($Arg1 -eq "exit") {
    exit
}
