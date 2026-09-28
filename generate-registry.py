#!/usr/bin/env python3
"""Generate registry.json from */manifest.json (Noctalia reads it from the repo root)."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO_URL = "https://github.com/ValdemarPospisil/noctalia-plugins"
FIELDS = ["id", "name", "version", "author", "description", "minNoctaliaVersion", "license", "tags"]


def last_updated(plugin_dir: Path) -> str:
    out = subprocess.run(
        ["git", "log", "-1", "--format=%aI", "--", plugin_dir.name],
        cwd=ROOT, capture_output=True, text=True,
    ).stdout.strip()
    return out or subprocess.run(["date", "-Iseconds"], capture_output=True, text=True).stdout.strip()


plugins = []
for manifest_path in sorted(ROOT.glob("*/manifest.json")):
    manifest = json.loads(manifest_path.read_text())
    entry = {k: manifest[k] for k in FIELDS if k in manifest}
    entry["official"] = False
    entry["repository"] = REPO_URL
    entry["lastUpdated"] = last_updated(manifest_path.parent)
    plugins.append(entry)

registry = {"version": 1, "plugins": plugins}
(ROOT / "registry.json").write_text(json.dumps(registry, indent=2, ensure_ascii=False) + "\n")
print(f"registry.json: {len(plugins)} plugins")
