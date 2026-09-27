Set-StrictMode -Version Latest

$script:LenovoRecipeCardUri = 'https://download.lenovo.com/cdrt/ddrc/recipecard.json'

function Get-LenovoWinPECatalog {
    [CmdletBinding()]
    param(
        [string]$CatalogUri = $script:LenovoRecipeCardUri
    )

    try {
        if ($CatalogUri -match '^https?://') {
            return Invoke-RestMethod -Uri $CatalogUri -UseBasicParsing -ErrorAction Stop
        }

        if (Test-Path -LiteralPath $CatalogUri -PathType Leaf) {
            return Get-Content -LiteralPath $CatalogUri -Raw -ErrorAction Stop | ConvertFrom-Json
        }

        throw "Catalog path does not exist: $CatalogUri"
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

        foreach ($winpeId in @($recipe.winpePacks)) {
            $winpeKey = [string]$winpeId
            $winpe = if ($winpeLookup.ContainsKey($winpeKey)) { $winpeLookup[$winpeKey] } else { $null }

            if (-not $winpe) {
                continue
            }

            $url = [string]$winpe.url
            $version = [string]$winpe.version

            if ($version -notmatch '(?i)^WinPE\s*11(?:\b|$)') {
                continue
            }

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


function Resolve-LenovoWinPEDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Pack
    )

    $response = Invoke-WebRequest -Uri $Pack.Url -UseBasicParsing -ErrorAction Stop
    $content = [string]$response.Content

    $normalized = $content -replace '\\/', '/'
    $normalized = [System.Net.WebUtility]::HtmlDecode($normalized)

    $directMatches = [regex]::Matches(
        $normalized,
        'https://download\.lenovo\.com/[^"'']+?\.exe(?:\?[^"'']*)?',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    $directUrls = @(
        $directMatches |
            ForEach-Object { $_.Value } |
            Select-Object -Unique
    )

    $preferred = @($directUrls | Where-Object { $_ -match '(?i)(?:pe11|winpe11)' }) | Select-Object -First 1
    if (-not $preferred) {
        $preferred = $directUrls | Select-Object -First 1
    }

    if ($preferred) {
        return [pscustomobject]@{
            DownloadUrl = $preferred
            FileName    = [IO.Path]::GetFileName(([uri]$preferred).AbsolutePath)
        }
    }

    $fileMatches = [regex]::Matches(
        $normalized,
        '(?i)\b[A-Za-z0-9][A-Za-z0-9._-]*?(?:pe11|winpe11)[A-Za-z0-9._-]*?\.exe\b'
    )
    $fileName = @($fileMatches | ForEach-Object { $_.Value } | Select-Object -Unique) | Select-Object -First 1

    if (-not $fileName) {
        throw "Unable to locate the WinPE 11 package filename on Lenovo support page '$($Pack.Url)'."
    }

    $basePaths = switch ($Pack.Family) {
        'ThinkPad'     { @('https://download.lenovo.com/pccbbs/mobiles/') }
        'ThinkCentre'  { @('https://download.lenovo.com/pccbbs/thinkcentre_drivers/', 'https://download.lenovo.com/pccbbs/desktop/') }
        'ThinkStation' { @('https://download.lenovo.com/pccbbs/thinkstation/', 'https://download.lenovo.com/pccbbs/desktop/') }
        default        { @('https://download.lenovo.com/pccbbs/mobiles/', 'https://download.lenovo.com/pccbbs/desktop/') }
    }

    foreach ($base in $basePaths) {
        $candidate = $base + $fileName
        try {
            $head = Invoke-WebRequest -Uri $candidate -Method Head -UseBasicParsing -ErrorAction Stop
            if ($head.StatusCode -ge 200 -and $head.StatusCode -lt 400) {
                return [pscustomobject]@{
                    DownloadUrl = $candidate
                    FileName    = $fileName
                }
            }
        }
        catch {
            Write-Verbose "Lenovo download candidate did not resolve: $candidate"
        }
    }

    throw "Lenovo WinPE 11 package '$fileName' was found, but its download URL could not be resolved."
}

function Save-LenovoWinPEDriverPack {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9]{4}$')]
        [string]$MachineType,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [switch]$Force
    )

    $pack = @(Get-LenovoWinPEDriverPackInfo -MachineType $MachineType) | Select-Object -First 1
    if (-not $pack) {
        throw "No Lenovo WinPE 11 driver pack was found for Machine Type '$MachineType'."
    }

    $download = Resolve-LenovoWinPEDownload -Pack $pack

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }

    $destination = Join-Path $Path $download.FileName

    if ((Test-Path -LiteralPath $destination) -and -not $Force) {
        return [pscustomobject]@{
            PSTypeName  = 'LenovoWinPEDrivers.Result'
            MachineType = $MachineType.ToUpperInvariant()
            Model       = $pack.Model
            WinPE       = $pack.WinPE
            PackageId   = $pack.PackageId
            FileName    = $download.FileName
            DownloadUrl = $download.DownloadUrl
            Status      = 'Current'
            Path        = $destination
        }
    }

    if (-not $PSCmdlet.ShouldProcess($destination, "Download Lenovo WinPE 11 driver pack $($pack.PackageId)")) {
        return
    }

    Invoke-WebRequest -Uri $download.DownloadUrl -OutFile $destination -UseBasicParsing -ErrorAction Stop

    [pscustomobject]@{
        PSTypeName  = 'LenovoWinPEDrivers.Result'
        MachineType = $MachineType.ToUpperInvariant()
        Model       = $pack.Model
        WinPE       = $pack.WinPE
        PackageId   = $pack.PackageId
        FileName    = $download.FileName
        DownloadUrl = $download.DownloadUrl
        Status      = 'Saved'
        Path        = $destination
    }
}

Export-ModuleMember -Function Get-LenovoWinPEModel, Get-LenovoWinPEDriverPackInfo, Save-LenovoWinPEDriverPack
