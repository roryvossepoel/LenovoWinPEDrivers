Set-StrictMode -Version Latest

$script:LenovoRecipeCardUri = 'https://download.lenovo.com/cdrt/ddrc/recipecard.json'

function Get-LenovoWinPECatalog {
    [CmdletBinding()]
    param(
        [string]$CatalogUri = $script:LenovoRecipeCardUri
    )

    try {
        Invoke-RestMethod -Uri $CatalogUri -UseBasicParsing -ErrorAction Stop
    }
    catch {
        throw "Unable to retrieve Lenovo Deployment Recipe Card catalog from '$CatalogUri'. $($_.Exception.Message)"
    }
}

function Get-LenovoCatalogModels {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Catalog
    )

    $families = @(
        @{ Name = 'ThinkPad';     Property = 'ThinkPad' }
        @{ Name = 'ThinkCentre';  Property = 'ThinkCentre' }
        @{ Name = 'ThinkStation'; Property = 'ThinkStation' }
        @{ Name = 'Lenovo';       Property = 'Lenovo' }
    )

    foreach ($family in $families) {
        $property = $Catalog.PSObject.Properties[$family.Property]
        if (-not $property) {
            continue
        }

        foreach ($model in @($property.Value)) {
            [pscustomobject]@{
                PSTypeName   = 'LenovoWinPEDrivers.Model'
                Family       = $family.Name
                Series       = $model.series
                Model        = $model.name
                ModelId      = [string]$model.id
                MachineTypes = @($model.types)
                SMBIOS       = @($model.smbios)
                Version      = $model.version
                Image        = $model.image
            }
        }
    }
}

function Get-LenovoWinPEModel {
    [CmdletBinding()]
    param(
        [ValidateSet('ThinkPad','ThinkCentre','ThinkStation','Lenovo')]
        [string]$Family,

        [string]$Series,

        [string]$Model,

        [ValidatePattern('^[A-Za-z0-9]{4}$')]
        [string]$MachineType,

        [string]$CatalogUri = $script:LenovoRecipeCardUri
    )

    $catalog = Get-LenovoWinPECatalog -CatalogUri $CatalogUri
    $models = @(Get-LenovoCatalogModels -Catalog $catalog)

    if ($Family) {
        $models = @($models | Where-Object Family -eq $Family)
    }

    if ($Series) {
        $models = @($models | Where-Object Series -eq $Series)
    }

    if ($Model) {
        $models = @($models | Where-Object Model -like $Model)
    }

    if ($MachineType) {
        $mt = $MachineType.ToUpperInvariant()
        $models = @($models | Where-Object { @($_.MachineTypes | ForEach-Object { ([string]$_).ToUpperInvariant() }) -contains $mt })
    }

    $models | Sort-Object Family, Series, Model
}

function Get-LenovoWinPEDriverPackInfo {
    [CmdletBinding()]
    param(
        [ValidateSet('ThinkPad','ThinkCentre','ThinkStation','Lenovo')]
        [string]$Family,

        [string]$Series,

        [string]$Model,

        [ValidatePattern('^[A-Za-z0-9]{4}$')]
        [string]$MachineType,

        [string]$OperatingSystem,

        [switch]$IncludeUnavailable,

        [string]$CatalogUri = $script:LenovoRecipeCardUri
    )

    $catalog = Get-LenovoWinPECatalog -CatalogUri $CatalogUri
    $models = @(Get-LenovoCatalogModels -Catalog $catalog)

    if ($Family) {
        $models = @($models | Where-Object Family -eq $Family)
    }

    if ($Series) {
        $models = @($models | Where-Object Series -eq $Series)
    }

    if ($Model) {
        $models = @($models | Where-Object Model -like $Model)
    }

    if ($MachineType) {
        $mt = $MachineType.ToUpperInvariant()
        $models = @($models | Where-Object { @($_.MachineTypes | ForEach-Object { ([string]$_).ToUpperInvariant() }) -contains $mt })
    }

    $osLookup = @{}
    foreach ($os in @($catalog.OperatingSystems)) {
        $osLookup[[string]$os.id] = $os
    }

    $winpeLookup = @{}
    foreach ($pack in @($catalog.WinPEPacks)) {
        $winpeLookup[[string]$pack.id] = $pack
    }

    $modelLookup = @{}
    foreach ($item in $models) {
        $modelLookup[[string]$item.ModelId] = $item
    }

    foreach ($recipe in @($catalog.RecipeCards)) {
        $modelId = [string]$recipe.modelId
        if (-not $modelLookup.ContainsKey($modelId)) {
            continue
        }

        $modelInfo = $modelLookup[$modelId]
        $osId = [string]$recipe.osId
        $osInfo = if ($osLookup.ContainsKey($osId)) { $osLookup[$osId] } else { $null }
        $osName = if ($osInfo) { [string]$osInfo.name } else { $osId }

        if ($OperatingSystem -and $osName -notlike $OperatingSystem) {
            continue
        }

        foreach ($winpeId in @($recipe.winpePacks)) {
            $winpeKey = [string]$winpeId
            $winpe = if ($winpeLookup.ContainsKey($winpeKey)) { $winpeLookup[$winpeKey] } else { $null }

            if (-not $winpe) {
                continue
            }

            $url = [string]$winpe.url
            $version = [string]$winpe.version
            $available = -not (
                [string]::IsNullOrWhiteSpace($url) -or
                $url -match '(?i)no winpe' -or
                $url -match '(?i)Import NIC and Storage drivers from the SCCM Driver Pack'
            )

            if (-not $IncludeUnavailable -and -not $available) {
                continue
            }

            $packageId = $null
            if ($url -match '(?i)(ds\d+)') {
                $packageId = $Matches[1].ToUpperInvariant()
            }

            [pscustomobject]@{
                PSTypeName    = 'LenovoWinPEDrivers.DriverPack'
                Family        = $modelInfo.Family
                Series        = $modelInfo.Series
                Model         = $modelInfo.Model
                MachineTypes  = $modelInfo.MachineTypes
                OperatingSystem = $osName
                WinPE         = $version
                PackageId     = $packageId
                Url           = $url
                Available     = $available
                RecipeId      = [string]$recipe.recipeId
                RecipeCreated = $recipe.creationDate
            }
        }
    }
}

Export-ModuleMember -Function Get-LenovoWinPEModel, Get-LenovoWinPEDriverPackInfo
