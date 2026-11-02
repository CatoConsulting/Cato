"""Tests for datatool.py. Run: python -m pytest data-server/tests"""

import json
import sys
from pathlib import Path

import pyarrow.parquet as pq
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import datatool  # noqa: E402


def write(path: Path, text: str, encoding: str = "utf-8") -> Path:
    path.write_bytes(text.encode(encoding))
    return path


def run(*argv: str) -> int:
    return datatool.main(list(argv))


# ---------------------------------------------------------------- convert


def test_convert_round_trip(tmp_path):
    src = write(tmp_path / "sales.csv", "id,region,amount\n1,north,10.5\n2,south,3.25\n")
    assert run("convert", str(src)) == 0
    table = pq.read_table(tmp_path / "sales.parquet")
    assert table.num_rows == 2
    assert table.column_names == ["id", "region", "amount"]
    assert table.column("amount").to_pylist() == [10.5, 3.25]
    assert src.exists(), "source CSV must be left in place"
    assert not list(tmp_path.glob(".*.tmp")), "no temp files left behind"


def test_leading_zeros_kept_as_text(tmp_path):
    src = write(tmp_path / "zips.csv", "zip,count\n00123,1\n02134,2\n90210,3\n")
    assert run("convert", str(src)) == 0
    table = pq.read_table(tmp_path / "zips.parquet")
    assert table.schema.field("zip").type == "string"
    assert table.column("zip").to_pylist() == ["00123", "02134", "90210"]
    assert table.schema.field("count").type == "int64"


def test_late_text_in_numeric_column_names_column(tmp_path, capsys, monkeypatch):
    monkeypatch.setattr(datatool, "BLOCK_SIZE", 1 << 16)  # types are inferred from the first block only
    rows = "".join(f"{i},{i}\n" for i in range(300_000))
    src = write(tmp_path / "late.csv", "id,val\n" + rows + "300000,abc\n")
    assert run("convert", str(src)) == 1
    err = capsys.readouterr().err
    assert "'val'" in err
    assert "--string-columns val" in err
    assert not (tmp_path / "late.parquet").exists()
    assert not list(tmp_path.glob(".*.tmp"))
    assert run("convert", str(src), "--string-columns", "val") == 0
    assert pq.read_table(tmp_path / "late.parquet").column("val")[-1].as_py() == "abc"


def test_cp1252_detected_and_converted_with_flag(tmp_path, capsys):
    src = write(tmp_path / "excel.csv", "name,city\nJosé,Zürich\n", encoding="cp1252")
    assert run("convert", str(src)) == 1
    assert "--encoding cp1252" in capsys.readouterr().err
    assert run("convert", str(src), "--encoding", "cp1252") == 0
    assert pq.read_table(tmp_path / "excel.parquet").column("city").to_pylist() == ["Zürich"]


def test_bom_stripped_from_header(tmp_path):
    src = write(tmp_path / "bom.csv", "﻿name,x\na,1\n")
    assert run("convert", str(src)) == 0
    assert pq.read_table(tmp_path / "bom.parquet").column_names == ["name", "x"]


def test_semicolon_hint_and_delimiter(tmp_path, capsys):
    src = write(tmp_path / "semi.csv", "a;b\n1;2\n3;4\n")
    assert run("convert", str(src)) == 1, "must not silently produce one column named 'a;b'"
    assert "--delimiter ';'" in capsys.readouterr().err
    assert not (tmp_path / "semi.parquet").exists()
    ok = write(tmp_path / "semi_ok.csv", "a;b\n1;2\n3;4\n")
    assert run("convert", str(ok), "--delimiter", ";") == 0
    assert pq.read_table(tmp_path / "semi_ok.parquet").column_names == ["a", "b"]


def test_refuses_to_overwrite_without_force(tmp_path, capsys):
    src = write(tmp_path / "d.csv", "a\n1\n")
    assert run("convert", str(src)) == 0
    before = (tmp_path / "d.parquet").stat().st_mtime_ns
    assert run("convert", str(src)) == 1
    assert "--force" in capsys.readouterr().err
    assert (tmp_path / "d.parquet").stat().st_mtime_ns == before
    assert run("convert", str(src), "--force") == 0


