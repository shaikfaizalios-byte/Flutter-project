# PrepLoop API (FastAPI)

See the [root README](../../README.md) for setup and run commands, and [CLAUDE.md](../../CLAUDE.md) for conventions.

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload
.\.venv\Scripts\pytest.exe
.\.venv\Scripts\ruff.exe check . ; .\.venv\Scripts\mypy.exe app tests
```

Dependency ranges are declared in `pyproject.toml`, and exact versions are pinned in `requirements.lock.txt`.
After changing dependencies, regenerate the lock file with:
`.\.venv\Scripts\python.exe -m pip freeze --exclude-editable | Set-Content -Encoding ascii requirements.lock.txt`
(do not use `>` in Windows PowerShell 5.1, which writes UTF-16).
