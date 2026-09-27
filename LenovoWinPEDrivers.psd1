@{
    RootModule        = 'LenovoWinPEDrivers.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'd67a970a-8d27-422f-8435-ba30df17235c'
    Author            = 'Rory Vossepoel'
    CompanyName       = ''
    Copyright         = '(c) 2026 Rory Vossepoel. Licensed under the MIT License.'
    Description       = 'Discovers Lenovo Windows PE driver packs from Lenovo''s official Deployment Recipe Card catalog.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Get-LenovoWinPEModel'
        'Get-LenovoWinPEDriverPackInfo'
        'Save-LenovoWinPEDriverPack'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('Lenovo', 'WinPE', 'Drivers', 'Deployment', 'OSD', 'WindowsPE', 'Automation', 'ThinkPad', 'ThinkCentre', 'ThinkStation')
            LicenseUri = 'https://github.com/roryvossepoel/LenovoWinPEDrivers/blob/main/LICENSE'
            ProjectUri = 'https://github.com/roryvossepoel/LenovoWinPEDrivers'
            Prerelease = 'preview1'
            ReleaseNotes = 'Initial preview. Discovers Lenovo models and WinPE driver pack mappings directly from Lenovo Deployment Recipe Card JSON.'
        }
    }
}
