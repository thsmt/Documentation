param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$tutorialsRoot = Join-Path $root 'tutorials'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$errors = [System.Collections.Generic.List[string]]::new()
$updatedCount = 0

$topic = -join @([char]0x30C8, [char]0x30D4, [char]0x30C3, [char]0x30AF)
$pageInside = -join @([char]0x30DA, [char]0x30FC, [char]0x30B8, [char]0x5185)
$homeIcon = [char]0x2302

function Get-NormalizedContent {
    param(
        [string]$Content
    )

    $normalized = $Content
    $normalized = $normalized.Replace('<header class="topbar">', '<header class="site-header">')
    $normalized = [regex]::Replace(
        $normalized,
        '(<a class="brand"[^>]*>\s*<img src="\.\./assets/icon\.jpg") alt=""',
        '$1 alt="Documentation icon"'
    )
    $normalized = $normalized.Replace('<main>', '<main class="content">')

    $breadcrumb = @"
      <nav class="breadcrumb" aria-label="Breadcrumb">
        <a href="../"><span class="nav-icon" aria-hidden="true">$homeIcon</span>Home</a>
        <span>$topic</span>
      </nav>
"@
    $normalized = [regex]::Replace(
        $normalized,
        '(?s)      <(?:div|nav) class="breadcrumb"(?: aria-label="Breadcrumb")?>.*?      </(?:div|nav)>',
        $breadcrumb,
        1
    )
    $normalized = [regex]::Replace(
        $normalized,
        '(<aside class="toc"[^>]*>\s*)<h2>[^<]+</h2>',
        "`$1<h2>$pageInside</h2>",
        1
    )

    return $normalized
}

foreach ($file in Get-ChildItem -LiteralPath $tutorialsRoot -File -Filter '*.html' | Sort-Object Name) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $normalized = Get-NormalizedContent -Content $content

    if ($content -cne $normalized) {
        $relativePath = $file.FullName.Substring($root.Length).TrimStart('\', '/')

        if ($Check) {
            $errors.Add("Page shell is out of sync: $relativePath")
            continue
        }

        [System.IO.File]::WriteAllText($file.FullName, $normalized, $utf8NoBom)
        $updatedCount++
    }
}

if ($errors.Count -gt 0) {
    foreach ($errorMessage in $errors) {
        [Console]::Error.WriteLine($errorMessage)
    }

    exit 1
}

if ($Check) {
    Write-Host 'Page shell check passed'
} else {
    Write-Host "Synchronized page shell in $updatedCount file(s)"
}