def test_bad_headers_rejected(tmp_path, capsys):
    dup = write(tmp_path / "dup.csv", "a,a\n1,2\n")
    empty_name = write(tmp_path / "blank.csv", "a,\n1,2\n")
    assert run("convert", str(dup), str(empty_name)) == 1
    err = capsys.readouterr().err
    assert "duplicate column names: a" in err
    assert "empty name" in err


def test_empty_and_header_only(tmp_path, capsys):
    empty = write(tmp_path / "empty.csv", "")
    assert run("convert", str(empty)) == 1
    assert "empty" in capsys.readouterr().err
    header = write(tmp_path / "header.csv", "a,b\n")
    assert run("convert", str(header)) == 0
    meta = pq.ParquetFile(tmp_path / "header.parquet").metadata
    assert meta.num_rows == 0
    assert meta.num_columns == 2


def test_row_groups_are_batched(tmp_path, monkeypatch):
    monkeypatch.setattr(datatool, "ROW_GROUP_ROWS", 50_000)
    monkeypatch.setattr(datatool, "BLOCK_SIZE", 1 << 14)  # many small batches
    src = write(tmp_path / "big.csv", "a,b\n" + "".join(f"{i},{i * 2}\n" for i in range(120_000)))
    assert run("convert", str(src)) == 0
    meta = pq.ParquetFile(tmp_path / "big.parquet").metadata
    assert meta.num_rows == 120_000
    sizes = [meta.row_group(i).num_rows for i in range(meta.num_row_groups)]
    assert sizes == [50_000, 50_000, 20_000], f"small batches must be grouped into full row groups, got {sizes}"
    assert meta.row_group(0).column(0).compression == "ZSTD"
    assert meta.row_group(0).column(0).statistics is not None


def test_ragged_rows_rejected(tmp_path, capsys):
    src = write(tmp_path / "ragged.csv", "a,b\n1,2\n3,4,5\n")
    assert run("convert", str(src)) == 1
    assert "different numbers of fields" in capsys.readouterr().err


@pytest.mark.parametrize(("value", "other", "reason"), [
    ("0x1F", "0XFF", "hex values"),
    ("+15551234567", "+15550000000", "leading +"),
    ("12345678901234567890", "1", "16+ digit numbers"),
    ("9007199254740993", "1.5", "16+ digit numbers"),
])
def test_code_like_values_kept_as_text(tmp_path, capsys, value, other, reason):
    src = write(tmp_path / "codes.csv", f"code,n\n{value},1\n{other},2\n")
    assert run("convert", str(src)) == 0
    table = pq.read_table(tmp_path / "codes.parquet")
    assert table.column("code").to_pylist() == [value, other]
    assert table.schema.field("n").type == "int64"
    assert f"code ({reason})" in capsys.readouterr().out


def test_blank_first_line_keeps_header(tmp_path):
    src = write(tmp_path / "blank.csv", "\r\n\nid,v\n1,2\n")
    assert run("convert", str(src)) == 0
    table = pq.read_table(tmp_path / "blank.parquet")
    assert table.to_pylist() == [{"id": 1, "v": 2}]


def test_multiline_cells_across_blocks(tmp_path, monkeypatch):
    monkeypatch.setattr(datatool, "BLOCK_SIZE", 4096)
    rows = "".join(f'{i},"line one\nline two {i}"\n' for i in range(2000))
    src = write(tmp_path / "multi.csv", "id,note\n" + rows)
    assert run("convert", str(src)) == 0
    table = pq.read_table(tmp_path / "multi.parquet")
    assert table.num_rows == 2000
    assert table.column("note")[1999].as_py() == "line one\nline two 1999"


def test_blank_text_cells_become_null(tmp_path):
    src = write(tmp_path / "b.csv", "zip,country,n\n00501,NA,1\n,US,\n")
    assert run("convert", str(src)) == 0
    rows = pq.read_table(tmp_path / "b.parquet").to_pylist()
    assert rows[1] == {"zip": None, "country": "US", "n": None}
    assert rows[0]["country"] == "NA", "NA in a text column is data (e.g. Namibia), not missing"


def test_row_groups_sized_by_bytes(tmp_path, monkeypatch):
    monkeypatch.setattr(datatool, "ROW_GROUP_BYTES", 200_000)
    wide = ",".join(f"c{i}" for i in range(40))
    rows = "".join(",".join(f"value-{r}-{c}" for c in range(40)) + "\n" for r in range(5000))
    src = write(tmp_path / "wide.csv", wide + "\n" + rows)
    assert run("convert", str(src)) == 0
    meta = pq.ParquetFile(tmp_path / "wide.parquet").metadata
    assert meta.num_rows == 5000
    assert meta.num_row_groups > 1, "a wide file must be split by size, not one huge row group"


