# LenovoWinPEDrivers

`LenovoWinPEDrivers` is a PowerShell module for discovering Lenovo **WinPE 11** driver packs from Lenovo's official Deployment Recipe Card data.

The module reads Lenovo's machine-readable Recipe Card catalog at:

```text
https://download.lenovo.com/cdrt/ddrc/recipecard.json
```

It does not depend on the hardware of the build machine and does not maintain a static Lenovo model list.

## Design

Lenovo's catalog already contains the relationships between:

```text
Family
  -> Series
    -> Model
      -> Machine Type(s)
        -> Operating System
          -> WinPE Driver Pack
```

The module resolves those relationships directly from Lenovo's current catalog.

## Commands

### List supported Lenovo models

```powershell
Get-LenovoWinPEModel
```

Filter by family or series:

```powershell
Get-LenovoWinPEModel -Family ThinkPad
Get-LenovoWinPEModel -Family ThinkPad -Series 'X-SERIES'
```

Find a model by Machine Type:

```powershell
Get-LenovoWinPEModel -MachineType 21KD
```

### Discover WinPE driver packs

```powershell
Get-LenovoWinPEDriverPackInfo -MachineType 21KD
```

or:

```powershell
Get-LenovoWinPEDriverPackInfo -Model 'ThinkPad X1 Carbon Gen 12'
```

Example result:

```text
Family       : ThinkPad
Series       : X-SERIES
Model        : ThinkPad X1 Carbon Gen 12
MachineTypes : {21KD, 21KC}
OS           : Windows 11
WinPE        : WinPE 11
PackageId    : DS568138
Url          : https://support.lenovo.com/downloads/ds568138
```

Without a selector, all **WinPE 11** mappings in Lenovo's current Recipe Card are returned. WinPE 10 mappings are intentionally ignored.

## Source

The module uses Lenovo-maintained data at runtime:

- [Lenovo Deployment Recipe Card](https://download.lenovo.com/cdrt/ddrc/RecipeCardWeb.html)
- [Lenovo Recipe Card JSON](https://download.lenovo.com/cdrt/ddrc/recipecard.json)

The Recipe Card web application itself resolves models, Machine Types, operating systems, and WinPE pack IDs from this JSON catalog.

## Scope

The initial version focuses on reliable **WinPE 11** catalog discovery and normalization.

It does **not**:

- inspect the hardware of the build machine;
- return or download WinPE 10 driver packs;
- inject drivers into a Windows PE image;
- maintain a static model-to-package mapping;
- scrape Lenovo's Recipe Card HTML.

Package download/extraction will build on the normalized catalog data.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Internet access to `download.lenovo.com`

## License

MIT
