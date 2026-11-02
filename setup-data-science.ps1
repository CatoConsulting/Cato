<#
.SYNOPSIS
    Data Engineering and Data Science environment setup for Windows
.DESCRIPTION
    Complete development environment setup including:
    - Python (Anaconda distribution with data science packages)
    - R and RStudio
    - Jupyter Lab
    - Databases (PostgreSQL, MongoDB)
    - Big Data tools (Apache Spark)
    - Development tools (VS Code, Git, Docker)
    - Database clients (DBeaver)
    - Cloud CLIs (Azure, AWS)
    - Visualization tools (Power BI Desktop)
.PARAMETER SkipR
    Skip R and RStudio installation
.PARAMETER SkipDatabases
    Skip database installations
.PARAMETER SkipDocker
    Skip Docker Desktop installation
.PARAMETER SkipPowerBI
    Skip Power BI Desktop installation
.EXAMPLE
    .\setup-data-science.ps1
.EXAMPLE
    .\setup-data-science.ps1 -SkipR -SkipPowerBI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$SkipR,

    [Parameter(Mandatory=$false)]
    [switch]$SkipDatabases,

    [Parameter(Mandatory=$false)]
    [switch]$SkipDocker,

    [Parameter(Mandatory=$false)]
    [switch]$SkipPowerBI
)

# Require Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script requires Administrator privileges. Please run as Administrator."
    exit 1
}

$ErrorActionPreference = "Continue"
$LogFile = Join-Path $PSScriptRoot "setup-data-science-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        "SECTION" { "Cyan" }
        default   { "White" }
    }
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $color
    Add-Content -Path $LogFile -Value $logMessage
}

# Progress tracking
$TotalSteps = 15
$CurrentStep = 0

function Show-Progress {
    param([string]$Activity)
    $script:CurrentStep++
    $percent = [math]::Round(($script:CurrentStep / $TotalSteps) * 100)
    Write-Progress -Activity "Data Science Environment Setup" -Status $Activity -PercentComplete $percent
    Write-Log "=== Step $CurrentStep/$TotalSteps: $Activity ===" "SECTION"
}

# Banner
Write-Host "`n" -NoNewline
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   Data Engineering & Data Science Environment Setup" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "This will install a complete data science development environment" -ForegroundColor Yellow
Write-Host "Log file: $LogFile" -ForegroundColor Yellow
Write-Host "================================================================`n" -ForegroundColor Cyan

# Function to refresh environment
function Update-EnvironmentPath {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# Step 1: Install Chocolatey
Show-Progress "Installing Chocolatey Package Manager"
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Log "Installing Chocolatey..."
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Update-EnvironmentPath
        Write-Log "Chocolatey installed successfully" "SUCCESS"
    } catch {
        Write-Log "Failed to install Chocolatey: $($_.Exception.Message)" "ERROR"
        throw
    }
} else {
    Write-Log "Chocolatey already installed" "SUCCESS"
}

# Step 2: Install Python (Anaconda Distribution)
Show-Progress "Installing Anaconda Python Distribution"
if (-not (Get-Command conda -ErrorAction SilentlyContinue)) {
    Write-Log "Installing Anaconda3..."
    try {
        choco install anaconda3 -y
        Update-EnvironmentPath
        Write-Log "Anaconda installed successfully" "SUCCESS"

        # Initialize conda for PowerShell
        Write-Log "Initializing conda for PowerShell..."
        & conda init powershell
        Write-Log "Please restart your terminal after setup completes to use conda" "WARNING"
    } catch {
        Write-Log "Failed to install Anaconda: $($_.Exception.Message)" "ERROR"
    }
} else {
    Write-Log "Anaconda already installed" "SUCCESS"
}

# Step 3: Install Git
Show-Progress "Installing Git for Version Control"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Log "Installing Git..."
    try {
        choco install git -y
        Update-EnvironmentPath
        Write-Log "Git installed successfully" "SUCCESS"
    } catch {
        Write-Log "Failed to install Git: $($_.Exception.Message)" "ERROR"
    }
} else {
    Write-Log "Git already installed" "SUCCESS"
}

# Step 4: Install Visual Studio Code
Show-Progress "Installing Visual Studio Code"
if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Log "Installing VS Code..."
    try {
        choco install vscode -y
        Update-EnvironmentPath
        Start-Sleep -Seconds 5

        # Install essential extensions
        Write-Log "Installing VS Code extensions..."
        $extensions = @(
            "ms-python.python",
            "ms-python.vscode-pylance",
            "ms-toolsai.jupyter",
            "ms-toolsai.jupyter-keymap",
            "ms-toolsai.jupyter-renderers",
            "ms-toolsai.vscode-jupyter-cell-tags",
            "ms-toolsai.vscode-jupyter-slideshow",
            "donjayamanne.githistory",
            "eamodio.gitlens",
            "ms-vscode.powershell",
            "redhat.vscode-yaml",
            "ms-azuretools.vscode-docker"
        )

        foreach ($ext in $extensions) {
            try {
                code --install-extension $ext --force 2>&1 | Out-Null
            } catch {
                Write-Log "Failed to install extension $ext" "WARNING"
            }
        }
        Write-Log "VS Code and extensions installed successfully" "SUCCESS"
    } catch {
        Write-Log "Failed to install VS Code: $($_.Exception.Message)" "ERROR"
    }
} else {
    Write-Log "VS Code already installed" "SUCCESS"
}

