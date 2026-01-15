$py = Join-Path $PSScriptRoot "python-3.14.2-embed-amd64\python.exe"
$env:PYTHONPATH = Join-Path $PSScriptRoot "vendor\site-packages"
$env:PLAYWRIGHT_BROWSERS_PATH = Join-Path $PSScriptRoot "vendor\ms-playwright"

& $py (Join-Path $PSScriptRoot "run.py")