def test_row_groups_shrink_when_later_rows_are_wider(tmp_path, monkeypatch):
    monkeypatch.setattr(datatool, "ROW_GROUP_BYTES", 200_000)
    monkeypatch.setattr(datatool, "BLOCK_SIZE", 1 << 16)  # the first batches hold only the short rows
    short = "".join(f"{i},x\n" for i in range(20_000))
    long = "".join(f"{i},{'y' * 500}\n" for i in range(3_000))
    src = write(tmp_path / "mixed.csv", "a,b\n" + short + long)
    assert run("convert", str(src)) == 0
    pf = pq.ParquetFile(tmp_path / "mixed.parquet")
    assert pf.metadata.num_rows == 23_000
    biggest = max(pf.read_row_group(i).nbytes for i in range(pf.num_row_groups))
    assert biggest <= 1.2 * 200_000, f"a row group held {biggest:,} bytes; the cap is 200,000"


def test_row_groups_grow_back_after_wide_rows(tmp_path, monkeypatch):
    monkeypatch.setattr(datatool, "ROW_GROUP_BYTES", 200_000)
    monkeypatch.setattr(datatool, "BLOCK_SIZE", 1 << 16)
    long = "".join(f"{i},{'y' * 500}\n" for i in range(300))
    short = "".join(f"{i},x\n" for i in range(60_000))
    src = write(tmp_path / "mixed.csv", "a,b\n" + long + short)
    assert run("convert", str(src)) == 0
    sizes = [rg.num_rows for rg in (pq.ParquetFile(tmp_path / "mixed.parquet").metadata.row_group(i)
                                    for i in range(pq.ParquetFile(tmp_path / "mixed.parquet").num_row_groups))]
    assert sum(sizes) == 60_300
    assert max(sizes) > 5_000, f"narrow rows after wide ones must get big row groups again: {sizes}"


def test_late_decimals_in_integer_column(tmp_path, capsys, monkeypatch):
    monkeypatch.setattr(datatool, "BLOCK_SIZE", 1 << 12)  # types are inferred from the first block only
    src = write(tmp_path / "prices.csv", "price,name\n" + "".join(f"{i},x\n" for i in range(3000)) + "2.5,y\n")
    assert run("convert", str(src)) == 0
    assert "decimals found further down: price" in capsys.readouterr().out
    table = pq.read_table(tmp_path / "prices.parquet")
    assert str(table.schema.field("price").type) == "double"
    assert table.column("price")[-1].as_py() == 2.5
    assert table.column("price")[7].as_py() == 7


def test_hidden_csv_rejected(tmp_path, capsys):
    src = write(tmp_path / ".sales.csv", "a\n1\n")
    assert run("convert", str(src)) == 1
    assert "would be hidden" in capsys.readouterr().err
    assert not (tmp_path / ".sales.parquet").exists()


def test_same_output_name_twice_rejected(tmp_path, capsys):
    (tmp_path / "jan").mkdir()
    (tmp_path / "feb").mkdir()
    one = write(tmp_path / "jan" / "sales.csv", "a\n1\n")
    two = write(tmp_path / "feb" / "sales.csv", "a\n2\n")
    out = tmp_path / "out"
    assert run("convert", str(one), str(two), "--out-dir", str(out), "--force") == 1
    assert "would both become sales.parquet" in capsys.readouterr().err
    assert pq.read_table(out / "sales.parquet").column("a")[0].as_py() == 1


def test_source_changed_during_convert_is_not_published(tmp_path, capsys, monkeypatch):
    src = write(tmp_path / "live.csv", "a\n1\n")
    real_write = datatool.write_parquet

    def write_then_append(*args):
        real_write(*args)
        with src.open("a") as fh:
            fh.write("2\n")

    monkeypatch.setattr(datatool, "write_parquet", write_then_append)
    assert run("convert", str(src)) == 1
    assert "changed while it was being converted" in capsys.readouterr().err
    assert not (tmp_path / "live.parquet").exists()


