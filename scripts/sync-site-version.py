#!/usr/bin/env python3
"""Keep current marketing version labels and links aligned with Xcode."""
import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
FILES = ("docs/index.html", "docs/llms.txt", "README.md")
NUMBER = r"\d+\.\d+(?:\.\d+)?"
PATTERNS = (
    rf"((?:MacEdgeLight |version:? |new in |Download ))({NUMBER})(?!\d|\.\d)",
    rf"(/releases/(?:tag|download)/v)({NUMBER})(?!\d|\.\d)",
    rf'("softwareVersion"\s*:\s*")({NUMBER})(?!\d|\.\d)',
    rf"(\[)({NUMBER})(?= DMG\])",
)


def synchronize(text, version):
    for pattern in PATTERNS:
        text = re.sub(pattern, lambda match: match[1] + version, text, flags=re.IGNORECASE)
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail instead of changing stale versions")
    args = parser.parse_args()
    project = (ROOT / "MacEdgeLight.xcodeproj/project.pbxproj").read_text()
    versions = set(re.findall(r"MARKETING_VERSION = ([^;]+);", project))
    if len(versions) != 1 or not re.fullmatch(r"\d+\.\d+\.\d+", next(iter(versions), "")):
        parser.error("Xcode configurations must share one full major.minor.patch version")
    version = versions.pop()
    stale = []
    for name in FILES:
        path = ROOT / name
        original = path.read_text()
        updated = synchronize(original, version)
        if updated != original:
            stale.append(name)
            if not args.check:
                path.write_text(updated)
    if args.check and stale:
        parser.exit(1, f"Expected {version} in {', '.join(stale)}. Run make sync-site-version.\n")
    print(f"Marketing version {'verified' if args.check else 'synchronized'}: {version}")


if __name__ == "__main__":
    main()
