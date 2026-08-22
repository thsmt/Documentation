$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$files = Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.html'
$errors = [System.Collections.Generic.List[string]]::new()

$mainPattern = [regex]::new(
    '<main\b.*?</main>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)
$externalAnchorPattern = [regex]::new(
    '<a\b(?=[^>]*\bhref="https?://[^"]+")[^>]*>.*?</a>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)
$codeBlockPattern = [regex]::new(
    '<pre><code(?:\s[^>]*)?>',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)
$codeElementPattern = [regex]::new(
    '<pre><code(?:\s[^>]*)?>.*?</code></pre>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)
$copyButtonPattern = [regex]::new(
    '<button\s+class="copy"\s+type="button">',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)
$prohibitedLinkPatterns = [string[]]@(
    '(?:詳細については|詳しくは|詳細は)\s*(?:AWS公式手順：|出典：)?\s*<a\b[^>]*href="https?://'
    '<a\b(?=[^>]*href="https?://)[^>]*>.*?</a>\s*(?:を|で|も)?(?:再)?確認'
    '<a\b(?=[^>]*href="https?://)[^>]*>.*?</a>\s*(?:を|も)?参照'
    '(?:AWS|GitHub|Visual Studio Code)公式の(?:AWS公式手順：|出典：)'
    '公式情報\s*[:：]\s*(?:AWS公式手順：|出典：)'
)

& (Join-Path $PSScriptRoot 'sync-page-list.ps1') -Check
& (Join-Path $PSScriptRoot 'sync-home-groups.ps1') -Check
& (Join-Path $PSScriptRoot 'sync-page-shell.ps1') -Check
& (Join-Path $PSScriptRoot 'check-page-consistency.ps1')

foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
    $linkContent = $codeElementPattern.Replace($content, '')
    $relativePath = $file.FullName.Substring($root.Length).TrimStart('\', '/')
    $ids = @{}

    foreach ($match in [regex]::Matches($linkContent, 'id="([^"]+)"')) {
        $ids[$match.Groups[1].Value] = $true
    }

    foreach ($match in [regex]::Matches($linkContent, 'href="#([^"]+)"')) {
        $target = $match.Groups[1].Value
        if (-not $ids.ContainsKey($target)) {
            $errors.Add("$relativePath`: missing #$target")
        }
    }

    if ($content -notmatch '<script\s+src="(?:\.\./)?assets/app\.js(?:\?[^\"]*)?"></script>') {
        $errors.Add("$relativePath`: missing shared assets/app.js")
    }

    $codeBlockCount = $codeBlockPattern.Matches($content).Count
    $copyButtonCount = $copyButtonPattern.Matches($content).Count
    if ($codeBlockCount -ne $copyButtonCount) {
        $errors.Add(
            "$relativePath`: every code block requires one copy button " +
            "(code blocks=$codeBlockCount, copy buttons=$copyButtonCount)"
        )
    }

    $mainMatch = $mainPattern.Match($content)
    if (-not $mainMatch.Success) {
        $errors.Add("$relativePath`: missing main element")
        continue
    }

    foreach ($match in $externalAnchorPattern.Matches($mainMatch.Value)) {
        $prefix = $mainMatch.Value.Substring(0, $match.Index)
        if ($prefix -notmatch '(AWS公式手順：|出典：)\s*$') {
            $lineNumber = 1 + ([regex]::Matches(
                $content.Substring(0, $mainMatch.Index + $match.Index),
                "`n"
            )).Count
            $errors.Add("$relativePath`:$lineNumber`: external link requires a source label")
        }
    }

    foreach ($pattern in $prohibitedLinkPatterns) {
        foreach ($match in [regex]::Matches(
            $mainMatch.Value,
            $pattern,
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        )) {
            $lineNumber = 1 + ([regex]::Matches(
                $content.Substring(0, $mainMatch.Index + $match.Index),
                "`n"
            )).Count
            $errors.Add("$relativePath`:$lineNumber`: replace link-guidance wording with a source label")
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { [Console]::Error.WriteLine($_) }
    exit 1
}

Write-Host 'Page link check passed'
