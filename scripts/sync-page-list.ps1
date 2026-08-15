param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$tutorialsRoot = Join-Path $root 'tutorials'
$groups = @(
    [pscustomobject]@{
        Label = 'AWS'
        Pages = @(
            [pscustomobject]@{ File = 'cloudformation.html'; Label = 'CloudFormation 運用手順集' }
            [pscustomobject]@{ File = 'aws-cli.html'; Label = 'AWS CLI 特殊対応' }
            [pscustomobject]@{ File = 'aws-cli-reference.html'; Label = 'AWS CLI コマンドリファレンス' }
            [pscustomobject]@{ File = 'eventbridge-scheduler.html'; Label = 'EventBridge Scheduler' }
            [pscustomobject]@{ File = 'amazon-workspaces.html'; Label = 'Amazon WorkSpaces' }
            [pscustomobject]@{ File = 'amazon-ses.html'; Label = 'Amazon SES SMTPリレー' }
            [pscustomobject]@{ File = 'amazon-ses-monitoring.html'; Label = 'Amazon SES 配信監視' }
            [pscustomobject]@{ File = 'amazon-rds-blue-green.html'; Label = 'Amazon RDS Blue/Green Deployments' }
            [pscustomobject]@{ File = 'aws-certificate-manager.html'; Label = 'AWS Certificate Manager (ACM)' }
        )
    }
    [pscustomobject]@{
        Label = 'OS／ミドルウェア'
        Pages = @(
            [pscustomobject]@{ File = 'rhel9.html'; Label = 'Red Hat Enterprise Linux 9' }
            [pscustomobject]@{ File = 'rhel10.html'; Label = 'Red Hat Enterprise Linux 10' }
            [pscustomobject]@{ File = 'amazon-linux-2023.html'; Label = 'Amazon Linux 2023' }
            [pscustomobject]@{ File = 'windows-server-2022.html'; Label = 'Windows Server 2022' }
            [pscustomobject]@{ File = 'windows-server-2025.html'; Label = 'Windows Server 2025' }
 [pscustomobject]@{ File = 'windows-server-2016-upgrade.html'; Label = 'Windows Server 2016 インプレースアップグレード' }
            [pscustomobject]@{ File = 'apache.html'; Label = 'Apache' }
            [pscustomobject]@{ File = 'apache-self-signed-https.html'; Label = 'Apache 自己署名HTTPS化' }
            [pscustomobject]@{ File = 'apache-acm-certificate-update.html'; Label = 'Apache ACM証明書更新' }
            [pscustomobject]@{ File = 'mariadb.html'; Label = 'MariaDB' }
            [pscustomobject]@{ File = 'zabbix-ops.html'; Label = 'Zabbix 6.0 運用手順' }
        )
    }
    [pscustomobject]@{
        Label = '開発／自動化'
        Pages = @(
            [pscustomobject]@{ File = 'git-github-basics.html'; Label = 'Git / GitHub 基本編' }
            [pscustomobject]@{ File = 'git-github-practical.html'; Label = 'Git / GitHub 実践編' }
            [pscustomobject]@{ File = 'terraform.html'; Label = 'Terraform' }
            [pscustomobject]@{ File = 'awx-ansible.html'; Label = 'AWX / Ansible' }
            [pscustomobject]@{ File = 'container.html'; Label = 'コンテナ' }
            [pscustomobject]@{ File = 'github-actions.html'; Label = 'GitHub Actions' }
        )
    }
    [pscustomobject]@{
        Label = 'リファレンス'
        Pages = @(
            [pscustomobject]@{ File = 'troubleshooting.html'; Label = '障害切り分けチェックリスト' }
            [pscustomobject]@{ File = 'eol.html'; Label = 'EOL / ライフサイクル一覧表' }
            [pscustomobject]@{ File = 'glossary.html'; Label = '用語集' }
        )
    }
)
$pages = @(
    foreach ($group in $groups) {
        foreach ($page in $group.Pages) {
            $page
        }
    }
)
$hiddenAliasFiles = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
[void]$hiddenAliasFiles.Add('ec2-rhel9-apache-https.html')
[void]$hiddenAliasFiles.Add('rhel9-apache-tls.html')

$errors = [System.Collections.Generic.List[string]]::new()
$pageFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($page in $pages) {
    [void]$pageFiles.Add($page.File)

    if (-not (Test-Path -LiteralPath (Join-Path $tutorialsRoot $page.File))) {
        $errors.Add("Missing tutorial page: $($page.File)")
    }
}

foreach ($aliasFile in $hiddenAliasFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $tutorialsRoot $aliasFile))) {
        $errors.Add("Missing hidden alias page: $aliasFile")
    }
}

$targets = @(
    Get-Item -LiteralPath (Join-Path $root 'index.html')
    Get-ChildItem -LiteralPath $tutorialsRoot -File -Filter '*.html' |
        Where-Object { -not $hiddenAliasFiles.Contains($_.Name) } |
        Sort-Object Name
)
$pattern = '(?s)    <aside id="site-sidebar" class="sidebar" aria-label="[^"]+">.*?    </aside>'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$updatedCount = 0

foreach ($target in $targets) {
    $isIndex = $target.FullName -eq (Join-Path $root 'index.html')

    if (-not $isIndex -and -not $pageFiles.Contains($target.Name)) {
        $errors.Add("Page list manifest does not include: $($target.Name)")
        continue
    }

    $content = [System.IO.File]::ReadAllText($target.FullName)
    $match = [regex]::Match($content, $pattern)

    if (-not $match.Success) {
        $errors.Add("Sidebar marker not found: $($target.FullName)")
        continue
    }

    $newline = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $hrefPrefix = if ($isIndex) { 'tutorials/' } else { '' }
    $activeFile = if ($isIndex) { $null } else { $target.Name }
    $lines = [System.Collections.Generic.List[string]]::new()

    $lines.Add('    <aside id="site-sidebar" class="sidebar" aria-label="Page list">')
    $lines.Add('      <div class="sidebar-heading">')
    $lines.Add('        <h2>ページ一覧</h2>')
    $lines.Add('        <button class="icon-button sidebar-toggle sidebar-toggle-inline" type="button" aria-controls="site-sidebar" aria-expanded="true" title="ページ一覧を閉じる" aria-label="ページ一覧を閉じる">☰</button>')
    $lines.Add('      </div>')

    foreach ($group in $groups) {
        $lines.Add("      <p class=`"sidebar-group`">$($group.Label)</p>")

        foreach ($page in $group.Pages) {
            $activeClass = if ($page.File -eq $activeFile) { ' class="active"' } else { '' }
            $lines.Add("      <a$activeClass href=`"$hrefPrefix$($page.File)`">$($page.Label)</a>")
        }
    }

    $lines.Add('    </aside>')
    $expected = $lines -join $newline

    if ($match.Value -cne $expected) {
        $relativePath = $target.FullName.Substring($root.Length).TrimStart('\', '/')

        if ($Check) {
            $errors.Add("Page list is out of sync: $relativePath")
            continue
        }

        $updated = $content.Substring(0, $match.Index) + $expected + $content.Substring($match.Index + $match.Length)
        [System.IO.File]::WriteAllText($target.FullName, $updated, $utf8NoBom)
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
    Write-Host 'Page list check passed'
} else {
    Write-Host "Synchronized page list in $updatedCount file(s)"
}
