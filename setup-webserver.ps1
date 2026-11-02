<#
.SYNOPSIS
    Simple web server setup script for testing and development
.DESCRIPTION
    Installs Node.js and http-server for quick local web server setup.
    Useful for testing static websites, HTML files, and web applications.
.PARAMETER Port
    Port number for the web server (default: 8080)
.PARAMETER Directory
    Directory to serve (default: current directory)
.PARAMETER Start
    Automatically start the web server after installation
.EXAMPLE
    .\setup-webserver.ps1
.EXAMPLE
    .\setup-webserver.ps1 -Port 3000 -Start
.EXAMPLE
    .\setup-webserver.ps1 -Directory "C:\Projects\MyApp" -Port 8080 -Start
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [int]$Port = 8080,

    [Parameter(Mandatory=$false)]
    [string]$Directory = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [switch]$Start
)

# Require Administrator for installation
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges for installation."
    Write-Host "Please run as Administrator, or install manually with:" -ForegroundColor Yellow
    Write-Host "  npm install -g http-server" -ForegroundColor Cyan
    Write-Host "  http-server -p $Port" -ForegroundColor Cyan
    exit 1
}

$ErrorActionPreference = "Stop"

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        default   { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Banner
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "   Simple Web Server Setup" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Port: $Port" -ForegroundColor Yellow
Write-Host "Directory: $Directory" -ForegroundColor Yellow
Write-Host "================================================`n" -ForegroundColor Cyan

# Step 1: Check for Chocolatey
Write-Log "Checking for Chocolatey package manager..."
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Log "Installing Chocolatey package manager..."
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Log "Chocolatey installed successfully" "SUCCESS"

        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    } catch {
        Write-Log "Failed to install Chocolatey: $($_.Exception.Message)" "ERROR"
        throw
    }
} else {
    Write-Log "Chocolatey is already installed" "SUCCESS"
}

# Step 2: Check for Node.js
Write-Log "Checking for Node.js..."
$nodeVersion = $null
try {
    $nodeVersion = & node --version 2>&1
} catch {
    Write-Log "Node.js not found"
}

if (-not $nodeVersion) {
    Write-Log "Installing Node.js LTS..."
    try {
        choco install nodejs-lts -y
        Write-Log "Node.js installed successfully" "SUCCESS"

        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        # Verify installation
        $nodeVersion = & node --version 2>&1
        Write-Log "Node.js version: $nodeVersion" "SUCCESS"
    } catch {
        Write-Log "Failed to install Node.js: $($_.Exception.Message)" "ERROR"
        throw
    }
} else {
    Write-Log "Node.js is already installed: $nodeVersion" "SUCCESS"
}

# Step 3: Check npm
Write-Log "Verifying npm..."
try {
    $npmVersion = & npm --version 2>&1
    Write-Log "npm version: $npmVersion" "SUCCESS"
} catch {
    Write-Log "npm not found. Please reinstall Node.js" "ERROR"
    throw "npm is required but not found"
}

# Step 4: Install http-server globally
Write-Log "Checking for http-server..."
$httpServerInstalled = $false
try {
    $null = & http-server --version 2>&1
    $httpServerInstalled = $true
    Write-Log "http-server is already installed" "SUCCESS"
} catch {
    Write-Log "http-server not found, installing..."
}

