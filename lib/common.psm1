<#
.SYNOPSIS
    Common module for Catoconsting PowerShell setup scripts
.DESCRIPTION
    Contains shared functions and utilities used across PowerShell setup scripts
.NOTES
    Usage: Import this module from other scripts, then point it at the log file
    Import-Module "$PSScriptRoot\lib\common.psm1" -Force
    Set-LogFile -Path $LogFile
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive setup scripts write coloured console output')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Setup helpers are not intended for -WhatIf use')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Official Chocolatey install method')]
param()

# Module state. A module cannot see the calling script's variables, so the log
# path and the list of failed steps live here.
$script:LogFile = $null
$script:Failures = [System.Collections.Generic.List[string]]::new()

# Exit codes Chocolatey treats as success (1641/3010 mean a reboot is pending)
$script:ChocoSuccessCodes = @(0, 1605, 1614, 1641, 3010)
$script:ChocoRebootCodes = @(1641, 3010)

# Set the file Write-Log appends to
function Set-LogFile {
    param([string]$Path)
    $script:LogFile = $Path
}

# Logging function
# Usage: Write-Log "message" ["level"]
# ERROR entries are also recorded as failed steps (see Get-SetupFailure)
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $logMessage
    }
    if ($Level -eq "ERROR") {
        $script:Failures.Add($Message)
    }
}

# Return the messages of every ERROR logged since the module was imported
function Get-SetupFailure {
    return $script:Failures.ToArray()
}

# Check if running as Administrator
# Returns $true if running as admin, $false otherwise
function Test-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Require Administrator privileges
# Throws an error if not running as Administrator
function Assert-Administrator {
    if (-NOT (Test-Administrator)) {
        Write-Log "This script requires Administrator privileges" "ERROR"
        throw "Administrator privileges required"
    }
}
Set-Alias -Name Require-Administrator -Value Assert-Administrator

# Install a Chocolatey package and fail loudly if choco reports an error.
# choco is a native program, so a failed install does not throw on its own.
function Invoke-ChocoInstall {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Package
    )
    & choco install $Package -y --no-progress | Out-Host
    $exitCode = $LASTEXITCODE
    if ($exitCode -notin $script:ChocoSuccessCodes) {
        throw "choco install $Package failed with exit code $exitCode"
    }
    if ($exitCode -in $script:ChocoRebootCodes) {
        Write-Log "$Package installed but Windows needs a restart to finish" "WARNING"
    }
}

# Check whether Chocolatey has a package installed (works with choco v1 and v2)
function Test-ChocoPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Package
    )
    $chocoRoot = if ($env:ChocolateyInstall) { $env:ChocolateyInstall } else { Join-Path $env:ProgramData "chocolatey" }
    return Test-Path (Join-Path $chocoRoot "lib\$Package")
}

# Install Chocolatey package manager if not present
function Install-Chocolatey {
    Write-Log "Checking for Chocolatey package manager..."
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Log "Installing Chocolatey package manager..."
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            # Official Chocolatey install method
            $installer = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
            Invoke-Expression $installer

            # Refresh environment variables
            Update-EnvironmentPath

            if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                throw "choco was not found on PATH after installation"
            }
            Write-Log "Chocolatey installed successfully" "SUCCESS"
        } catch {
            Write-Log "Failed to install Chocolatey: $($_.Exception.Message)" "ERROR"
            throw
        }
    } else {
        Write-Log "Chocolatey is already installed" "SUCCESS"
    }
}

# Refresh environment PATH variable
function Update-EnvironmentPath {
    $paths = @(
        [System.Environment]::GetEnvironmentVariable("Path", "Machine"),
        [System.Environment]::GetEnvironmentVariable("Path", "User")
    ) | Where-Object { $_ }
    $env:Path = $paths -join ";"
}

