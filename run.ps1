
$ErrorActionPreference = "Stop"
$Root                  = Split-Path -Parent $MyInvocation.MyCommand.Path
$stigs_downloadsPath   = $Root+"\stigs_downloads.csv"
$parsed_STIGsPath      = $Root+"\parsed_STIGs.csv"
$items                 = @()

$py = Join-Path $Root "python-3.14.2-embed-amd64\python.exe"
if (-not (Test-Path $py)) { throw "Missing embedded python: $py" }

# Ensure vendor is present
if (-not (Test-Path (Join-Path $Root "vendor\site-packages\playwright") -PathType Container)) {
    Write-Host "[run] vendor not present; running init.ps1..."
    & (Join-Path $Root "init.ps1")
}

# Remove old files
rm -path $stigs_downloadsPath -ErrorAction SilentlyContinue
rm -path $parsed_STIGsPath    -ErrorAction SilentlyContinue

# Run the python downloader
write-host "Downloading DISA STIG information..." -NoNewline
& $py (Join-Path $Root "run.py")
write-host -NoNewline -ForegroundColor Green "Done"
$csv   = Import-Csv $stigs_downloadsPath
$count = " (Total: "+$csv.Count+")"
write-host $count

# Loop over and parse the names into [name | V# | R# |...]
foreach ($row in $csv){
    $name          = $row.name
    $date          = $row.'Upload Date'
    $link          = $row.Link
    $versionNumber = $null
    $releaseNumber = $null


    # Extract version/release and strip them from $name

    # 1) Version + Release (comma optional, long/short words accepted)
    if ($name -match '(?i)\bver(?:sion)?\s*(\d+)\s*[,;]?\s*(?:rel(?:ease)?)\s*(\d+)\b') {
        $versionNumber = $matches[1]
        $releaseNumber = $matches[2]
        $name = [regex]::Replace($name, '(?i)[\s\-–—,:]*\bver(?:sion)?\s*\d+\s*[,;]?\s*(?:rel(?:ease)?)\s*\d+\b', '')
    }
    # 2) Version only (e.g., "Version 1")
    elseif ($name -match '(?i)\bver(?:sion)?\s*(\d+)\b') {
        $versionNumber = $matches[1]
        $name = [regex]::Replace($name, '(?i)[\s\-–—,:]*\bver(?:sion)?\s*\d+\b', '')
    }
    # 3) (optional) Release only, if you want to catch lone "Rel 5"
    elseif ($name -match '(?i)\brel(?:ease)?\s*(\d+)\b') {
        $releaseNumber = $matches[1]
        $name = [regex]::Replace($name, '(?i)[\s\-–—,:]*\brel(?:ease)?\s*\d+\b', '')
    }

    # tidy leftover spaces/punctuation
    $name = ($name -replace '\s{2,}',' ').Trim(' -–—,:;')



      $items += [pscustomobject]@{
        'Name'    = $name
        'Version' = $versionNumber
        'Release' = $releaseNumber
        'Date'    = $date
        'Link'    = $link
      }
}

# Save CSV next to the script
$items | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $parsed_STIGsPath

#"HTML: $renderedPath"
#"CSV : $csv"
"Rows: $($items.Count)"