# Data Science & Data Engineering Environment Setup Guide

Complete development environment for personal data science and data engineering work on Windows.

## Overview

This setup script installs everything you need for:
- **Data Analysis** - Pandas, NumPy, data wrangling
- **Machine Learning** - scikit-learn, TensorFlow, PyTorch
- **Big Data Processing** - Apache Spark (PySpark)
- **Database Work** - PostgreSQL, MongoDB, SQL
- **Visualization** - Matplotlib, Seaborn, Plotly, Power BI
- **Statistical Analysis** - SciPy, statsmodels, R
- **Cloud Platforms** - Azure, AWS
- **Workflow Orchestration** - Apache Airflow, dbt

## Quick Start

### Prerequisites

- Windows 10/11
- Administrator privileges
- 30+ GB free disk space
- Internet connection

### Installation

1. **Download the script** to a folder (e.g., `C:\Setup`)

2. **Open PowerShell as Administrator**

3. **Run the setup:**
   ```powershell
   cd C:\Setup
   .\setup-data-science.ps1
   ```

4. **Custom installation** (skip certain components):
   ```powershell
   # Skip R and RStudio
   .\setup-data-science.ps1 -SkipR
   
   # Skip databases
   .\setup-data-science.ps1 -SkipDatabases
   
   # Skip Docker
   .\setup-data-science.ps1 -SkipDocker
   
   # Skip Power BI
   .\setup-data-science.ps1 -SkipPowerBI
   
   # Minimal install (Python + VS Code only)
   .\setup-data-science.ps1 -SkipR -SkipDatabases -SkipDocker -SkipPowerBI
   ```

5. **After installation:**
   - Restart your terminal
   - Run `.\create-datasci-env.ps1` to create the conda environment
   - Restart your computer (if Docker was installed)

## What Gets Installed

### Core Tools

| Tool | Purpose | Size |
|------|---------|------|
| **Anaconda Python** | Python 3.11 + 250+ data science packages | ~3 GB |
| **Git** | Version control | ~250 MB |
| **Visual Studio Code** | Code editor with Python extensions | ~500 MB |

### Data Science Stack

| Component | Description |
|-----------|-------------|
| **Jupyter Lab** | Interactive notebooks |
| **NumPy** | Numerical computing |
| **Pandas** | Data manipulation and analysis |
| **Matplotlib** | Data visualization |
| **Seaborn** | Statistical visualization |
| **Scikit-learn** | Machine learning |
| **TensorFlow** | Deep learning framework |
| **PyTorch** | Deep learning framework |
| **SciPy** | Scientific computing |
| **Statsmodels** | Statistical modeling |

### R Environment (Optional)

| Tool | Purpose |
|------|---------|
| **R** | Statistical programming language |
| **RStudio** | IDE for R |

### Databases (Optional)

| Database | Type | Default Port |
|----------|------|--------------|
| **PostgreSQL** | Relational | 5432 |
| **MongoDB** | NoSQL | 27017 |
| **DBeaver** | Universal database client | - |

### Big Data Tools

| Tool | Purpose |
|------|---------|
| **Apache Spark (PySpark)** | Distributed data processing |
| **Dask** | Parallel computing |
| **Polars** | Fast DataFrame library |

### Cloud Platforms

| CLI | Purpose |
|-----|---------|
| **Azure CLI** | Microsoft Azure management |
| **AWS CLI** | Amazon Web Services management |

### Visualization & BI (Optional)

| Tool | Purpose |
|------|---------|
| **Power BI Desktop** | Business intelligence and dashboards |
| **Plotly** | Interactive visualizations |
| **Bokeh** | Web-ready visualizations |
| **Altair** | Declarative visualization |

### DevOps (Optional)

| Tool | Purpose |
|------|---------|
| **Docker Desktop** | Containerization |

### Data Engineering Tools

| Tool | Purpose |
|------|---------|
| **Apache Airflow** | Workflow orchestration |
| **dbt** | Data transformation tool |
| **Great Expectations** | Data quality testing |
| **Streamlit** | Data apps framework |

## Installation Time & Size

- **Installation Time:** 45-90 minutes (depending on internet speed)
- **Total Disk Space:** 15-30 GB
  - Anaconda: ~3 GB
  - Conda environment: ~5-8 GB
  - R + RStudio: ~1 GB
  - Databases: ~500 MB
  - Docker: ~3-5 GB
  - Power BI: ~500 MB
  - VS Code + Extensions: ~500 MB

