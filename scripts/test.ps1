$ErrorActionPreference = "Stop"

$env:PYTHONPATH = "src"

if (Get-Command uv -ErrorAction SilentlyContinue) {
    uv run pytest -v
} elseif (Test-Path ".\.venv\Scripts\pytest.exe") {
    & ".\.venv\Scripts\pytest.exe" -v
} else {
    python -m pytest -v
}