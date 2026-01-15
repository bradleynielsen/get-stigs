# setup.ps1
# Bootstraps this repo for offline-ish use (no pip/venv needed):
# - Downloads 4 files to ./temp
# - Extracts Python Embedded
# - Extracts 3 wheels into .\vendor\site-packages
# - Ensures python314._pth includes vendor\site-packages + import site
# - Installs Chromium into .\vendor\ms-playwright

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

# ---- Config (4 downloads) ----
$PythonVersion = "3.14.2"
$PythonZipUrl   = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip"
$PythonZipName  = "python-$PythonVersion-embed-amd64.zip"
$PythonDirName  = "python-$PythonVersion-embed-amd64"

# Wheels (direct file URLs)
# --- Resolve wheel URLs from PyPI JSON (stable) ---
function Get-PypiWheelUrl {
  param(
    [Parameter(Mandatory)] [string] $Package,
    [Parameter(Mandatory)] [string] $Version,
    [Parameter(Mandatory)] [string] $Filename
  )

  $jsonUrl = "https://pypi.org/pypi/$Package/$Version/json"
  $meta = Invoke-RestMethod -Uri $jsonUrl -UseBasicParsing

  $file = $meta.urls | Where-Object { $_.filename -eq $Filename } | Select-Object -First 1
  if (-not $file) {
    throw "Could not find $Filename on $Package $Version (check version/filename)."
  }
  return $file.url
}

# --- Versions / filenames ---
$PythonVersion = "3.14.2"
$PlaywrightVer = "1.57.0"
$PyeeVer       = "13.0.0"
$GreenletVer   = "3.3.0"

$PythonZipUrl  = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip"

$PlaywrightWhl = "playwright-$PlaywrightVer-py3-none-win_amd64.whl"
$PyeeWhl       = "pyee-$PyeeVer-py3-none-any.whl"
$GreenletWhl   = "greenlet-$GreenletVer-cp314-cp314-win_amd64.whl"

$PlaywrightWhlUrl = Get-PypiWheelUrl -Package "playwright" -Version $PlaywrightVer -Filename $PlaywrightWhl
$PyeeWhlUrl       = Get-PypiWheelUrl -Package "pyee"       -Version $PyeeVer       -Filename $PyeeWhl
$GreenletWhlUrl   = Get-PypiWheelUrl -Package "greenlet"   -Version $GreenletVer   -Filename $GreenletWhl


# ---- Paths ----
$Tmp = Join-Path $Root "temp"
$VendorDir = Join-Path $Root "vendor"
$SitePackages = Join-Path $VendorDir "site-packages"
$BrowserDir = Join-Path $VendorDir "ms-playwright"
$PythonDir = Join-Path $Root $PythonDirName
$PythonExe = Join-Path $PythonDir "python.exe"
$PthFile   = Join-Path $PythonDir "python314._pth"

function Ensure-Dir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Download-File([string]$Url, [string]$OutPath) {
  Write-Host "Downloading: $Url"
  Invoke-WebRequest -Uri $Url -OutFile $OutPath -UseBasicParsing
}

function Expand-Zip([string]$ZipPath, [string]$Dest) {
  Ensure-Dir $Dest
  Expand-Archive -LiteralPath $ZipPath -DestinationPath $Dest -Force
}

function Expand-Wheel-ToSitePackages([string]$WheelPath, [string]$DestSitePackages) {
  # A .whl is a .zip; Expand-Archive wants .zip.
  $zipPath = [System.IO.Path]::ChangeExtension($WheelPath, ".zip")
  Copy-Item -LiteralPath $WheelPath -Destination $zipPath -Force
  Expand-Zip -ZipPath $zipPath -Dest $DestSitePackages
  Remove-Item -LiteralPath $zipPath -Force
}

function Ensure-PythonPth([string]$pthPath) {
  if (-not (Test-Path -LiteralPath $pthPath)) {
    throw "Missing $pthPath (Python embedded did not extract correctly)."
  }

  $lines = Get-Content -LiteralPath $pthPath -ErrorAction Stop

  # Ensure vendor site-packages line exists
  $vendorLine = "..\vendor\site-packages"
  if ($lines -notcontains $vendorLine) {
    $lines += $vendorLine
  }

  # Ensure import site is enabled (uncommented)
  $hasImportSite = $false
  $newLines = foreach ($l in $lines) {
    if ($l.Trim() -eq "import site") { $hasImportSite = $true; $l }
    elseif ($l.Trim() -eq "#import site") { $hasImportSite = $true; "import site" }
    else { $l }
  }
  if (-not $hasImportSite) {
    $newLines += "import site"
  }

  Set-Content -LiteralPath $pthPath -Value $newLines -Encoding ASCII
}

# ---- Run ----
Write-Host "Repo root: $Root"
Ensure-Dir $Tmp
Ensure-Dir $VendorDir
Ensure-Dir $SitePackages
Ensure-Dir $BrowserDir

# 1) Download 4 files
$PythonZipPath = Join-Path $Tmp $PythonZipName
$PlaywrightWhlPath = Join-Path $Tmp $PlaywrightWhlName
$PyeeWhlPath = Join-Path $Tmp $PyeeWhlName
$GreenletWhlPath = Join-Path $Tmp $GreenletWhlName

Download-File $PythonZipUrl $PythonZipPath
Download-File $PlaywrightWhlUrl $PlaywrightWhlPath
Download-File $PyeeWhlUrl $PyeeWhlPath
Download-File $GreenletWhlUrl $GreenletWhlPath

# 2) Extract Python embedded
if (Test-Path -LiteralPath $PythonDir) {
  Write-Host "Python folder already exists: $PythonDir"
} else {
  Write-Host "Extracting Python embedded to: $PythonDir"
  Expand-Zip -ZipPath $PythonZipPath -Dest $PythonDir
}

# 3) Fix python314._pth so embedded python sees vendor\site-packages
Ensure-PythonPth $PthFile

# 4) Extract wheels into vendor\site-packages
Write-Host "Extracting wheels into: $SitePackages"
Expand-Wheel-ToSitePackages $PlaywrightWhlPath $SitePackages
Expand-Wheel-ToSitePackages $PyeeWhlPath $SitePackages
Expand-Wheel-ToSitePackages $GreenletWhlPath $SitePackages

# 5) Sanity check imports (use resolved python.exe)
$PyDir = Join-Path $Root "python-3.14.2-embed-amd64"
$py    = Join-Path $PyDir "python.exe"
if (-not (Test-Path -LiteralPath $py)) { throw "python.exe not found at: $py" }

Write-Host "Checking imports..."
& $py -c "import pyee, greenlet; from playwright.sync_api import sync_playwright; print('imports ok')"


# 6) Install Chromium into vendor\ms-playwright
Write-Host "Installing Chromium (Playwright browsers)..."

$oldEap = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
& $py -m playwright install chromium 2>$null
$ErrorActionPreference = $oldEap

if ($LASTEXITCODE -ne 0) {
  throw "Playwright install chromium failed with exit code $LASTEXITCODE"
}






Write-Host ""
Write-Host "Python: $PythonExe"
Write-Host "Site-packages: $SitePackages"
Write-Host "Playwright browsers: $BrowserDir"
Write-Host "DONE"

#rm -Path $Root\temp -Recurse -Force


