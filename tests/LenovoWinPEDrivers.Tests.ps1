Describe 'LenovoWinPEDrivers' {
    BeforeAll {
        $here = $PSScriptRoot
        $repoRoot = Split-Path -Parent $here
        $script:modulePath = Join-Path $repoRoot 'LenovoWinPEDrivers.psd1'
        $script:fixturePath = Join-Path $here 'fixtures\recipecard.sample.json'

        Import-Module $script:modulePath -Force
    }

    It 'imports successfully' {
        Get-Module -Name LenovoWinPEDrivers | Should -Not -BeNullOrEmpty
    }

    It 'resolves a Lenovo model by Machine Type' {
        $result = Get-LenovoWinPEModel -MachineType 21KD -CatalogUri $script:fixturePath

        $result.Model | Should -Be 'ThinkPad X1 Carbon Gen 12'
        $result.Family | Should -Be 'ThinkPad'
        $result.Series | Should -Be 'X-SERIES'
        $result.MachineTypes | Should -Contain '21KC'
    }

    It 'resolves the WinPE package through RecipeCards and WinPEPacks' {
        $result = Get-LenovoWinPEDriverPackInfo -MachineType 21KD -CatalogUri $script:fixturePath

        $result.Model | Should -Be 'ThinkPad X1 Carbon Gen 12'
        $result.OperatingSystem | Should -Be 'Windows 11'
        $result.WinPE | Should -Be 'WinPE 11'
        $result.PackageId | Should -Be 'DS568138'
        $result.Url | Should -Be 'https://support.lenovo.com/downloads/ds568138'
        $result.Available | Should -BeTrue
    }

    It 'supports model-name lookup' {
        $result = Get-LenovoWinPEDriverPackInfo -Model '*Carbon Gen 12' -CatalogUri $script:fixturePath

        @($result).Count | Should -Be 1
        $result.MachineTypes | Should -Contain '21KD'
    }

    It 'returns no result for an unknown Machine Type' {
        $result = @(Get-LenovoWinPEDriverPackInfo -MachineType 9999 -CatalogUri $script:fixturePath)
        $result.Count | Should -Be 0
    }
}
