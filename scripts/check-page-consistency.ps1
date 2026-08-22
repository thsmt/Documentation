$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$tutorialsRoot = Join-Path $root 'tutorials'
$errors = [System.Collections.Generic.List[string]]::new()
$manifestContent = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'sync-page-list.ps1'))
$manifestEntries = [regex]::Matches(
    $manifestContent,
    "\[pscustomobject\]@\{ File = '([^']+)'; Label = '([^']+)' \}"
)

foreach ($entry in $manifestEntries) {
    $fileName = $entry.Groups[1].Value
    $manifestLabel = $entry.Groups[2].Value
    $file = Get-Item -LiteralPath (Join-Path $tutorialsRoot $fileName)
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $titleMatch = [regex]::Match($content, '<title>(.*?) \| Documentation</title>')
    $h1Matches = [regex]::Matches($content, '<h1[^>]*>(.*?)</h1>')
    $descriptionMatch = [regex]::Match(
        $content,
        '<meta name="description" content="([^"]+)"'
    )
    $leadMatches = [regex]::Matches($content, '<p class="lead">.*?</p>', 'Singleline')
    $activeSidebarMatch = [regex]::Match(
        $content,
        '<a class="active" href="([^"]+)">(.*?)</a>',
        'Singleline'
    )

    if (-not $titleMatch.Success) {
        $errors.Add("${fileName}: missing normalized title")
    }

    if ($h1Matches.Count -ne 1) {
        $errors.Add("${fileName}: expected one h1, found $($h1Matches.Count)")
    } elseif ($titleMatch.Success -and $h1Matches[0].Groups[1].Value -cne $titleMatch.Groups[1].Value) {
        $errors.Add(
            "${fileName}: title and h1 differ ('$($titleMatch.Groups[1].Value)' / '$($h1Matches[0].Groups[1].Value)')"
        )
    }

    if ($titleMatch.Success -and $titleMatch.Groups[1].Value -cne $manifestLabel) {
        $errors.Add("${fileName}: manifest label and title differ ('$manifestLabel' / '$($titleMatch.Groups[1].Value)')")
    }

    if (-not $activeSidebarMatch.Success) {
        $errors.Add("${fileName}: active sidebar entry is missing")
    } else {
        if ([System.IO.Path]::GetFileName($activeSidebarMatch.Groups[1].Value) -cne $fileName) {
            $errors.Add("${fileName}: active sidebar URL differs")
        }
        if ($activeSidebarMatch.Groups[2].Value -cne $manifestLabel) {
            $errors.Add("${fileName}: active sidebar label differs from manifest")
        }
    }

    if (-not $descriptionMatch.Success) {
        $errors.Add("${fileName}: missing meta description")
    }

    if ($leadMatches.Count -ne 1) {
        $errors.Add("${fileName}: expected one lead paragraph, found $($leadMatches.Count)")
    }

    $headingLabels = @{}
    foreach ($heading in [regex]::Matches($content, '<h[2-4][^>]*\sid="([^"]+)"[^>]*>(.*?)</h[2-4]>', 'Singleline')) {
        $headingLabels[$heading.Groups[1].Value] = $heading.Groups[2].Value.Trim()
    }

    $tocMatch = [regex]::Match($content, '<aside class="toc".*?</aside>', 'Singleline')
    foreach ($tocLink in [regex]::Matches($tocMatch.Value, '<a[^>]*href="#([^"]+)"[^>]*>(.*?)</a>', 'Singleline')) {
        $targetId = $tocLink.Groups[1].Value
        $tocLabel = $tocLink.Groups[2].Value.Trim()
        if (-not $headingLabels.ContainsKey($targetId)) {
            $errors.Add("${fileName}: TOC target '#$targetId' is missing")
        } elseif ($tocLabel -cne $headingLabels[$targetId]) {
            $errors.Add("${fileName}: TOC label differs for '#$targetId'")
        }
    }

    foreach ($codeBlock in [regex]::Matches($content, '<div class="code"(?: data-prompt="([#$])")?>.*?<pre><code>(.*?)</code></pre>.*?</div>', 'Singleline')) {
        $prompt = $codeBlock.Groups[1].Value
        $codeText = [System.Net.WebUtility]::HtmlDecode($codeBlock.Groups[2].Value)
        if ($prompt -ceq '$' -and $codeText -match '(?m)^\s*\$\s+') {
            $errors.Add("${fileName}: prompt is written directly in code text")
        }
        if ($prompt -ceq '#' -and $codeText -match '(?m)^\s*sudo\s+') {
            $errors.Add("${fileName}: root prompt block still contains sudo")
        }
    }
}

if ($errors.Count -gt 0) {
    foreach ($errorMessage in $errors) {
        [Console]::Error.WriteLine($errorMessage)
    }

    exit 1
}

Write-Host 'Page consistency check passed'
