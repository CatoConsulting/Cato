# kevin-Mini Data Server

A static website on the Windows mini PC that serves data files (CSV, Parquet, JSON, ...) to devices on your home network. Nothing is exposed to the internet.

It uses [Caddy](https://caddyserver.com) 2.11.7, installed by `setup-data-server.ps1` as a Windows service that starts at boot.

## Set it up

On kevin-Mini, in **PowerShell as Administrator**, from this repository's folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass        # allow this repo's scripts in this window only
Get-ChildItem -Recurse | Unblock-File            # only if you downloaded the repo as a ZIP
.\setup-data-server.ps1
```

Then copy files into `C:\DataServer\public\data` and open `http://kevin-Mini:8080/` from another device.

Re-running the script is safe: it updates the install in place and only restarts the server when something changed.

| Option | What it does |
|---|---|
| `-Port 8090` | Use another port (default 8080) |
| `-DataRoot D:\Datasets` | Serve a different folder; data goes in its `data` subfolder |
| `-BasicAuthUser kevin` | Require a login; you're prompted for the password (8+ characters) |
| `-RemoveBasicAuth` | Remove the login. A plain re-run keeps an existing login. |
| `-BindAddress 192.168.1.50` | Listen on one address only (reserve it in your router first) |
| `-SetNetworkPrivate` | Switch your home network from Public to Private if needed (see below). Other networks (VPNs, virtual adapters) are left alone. If the script can't tell which network is home, it switches nothing; add `-BindAddress <LAN IP>` to choose. |
| `-AllowSleep` | Don't change sleep settings |
| `-Uninstall` | Remove the service and firewall rule; files stay |

## What the script does

1. **Downloads Caddy 2.11.7** from its GitHub release and checks it against the published SHA-512. A mismatch stops the install. It picks the x64 or ARM64 build automatically.
2. **Creates folders** under `C:\DataServer`: `caddy\` (program), `Caddyfile` (config), `logs\` (`access.log` and Caddy's own `caddy.log`), `state\`, and `public\` (the website: `index.html` plus `data\`).
3. **Writes the config** from `data-server/Caddyfile.template` and has Caddy validate it.
4. **Installs the `DataServer` service**:
   - It starts automatically at boot (delayed start, so the network is up first) and restarts itself if it crashes.
   - It runs as the low-privilege **LocalService** account. That account gets read access to the program and data, and write access only to `logs\` and `state\`.
5. **Adds a firewall rule** that lets other devices connect only on networks Windows classifies as **Private**, only from your **local subnet**, and only to `caddy.exe`.
6. **Keeps the PC awake** on AC power (sleep and hibernate set to Never), since a sleeping server is unreachable. Skip this with `-AllowSleep`.
7. **Checks the server answers**, then prints the addresses to use.

## Reaching it from other devices

Try these, in order:

| Address | Usually works from |
|---|---|
| `http://kevin-Mini:8080/` | Other Windows PCs |
| `http://kevin-mini.local:8080/` | Macs, iPhones/iPads, Linux |
| `http://<IP shown by the script>:8080/` | Everything |

If the names don't resolve on your network, use the IP. To keep the IP from changing, set a **DHCP reservation** for kevin-Mini in your router's settings (often under LAN or DHCP, "address reservation"). Use the MAC address shown by `Get-NetAdapter` on kevin-Mini.

**Can't connect at all?** The most common cause is that Windows classifies your home network as **Public**, where the firewall rule doesn't apply. The script warns you about this. Fix it with `-SetNetworkPrivate`, or under **Settings → Network & internet → (your connection) → Network profile type → Private**.

## Using the data

The landing page at `/` shows copy-paste snippets with the right address filled in. `/data/` lists the files.

```python
import pandas as pd
df = pd.read_csv("http://kevin-Mini:8080/data/sales.csv")
df = pd.read_parquet("http://kevin-Mini:8080/data/sales.parquet")  # pip install pyarrow fsspec aiohttp

import polars as pl
lazy = pl.scan_parquet("http://kevin-Mini:8080/data/sales.parquet")  # reads only what the query needs
```

```sql
-- DuckDB
INSTALL httpfs; LOAD httpfs;
SELECT region, count(*) FROM read_parquet('http://kevin-Mini:8080/data/sales.parquet') GROUP BY 1;
```

How the server is set up for data work:
- **Range requests:** DuckDB, pyarrow and Polars read only the parts of a Parquet file they need.
- **Content types** are set explicitly: `text/csv`, `application/json`, `application/x-ndjson` and `application/vnd.apache.parquet` (IANA-registered 2024). Windows would otherwise guess from the registry, where Excel claims `.csv`.
- **Compression:** CSV, JSON and text are gzip/zstd-compressed (about 3× smaller for CSV). Parquet is left alone, since it's already compressed.
- **CORS** is open, so browser-based tools served over plain `http://` on your network can fetch files.
- **Hidden files:** dotfiles, `desktop.ini` and `Thumbs.db` are hidden and return 404.

**Browser tools on `https://` sites can't use this server.** Examples are shell.duckdb.org and Observable. Browsers block an `https://` page from fetching an `http://` address (mixed content), and Chrome also asks for local-network permission. Use DuckDB, pandas or Polars locally instead, or serve the tool's page from this server too.

## Preparing data: `datatool.py`

`data-server/datatool.py` converts, checks and catalogs your files. It needs Python 3.10+ and pyarrow, and runs from your normal account (no admin needed). Run these from this repository's folder:

```powershell
py -m pip install pyarrow
py data-server\datatool.py convert C:\Downloads\sales.csv --out-dir C:\DataServer\public\data
py data-server\datatool.py validate
py data-server\datatool.py catalog
```

`validate` and `catalog` use `C:\DataServer\public\data` by default; pass `--data-dir` for another folder. If that folder doesn't exist yet (the server isn't set up on this PC), they stop with `the following arguments are required: --data-dir`. Every command exits with 1 if something failed (2 for a usage mistake, such as an unknown option), so it can be used in scripts.

