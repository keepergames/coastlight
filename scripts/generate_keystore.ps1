<#
    generate_keystore.ps1 — Keeper of the Cove release signing key generator.

    Creates a JKS keystore for signing release builds, then prints its base64
    encoding plus the exact GitHub Secrets to set. Run this ONCE, store the four
    values as repository secrets, and keep the generated .jks + .txt somewhere
    safe and OFFLINE. They are git-ignored and must never be committed.

    PRIVACY: This script asks you to type every value. It does NOT read your
    machine name, username, IP address, location, or any other system data, and
    it does NOT auto-fill any field. Nothing leaves your computer.

    Requires: keytool (bundled with any JDK; e.g. Temurin 17). Verify with:
        keytool -help
#>

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Keeper of the Cove - release keystore generator" -ForegroundColor Cyan
Write-Host "Enter your COMPANY details below. Nothing is pre-filled." -ForegroundColor DarkGray
Write-Host ""

function Read-Required([string]$Prompt) {
    while ($true) {
        $value = Read-Host $Prompt
        if (-not [string]::IsNullOrWhiteSpace($value)) { return $value.Trim() }
        Write-Host "  This field is required." -ForegroundColor Yellow
    }
}

# --- Company / certificate details (all typed by you, none auto-filled) ---
$org        = Read-Required "Organization (O), e.g. your company name"
$orgUnit    = Read-Required "Organizational Unit (OU), e.g. Mobile"
$commonName = Read-Required "Common Name (CN), e.g. the app or company name"
$city       = Read-Required "City / Locality (L)"
$state      = Read-Required "State / Province (ST)"
$country    = Read-Required "Two-letter Country code (C), e.g. US"

# --- Key identity & secrets ---
$alias = Read-Required "Key alias, e.g. coastlight-release"

$storePassSecure = Read-Host "Keystore password (min 6 chars)" -AsSecureString
$keyPassSecure   = Read-Host "Key password (press Enter to reuse the keystore password)" -AsSecureString

# Convert secure strings to plain text only in-memory for keytool.
$storePass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePassSecure))
$keyPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPassSecure))
if ([string]::IsNullOrWhiteSpace($keyPass)) { $keyPass = $storePass }

if ($storePass.Length -lt 6) { throw "Keystore password must be at least 6 characters." }

$dname = "CN=$commonName, OU=$orgUnit, O=$org, L=$city, ST=$state, C=$country"

$outDir = Join-Path $PSScriptRoot "..\android\app"
$outDir = (Resolve-Path $outDir).Path
$keystorePath = Join-Path $outDir "keeper-release.jks"

if (Test-Path $keystorePath) {
    throw "A keystore already exists at $keystorePath. Move or delete it first (do NOT overwrite a key you already published with)."
}

Write-Host ""
Write-Host "Generating keystore..." -ForegroundColor Cyan

& keytool -genkeypair -v `
    -keystore $keystorePath `
    -storetype JKS `
    -keyalg RSA -keysize 2048 -validity 10000 `
    -alias $alias `
    -dname $dname `
    -storepass $storePass `
    -keypass $keyPass

if ($LASTEXITCODE -ne 0) { throw "keytool failed (exit $LASTEXITCODE). Is the JDK on your PATH?" }

# Base64-encode for the GitHub Secret.
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($keystorePath))
$base64Path = Join-Path $outDir "keeper-release.keystore.base64.txt"
Set-Content -Path $base64Path -Value $base64 -Encoding ascii

Write-Host ""
Write-Host "Done. Keystore: $keystorePath" -ForegroundColor Green
Write-Host "Base64 (for the secret) written to: $base64Path" -ForegroundColor Green
Write-Host ""
Write-Host "Add these four GitHub repository secrets" -ForegroundColor Cyan
Write-Host "(Settings -> Secrets and variables -> Actions -> New repository secret):" -ForegroundColor Cyan
Write-Host ""
Write-Host "  COASTLIGHT_KEYSTORE_BASE64    = the entire contents of keeper-release.keystore.base64.txt"
Write-Host "  COASTLIGHT_KEYSTORE_PASSWORD  = the keystore password you just entered"
Write-Host "  COASTLIGHT_KEY_PASSWORD       = the key password you just entered"
Write-Host "  COASTLIGHT_KEY_ALIAS          = $alias"
Write-Host ""
Write-Host "Keep keeper-release.jks and the base64 file safe and offline. They are" -ForegroundColor Yellow
Write-Host "git-ignored and must NEVER be committed. If you lose this key you cannot" -ForegroundColor Yellow
Write-Host "update the published app." -ForegroundColor Yellow

# Best-effort scrub of plaintext passwords from memory.
$storePass = $null; $keyPass = $null
[GC]::Collect()