# Install Java JDK 17 (Microsoft distribution)
function Install-JavaJDK17 {
    Write-Log "Checking for Java JDK 17..."
    $javaVersion = $null
    if (Get-Command java -ErrorAction SilentlyContinue) {
        # java -version writes to stderr; collect it as plain text without
        # letting a caller's ErrorActionPreference turn that into an error
        $ErrorActionPreference = "Continue"
        $javaVersion = (& java -version 2>&1 | ForEach-Object { "$_" }) -join " "
    } else {
        Write-Log "Java not found"
    }

    if ($javaVersion -notmatch 'version "17\.') {
        Write-Log "Installing Microsoft OpenJDK 17..."
        try {
            Invoke-ChocoInstall -Package microsoft-openjdk17
            Write-Log "Java JDK 17 installed successfully" "SUCCESS"

            # Refresh environment
            Update-EnvironmentPath
        } catch {
            Write-Log "Failed to install Java JDK 17: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Log "Java JDK 17 is already installed: $javaVersion" "SUCCESS"
    }
}

# Make sure JAVA_HOME points at a real JDK.
# Prefers the machine-wide value the JDK installer sets, and only works one out
# from PATH as a last resort.
function Set-JavaHome {
    $isJdk = { param($dir) $dir -and (Test-Path (Join-Path $dir "bin\java.exe")) }

    $machineHome = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")
    if (& $isJdk $machineHome) {
        $env:JAVA_HOME = $machineHome
        Write-Log "JAVA_HOME is set to: $machineHome" "SUCCESS"
        return
    }

    Write-Log "Setting JAVA_HOME environment variable..."
    $javaPath = (Get-Command java -ErrorAction SilentlyContinue).Source
    if (-not $javaPath) {
        Write-Log "Cannot set JAVA_HOME: java is not on PATH" "WARNING"
        return
    }
    if ($javaPath -match '\\javapath\\') {
        Write-Log "Cannot set JAVA_HOME: java on PATH is the Oracle javapath shim ($javaPath)" "WARNING"
        return
    }

    $javaHome = Split-Path (Split-Path $javaPath -Parent) -Parent
    if (-not (& $isJdk $javaHome)) {
        Write-Log "Cannot set JAVA_HOME: $javaHome does not contain bin\java.exe" "WARNING"
        return
    }
    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "Machine")
    $env:JAVA_HOME = $javaHome
    Write-Log "JAVA_HOME set to: $javaHome" "SUCCESS"
}

# Write a file only when its content changed, keeping a .bak of the old version.
# Lines matching IgnorePattern (e.g. a "Generated:" timestamp) are left out of
# the comparison so they alone do not cause a rewrite.
function Set-FileIfChanged {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Value,

        [string]$IgnorePattern
    )
    $normalize = {
        param($text)
        $lines = ($text -replace "`r", "").TrimEnd() -split "`n"
        if ($IgnorePattern) { $lines = $lines | Where-Object { $_ -notmatch $IgnorePattern } }
        $lines -join "`n"
    }

    if (Test-Path $Path) {
        $current = Get-Content -Path $Path -Raw
        if ((& $normalize $current) -eq (& $normalize $Value)) {
            Write-Log "Unchanged, leaving as is: $Path" "SUCCESS"
            return
        }
        Copy-Item -Path $Path -Destination "$Path.bak" -Force
        Write-Log "Existing file differs; previous version saved to $Path.bak" "WARNING"
    }
    Set-Content -Path $Path -Value $Value
    Write-Log "Wrote: $Path" "SUCCESS"
}

# Export module members
Export-ModuleMember -Function Set-LogFile
Export-ModuleMember -Function Write-Log
Export-ModuleMember -Function Get-SetupFailure
Export-ModuleMember -Function Test-Administrator
Export-ModuleMember -Function Assert-Administrator
Export-ModuleMember -Function Invoke-ChocoInstall
Export-ModuleMember -Function Test-ChocoPackage
Export-ModuleMember -Function Install-Chocolatey
Export-ModuleMember -Function Update-EnvironmentPath
Export-ModuleMember -Function Install-JavaJDK17
Export-ModuleMember -Function Set-JavaHome
Export-ModuleMember -Function Set-FileIfChanged
Export-ModuleMember -Alias Require-Administrator