### `convert`: CSV to Parquet

Parquet files are typically a quarter of the CSV's size and much faster to query over the network, because DuckDB, pyarrow and Polars fetch only the columns and row groups they need.

The command:
- Keeps the CSV. If the `.parquet` already exists, it refuses to replace it unless you add `--force`.
- Writes to a hidden temp file first (the server never serves it). It checks that file's row count and column names, then swaps it in, so readers never see a half-written file.
- Keeps **code-like columns** as text, so they aren't silently changed into numbers. A column stays text if any value has:
  - leading zeros (ZIP codes, IDs like `00123`)
  - a hex prefix (`0x1F`)
  - a leading `+` (phone numbers)
  - 16 or more digits, which a float can't hold exactly

  Values like `1.10` (a version number) or `1E5` aren't detected, because prices such as `2.50` and scientific notation look the same. If a column holds codes like those, add `--string-columns name`.
- Stops with a clear message, instead of writing bad data, when:
  - The text isn't UTF-8. In Excel's **Save As**, "CSV UTF-8 (Comma delimited)" works as is, but plain "CSV (Comma delimited)" saves cp1252 on Western-language Windows: add `--encoding cp1252`.
  - The file uses `;` or tabs as separators: add `--delimiter ';'` or `--delimiter tab`.
  - A column looks numeric at first but has text further down: add `--string-columns name`.
  - The header has empty or duplicate column names.
  - The CSV's name starts with `.`, since the Parquet file would be hidden too.
  - Two inputs in one run would get the same output name (`jan\sales.csv` and `feb\sales.csv` into one `--out-dir`).
  - The CSV changed while it was being converted. Run it again once whatever is writing the file has finished.
- Stores a column as decimals if it starts with whole numbers and has decimals further down (`1`, `2`, ... `2.5`).
- Turns blank cells into missing values in every column. `NA`, `N/A`, `NULL` and `NaN` count as missing only **in numeric columns**; text columns keep them as written, so `NA` for Namibia stays `NA`.
- Handles quoted cells that contain line breaks, and blank lines before the header.
- Reads dates only in `yyyy-mm-dd` form. Excel saves cells as they're displayed, so `1/5/2026` dates and `$12.50` amounts stay text; format those columns as `yyyy-mm-dd` and plain numbers in Excel before saving. Excel also drops leading zeros as you type, before the CSV is written, unless the column is formatted as Text.

### `validate`: check before you publish

