#!/usr/bin/env python3
"""Inventory bundled SDL declarations and binding references; not an ABI proof.

Run from any directory. --json includes per-function references. Exit status 1
means a direct BlitzMax binding mentions C bool in its SDL prototype.
Preprocessor branches are all included; macro APIs and callback typedefs are not.
"""
import argparse
import json
import re
from collections import Counter
from pathlib import Path


def inventory(root):
	functions = {}
	for path in sorted((root / "sdl3.mod/SDL3/include/SDL3").glob("*.h")):
		text = re.sub(r"/\*.*?\*/", "", path.read_text(), flags=re.S)
		pattern = r"extern\s+SDL_DECLSPEC\s+([^;{}]+?)\s+SDLCALL\s+(SDL_\w+)\s*\(([^;{}]*?)\)\s*;"
		for match in re.finditer(pattern, text, re.S):
			result, name, args = match.groups()
			functions[name] = dict(header=path.name, result=" ".join(result.split()),
				arguments=" ".join(args.split()), native_references=[], direct_bindings=[])
	for module in sorted(root.glob("*.mod")):
		for path in sorted(module.iterdir()):
			if not path.is_file() or path.suffix not in (".bmx", ".c", ".m", ".h"):
				continue
			text = path.read_text()
			location = str(path.relative_to(root))
			if path.suffix == ".bmx":
				text = re.sub(r"^\s*Rem\b.*?^\s*End\s*Rem\b[^\n]*", "", text, flags=re.M | re.S | re.I)
				text = re.sub(r"'[^\n]*", "", text)
				for block in re.findall(r"^\s*Extern\b[^\n]*\n(.*?)^\s*End\s*Extern\b", text, re.M | re.S | re.I):
					for line in block.splitlines():
						match = re.match(r'\s*Function\s+(\w+).*', line, re.I)
						if not match:
							continue
						alias = re.search(r'=\s*"(\w+)"', line)
						target = alias[1] if alias else match[1]
						if target in functions:
							functions[target]["direct_bindings"].append(location)
			else:
				text = re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S)
				for name in set(re.findall(r"\bSDL_\w+(?=\s*\()", text)):
					if name in functions:
						functions[name]["native_references"].append(location)
	return functions


def main():
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--json", action="store_true")
	args = parser.parse_args()
	functions = inventory(Path(__file__).resolve().parents[1])
	issues = [name for name, f in functions.items() if f["direct_bindings"]
		and re.search(r"\bbool\b", f["result"] + " " + f["arguments"])]
	if args.json:
		print(json.dumps(dict(functions=functions, direct_bool_issues=issues), indent=2, sort_keys=True))
	else:
		totals = Counter(f["header"] for f in functions.values())
		refs = Counter(f["header"] for f in functions.values() if f["native_references"] or f["direct_bindings"])
		print("Header | Exported declarations | Referenced by bindings/glue")
		for header in sorted(totals):
			print(f"{header} | {totals[header]} | {refs[header]}")
		print(f"Direct SDL declarations: {sum(len(f['direct_bindings']) for f in functions.values())}")
		print(f"Direct C bool findings: {len(issues)}")
		for name in issues:
			print(name, functions[name]["direct_bindings"])
		print("References include internal/test glue; they do not measure public API coverage.")
	raise SystemExit(bool(issues))


if __name__ == "__main__":
	main()
