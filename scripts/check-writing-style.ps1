$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$targetFiles = Get-ChildItem -LiteralPath $repositoryRoot -Recurse -File |
    Where-Object {
        $_.Extension -in ".html", ".md" -and
        $_.FullName -notmatch "[\\/]\.git[\\/]"
    }

$fullStop = [char]0x3002
$patterns = [string[]]@(
    ([regex]::Escape($fullStop) + "\s*</(p|li|td|th|strong|div|h[1-6]|figcaption)>")
    ([regex]::Escape($fullStop) + "\s*$")
)

$violations = foreach ($file in $targetFiles) {
    Select-String -LiteralPath $file.FullName -Encoding UTF8 -Pattern $patterns
}

if ($violations) {
    $violations | ForEach-Object {
        "{0}:{1}: {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim()
    }
    throw "Japanese full stop found at the end of a sentence"
}

$htmlFiles = $targetFiles | Where-Object { $_.Extension -eq ".html" }
$blockPattern = [regex]::new(
    "<(?<tag>p|li|td|th|strong|figcaption)(?:\s[^>]*)?>(?<body>.*?)</\k<tag>>",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$politeEnding = "(ます|です|ません|ました)$"
$procedureVerbEnding = "(する|できる|なる|れる|られる|[ぁ-ん](る|す|う|む|く|ぐ|つ|ぬ|ぶ))$"
$politeViolations = [System.Collections.Generic.List[string]]::new()
$structuralPoliteEnding = [regex]::new(
    "(ます|です|ません|ました)(?=(?:\s*</(?:a|code|strong|em|span)>)*\s*</(?:div|section|aside|main|article|h[1-6])>)",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$structuralFullStopEnding = [regex]::new(
    [regex]::Escape([string]$fullStop) + "(?=(?:\s*</(?:a|code|strong|em|span)>)*\s*</(?:div|section|aside|main|article|h[1-6])>)",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$codeBlockPattern = [regex]::new(
    '<pre><code(?:\s[^>]*)?>',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)
$wrappedCodeBlockPattern = [regex]::new(
    '<div class="code"(?:\s[^>]*)?>\s*<div class="code-header">.*?</div>\s*<pre><code(?:\s[^>]*)?>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)

foreach ($file in $htmlFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8

    foreach ($match in $structuralPoliteEnding.Matches($content)) {
        $lineNumber = 1 + ([regex]::Matches($content.Substring(0, $match.Index), "`n")).Count
        $politeViolations.Add(
            ("{0}:{1}: structural content ends with a polite form" -f @(
                $file.FullName
                $lineNumber
            ))
        )
    }

    foreach ($match in $structuralFullStopEnding.Matches($content)) {
        $lineNumber = 1 + ([regex]::Matches($content.Substring(0, $match.Index), "`n")).Count
        $politeViolations.Add(
            ("{0}:{1}: structural content ends with a Japanese full stop" -f @(
                $file.FullName
                $lineNumber
            ))
        )
    }

    $codeBlockCount = $codeBlockPattern.Matches($content).Count
    $wrappedCodeBlockCount = $wrappedCodeBlockPattern.Matches($content).Count
    if ($codeBlockCount -ne $wrappedCodeBlockCount) {
        $politeViolations.Add(
            ("{0}: code blocks must use the shared copyable wrapper (total={1}, wrapped={2})" -f @(
                $file.FullName
                $codeBlockCount
                $wrappedCodeBlockCount
            ))
        )
    }

    foreach ($match in $blockPattern.Matches($content)) {
        $text = [regex]::Replace($match.Groups["body"].Value, "<[^>]+>", "")
        $text = [System.Net.WebUtility]::HtmlDecode($text).Trim()
        $textWithoutFullStop = $text.TrimEnd($fullStop)
        $tag = $match.Groups["tag"].Value
        $prefix = $content.Substring(0, $match.Index)
        $isOrderedListItem = $tag -eq "li" -and
            $prefix.LastIndexOf("<ol") -gt $prefix.LastIndexOf("</ol>")
        $isProcedureStep = $tag -eq "p" -and
            $match.Value -match '^<p[^>]*\bclass="[^"]*\bprocedure-step\b'

        if ($textWithoutFullStop -match $politeEnding) {
            $lineNumber = 1 + ([regex]::Matches($content.Substring(0, $match.Index), "`n")).Count
            $message = "{0}:{1}: <{2}> ends with a polite form: {3}" -f @(
                $file.FullName
                $lineNumber
                $match.Groups["tag"].Value
                $text
            )
            $politeViolations.Add($message)
        }

        if (
            ($isOrderedListItem -or $isProcedureStep) -and
            $textWithoutFullStop -match $procedureVerbEnding
        ) {
            $lineNumber = 1 + ([regex]::Matches($content.Substring(0, $match.Index), "`n")).Count
            $message = "{0}:{1}: procedure step should end with an operation name: {2}" -f @(
                $file.FullName
                $lineNumber
                $text
            )
            $politeViolations.Add($message)
        }
    }
}

if ($politeViolations.Count -gt 0) {
    $politeViolations | ForEach-Object { $_ }
    throw "Polite sentence ending found in an HTML content block"
}

Write-Host "Writing style check passed"