`validate` reads every file in the data folder (Parquet only from its footer, so it stays fast) and reports:
- **Errors:** files that won't work, such as unreadable Parquet, CSVs with inconsistent rows or bad encoding, and invalid JSON or NDJSON (with the line number). `NaN` and `Infinity` count as invalid, since browsers can't parse them.
- **Warnings:** names with spaces or special characters, in the file or its folders (they break URLs and code snippets), JSON files over 200 MB and NDJSON lines over 200 MB (too big to check), JSON nested too deeply to check, spreadsheets (`.xlsx` can't be queried over HTTP), and temp files left by an interrupted run.
- **Notes:** row and column counts, leading-zero columns, large CSVs worth converting, and hidden files the server won't serve.

### `catalog`: a page listing every dataset

`catalog` writes `catalog.json` and `catalog.html` next to the `data` folder, so they're served at `/catalog.json` and `/catalog.html`. Each dataset shows its size. CSV and Parquet files also show their columns, and Parquet files show column types and row counts. CSVs show row counts only with `--scan-csv`, since that reads every CSV in full. A file that can't be read is still listed, with the reason, because the server serves it anyway. Run it again after adding files; a re-run with nothing changed doesn't rewrite anything.

The landing page links to the catalog once it exists. Installs set up before this change keep their own `index.html`; to get the link, copy `data-server\index.html` over `C:\DataServer\public\index.html`, or just open `/catalog.html`.

## The optional login

`-BasicAuthUser` turns on HTTP basic authentication: browsers show a login prompt, and tools pass credentials in the URL or as options. The password is stored only as a bcrypt hash.

The first request after a login takes about a second while the password is checked; Caddy caches the result, so later requests (including the many small Range requests DuckDB and pyarrow make) are as fast as without a login. Browser tools can't fetch files cross-origin with a login on, because credentialed CORS requests need a specific origin rather than `*`.

**Over plain HTTP, this is a deterrent, not real security.** Anyone on your network who captures the traffic can read the password. Don't reuse an important password, and keep sensitive data off the server.

## Managing it

```powershell
Get-Service DataServer
Restart-Service DataServer
Get-Content C:\DataServer\logs\access.log -Tail 20       # who fetched what
Get-Content C:\DataServer\logs\caddy.log -Tail 20        # why it didn't start
notepad C:\DataServer\public\index.html                  # edit the landing page (re-runs don't overwrite it)
.\setup-data-server.ps1 -Uninstall
```

To change the Caddy config, edit `data-server/Caddyfile.template` in this repo and re-run the script. Edits made directly to `C:\DataServer\Caddyfile` are replaced on the next run.

## What was tested, and what wasn't

Data tools (`datatool.py`), tested on Linux with pyarrow 26:
- **Test suite:** 49 tests in `data-server/tests`, run with `python -m pytest data-server/tests`. They cover:
  - code-like values (leading zeros, hex, `+`, long numbers)
  - cp1252, byte-order marks, semicolon and tab files (and one-column files with `;` in the header)
  - blank first lines, multi-line cells, and text or decimals appearing late in a numeric column
  - bad headers, empty and header-only files, and blank cells
  - row groups sized by rows and by memory, as rows get wider or narrower through the file
  - refusing to overwrite, hidden output names, two inputs with one output name, and a CSV that changes mid-run
  - files that are locked or unreadable: `convert` and `validate` report them and carry on with the rest
  - every `validate` finding, including `NaN` in JSON
  - the catalog's escaping, URLs, stability and listing of unreadable files

  The fixes after the `data-reviewer` subagent's review each have a test that fails on the earlier code.
- **End to end:** a 200,000-row CSV was converted, validated and cataloged, then served through Caddy with this config and read over HTTP with DuckDB, pandas and Polars. ZIP codes stayed text and dates came through as dates.
- **Not tested on Windows:**
  - Replacing a `.parquet` while someone is downloading it. Windows may lock the file; the tool then says it's in use instead of failing silently.
  - Real Excel exports.
  - Windows paths and the default data folder.

  [`data-server/WINDOWS-CHECKLIST.md`](data-server/WINDOWS-CHECKLIST.md) walks through each of these on kevin-Mini, with the output to expect. On Windows the test suite skips two tests that need things Windows doesn't allow by default: a file name with control characters, and a symlink (allowed only with Developer Mode or admin rights).


The script hasn't been run on Windows yet. What was tested, in a Linux sandbox:
- **Caddy's behavior:** the same 2.11.7 build and the same config template. This covered content types, Range requests (206), compression on CSV only, CORS preflight, hidden files, the login, and binding to one address.
- **Real clients:** pandas, pyarrow, Polars and DuckDB all read CSV and Parquet over HTTP.
- **The setup script:** run with PowerShell 7. Windows-only commands (services, firewall, `sc.exe`, `icacls`, `powercfg`) were replaced with recorders, but the real Caddy did the validation, password hashing and health checks. I ran a fresh install, a re-run with no changes, login on, kept, and removed, invalid input, and uninstall.
- **Downloads:** the pinned SHA-512 hashes were checked against GitHub for both x64 and ARM64, and a corrupted download was refused.
- **Static analysis:** PSScriptAnalyzer found no issues, including syntax compatibility with Windows PowerShell 5.1.

Not tested; please check on kevin-Mini:
- The service starting at boot as LocalService.
- The firewall rule and network-profile handling.
- Name resolution (`kevin-Mini`, `kevin-mini.local`) from your devices.
- Running under Windows PowerShell 5.1 itself, not just its syntax.
