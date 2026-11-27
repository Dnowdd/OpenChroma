"""Merges lib/l10n/parts/*_en.arb and *_pt.arb into app_en.arb / app_pt.arb."""
import json
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parent.parent / "lib" / "l10n"
parts = root / "parts"
errors = []

for locale in ("en", "pt"):
    merged = {"@@locale": locale}
    owner = {}
    for f in sorted(parts.glob(f"*_{locale}.arb")):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            errors.append(f"{f.name}: {e}")
            continue
        for k, v in data.items():
            if k.startswith("@@"):
                continue
            if k in merged and merged[k] != v:
                errors.append(f"{f.name}: key '{k}' also defined in {owner[k]}")
            merged[k] = v
            owner[k] = f.name
    (root / f"app_{locale}.arb").write_text(
        json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

en = json.loads((root / "app_en.arb").read_text(encoding="utf-8"))
pt = json.loads((root / "app_pt.arb").read_text(encoding="utf-8"))
keys = lambda d: {k for k in d if not k.startswith("@")}
for k in sorted(keys(pt) - keys(en)):
    errors.append(f"pt key '{k}' has no English source")
missing = sorted(keys(en) - keys(pt) - {"appTitle"})
if missing:
    print("untranslated pt keys:", ", ".join(missing))
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