def test_one_column_csv_with_semicolon_in_header(tmp_path):
    src = write(tmp_path / "prices.csv", "price;usd\n12\n13\n")
    assert run("convert", str(src)) == 0
    assert pq.read_table(tmp_path / "prices.parquet").column_names == ["price;usd"]


def test_semicolon_file_with_decimal_commas_still_detected(tmp_path, capsys):
    src = write(tmp_path / "eu.csv", "a;b\n1,5;2\n3,5;4\n")
    assert run("convert", str(src)) == 1
    assert "--delimiter ';'" in capsys.readouterr().err


def test_string_columns_match_padded_headers(tmp_path):
    src = write(tmp_path / "padded.csv", " zip ,n\n123,1\n")
    assert run("convert", str(src), "--string-columns", "zip") == 0
    assert str(pq.read_table(tmp_path / "padded.parquet").schema.field(" zip ").type) == "string"


def test_temp_file_never_follows_a_planted_link(tmp_path, capsys, monkeypatch):
    victim = write(tmp_path / "victim.txt", "keep me")
    src = write(tmp_path / "sales.csv", "a\n1\n")
    monkeypatch.setattr(datatool.secrets, "token_hex", lambda n: "fixed")
    try:
        (tmp_path / ".sales.parquet.fixed.tmp").symlink_to(victim)
    except OSError:  # Windows allows symlinks only with Developer Mode or admin rights
        pytest.skip("this account can't create symlinks")
    assert run("convert", str(src)) == 1
    assert victim.read_text() == "keep me"
    assert not (tmp_path / "sales.parquet").exists()


@pytest.mark.skipif(sys.platform == "win32", reason="Windows file names can't contain control characters")
def test_control_characters_in_names_are_escaped(tmp_path, capsys):
    data = tmp_path / "data"
    data.mkdir()
    write(data / "evil\x1b[2J.csv", "a\n1\n")
    run("validate", "--data-dir", str(data))
    out = capsys.readouterr().out
    assert "\x1b" not in out
    assert "evil\\x1b[2J.csv" in out


def test_empty_batch_from_reader_does_not_hang(tmp_path, monkeypatch):
    real_open = datatool.pacsv.open_csv

    class EmptyFirst:
        def __init__(self, reader):
            self.schema = reader.schema
            self._reader = reader

        def __iter__(self):
            yield datatool.pa.RecordBatch.from_pylist([], schema=self.schema)
            yield from self._reader

        def close(self):
            self._reader.close()

    monkeypatch.setattr(datatool.pacsv, "open_csv", lambda *a, **k: EmptyFirst(real_open(*a, **k)))
    src = write(tmp_path / "e.csv", "a,b\n1,2\n3,4\n")
    assert run("convert", str(src)) == 0
    assert pq.read_table(tmp_path / "e.parquet").num_rows == 2


@pytest.mark.parametrize(("args", "message"), [
    (["--delimiter", ";;"], "single character"),
    (["--encoding", "latin-9x"], "unknown encoding"),
])
def test_bad_options_are_usage_errors(tmp_path, capsys, args, message):
    src = write(tmp_path / "x.csv", "a\n1\n")
    with pytest.raises(SystemExit) as exc:
        run("convert", str(src), *args)
    assert exc.value.code == 2
    assert message in capsys.readouterr().err


def test_tab_delimiter_by_name(tmp_path):
    src = write(tmp_path / "t.csv", "a\tb\n1\t2\n")
    assert run("convert", str(src), "--delimiter", "tab") == 0
    assert pq.read_table(tmp_path / "t.parquet").column_names == ["a", "b"]


def test_convert_continues_after_unreadable_file(tmp_path, capsys, monkeypatch):
    locked = write(tmp_path / "locked.csv", "a\n1\n")
    ok = write(tmp_path / "ok.csv", "a\n1\n")
    real_scan = datatool.scan_csv

    def scan(path, opts):
        if path.name == "locked.csv":
            raise PermissionError(13, "being used by another process", str(path))
        return real_scan(path, opts)

    monkeypatch.setattr(datatool, "scan_csv", scan)
    assert run("convert", str(locked), str(ok)) == 1
    assert "locked.csv" in capsys.readouterr().err
    assert (tmp_path / "ok.parquet").exists()


def test_unknown_string_column_rejected(tmp_path, capsys):
    src = write(tmp_path / "s.csv", "a\n1\n")
    assert run("convert", str(src), "--string-columns", "nope") == 1
    assert "nope" in capsys.readouterr().err