## Workspace Structure

The script creates a workspace at `%USERPROFILE%\DataScience`:

```
%USERPROFILE%\DataScience\
├── projects/       # Your data science projects
├── datasets/       # Raw and processed data
├── notebooks/      # Jupyter notebooks
├── scripts/        # Python/R scripts
├── models/         # Trained ML models
├── outputs/        # Results, plots, reports
└── README.txt      # Workspace guide
```

## Post-Installation Setup

### 1. Create Conda Environment

After restarting your terminal:

```powershell
# Run the environment creation script
.\create-datasci-env.ps1

# This creates a 'datasci' environment with:
# - Python 3.11
# - All major data science libraries
# - TensorFlow and PyTorch
# - Jupyter Lab
# - PySpark
# - Database connectors
```

### 2. Activate the Environment

```powershell
# Activate the data science environment
conda activate datasci

# Your prompt should change to show (datasci)
```

### 3. Configure Git

```powershell
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 4. Start Jupyter Lab

```powershell
# Navigate to your workspace
cd $env:USERPROFILE\DataScience\notebooks

# Start Jupyter Lab
jupyter lab

# Opens in browser at http://localhost:8888
```

## Common Workflows

### Starting a New Data Science Project

```powershell
# Activate environment
conda activate datasci

# Navigate to projects
cd $env:USERPROFILE\DataScience\projects

# Create project directory
mkdir my-analysis
cd my-analysis

# Initialize git repository
git init

# Create project structure
mkdir data notebooks src models

# Start Jupyter Lab
jupyter lab
```

### Working with Databases

#### PostgreSQL

```powershell
# Connect using psql
psql -U postgres

# Or use DBeaver GUI application
```

#### MongoDB

```powershell
# Connect using mongo shell
mongo

# Or use DBeaver or MongoDB Compass
```

### Running Spark Jobs

```python
# In Jupyter or Python script
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("MyApp") \
    .getOrCreate()

df = spark.read.csv("data.csv", header=True)
df.show()
```

### Creating Data Pipelines with Airflow

```powershell
# Initialize Airflow
airflow db init

# Start webserver
airflow webserver -p 8080

# Start scheduler (in another terminal)
airflow scheduler
```

### Building Data Apps with Streamlit

```python
# Create app.py
import streamlit as st
import pandas as pd

st.title("My Data App")
df = pd.read_csv("data.csv")
st.dataframe(df)
```

```powershell
# Run the app
streamlit run app.py
```

## Package Management

### Installing New Packages

```powershell
# Activate environment
conda activate datasci

# Install from conda
conda install package-name

# Install from pip
pip install package-name

# Install specific version
conda install package-name=1.2.3
```

### Common Package Commands

```powershell
# List all packages
conda list

# Search for package
conda search package-name

# Update package
conda update package-name

# Remove package
conda remove package-name

# Export environment
conda env export > environment.yml

# Create from environment file
conda env create -f environment.yml
```

## VS Code Setup for Data Science

### Installed Extensions

- **Python** - Python language support
- **Pylance** - Python language server
- **Jupyter** - Jupyter notebook support
- **Jupyter Keymap** - Jupyter keyboard shortcuts
- **Git History** - View git log
- **GitLens** - Enhanced git features
- **PowerShell** - PowerShell support
- **YAML** - YAML language support
- **Docker** - Docker support

### Recommended Settings

Create `.vscode/settings.json` in your project:

```json
{
    "python.defaultInterpreterPath": "C:\\Users\\<YourName>\\anaconda3\\envs\\datasci\\python.exe",
    "jupyter.notebookFileRoot": "${workspaceFolder}",
    "python.linting.enabled": true,
    "python.linting.pylintEnabled": true,
    "python.formatting.provider": "black",
    "editor.formatOnSave": true
}
```

## Database Configuration

### PostgreSQL Setup

1. **Start PostgreSQL service:**
   ```powershell
   # Find service name
   Get-Service postgresql*
   
   # Start service
   Start-Service postgresql-x64-<version>
   ```

2. **Create a database:**
   ```sql
   -- Connect as postgres user
   psql -U postgres
   
   -- Create database
   CREATE DATABASE mydata;
   
   -- Create user
   CREATE USER datauser WITH PASSWORD '<choose-a-strong-password>';
   
   -- Grant privileges
   GRANT ALL PRIVILEGES ON DATABASE mydata TO datauser;
   ```

3. **Connect from Python:**
   ```python
   import os
   import psycopg2
   
   conn = psycopg2.connect(
       host="localhost",
       database="mydata",
       user="datauser",
       password=os.environ["PGPASSWORD"]
   )
   ```

### MongoDB Setup

1. **Start MongoDB service:**
   ```powershell
   Start-Service MongoDB
   ```

2. **Connect from Python:**
   ```python
   from pymongo import MongoClient
   
   client = MongoClient('mongodb://localhost:27017/')
   db = client['mydata']
   collection = db['mycollection']
   ```

## Cloud Platform Setup

### Azure CLI

```powershell
# Login to Azure
az login

