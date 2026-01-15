$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$py = Join-Path $Root "python-3.14.2-embed-amd64\python.exe"
if (-not (Test-Path $py)) { throw "Missing embedded python: $py" }

# Ensure vendor is present
if (-not (Test-Path (Join-Path $Root "vendor\site-packages\playwright") -PathType Container)) {
    Write-Host "[run] vendor not present; running init.ps1..."
    & (Join-Path $Root "init.ps1")
}

& $py (Join-Path $Root "run.py")
