[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'out')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$moduleName = 'LenovoWinPEDrivers'
$modulePath = Join-Path $OutputPath $moduleName

if (Test-Path -LiteralPath $modulePath) {
    Remove-Item -LiteralPath $modulePath -Recurse -Force
}

New-Item -ItemType Directory -Path $modulePath -Force | Out-Null

foreach ($file in @(
    'LenovoWinPEDrivers.psd1',
    'LenovoWinPEDrivers.psm1',
    'README.md',
    'LICENSE'
)) {
    $source = Join-Path $PSScriptRoot $file
    if (Test-Path -LiteralPath $source) {
        Copy-Item -LiteralPath $source -Destination $modulePath
    }
}

$manifestPath = Join-Path $modulePath 'LenovoWinPEDrivers.psd1'
$manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop

[pscustomobject]@{
    ModuleName    = $manifest.Name
    ModuleVersion = $manifest.Version.ToString()
    Prerelease    = $manifest.PrivateData.PSData.Prerelease
    Path          = $modulePath
}