if (-not $httpServerInstalled) {
    try {
        Write-Log "Installing http-server globally..."
        & npm install -g http-server
        Write-Log "http-server installed successfully" "SUCCESS"

        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    } catch {
        Write-Log "Failed to install http-server: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Step 5: Verify http-server installation
try {
    $httpServerVersion = & http-server --version 2>&1
    Write-Log "http-server version: $httpServerVersion" "SUCCESS"
} catch {
    Write-Log "http-server verification failed" "ERROR"
    throw "http-server installation verification failed"
}

# Step 6: Create a wrapper script for easy server startup
$wrapperScriptPath = Join-Path $PSScriptRoot "start-webserver.ps1"
Write-Log "Creating web server wrapper script: $wrapperScriptPath"

$wrapperScript = @"
<#
.SYNOPSIS
    Start the http-server web server
.DESCRIPTION
    Convenience script to start http-server with common options
.PARAMETER Port
    Port number (default: 8080)
.PARAMETER Directory
    Directory to serve (default: current directory)
.PARAMETER Open
    Open browser automatically
.EXAMPLE
    .\start-webserver.ps1
.EXAMPLE
    .\start-webserver.ps1 -Port 3000 -Open
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=`$false)]
    [int]`$Port = 8080,

    [Parameter(Mandatory=`$false)]
    [string]`$Directory = (Get-Location).Path,

    [Parameter(Mandatory=`$false)]
    [switch]`$Open
)

Write-Host "Starting web server..." -ForegroundColor Cyan
Write-Host "Directory: `$Directory" -ForegroundColor Yellow
Write-Host "Port: `$Port" -ForegroundColor Yellow
Write-Host "URL: http://localhost:`$Port" -ForegroundColor Green
Write-Host "`nPress Ctrl+C to stop the server`n" -ForegroundColor Yellow

`$args = @("-p", `$Port)

if (`$Open) {
    `$args += "-o"
}

# Change to the target directory
Set-Location `$Directory

# Start http-server
& http-server @args
"@

Set-Content -Path $wrapperScriptPath -Value $wrapperScript
Write-Log "Wrapper script created successfully" "SUCCESS"

# Summary
Write-Host "`n================================================" -ForegroundColor Green
Write-Host "   Web Server Setup Complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host "`nInstalled Components:" -ForegroundColor Cyan
Write-Host "  - Node.js (LTS)" -ForegroundColor White
Write-Host "  - npm" -ForegroundColor White
Write-Host "  - http-server" -ForegroundColor White
Write-Host "`nUsage Options:" -ForegroundColor Cyan
Write-Host "`n  Option 1: Use the wrapper script" -ForegroundColor Yellow
Write-Host "    .\start-webserver.ps1" -ForegroundColor White
Write-Host "    .\start-webserver.ps1 -Port 3000" -ForegroundColor White
Write-Host "    .\start-webserver.ps1 -Port 8080 -Open" -ForegroundColor White
Write-Host "`n  Option 2: Use http-server directly" -ForegroundColor Yellow
Write-Host "    http-server -p 8080" -ForegroundColor White
Write-Host "    http-server -p 8080 -o" -ForegroundColor White
Write-Host "    http-server ./public -p 3000" -ForegroundColor White
Write-Host "`n  Common Options:" -ForegroundColor Yellow
Write-Host "    -p <port>    Port number (default: 8080)" -ForegroundColor White
Write-Host "    -o           Open browser automatically" -ForegroundColor White
Write-Host "    -c-1         Disable caching" -ForegroundColor White
Write-Host "    --cors       Enable CORS" -ForegroundColor White
Write-Host "    -g or --gzip Enable gzip compression" -ForegroundColor White
Write-Host "`n================================================`n" -ForegroundColor Green

# Step 7: Optionally start the server
if ($Start) {
    Write-Host "Starting web server now...`n" -ForegroundColor Cyan
    Write-Host "Server URL: http://localhost:$Port" -ForegroundColor Green
    Write-Host "Press Ctrl+C to stop the server`n" -ForegroundColor Yellow

    # Change to target directory
    Set-Location $Directory

    # Start the server
    & http-server -p $Port
} else {
    Write-Host "To start the server, run:" -ForegroundColor Yellow
    Write-Host "  .\start-webserver.ps1" -ForegroundColor Cyan
    Write-Host "Or:" -ForegroundColor Yellow
    Write-Host "  http-server -p $Port`n" -ForegroundColor Cyan
}