# List subscriptions
az account list

# Set default subscription
az account set --subscription "<subscription-id>"

# Create storage account (example)
az storage account create --name mystorageacct --resource-group myresourcegroup
```

### AWS CLI

```powershell
# Configure AWS credentials
aws configure

# List S3 buckets
aws s3 ls

# Upload to S3
aws s3 cp file.csv s3://mybucket/
```

## Performance Tips

### 1. Use Appropriate Data Structures

```python
# For large datasets, use
import polars as pl  # Faster than pandas
df = pl.read_csv("large_file.csv")

# Or use Dask for out-of-core computing
import dask.dataframe as dd
df = dd.read_csv("huge_file.csv")
```

### 2. Optimize Pandas

```python
# Use categorical for string columns with few unique values
df['category_col'] = df['category_col'].astype('category')

# Use appropriate dtypes
df = pd.read_csv('file.csv', dtype={'col1': 'int32', 'col2': 'float32'})

# Read only needed columns
df = pd.read_csv('file.csv', usecols=['col1', 'col2'])
```

### 3. Use Vectorization

```python
# Bad (slow loop)
for i in range(len(df)):
    df.loc[i, 'new_col'] = df.loc[i, 'col1'] * 2

# Good (vectorized)
df['new_col'] = df['col1'] * 2
```

### 4. Profile Your Code

```python
# Use %%timeit in Jupyter
%%timeit
result = df.groupby('category').sum()

# Use cProfile for detailed profiling
import cProfile
cProfile.run('my_function()')
```

## Troubleshooting

### Conda Environment Issues

**Problem:** `conda: command not found`

**Solution:**
1. Restart your terminal
2. Or manually add to PATH: `C:\Users\<YourName>\anaconda3\Scripts`

**Problem:** Package installation fails

**Solution:**
```powershell
# Update conda
conda update conda

# Clear package cache
conda clean --all

# Try installing with pip
pip install package-name
```

### Jupyter Notebook Issues

**Problem:** Kernel not found

**Solution:**
```powershell
# Reinstall kernel
python -m ipykernel install --user --name datasci --display-name "Python (DataSci)"
```

**Problem:** Jupyter doesn't start

**Solution:**
```powershell
# Restart kernel
jupyter kernelspec list
jupyter kernelspec remove datasci
python -m ipykernel install --user --name datasci
```

### Database Connection Issues

**Problem:** Can't connect to PostgreSQL

**Solution:**
```powershell
# Check if service is running
Get-Service postgresql*

# Start if stopped
Start-Service postgresql-x64-<version>

# Check firewall
Test-NetConnection -ComputerName localhost -Port 5432
```

**Problem:** Can't connect to MongoDB

**Solution:**
```powershell
# Check service
Get-Service MongoDB

# Start if stopped
Start-Service MongoDB

# Check connection
Test-NetConnection -ComputerName localhost -Port 27017
```

### Memory Issues

**Problem:** Out of memory errors

**Solution:**
1. Use chunking for large files:
   ```python
   # Read CSV in chunks
   for chunk in pd.read_csv('large.csv', chunksize=10000):
       process(chunk)
   ```

2. Use Dask for larger-than-memory datasets
3. Increase Jupyter memory limit
4. Close unused notebooks

### Import Errors

**Problem:** `ModuleNotFoundError`

**Solution:**
```powershell
# Make sure environment is activated
conda activate datasci

# Install missing package
conda install package-name

