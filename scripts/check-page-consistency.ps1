$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$tutorialsRoot = Join-Path $root 'tutorials'
$errors = [System.Collections.Generic.List[string]]::new()

foreach ($file in Get-ChildItem -LiteralPath $tutorialsRoot -File -Filter '*.html' | Sort-Object Name) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $titleMatch = [regex]::Match($content, '<title>(.*?) \| Documentation</title>')
    $h1Matches = [regex]::Matches($content, '<h1[^>]*>(.*?)</h1>')
    $descriptionMatch = [regex]::Match(
        $content,
        '<meta name="description" content="([^"]+)"'
    )
    $leadMatches = [regex]::Matches($content, '<p class="lead">.*?</p>', 'Singleline')

    if (-not $titleMatch.Success) {
        $errors.Add("$($file.Name): missing normalized title")
    }

    if ($h1Matches.Count -ne 1) {
        $errors.Add("$($file.Name): expected one h1, found $($h1Matches.Count)")
    } elseif ($titleMatch.Success -and $h1Matches[0].Groups[1].Value -cne $titleMatch.Groups[1].Value) {
        $errors.Add(
            "$($file.Name): title and h1 differ ('$($titleMatch.Groups[1].Value)' / '$($h1Matches[0].Groups[1].Value)')"
        )
    }

    if (-not $descriptionMatch.Success) {
        $errors.Add("$($file.Name): missing meta description")
    }

    if ($leadMatches.Count -ne 1) {
        $errors.Add("$($file.Name): expected one lead paragraph, found $($leadMatches.Count)")
    }
}

if ($errors.Count -gt 0) {
    foreach ($errorMessage in $errors) {
        [Console]::Error.WriteLine($errorMessage)
    }

    exit 1
}

Write-Host 'Page consistency check passed'