# Step 5: Install R and RStudio
if (-not $SkipR) {
    Show-Progress "Installing R and RStudio"

    if (-not (Get-Command R -ErrorAction SilentlyContinue)) {
        Write-Log "Installing R..."
        try {
            choco install r.project -y
            Update-EnvironmentPath
            Write-Log "R installed successfully" "SUCCESS"
        } catch {
            Write-Log "Failed to install R: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Log "R already installed" "SUCCESS"
    }

    if (-not (Test-Path "C:\Program Files\RStudio\rstudio.exe")) {
        Write-Log "Installing RStudio..."
        try {
            choco install r.studio -y
            Write-Log "RStudio installed successfully" "SUCCESS"
        } catch {
            Write-Log "Failed to install RStudio: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Log "RStudio already installed" "SUCCESS"
    }
} else {
    Write-Log "Skipping R and RStudio installation" "WARNING"
}

# Step 6: Install PostgreSQL
if (-not $SkipDatabases) {
    Show-Progress "Installing PostgreSQL Database"

    if (-not (Test-Path "C:\Program Files\PostgreSQL\*\bin\psql.exe")) {
        Write-Log "Installing PostgreSQL..."
        try {
            choco install postgresql -y
            Update-EnvironmentPath
            Write-Log "PostgreSQL installed successfully" "SUCCESS"
            Write-Log "Default credentials - User: postgres, Password: set during installation" "WARNING"
        } catch {
            Write-Log "Failed to install PostgreSQL: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Log "PostgreSQL already installed" "SUCCESS"
    }

    # Step 7: Install MongoDB
    Show-Progress "Installing MongoDB"

    if (-not (Test-Path "C:\Program Files\MongoDB\Server\*\bin\mongod.exe")) {
        Write-Log "Installing MongoDB..."
        try {
            choco install mongodb -y
            Update-EnvironmentPath
            Write-Log "MongoDB installed successfully" "SUCCESS"
        } catch {
            Write-Log "Failed to install MongoDB: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Log "MongoDB already installed" "SUCCESS"
    }
} else {
    Write-Log "Skipping database installations" "WARNING"
}

# Step 8: Install DBeaver (Universal Database Client)
Show-Progress "Installing DBeaver Database Client"
if (-not (Test-Path "C:\Program Files\DBeaver\dbeaver.exe")) {
    Write-Log "Installing DBeaver..."
    try {
        choco install dbeaver -y
        Write-Log "DBeaver installed successfully" "SUCCESS"
    } catch {
        Write-Log "Failed to install DBeaver: $($_.Exception.Message)" "ERROR"
    }
} else {
    Write-Log "DBeaver already installed" "SUCCESS"
}

# Step 9: Install Docker Desktop
if (-not $SkipDocker) {
    Show-Progress "Installing Docker Desktop"

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Log "Installing Docker Desktop..."
        try {
            choco install docker-desktop -y
            Write-Log "Docker Desktop installed successfully" "SUCCESS"
            Write-Log "Please restart your computer to complete Docker installation" "WARNING"
        } catch {
            Write-Log "Failed to install Docker Desktop: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Log "Docker Desktop already installed" "SUCCESS"
    }
} else {
    Write-Log "Skipping Docker Desktop installation" "WARNING"
}

# Step 10: Install Azure CLI
Show-Progress "Installing Azure CLI"
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Log "Installing Azure CLI..."
    try {
        choco install azure-cli -y
        Update-EnvironmentPath
        Write-Log "Azure CLI installed successfully" "SUCCESS"
    } catch {
        Write-Log "Failed to install Azure CLI: $($_.Exception.Message)" "ERROR"
    }
} else {
    Write-Log "Azure CLI already installed" "SUCCESS"
}

# Step 11: Install AWS CLI
Show-Progress "Installing AWS CLI"
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Log "Installing AWS CLI..."
    try {
        choco install awscli -y
        Update-EnvironmentPath
        Write-Log "AWS CLI installed successfully" "SUCCESS"
    } catch {
        Write-Log "Failed to install AWS CLI: $($_.Exception.Message)" "ERROR"
    }
} else {
    Write-Log "AWS CLI already installed" "SUCCESS"
}

# Step 12: Install Power BI Desktop
if (-not $SkipPowerBI) {
    Show-Progress "Installing Power BI Desktop"

    if (-not (Test-Path "C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe")) {
        Write-Log "Installing Power BI Desktop..."
        try {
            choco install powerbi -y
            Write-Log "Power BI Desktop installed successfully" "SUCCESS"
        } catch {
            Write-Log "Failed to install Power BI Desktop: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Log "Power BI Desktop already installed" "SUCCESS"
    }
} else {
    Write-Log "Skipping Power BI Desktop installation" "WARNING"
}

# Step 13: Install Apache Spark (via PySpark)
Show-Progress "Installing Apache Spark (PySpark)"
Write-Log "PySpark will be installed via conda in the data science environment..."

# Step 14: Create Data Science Conda Environment
Show-Progress "Creating Data Science Conda Environment"
Write-Log "Creating 'datasci' conda environment with essential packages..."

$condaEnvScript = @'
# Create data science environment
conda create -n datasci python=3.11 -y

# Activate environment
conda activate datasci

# Install data science packages
conda install -y numpy pandas scipy matplotlib seaborn scikit-learn

# Install Jupyter
conda install -y jupyter jupyterlab notebook ipykernel

# Install machine learning frameworks
conda install -y tensorflow pytorch torchvision torchaudio cpuonly -c pytorch

# Install big data tools
conda install -y pyspark

# Install database connectors
conda install -y sqlalchemy psycopg2 pymongo

# Install data processing tools
conda install -y dask polars

# Install visualization libraries
conda install -y plotly bokeh altair

# Install statistical libraries
conda install -y statsmodels

# Additional useful packages
pip install streamlit
pip install great-expectations
pip install dbt-core dbt-postgres
pip install apache-airflow

# Register kernel with Jupyter
python -m ipykernel install --user --name datasci --display-name "Python (DataSci)"

echo "Data science environment 'datasci' created successfully!"
'@

$envScriptPath = Join-Path $PSScriptRoot "create-datasci-env.ps1"
Set-Content -Path $envScriptPath -Value $condaEnvScript
Write-Log "Created environment setup script: $envScriptPath" "SUCCESS"
Write-Log "Run this script after restarting your terminal to create the data science environment" "WARNING"

# Step 15: Create workspace directory structure
Show-Progress "Creating Workspace Directory Structure"

$workspaceRoot = Join-Path $env:USERPROFILE "DataScience"
$directories = @(
    $workspaceRoot,
    (Join-Path $workspaceRoot "projects"),
    (Join-Path $workspaceRoot "datasets"),
    (Join-Path $workspaceRoot "notebooks"),
    (Join-Path $workspaceRoot "scripts"),
    (Join-Path $workspaceRoot "models"),
    (Join-Path $workspaceRoot "outputs")
)

Write-Log "Creating workspace structure at: $workspaceRoot"
foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Log "Created: $dir" "SUCCESS"
    } else {
        Write-Log "Exists: $dir" "SUCCESS"
    }
}

# Create README file
$readmePath = Join-Path $workspaceRoot "README.txt"
$readmeContent = @"
====================================================================
  Data Science & Data Engineering Workspace
====================================================================

Welcome to your data science workspace!

DIRECTORY STRUCTURE:
--------------------
projects/   - Your data science and engineering projects
datasets/   - Raw and processed datasets
notebooks/  - Jupyter notebooks
scripts/    - Python/R scripts and utilities
models/     - Trained ML models and serialized objects
outputs/    - Visualizations, reports, and results

INSTALLED TOOLS:
----------------
Core:
  - Anaconda Python (with data science packages)
  - Git for version control
  - Visual Studio Code with extensions

Data Science:
  - Jupyter Lab
  - Python libraries (pandas, numpy, scikit-learn, etc.)
  - TensorFlow and PyTorch
  - R and RStudio

Data Engineering:
  - Apache Spark (PySpark)
  - PostgreSQL
  - MongoDB
  - DBeaver (database client)

Cloud & DevOps:
  - Azure CLI
  - AWS CLI
  - Docker Desktop

Visualization:
  - Power BI Desktop
  - Plotly, Matplotlib, Seaborn

GETTING STARTED:
----------------
1. Restart your terminal to activate conda

2. Create the data science environment:
   .\create-datasci-env.ps1

3. Activate the environment:
   conda activate datasci

4. Start Jupyter Lab:
   jupyter lab

5. Configure Git (if not already):
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"

CONDA ENVIRONMENTS:
-------------------
- base: Default Anaconda environment
- datasci: Your data science environment with all packages

Useful conda commands:
  conda env list              # List all environments
  conda activate datasci      # Activate environment
  conda deactivate            # Deactivate environment
  conda list                  # List installed packages
  conda install <package>     # Install new package

JUPYTER LAB:
------------
Start Jupyter Lab:
  jupyter lab

Access at: http://localhost:8888

Create a new notebook:
  - Click "+" in the file browser
  - Select "Python (DataSci)" kernel

DATABASES:
----------
PostgreSQL:
  - Service: postgresql-x64-<version>
  - Port: 5432
  - User: postgres
  - Connect via: DBeaver or psql

MongoDB:
  - Service: MongoDB
  - Port: 27017
  - Connect via: DBeaver or mongo shell

HELPFUL RESOURCES:
------------------
- Anaconda Docs: https://docs.anaconda.com
- Jupyter Docs: https://jupyter.org/documentation
- Pandas Docs: https://pandas.pydata.org/docs
- Scikit-learn: https://scikit-learn.org
- TensorFlow: https://www.tensorflow.org
- PyTorch: https://pytorch.org
- PySpark: https://spark.apache.org/docs/latest/api/python

NEXT STEPS:
-----------
1. Restart your terminal
2. Run: .\create-datasci-env.ps1
3. Activate: conda activate datasci
4. Start Jupyter: jupyter lab
5. Begin your first project!

====================================================================
Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
====================================================================
"@

Set-Content -Path $readmePath -Value $readmeContent
Write-Log "Created workspace README: $readmePath" "SUCCESS"

# Complete!
Write-Progress -Activity "Data Science Environment Setup" -Completed

Write-Host "`n" -NoNewline
Write-Host "================================================================" -ForegroundColor Green
Write-Host "   Data Science Environment Setup Complete!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green

Write-Host "`nInstalled Components:" -ForegroundColor Cyan
Write-Host "  Core:" -ForegroundColor Yellow
Write-Host "    ✓ Anaconda Python Distribution" -ForegroundColor White
Write-Host "    ✓ Git for Version Control" -ForegroundColor White
Write-Host "    ✓ Visual Studio Code with Extensions" -ForegroundColor White

Write-Host "`n  Data Science:" -ForegroundColor Yellow
Write-Host "    ✓ Jupyter Lab & Notebook" -ForegroundColor White
if (-not $SkipR) {
    Write-Host "    ✓ R and RStudio" -ForegroundColor White
}
Write-Host "    ✓ Python Data Science Libraries" -ForegroundColor White
Write-Host "    ✓ TensorFlow & PyTorch (via conda env)" -ForegroundColor White

if (-not $SkipDatabases) {
    Write-Host "`n  Databases:" -ForegroundColor Yellow
    Write-Host "    ✓ PostgreSQL" -ForegroundColor White
    Write-Host "    ✓ MongoDB" -ForegroundColor White
    Write-Host "    ✓ DBeaver (Database Client)" -ForegroundColor White
}

Write-Host "`n  Data Engineering:" -ForegroundColor Yellow
Write-Host "    ✓ Apache Spark (PySpark via conda)" -ForegroundColor White

Write-Host "`n  Cloud & DevOps:" -ForegroundColor Yellow
Write-Host "    ✓ Azure CLI" -ForegroundColor White
Write-Host "    ✓ AWS CLI" -ForegroundColor White
if (-not $SkipDocker) {
    Write-Host "    ✓ Docker Desktop" -ForegroundColor White
}

if (-not $SkipPowerBI) {
    Write-Host "`n  Visualization:" -ForegroundColor Yellow
    Write-Host "    ✓ Power BI Desktop" -ForegroundColor White
}

Write-Host "`nWorkspace Location:" -ForegroundColor Cyan
Write-Host "  $workspaceRoot" -ForegroundColor White

Write-Host "`nIMPORTANT - Next Steps:" -ForegroundColor Yellow
Write-Host "  1. RESTART YOUR TERMINAL to activate conda" -ForegroundColor White
Write-Host "  2. Run the environment setup script:" -ForegroundColor White
Write-Host "     .\create-datasci-env.ps1" -ForegroundColor Cyan
Write-Host "  3. Activate the data science environment:" -ForegroundColor White
Write-Host "     conda activate datasci" -ForegroundColor Cyan
Write-Host "  4. Start Jupyter Lab:" -ForegroundColor White
Write-Host "     jupyter lab" -ForegroundColor Cyan
Write-Host "  5. Read the workspace guide:" -ForegroundColor White
Write-Host "     $readmePath" -ForegroundColor Cyan

if (-not $SkipDocker) {
    Write-Host "`n  Note: Restart your computer to complete Docker installation" -ForegroundColor Yellow
}

Write-Host "`nLog file saved to: $LogFile" -ForegroundColor Yellow
Write-Host "================================================================`n" -ForegroundColor Green

Write-Log "=== Data Science Environment Setup Completed Successfully ===" "SUCCESS"
