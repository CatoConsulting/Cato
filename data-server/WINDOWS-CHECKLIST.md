# Checking `datatool.py` on kevin-Mini

`datatool.py` was tested on Linux only. These steps cover what still needs a real Windows machine: Windows paths and the default data folder, real Excel exports, and replacing a file while it's being downloaded. It takes about 15 minutes.

Run everything in a **normal PowerShell window** (not as Administrator), since that's how the tool is meant to be used. The data server must already be installed with `setup-data-server.ps1`.

If a result doesn't match what's written here, copy the output and send it back. A Python traceback (lines starting `Traceback (most recent call last):`) is always a bug.

## 1. Get ready

```powershell
cd C:\CatoRepository              # or wherever this repo lives on kevin-Mini
git pull
py --version
py -m pip install pyarrow pytest
$tool = "$PWD\data-server\datatool.py"
$data = 'C:\DataServer\public\data'
mkdir $HOME\datatest -Force | Out-Null; cd $HOME\datatest
```

**Expect:** `Python 3.10` or newer, and pip ending with `Successfully installed ...` (or `Requirement already satisfied`). If `py` isn't found, use `python` in every command below.

## 2. Run the test suite on Windows

```powershell
py -m pytest C:\CatoRepository\data-server\tests
```

**Expect:** `47 passed, 2 skipped`. The two skips are tests Windows can't run: one needs a file name with control characters, the other needs a symlink. With Developer Mode on, you'll see `48 passed, 1 skipped` instead. Any `failed` is worth sending back.

## 3. The default data folder

```powershell
py $tool validate; "exit $LASTEXITCODE"
py $tool catalog; "exit $LASTEXITCODE"
py $tool catalog; "exit $LASTEXITCODE"
```

