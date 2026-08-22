param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$indexPath = Join-Path $root 'index.html'
$content = [System.IO.File]::ReadAllText($indexPath)
$newline = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$errors = [System.Collections.Generic.List[string]]::new()
$pageInside = -join @([char]0x30DA, [char]0x30FC, [char]0x30B8, [char]0x5185)

$sidebarMatch = [regex]::Match(
    $content,
    '(?s)<aside id="site-sidebar" class="sidebar" aria-label="Page list">(.*?)</aside>'
)

if (-not $sidebarMatch.Success) {
    throw 'Sidebar marker not found in index.html'
}

$groupMatches = [regex]::Matches(
    $sidebarMatch.Groups[1].Value,
    '(?s)<p class="sidebar-group"><span class="sidebar-group-icon" aria-hidden="true">.*?</span>([^<]+)</p>(.*?)(?=<p class="sidebar-group">|$)'
)
$sectionIds = @('aws-cloud', 'os-server', 'reference')

if ($groupMatches.Count -ne $sectionIds.Count) {
    throw "Expected $($sectionIds.Count) sidebar groups, found $($groupMatches.Count)"
}

$cards = @{}
foreach ($cardMatch in [regex]::Matches($content, '(?s)        <article class="card">.*?</article>')) {
    $hrefMatch = [regex]::Match($cardMatch.Value, 'href="tutorials/([^"]+)"')

    if ($hrefMatch.Success) {
        $cards[$hrefMatch.Groups[1].Value] = $cardMatch.Value
    }
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('      <!-- home-groups:start -->')

for ($groupIndex = 0; $groupIndex -lt $groupMatches.Count; $groupIndex++) {
    $group = $groupMatches[$groupIndex]
    $groupLabel = $group.Groups[1].Value
    $linkMatches = [regex]::Matches($group.Groups[2].Value, 'href="tutorials/([^"]+)"')

    $lines.Add("      <h2 id=`"$($sectionIds[$groupIndex])`">$groupLabel</h2>")
    $lines.Add("      <section class=`"card-grid`" aria-label=`"$groupLabel`">")

    foreach ($linkMatch in $linkMatches) {
        $file = $linkMatch.Groups[1].Value

        if (-not $cards.ContainsKey($file)) {
            $errors.Add("Home card not found for: $file")
            continue
        }

        $lines.Add($cards[$file])
    }

    $lines.Add('      </section>')

    if ($groupIndex -lt ($groupMatches.Count - 1)) {
        $lines.Add('')
    }
}

$lines.Add('      <!-- home-groups:end -->')
$expectedGroups = $lines -join $newline
$groupPattern = if ($content.Contains('<!-- home-groups:start -->')) {
    '(?s)      <!-- home-groups:start -->.*?      <!-- home-groups:end -->'
} else {
    '(?s)      <h2 id="guides">.*?      </section>'
}
$groupBlock = [regex]::Match($content, $groupPattern)

if (-not $groupBlock.Success) {
    $errors.Add('Home group marker not found')
} elseif ($groupBlock.Value -cne $expectedGroups) {
    if ($Check) {
        $errors.Add('Home groups are out of sync')
    } else {
        $content = $content.Substring(0, $groupBlock.Index) +
            $expectedGroups +
            $content.Substring($groupBlock.Index + $groupBlock.Length)
    }
}

$tocLines = [System.Collections.Generic.List[string]]::new()
$tocLines.Add('    <aside class="toc" aria-label="Table of contents">')
$tocLines.Add("      <h2>$pageInside</h2>")

for ($groupIndex = 0; $groupIndex -lt $groupMatches.Count; $groupIndex++) {
    $activeClass = if ($groupIndex -eq 0) { ' class="active"' } else { '' }
    $tocLines.Add("      <a$activeClass href=`"#$($sectionIds[$groupIndex])`">$($groupMatches[$groupIndex].Groups[1].Value)</a>")
}

$tocLines.Add('    </aside>')
$expectedToc = $tocLines -join $newline
$tocMatch = [regex]::Match(
    $content,
    '(?s)    <aside class="toc" aria-label="Table of contents">.*?    </aside>'
)

if (-not $tocMatch.Success) {
    $errors.Add('Home table of contents marker not found')
} elseif ($tocMatch.Value -cne $expectedToc) {
    if ($Check) {
        $errors.Add('Home table of contents is out of sync')
    } else {
        $content = $content.Substring(0, $tocMatch.Index) +
            $expectedToc +
            $content.Substring($tocMatch.Index + $tocMatch.Length)
    }
}

if ($errors.Count -gt 0) {
    foreach ($errorMessage in $errors) {
        [Console]::Error.WriteLine($errorMessage)
    }

    exit 1
}

if ($Check) {
    Write-Host 'Home group check passed'
} else {
    [System.IO.File]::WriteAllText($indexPath, $content, $utf8NoBom)
    Write-Host 'Synchronized home groups'
}