# Or
pip install package-name
```

## Project Templates

### Data Analysis Template

```
project/
├── data/
│   ├── raw/              # Original data
│   ├── processed/        # Cleaned data
│   └── external/         # External data sources
├── notebooks/
│   ├── 01-exploration.ipynb
│   ├── 02-cleaning.ipynb
│   └── 03-analysis.ipynb
├── src/
│   ├── __init__.py
│   ├── data.py           # Data loading
│   ├── features.py       # Feature engineering
│   └── visualization.py  # Plotting functions
├── models/               # Trained models
├── reports/
│   ├── figures/
│   └── final_report.md
├── requirements.txt
└── README.md
```

### Machine Learning Template

```
ml-project/
├── data/
│   ├── raw/
│   ├── processed/
│   └── features/
├── notebooks/
│   ├── 01-eda.ipynb
│   ├── 02-baseline.ipynb
│   ├── 03-modeling.ipynb
│   └── 04-evaluation.ipynb
├── src/
│   ├── data/
│   │   ├── make_dataset.py
│   │   └── features.py
│   ├── models/
│   │   ├── train.py
│   │   ├── predict.py
│   │   └── evaluate.py
│   └── visualization/
│       └── visualize.py
├── models/               # Saved models
├── configs/              # Config files
├── tests/                # Unit tests
├── requirements.txt
└── README.md
```

## Learning Resources

### Python & Data Science
- [Pandas Documentation](https://pandas.pydata.org/docs/)
- [NumPy User Guide](https://numpy.org/doc/stable/user/)
- [Scikit-learn Tutorials](https://scikit-learn.org/stable/tutorial/index.html)
- [Python Data Science Handbook](https://jakevdp.github.io/PythonDataScienceHandbook/)

### Machine Learning
- [TensorFlow Tutorials](https://www.tensorflow.org/tutorials)
- [PyTorch Tutorials](https://pytorch.org/tutorials/)
- [Fast.ai Course](https://course.fast.ai/)
- [Kaggle Learn](https://www.kaggle.com/learn)

### Big Data
- [PySpark Documentation](https://spark.apache.org/docs/latest/api/python/)
- [Dask Tutorial](https://tutorial.dask.org/)

### Data Engineering
- [Airflow Documentation](https://airflow.apache.org/docs/)
- [dbt Tutorial](https://docs.getdbt.com/tutorial/setting-up)

### Visualization
- [Matplotlib Tutorials](https://matplotlib.org/stable/tutorials/index.html)
- [Seaborn Tutorial](https://seaborn.pydata.org/tutorial.html)
- [Plotly Documentation](https://plotly.com/python/)

### R
- [R for Data Science](https://r4ds.had.co.nz/)
- [RStudio Education](https://education.rstudio.com/)

## Best Practices

### 1. Project Organization
- Use consistent directory structure
- Keep data separate from code
- Version control everything (except large data files)
- Document your code and analysis

### 2. Code Quality
- Write modular, reusable functions
- Follow PEP 8 style guide for Python
- Add docstrings to functions
- Use meaningful variable names
- Write unit tests for critical functions

### 3. Data Management
- Never modify raw data
- Keep processed data separate
- Document data transformations
- Use version control for data schemas

### 4. Reproducibility
- Use virtual environments
- Pin package versions (requirements.txt)
- Set random seeds
- Document system dependencies

### 5. Security
- Never commit credentials
- Use environment variables for secrets
- Use `.gitignore` for sensitive files
- Regularly update packages

## Uninstallation

### Remove Conda Environment

```powershell
conda env remove -n datasci
```

### Uninstall All Components

```powershell
# Uninstall via Chocolatey
choco uninstall anaconda3 -y
choco uninstall git -y
choco uninstall vscode -y
choco uninstall r.project r.studio -y
choco uninstall postgresql mongodb -y
choco uninstall dbeaver -y
choco uninstall docker-desktop -y
choco uninstall azure-cli awscli -y
choco uninstall powerbi -y
```

### Remove Workspace

```powershell
# Delete workspace directory
Remove-Item -Recurse -Force "$env:USERPROFILE\DataScience"
```

## Support & Community

- **Python Community:** https://www.python.org/community/
- **Stack Overflow:** Tag your questions with `python`, `pandas`, `data-science`
- **Reddit:** r/datascience, r/learnpython, r/MachineLearning
- **Kaggle:** Join competitions and learn from notebooks

## Changelog

**Version 1.0.0** (2026-10-09)
- Initial release
- Complete data science environment setup
- Support for Windows 10/11
- Anaconda Python distribution
- R and RStudio support
- Database installations (PostgreSQL, MongoDB)
- Cloud CLI tools (Azure, AWS)
- Power BI Desktop
- Docker Desktop support

---

**Author:** Created with Claude Code  
**Last Updated:** 2026-10-09  
**License:** MIT
