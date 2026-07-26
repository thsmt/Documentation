$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$files = Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.html'
$errors = [System.Collections.Generic.List[string]]::new()

& (Join-Path $PSScriptRoot 'sync-page-list.ps1') -Check

foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
    $ids = @{}

    foreach ($match in [regex]::Matches($content, 'id="([^"]+)"')) {
        $ids[$match.Groups[1].Value] = $true
    }

    foreach ($match in [regex]::Matches($content, 'href="#([^"]+)"')) {
        $target = $match.Groups[1].Value
        if (-not $ids.ContainsKey($target)) {
            $relativePath = [System.IO.Path]::GetRelativePath($root, $file.FullName)
            $errors.Add("$relativePath`: missing #$target")
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host 'Page link check passed'
