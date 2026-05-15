[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$ScannedExtensions = @('.ps1', '.psm1', '.cmd', '.bat')
$ExcludedPathPatterns = @(
    '\.git\',
    '\tests\security_policy\.ps1$'
)

$PolicyRules = @(
    [pscustomobject]@{
        Name = 'No blind process termination'
        Pattern = '(?i)\b(Stop-Process|taskkill\.exe|taskkill)\b'
        Reason = 'GPTOPT must not blindly kill user processes or browser sessions.'
    },
    [pscustomobject]@{
        Name = 'No forced reboot/logoff/shutdown'
        Pattern = '(?i)\b(Restart-Computer|Stop-Computer|shutdown\.exe|shutdown\s+/|logoff\.exe|logoff\s+)\b'
        Reason = 'GPTOPT must never surprise reboot, shut down, or log off the user.'
    },
    [pscustomobject]@{
        Name = 'No game memory or injection APIs'
        Pattern = '(?i)\b(CreateRemoteThread|VirtualAllocEx|WriteProcessMemory|ReadProcessMemory|OpenProcess|SetWindowsHookEx)\b'
        Reason = 'HaloSight must stay telemetry-only and avoid game process memory or injection behavior.'
    },
    [pscustomobject]@{
        Name = 'No synthetic input APIs'
        Pattern = '(?i)\b(SendInput|mouse_event|keybd_event)\b'
        Reason = 'GPTOPT must not manipulate controller, mouse, or keyboard input.'
    },
    [pscustomobject]@{
        Name = 'No Halo priority mutation'
        Pattern = '(?is)HaloInfinite.{0,240}\.PriorityClass\s*='
        Reason = 'Halo priority should remain untouched unless a future measured feature explicitly owns it.'
    },
    [pscustomobject]@{
        Name = 'No browser close logic'
        Pattern = '(?is)\b(chrome|msedge|firefox|browser)\b.{0,240}\b(CloseMainWindow|Kill\(|Stop-Process|taskkill)\b'
        Reason = 'The browser may be the active ChatGPT/Codex session and must not be closed automatically.'
    }
)

$files = Get-ChildItem -LiteralPath $RepoRoot -Recurse -File |
    Where-Object { $ScannedExtensions -contains $_.Extension } |
    Where-Object {
        $path = $_.FullName
        -not ($ExcludedPathPatterns | Where-Object { $path -match $_ })
    }

$violations = foreach ($file in $files) {
    $content = Get-Content -Raw -LiteralPath $file.FullName
    foreach ($rule in $PolicyRules) {
        if ($content -match $rule.Pattern) {
            [pscustomobject]@{
                Rule = $rule.Name
                File = $file.FullName.Replace($RepoRoot.Path, '').TrimStart('\')
                Reason = $rule.Reason
            }
        }
    }
}

if ($violations) {
    $violations | Format-Table -AutoSize
    throw "Security policy scan failed with $($violations.Count) violation(s)."
}

Write-Host '[OK] Security policy scan passed.' -ForegroundColor Green
