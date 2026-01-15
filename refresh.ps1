$root = $PSScriptRoot
rm -Path $root\vendor -Recurse -Force -ErrorAction SilentlyContinue
rm -Path $root\temp -Recurse -Force -ErrorAction SilentlyContinue
rm -Path $root\python-3.14.2-embed-amd64 -Recurse -Force -ErrorAction SilentlyContinue
rm -path $root\stigs_downloads.csv -ErrorAction SilentlyContinue

