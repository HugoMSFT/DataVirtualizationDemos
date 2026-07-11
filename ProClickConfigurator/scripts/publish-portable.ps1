param(
    [string] $DotNet = "dotnet"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$artifactsRoot = Join-Path $projectRoot "artifacts"
$portableRoot = Join-Path $artifactsRoot "portable"
$buildRoot = Join-Path $artifactsRoot "build"
$windowsProject = Join-Path $projectRoot "src\ProClickConfigurator\ProClickConfigurator.csproj"
$macProject = Join-Path $projectRoot "src\ProClickConfigurator.Mac\ProClickConfigurator.Mac.csproj"
$infoPlist = Join-Path $projectRoot "src\ProClickConfigurator.Mac\Info.plist"
$macPackager = Join-Path $PSScriptRoot "package_macos.py"

function Invoke-Publish {
    param(
        [string] $Project,
        [string] $Runtime,
        [string] $Output
    )

    $publishArguments = @(
        "publish",
        $Project,
        "--configuration", "Release",
        "--runtime", $Runtime,
        "--self-contained", "true",
        "-p:PublishSingleFile=true",
        "-p:IncludeNativeLibrariesForSelfExtract=true",
        "-p:EnableCompressionInSingleFile=true",
        "-p:DebugSymbols=false",
        "-p:DebugType=None",
        "--output", $Output,
        "--verbosity", "quiet"
    )

    & $DotNet @publishArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Publishing $Runtime failed with exit code $LASTEXITCODE."
    }
}

if (Test-Path $portableRoot) {
    Remove-Item $portableRoot -Recurse -Force
}

if (Test-Path $buildRoot) {
    Remove-Item $buildRoot -Recurse -Force
}

New-Item $portableRoot -ItemType Directory | Out-Null
New-Item $buildRoot -ItemType Directory | Out-Null

$windowsOutput = Join-Path $portableRoot "ProClickConfigurator-win-x64"
Invoke-Publish $windowsProject "win-x64" $windowsOutput
Compress-Archive `
    -Path (Join-Path $windowsOutput "*") `
    -DestinationPath (Join-Path $portableRoot "ProClickConfigurator-win-x64.zip")

$python = $null
$pythonCandidates = if ($env:OS -eq "Windows_NT") {
    @("python", "py", "python3")
} else {
    @("python3", "python")
}

foreach ($candidateName in $pythonCandidates) {
    $candidate = Get-Command $candidateName -ErrorAction SilentlyContinue
    if ($null -eq $candidate -or $candidate.Source -like "*\WindowsApps\python*.exe") {
        continue
    }

    $python = $candidate
    break
}

if ($null -eq $python) {
    throw "Python 3 is required to preserve macOS executable permissions."
}

foreach ($runtime in @("osx-arm64", "osx-x64")) {
    $macOutput = Join-Path $buildRoot $runtime
    Invoke-Publish $macProject $runtime $macOutput

    $archive = Join-Path $portableRoot "ProClickConfigurator-$runtime.app.tar.gz"
    & $python.Source $macPackager $macOutput $infoPlist $archive
    if ($LASTEXITCODE -ne 0) {
        throw "Packaging $runtime failed with exit code $LASTEXITCODE."
    }
}

Remove-Item $buildRoot -Recurse -Force
Write-Host "Portable packages created in $portableRoot"
