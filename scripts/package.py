#!/usr/bin/env python3
"""Builds the Mod.io upload: dist/ritualist-<version>.zip with main.lua and plugin.json at the top level.

Usage: scripts/package.py

For development, plugin.json names PrettyUI by its dev_plugins folder; the upload names it by its mod.io ID.
"""

import json
import pathlib
import sys
import zipfile
from typing import Any

PRETTYUI_MODIO_ID = 6398181
SKIP: set[str] = {".gitkeep"}

ROOT = pathlib.Path(__file__).resolve().parent.parent
PLUGIN = ROOT / "plugin"


def manifest() -> dict[str, Any]:
    data: dict[str, Any] = json.loads((PLUGIN / "plugin.json").read_text())
    deps: dict[str, Any] = data.get("requiredDependencies", {})
    if deps.get("prettyui") != "prettyui":
        sys.exit('plugin.json: expected "requiredDependencies": { "prettyui": "prettyui" }')
    deps["prettyui"] = PRETTYUI_MODIO_ID
    return data


def main() -> None:
    data = manifest()
    out = ROOT / "dist" / f"ritualist-{data['version']}.zip"
    out.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(PLUGIN.rglob("*")):
            if path.is_file() and path.name not in SKIP:
                name = path.relative_to(PLUGIN).as_posix()
                if name == "plugin.json":
                    zf.writestr(name, json.dumps(data, indent=4) + "\n")
                else:
                    zf.write(path, name)
    print(f"Wrote {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