**Expect:**
- `validate` lists one line per file already in `C:\DataServer\public\data` (or nothing if it's empty), then `0 error(s), ... in C:\DataServer\public\data` and `exit 0` (warnings about your own files are fine here). You didn't pass `--data-dir`, so this shows the default folder is found.
- The first `catalog` prints `Wrote: C:\DataServer\public\catalog.html`, `Wrote: C:\DataServer\public\catalog.json`, `N dataset(s)` and `exit 0`. This also shows your normal account can write there.
- The second prints `Unchanged:` for both files.
- `http://localhost:8080/catalog.html` opens in a browser and lists the files.

If you see `can't write ... Access is denied`, your account can't write to `C:\DataServer\public`; send the output of `icacls C:\DataServer\public`.

## 4. Windows paths

```powershell
mkdir 'my data' -Force | Out-Null
Set-Content -Path 'my data\sales jan.csv' -Value "id,zip,amount`n1,02134,12.5`n2,10001,3"
py $tool convert 'my data\sales jan.csv'; "exit $LASTEXITCODE"
py $tool convert '.\my data\sales jan.csv' --out-dir out\nested; "exit $LASTEXITCODE"
py $tool convert 'my data\sales jan.csv'; "exit $LASTEXITCODE"
py $tool validate --data-dir 'my data'; "exit $LASTEXITCODE"
```

**Expect:**
1. `OK    sales jan.csv -> my data\sales jan.parquet  (2 rows, 3 columns, ...; kept as text: zip (leading zeros))`, then `exit 0`. The Parquet file goes next to the CSV, and the path uses backslashes.
2. The same `OK` line pointing to `out\nested\sales jan.parquet`. The `out\nested` folder is created for you.
3. `ERROR sales jan.parquet already exists; add --force to replace it` and `exit 1`.
4. Two `WARN ... name has spaces or special characters` lines (one for the CSV, one for the Parquet), two `NOTE` lines with row counts, then `0 error(s), 2 warning(s) in my data` and `exit 0`.

## 5. Real Excel exports

In Excel, make a new sheet with this header row and two rows of data:

| Name | ZIP | Amount | Date |
|---|---|---|---|
| Café Müller | '02134 | 12.50 | 2026-01-05 |
| José | 10001 | 3 | 2026-01-06 |

Type the ZIP with a leading apostrophe (`'02134`); otherwise Excel drops the zero itself before the tool ever sees it. The accented names matter, because they're what makes the two encodings differ.

Save it twice into `$HOME\datatest`, using **File → Save As**:
- **CSV (Comma delimited) (\*.csv)** as `excel-ansi.csv`
- **CSV UTF-8 (Comma delimited) (\*.csv)** as `excel-utf8.csv`

Close Excel, then:

```powershell
py $tool convert excel-ansi.csv --out-dir $data; "exit $LASTEXITCODE"
py $tool convert excel-ansi.csv --out-dir $data --encoding cp1252; "exit $LASTEXITCODE"
py $tool convert excel-utf8.csv --out-dir $data; "exit $LASTEXITCODE"
py -c "import pyarrow.parquet as pq; t = pq.read_table(r'$data\excel-utf8.parquet'); print(t.schema); print(t.to_pylist()[0])"
```

**Expect:**
1. `ERROR excel-ansi.csv: text isn't valid utf8. Try --encoding cp1252 (typical for Excel exports on Windows).` and `exit 1`.
2. `OK    excel-ansi.csv -> C:\DataServer\public\data\excel-ansi.parquet  (2 rows, 4 columns, ...; kept as text: ZIP (leading zeros))` and `exit 0`.
3. The same `OK` line for `excel-utf8.csv`, with no `--encoding` needed.
4. `Name: string`, `ZIP: string`, `Amount: double`. `Date` is `date32[day]` if Excel kept the `2026-01-05` format, or `string` if Excel changed it to `1/5/2026` (only `yyyy-mm-dd` dates become real dates). The first row reads `'Name': 'Café Müller'` with the accents intact and `'ZIP': '02134'`.

If step 1 says `OK` instead of an error, your Excel saves "CSV (Comma delimited)" as UTF-8 already; that's fine, just mention it. If you get `the header looks ';'-separated`, Windows is set to a region that uses `;` as the list separator: add `--delimiter ';'` and mention it.

## 6. A file that's open in another program

Put a CSV in the data folder and open it in Excel, which holds it open:

```powershell
Copy-Item excel-utf8.csv $data\open-in-excel.csv
Start-Process $data\open-in-excel.csv            # opens it in Excel; leave it open
py $tool validate; "exit $LASTEXITCODE"
```

**Expect:** either normal `NOTE open-in-excel.csv: 2 rows, 4 columns` lines (Excel lets others read the file), or `ERROR open-in-excel.csv: can't read the file (Permission denied)`. In both cases every other file is still listed and the summary line still prints. Close Excel when done.

## 7. Replacing a Parquet file while it's being downloaded

This is the main thing Linux couldn't check. Make a CSV big enough that a slowed-down download takes over a minute:

```powershell
py -c "import os, csv; w = csv.writer(open('big.csv', 'w', newline='')); w.writerow(['id', 'token']); [w.writerow([i, 'k' + os.urandom(24).hex()]) for i in range(300000)]"
py $tool convert big.csv --out-dir $data
```

**Expect:** `OK    big.csv -> C:\DataServer\public\data\big.parquet  (300,000 rows, 2 columns, ...)`. The file is about 8 MB.

Open a **second** PowerShell window and start a slow download (about 80 seconds). Add `-u kevin` before the URL if you turned the login on.

```powershell
curl.exe --limit-rate 100k -o NUL http://localhost:8080/data/big.parquet
```

While the progress meter is still running, go back to the first window:

```powershell
py $tool convert big.csv --out-dir $data --force; "exit $LASTEXITCODE"
Get-ChildItem $data -Force -Filter '.*.tmp'
```

**Expect:**
- `ERROR big.parquet is in use (probably being downloaded); try again in a moment` and `exit 1`.
- `Get-ChildItem` prints nothing, so no temp file was left behind.
- The download in the other window carries on to 100% without an error.

Once the download has finished, run the same `convert ... --force` again. It should print `OK` and `exit 0`.

If the first `--force` says `OK` while the download is still running, Windows allowed the swap. That isn't a failure (the reader keeps the old copy), but please mention it, because then the doc should say so.

## 8. Catalog the test files, then clean up

```powershell
py $tool catalog
```

**Expect:** `Wrote:` for both files, because the data folder now has the test files. Reload `http://localhost:8080/catalog.html`: `excel-utf8.parquet` lists its columns with types, and `big.parquet` shows `300,000` rows.

```powershell
Remove-Item $data\big.parquet, $data\excel-*.parquet, $data\open-in-excel.csv
py $tool catalog
cd $HOME; Remove-Item -Recurse $HOME\datatest
```

**Expect:** `Wrote:` for both files again, because the test files are gone from the list.

## Sending results back

The quickest report is "all steps matched", or the step numbers that didn't match, with their output pasted in.
