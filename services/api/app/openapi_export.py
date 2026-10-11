"""Write the OpenAPI schema to a file: python -m app.openapi_export <output-path>."""

import json
import sys
from pathlib import Path

from app.core.config import Environment, Settings
from app.main import create_app


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: python -m app.openapi_export <output-path>")
    output = Path(sys.argv[1])
    # Docs are disabled in production; export with development settings.
    schema = create_app(Settings(environment=Environment.DEVELOPMENT)).openapi()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(schema, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Wrote {output}")


if __name__ == "__main__":
    main()
