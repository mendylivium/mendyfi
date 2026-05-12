# ============================================
#   MendyFi Auto Installer for Windows
#   github.com/mendylivium/mendyfi
# ============================================

param(
    [string]$Action = "install"
)

$ErrorActionPreference = "Stop"

# --- Config ---
$BASE_URL      = "https://github.com/mendylivium/mendyfi/raw/master/binaries"
$INSTALL_DIR   = "C:\mendyfi"
$BINARY_NAME   = "mendyfi.exe"
$SERVICE_NAME  = "MendyFi"
$BINARY_PATH   = Join-Path $INSTALL_DIR $BINARY_NAME
$CERT_FILE     = Join-Path $INSTALL_DIR "cert.pem"
$KEY_FILE      = Join-Path $INSTALL_DIR "key.pem"
$NSSM_EXE      = Join-Path $INSTALL_DIR "nssm.exe"
$NSSM_ZIP_URL  = "https://nssm.cc/release/nssm-2.24.zip"

# --- Console helpers ---
function Info    { param([string]$msg) Write-Host "[INFO] $msg"  -ForegroundColor Cyan }
function Success { param([string]$msg) Write-Host "[OK]   $msg"  -ForegroundColor Green }
function Warn    { param([string]$msg) Write-Host "[WARN] $msg"  -ForegroundColor Yellow }
function Err     { param([string]$msg) Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

function Check-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Err "Run this script as Administrator (Run PowerShell as Administrator)."
    }
}

function Detect-ArchSuffix {
    $arch = $env:PROCESSOR_ARCHITECTURE
    switch ($arch.ToUpperInvariant()) {
        "AMD64" { return "amd64" }
        default { Err "Unsupported architecture '$arch'. Only AMD64 is currently supported for Windows installer." }
    }
}

function Ensure-WorkDir {
    Info "Preparing working directory: $INSTALL_DIR"
    New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null
    Success "Working directory ready."
}

function Download-Binary {
    $archSuffix = Detect-ArchSuffix
    $binaryURL = "$BASE_URL/mendyfi-windows-$archSuffix.exe"

    Info "Downloading binary: $binaryURL"
    try {
        Invoke-WebRequest -Uri $binaryURL -OutFile $BINARY_PATH -UseBasicParsing
    } catch {
        Err "Failed to download binary from: $binaryURL"
    }

    if (-not (Test-Path $BINARY_PATH)) {
        Err "Binary file was not downloaded."
    }

    if ((Get-Item $BINARY_PATH).Length -le 0) {
        Err "Downloaded binary is empty."
    }

    Success "Binary downloaded to: $BINARY_PATH"
}

function Get-ServerIPs {
    $allIPs = New-Object System.Collections.Generic.List[string]

    try {
        $publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5).ToString().Trim()
        if ($publicIP) {
            [void]$allIPs.Add($publicIP)
        }
    } catch {
        Warn "Unable to detect public IP (continuing)."
    }

    try {
        $lanIPs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object {
                $_.IPAddress -and
                $_.IPAddress -notmatch '^127\.' -and
                $_.IPAddress -notmatch '^169\.254\.'
            } |
            Select-Object -ExpandProperty IPAddress

        foreach ($ip in $lanIPs) {
            if ($ip -and -not ($allIPs -contains $ip)) {
                [void]$allIPs.Add($ip)
            }
        }
    } catch {
        Warn "Unable to detect LAN IP addresses (continuing)."
    }

    if ($allIPs.Count -eq 0) {
        [void]$allIPs.Add("127.0.0.1")
    }

    return ,$allIPs
}

function Generate-TLS {
    Info "Generating TLS certificate and key (OpenSSL)..."

    $openssl = Get-Command openssl -ErrorAction SilentlyContinue
    if (-not $openssl) {
        Warn "OpenSSL not found. Skipping cert generation."
        Warn "Install OpenSSL then run manually:"
        Warn "openssl req -x509 -newkey rsa:2048 -keyout $KEY_FILE -out $CERT_FILE -days 365 -nodes -subj \"/CN=<your_ip>\""
        return
    }

    $allIPs = Get-ServerIPs
    $cn = $allIPs[0]
    $san = ($allIPs | ForEach-Object { "IP:$_" }) -join ","

    $confFile = Join-Path $env:TEMP ("mendyfi-openssl-" + [System.Guid]::NewGuid().ToString("N") + ".cnf")
@"
[req]
default_bits = 2048
prompt = no
default_md = sha256
x509_extensions = v3_req
distinguished_name = dn

[dn]
CN = $cn

[v3_req]
subjectAltName = $san
"@ | Set-Content -Path $confFile -Encoding ascii

    try {
        & openssl req -x509 -newkey rsa:2048 -keyout $KEY_FILE -out $CERT_FILE -days 365 -nodes -subj "/CN=$cn" -extensions v3_req -config $confFile | Out-Null
    } catch {
        Warn "OpenSSL certificate generation failed."
    } finally {
        Remove-Item $confFile -Force -ErrorAction SilentlyContinue
    }

    if ((Test-Path $CERT_FILE) -and (Test-Path $KEY_FILE)) {
        Success "TLS certificate: $CERT_FILE"
        Success "TLS key: $KEY_FILE"
        Info "Certificate IPs: $($allIPs -join ', ')"
    } else {
        Warn "TLS files were not fully generated."
    }
}

