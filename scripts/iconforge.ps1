# Icon Forge Windows/PowerShell entry point. Machine API behavior matches scripts/iconforge.
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$Root = Split-Path -Parent $PSScriptRoot
$GodotCandidates = @(
    $env:ICONFORGE_GODOT,
    $env:ICONSTUDIO_GODOT,
    (Join-Path $Root ".tools\godot/Godot_v4.7.2-stable_win64.exe"),
    (Get-Command godot -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
    (Get-Command godot4 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
) | Where-Object { $_ -and (Test-Path $_) }

if (-not $GodotCandidates -or $GodotCandidates.Count -eq 0) {
    if ($Args -contains "--json") {
        Write-Output '{"success":false,"status":"failed","code":"RUNTIME_START_FAILED","message":"ICONFORGE_GODOT_NOT_FOUND","recommended_action":"check_runtime_installation"}'
    } else {
        Write-Error "ICONFORGE_GODOT_NOT_FOUND: install Godot 4.7.x or set ICONFORGE_GODOT"
    }
    exit 127
}

$Godot = $GodotCandidates[0]
Set-Location $Root
$GodotArgs = @("--path", $Root, "--headless", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--", "--cli") + $Args
& $Godot @GodotArgs
exit $LASTEXITCODE