# ---------------------------------------------------------------- validate


def make_data_dir(tmp_path: Path) -> Path:
    data = tmp_path / "public" / "data"
    data.mkdir(parents=True)
    write(data / "good.csv", "zip,v\n00501,1\n")
    write(data / "ragged.csv", "a,b\n1,2\n3\n")
    write(data / "bad.json", "{not json")
    write(data / "nan.json", '{"a": NaN}')
    write(data / "events.ndjson", '{"a": 1}\n{"a": 2\n')
    write(data / "my file.csv", "a\n1\n")
    write(data / ".secret", "x")
    write(data / ".half.parquet.tmp", "x")
    write(data / "report.xlsx", "x")
    write(data / "broken.parquet", "not parquet")
    return data


def test_validate_reports_each_problem(tmp_path, capsys):
    data = make_data_dir(tmp_path)
    assert run("validate", "--data-dir", str(data)) == 1
    out = capsys.readouterr().out
    expectations = {
        "ragged.csv": "different numbers of fields",
        "bad.json": "not valid UTF-8 JSON",
        "nan.json": "NaN isn't valid JSON",
        "events.ndjson": "line 2",
        "my file.csv": "spaces or special characters",
        ".secret": "won't serve",
        ".half.parquet.tmp": "leftover temp file",
        "report.xlsx": "export to CSV or Parquet",
        "broken.parquet": "not a readable Parquet file",
        "good.csv": "zip (leading zeros)",
    }
    for name, text in expectations.items():
        line = next((ln for ln in out.splitlines() if f" {name}:" in ln and text in ln), None)
        assert line, f"expected '{text}' for {name} in:\n{out}"
    assert "5 error(s)" in out


def test_validate_clean_folder_passes(tmp_path):
    data = tmp_path / "data"
    data.mkdir()
    write(data / "ok.csv", "a,b\n1,2\n")
    write(data / "bom.json", '\ufeff{"a": 1}')
    write(data / "bom.ndjson", '\ufeff{"a": 1}\n{"a": 2}\n')
    assert run("validate", "--data-dir", str(data)) == 0


def test_validate_reports_unreadable_file_and_keeps_going(tmp_path, capsys, monkeypatch):
    data = tmp_path / "data"
    data.mkdir()
    write(data / "a_locked.json", "{}")
    write(data / "b_ok.csv", "a,b\n1,2\n")

    def locked(rel, path):
        raise PermissionError(13, "being used by another process", str(path))

    monkeypatch.setitem(datatool.CHECKS, ".json", locked)
    assert run("validate", "--data-dir", str(data)) == 1
    out = capsys.readouterr().out
    assert "ERROR a_locked.json: can't read the file" in out
    assert "NOTE  b_ok.csv: 1 rows, 2 columns" in out


def test_validate_limits(tmp_path, capsys, monkeypatch):
    monkeypatch.setattr(datatool, "MAX_JSON_PARSE_BYTES", 64)
    data = tmp_path / "data"
    (data / "my folder").mkdir(parents=True)
    write(data / "my folder" / "ok.csv", "a\n1\n")
    write(data / "big.json", "[" + "1," * 100 + "1]")
    write(data / "long.ndjson", '{"a": 1}\n{"b": "' + "x" * 100 + '"}\n')
    assert run("validate", "--data-dir", str(data)) == 0  # warnings only
    out = capsys.readouterr().out
    assert "WARN  my folder/ok.csv: name has spaces" in out
    assert "WARN  big.json: over" in out
    assert "not checked" in out
    assert "WARN  long.ndjson: line 2 is over" in out


def test_validate_deep_json_is_a_warning(tmp_path, capsys):
    data = tmp_path / "data"
    data.mkdir()
    write(data / "deep.json", "[" * 100_000 + "]" * 100_000)
    write(data / "ok.csv", "a\n1\n")
    assert run("validate", "--data-dir", str(data)) == 0
    out = capsys.readouterr().out
    assert "WARN  deep.json: nested too deeply" in out
    assert "NOTE  ok.csv: 1 rows" in out


