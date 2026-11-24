#!/usr/bin/env python3
"""
mygame External Binary Assets Pack / Unpack / Verify Tool
Separates heavy binary 3D/animation/texture packs (synced via Google Drive)
from Git-tracked source code, scenes, shaders, .tres BoneMaps, and .import rules.

Usage:
  python tools/pack_assets.py pack --out dist/mygame-assets-v1.zip
  python tools/pack_assets.py unpack path/to/mygame-assets-v1.zip
  python tools/pack_assets.py verify
"""

import argparse
import hashlib
import json
import os
import sys
import zipfile
from typing import List

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MANIFEST_PATH = os.path.join(ROOT_DIR, "assets_manifest.json")

# External asset roots included in the Google Drive bundle (excluding *.import & *.tres which live in Git!)
ASSET_TARGETS = [
    "assets/packs/kenney_retro_urban",
    "assets/packs/summer_cuteness_avatar",
    "assets/animations/mixamo",
]

EXCLUDED_EXTS = {".import", ".tres", ".uid", ".gd", ".gdshader", ".tscn"}


def collect_asset_files() -> List[str]:
    files: List[str] = []
    for rel_root in ASSET_TARGETS:
        abs_root = os.path.join(ROOT_DIR, rel_root)
        if not os.path.exists(abs_root):
            continue
        for dp, _, fns in os.walk(abs_root):
            for fn in sorted(fns):
                ext = os.path.splitext(fn)[1].lower()
                if ext in EXCLUDED_EXTS:
                    continue
                full = os.path.join(dp, fn)
                rel = os.path.relpath(full, ROOT_DIR).replace("\\", "/")
                files.append(rel)
    files.sort()
    return files


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def cmd_pack(out_path: str, version: str, drive_folder_id: str, drive_file_id: str) -> int:
    files = collect_asset_files()
    if not files:
        print("[ERROR] No external asset files found to pack.", file=sys.stderr)
        return 1

    abs_out = out_path if os.path.isabs(out_path) else os.path.join(ROOT_DIR, out_path)
    os.makedirs(os.path.dirname(abs_out), exist_ok=True)

    total_bytes = 0
    with zipfile.ZipFile(abs_out, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for rel in files:
            full = os.path.join(ROOT_DIR, rel)
            total_bytes += os.path.getsize(full)
            zf.write(full, arcname=rel)

    zip_bytes = os.path.getsize(abs_out)
    zip_sha = sha256_file(abs_out)

    manifest = {
        "bundle_name": os.path.basename(abs_out),
        "version": version,
        "drive_folder_id": drive_folder_id,
        "drive_file_id": drive_file_id,
        "file_count": len(files),
        "uncompressed_bytes": total_bytes,
        "zip_bytes": zip_bytes,
        "zip_sha256": zip_sha,
        "included_roots": ASSET_TARGETS,
        "files": files,
    }
    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(
        f"[PACK OK] {abs_out}\n"
        f"  Files: {len(files)} | Raw: {total_bytes / 1024 / 1024:.2f} MB | "
        f"Zip: {zip_bytes / 1024 / 1024:.2f} MB | SHA256: {zip_sha[:12]}..."
    )
    print(f"[MANIFEST] Updated {MANIFEST_PATH}")
    return 0


def cmd_unpack(zip_path: str) -> int:
    if not os.path.exists(zip_path):
        print(f"[ERROR] Zip not found: {zip_path}", file=sys.stderr)
        return 1

    extracted = 0
    skipped = 0
    with zipfile.ZipFile(zip_path, "r") as zf:
        for member in zf.infolist():
            if member.is_dir():
                continue
            rel = member.filename.replace("\\", "/").lstrip("/")
            if ".." in rel.split("/"):
                print(f"[WARN] Skipping unsafe path: {rel}")
                continue
            ext = os.path.splitext(rel)[1].lower()
            if ext in EXCLUDED_EXTS:
                skipped += 1
                continue
            dest = os.path.join(ROOT_DIR, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with zf.open(member, "r") as src, open(dest, "wb") as dst:
                dst.write(src.read())
            extracted += 1

    print(f"[UNPACK OK] Extracted {extracted} asset files (preserved Git-tracked .import/.tres; skipped {skipped}).")
    print("Next step: run `godot --headless --path . --import` to rebuild local .godot/ cache.")
    return 0


def cmd_verify() -> int:
    if not os.path.exists(MANIFEST_PATH):
        print(f"[ERROR] Missing {MANIFEST_PATH}", file=sys.stderr)
        return 1
    with open(MANIFEST_PATH, encoding="utf-8") as f:
        manifest = json.load(f)

    expected: List[str] = manifest.get("files", [])
    missing = [rel for rel in expected if not os.path.exists(os.path.join(ROOT_DIR, rel))]
    if missing:
        print(f"[MISSING] {len(missing)} / {len(expected)} external assets are missing locally:")
        for m in missing[:15]:
            print(f"  - {m}")
        if len(missing) > 15:
            print(f"  ... and {len(missing) - 15} more.")
        print(f"Download '{manifest.get('bundle_name')}' from Google Drive and run:")
        print(f"  python tools/pack_assets.py unpack <downloaded-zip>")
        return 1

    print(f"[VERIFY OK] All {len(expected)} external asset files ({manifest.get('version')}) are present locally!")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="mygame external asset bundle helper")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_pack = sub.add_parser("pack", help="Pack external binary assets into a zip + update assets_manifest.json")
    p_pack.add_argument("--out", default="dist/mygame-assets-v1.zip", help="Output zip path")
    p_pack.add_argument("--version", default="v1", help="Bundle version tag")
    p_pack.add_argument("--drive-folder-id", default="", help="Google Drive folder ID")
    p_pack.add_argument("--drive-file-id", default="", help="Google Drive file ID")

    p_unpack = sub.add_parser("unpack", help="Extract downloaded asset zip into workspace safely")
    p_unpack.add_argument("zip_path", help="Path to downloaded mygame-assets-*.zip")

    sub.add_parser("verify", help="Verify all manifest assets exist locally")

    args = parser.parse_args()
    if args.cmd == "pack":
        return cmd_pack(args.out, args.version, args.drive_folder_id, args.drive_file_id)
    if args.cmd == "unpack":
        return cmd_unpack(args.zip_path)
    return cmd_verify()


if __name__ == "__main__":
    raise SystemExit(main())