function Ensure-Nssm {
    if (Test-Path $NSSM_EXE) {
        Success "NSSM found: $NSSM_EXE"
        return
    }

    $existingNssmCmd = Get-Command nssm -ErrorAction SilentlyContinue
    if ($existingNssmCmd) {
        $global:NSSM_EXE = $existingNssmCmd.Source
        Success "NSSM found in PATH: $global:NSSM_EXE"
        return
    }

    Info "Downloading NSSM (service manager)..."
    $tmpZip = Join-Path $env:TEMP ("nssm-" + [System.Guid]::NewGuid().ToString("N") + ".zip")
    $tmpDir = Join-Path $env:TEMP ("nssm-" + [System.Guid]::NewGuid().ToString("N"))

    try {
        Invoke-WebRequest -Uri $NSSM_ZIP_URL -OutFile $tmpZip -UseBasicParsing
        Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force

        $nssmWin64 = Get-ChildItem -Path $tmpDir -Recurse -Filter "nssm.exe" |
            Where-Object { $_.FullName -match "win64" } |
            Select-Object -First 1

        if (-not $nssmWin64) {
            Err "NSSM download succeeded but win64 nssm.exe not found."
        }

        Copy-Item $nssmWin64.FullName $NSSM_EXE -Force
        Success "NSSM installed: $NSSM_EXE"
    } catch {
        Err "Unable to install NSSM automatically. Please install NSSM manually and re-run installer."
    } finally {
        Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
        Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Remove-ServiceIfExists {
    $svc = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
    if (-not $svc) {
        return
    }

    Warn "Service '$SERVICE_NAME' already exists. Removing old service..."

    try {
        Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
    } catch {}

    if (Test-Path $NSSM_EXE) {
        & $NSSM_EXE remove $SERVICE_NAME confirm | Out-Null
    } else {
        & sc.exe delete $SERVICE_NAME | Out-Null
    }

    Start-Sleep -Seconds 2
}

function Install-Service {
    Ensure-Nssm
    Remove-ServiceIfExists

    Info "Registering Windows service via NSSM..."
    & $NSSM_EXE install $SERVICE_NAME $BINARY_PATH | Out-Null
    & $NSSM_EXE set $SERVICE_NAME AppDirectory $INSTALL_DIR | Out-Null
    & $NSSM_EXE set $SERVICE_NAME Start SERVICE_AUTO_START | Out-Null
    & $NSSM_EXE set $SERVICE_NAME DisplayName "MendyFi" | Out-Null
    & $NSSM_EXE set $SERVICE_NAME Description "MendyFi RADIUS Server - github.com/mendylivium/mendyfi" | Out-Null
    & $NSSM_EXE set $SERVICE_NAME AppStdout (Join-Path $INSTALL_DIR "mendyfi.log") | Out-Null
    & $NSSM_EXE set $SERVICE_NAME AppStderr (Join-Path $INSTALL_DIR "mendyfi-error.log") | Out-Null

    Success "Service registered: $SERVICE_NAME"
}

function Start-MendyFiService {
    Info "Starting service: $SERVICE_NAME"
    try {
        Start-Service -Name $SERVICE_NAME
        Start-Sleep -Seconds 2
        $svc = Get-Service -Name $SERVICE_NAME
        if ($svc.Status -eq "Running") {
            Success "MendyFi service is running."
        } else {
            Warn "Service status: $($svc.Status)"
        }
    } catch {
        Warn "Could not start service automatically. Try manually: Start-Service $SERVICE_NAME"
    }
}

function Show-Status {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   MendyFi Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Binary     : $BINARY_PATH"
    Write-Host "Service    : $SERVICE_NAME"
    Write-Host "Work Dir   : $INSTALL_DIR"
    Write-Host "Cert       : $CERT_FILE"
    Write-Host "Key        : $KEY_FILE"
    Write-Host ""
    Write-Host "Useful commands:" -ForegroundColor White
    Write-Host "Get-Service $SERVICE_NAME" -ForegroundColor Yellow
    Write-Host "Restart-Service $SERVICE_NAME" -ForegroundColor Yellow
    Write-Host "Get-Content $INSTALL_DIR\mendyfi.log -Tail 100" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Frontend : http://lite.waspradi.us" -ForegroundColor Cyan
    Write-Host "Login    : admin@<your_server_ip> / admin12345" -ForegroundColor Cyan
    Write-Host ""
}

function Uninstall-MendyFi {
    Warn "Uninstalling MendyFi..."

    try {
        Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
    } catch {}

    if (Test-Path $NSSM_EXE) {
        & $NSSM_EXE remove $SERVICE_NAME confirm | Out-Null
    } else {
        & sc.exe delete $SERVICE_NAME 2>$null | Out-Null
    }

    if (Test-Path $BINARY_PATH) {
        Remove-Item $BINARY_PATH -Force -ErrorAction SilentlyContinue
        Success "Binary removed."
    }

    $confirm = Read-Host "Also delete work directory and all data in '$INSTALL_DIR'? [y/N]"
    if ($confirm -match "^[Yy]$") {
        Remove-Item $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
        Success "Work directory removed."
    } else {
        Warn "Work directory preserved: $INSTALL_DIR"
    }

    Success "MendyFi has been uninstalled."
}

switch ($Action.ToLowerInvariant()) {
    "install" {
        Check-Admin
        Ensure-WorkDir
        Download-Binary
        Generate-TLS
        Install-Service
        Start-MendyFiService
        Show-Status
    }
    "uninstall" {
        Check-Admin
        Uninstall-MendyFi
    }
    default {
        Write-Host "Usage: .\windows_installer.ps1 [install|uninstall]"
        exit 1
    }
}