def test_validate_ndjson_limit_counts_bytes(tmp_path, capsys, monkeypatch):
    monkeypatch.setattr(datatool, "MAX_JSON_PARSE_BYTES", 64)
    data = tmp_path / "data"
    data.mkdir()
    write(data / "wide.ndjson", '{"a": "' + "é" * 40 + '"}\n')  # 40 characters, but over 64 bytes
    assert run("validate", "--data-dir", str(data)) == 0
    assert "WARN  wide.ndjson: line 1 is over" in capsys.readouterr().out


# ---------------------------------------------------------------- catalog


def test_catalog_contents_escaping_and_stability(tmp_path, capsys):
    data = tmp_path / "public" / "data"
    (data / "sub").mkdir(parents=True)
    write(data / "sales.csv", "id,amount\n1,2\n")
    assert run("convert", str(data / "sales.csv")) == 0
    write(data / "sub" / "a&b 'x'.csv", "<q>\n1\n")  # < > aren't allowed in Windows names
    write(data / ".hidden.csv", "a\n1\n")
    write(data / "notes.txt", "hi")
    assert run("catalog", "--data-dir", str(data)) == 0

    doc = json.loads((tmp_path / "public" / "catalog.json").read_text(encoding="utf-8"))
    paths = [d["path"] for d in doc["datasets"]]
    assert paths == ["sales.csv", "sales.parquet", "sub/a&b 'x'.csv"]
    parquet = next(d for d in doc["datasets"] if d["format"] == "parquet")
    assert parquet["rows"] == 1
    assert parquet["columns"][0] == {"name": "id", "type": "int64"}
    assert "rows" not in next(d for d in doc["datasets"] if d["path"] == "sales.csv")
    odd = next(d for d in doc["datasets"] if d["path"].startswith("sub/"))
    assert odd["url"] == "/data/sub/a%26b%20%27x%27.csv"

    page = (tmp_path / "public" / "catalog.html").read_text(encoding="utf-8")
    assert "a&amp;b &#x27;x&#x27;.csv" in page
    assert "&lt;q&gt;" in page
    assert "<q>" not in page

    capsys.readouterr()
    assert run("catalog", "--data-dir", str(data)) == 0
    assert capsys.readouterr().out.count("Unchanged") == 2, "re-run with no changes must not rewrite files"


def test_catalog_lists_unreadable_files_with_error(tmp_path):
    data = tmp_path / "public" / "data"
    data.mkdir(parents=True)
    write(data / "semi.csv", "a;b\n1;2\n")
    assert run("catalog", "--data-dir", str(data)) == 1
    doc = json.loads((tmp_path / "public" / "catalog.json").read_text(encoding="utf-8"))
    entry = doc["datasets"][0]
    assert entry["path"] == "semi.csv"
    assert "--delimiter" in entry["error"]
    assert "Can't read" in (tmp_path / "public" / "catalog.html").read_text(encoding="utf-8")


def test_catalog_lists_datasets_named_like_its_own_files(tmp_path):
    data = tmp_path / "public" / "data"
    (data / "sub").mkdir(parents=True)
    write(data / "sub" / "catalog.json", '{"a": 1}')
    assert run("catalog", "--data-dir", str(data)) == 0
    doc = json.loads((tmp_path / "public" / "catalog.json").read_text(encoding="utf-8"))
    assert [e["path"] for e in doc["datasets"]] == ["sub/catalog.json"]


def test_catalog_write_error_is_reported(tmp_path, capsys):
    data = tmp_path / "data"
    data.mkdir()
    write(data / "ok.csv", "a\n1\n")
    (tmp_path / "catalog.html").mkdir()  # can't be replaced by a file
    assert run("catalog", "--data-dir", str(data)) == 1
    assert "ERROR can't write" in capsys.readouterr().err


def test_catalog_scan_csv_counts_rows(tmp_path):
    data = tmp_path / "public" / "data"
    data.mkdir(parents=True)
    write(data / "t.csv", "a\n1\n2\n3\n")
    assert run("catalog", "--data-dir", str(data), "--scan-csv") == 0
    doc = json.loads((tmp_path / "public" / "catalog.json").read_text(encoding="utf-8"))
    assert doc["datasets"][0]["rows"] == 3


@pytest.mark.parametrize("command", ["validate", "catalog"])
def test_missing_data_dir_is_a_usage_error(tmp_path, command):
    with pytest.raises(SystemExit) as exc:
        run(command, "--data-dir", str(tmp_path / "nope"))
    assert exc.value.code == 2
