#!/usr/bin/env python3
"""strip images from claude code conversation JSONL files.

replaces base64 image blocks with lightweight text placeholders,
preserving conversation structure. creates a backup before modifying.

usage:
    claude-strip-images <file.jsonl>             # strip a specific file
    claude-strip-images --scan                   # scan all projects, report only
    claude-strip-images --scan <file.jsonl>      # scan a specific file, report only
    claude-strip-images --auto                   # strip all files with images
"""

import argparse
import base64
import glob
import json
import os
import shutil
import struct
import sys
from pathlib import Path


MIN_BASE64_SIZE = 1000  # ignore tiny inline icons


def get_png_dimensions(data_b64: str) -> tuple[int | None, int | None]:
    try:
        raw = base64.b64decode(data_b64[:100])
        if raw[:8] == b"\x89PNG\r\n\x1a\n":
            w = struct.unpack(">I", raw[16:20])[0]
            h = struct.unpack(">I", raw[20:24])[0]
            return w, h
    except Exception:
        pass
    return None, None


def get_jpeg_dimensions(data_b64: str) -> tuple[int | None, int | None]:
    try:
        raw = base64.b64decode(data_b64)
        i = 0
        while i < len(raw) - 1:
            if raw[i] != 0xFF:
                i += 1
                continue
            marker = raw[i + 1]
            if marker == 0xD8:
                i += 2
            elif marker in (0xC0, 0xC2):
                h = struct.unpack(">H", raw[i + 5 : i + 7])[0]
                w = struct.unpack(">H", raw[i + 7 : i + 9])[0]
                return w, h
            elif marker == 0xFF:
                i += 1
            else:
                length = struct.unpack(">H", raw[i + 2 : i + 4])[0]
                i += 2 + length
    except Exception:
        pass
    return None, None


def get_dimensions(data_b64: str, media_type: str) -> str:
    if "png" in media_type:
        w, h = get_png_dimensions(data_b64)
    elif "jpeg" in media_type or "jpg" in media_type:
        w, h = get_jpeg_dimensions(data_b64)
    else:
        w, h = get_png_dimensions(data_b64)
        if not w:
            w, h = get_jpeg_dimensions(data_b64)
    return f"{w}x{h}" if w else "unknown"


def strip_images(obj: any, stats: dict) -> any:
    """recursively replace image blocks with text placeholders."""
    if isinstance(obj, dict):
        if obj.get("type") == "image" and "source" in obj:
            src = obj["source"]
            data = src.get("data", "")
            if len(data) < MIN_BASE64_SIZE:
                return obj  # keep tiny icons
            media = src.get("media_type", "image/png")
            dims = get_dimensions(data, media)
            stats["count"] += 1
            stats["bytes"] += len(data)
            return {"type": "text", "text": f"[image removed: {dims} {media}]"}
        return {k: strip_images(v, stats) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [strip_images(item, stats) for item in obj]
    return obj


def scan_file(path: str) -> dict:
    """scan a JSONL file and return image stats without modifying it."""
    stats = {"count": 0, "bytes": 0, "lines": 0, "file_size": os.path.getsize(path)}
    with open(path) as f:
        for line in f:
            stats["lines"] += 1
            try:
                obj = json.loads(line)
                # count images without modifying
                count_images(obj, stats)
            except json.JSONDecodeError:
                pass
    return stats


def count_images(obj: any, stats: dict) -> None:
    """recursively count images and their sizes."""
    if isinstance(obj, dict):
        if obj.get("type") == "image" and "source" in obj:
            data = obj["source"].get("data", "")
            if len(data) >= MIN_BASE64_SIZE:
                stats["count"] += 1
                stats["bytes"] += len(data)
            return
        for v in obj.values():
            count_images(v, stats)
    elif isinstance(obj, list):
        for item in obj:
            count_images(item, stats)


def fix_file(path: str, no_backup: bool = False) -> dict:
    """strip images from a JSONL file. returns stats."""
    stats = {"count": 0, "bytes": 0}

    with open(path) as f:
        lines = f.readlines()

    if not no_backup:
        backup = path + ".bak"
        shutil.copy2(path, backup)

    new_lines = []
    for line in lines:
        try:
            obj = json.loads(line)
            obj = strip_images(obj, stats)
            new_lines.append(json.dumps(obj, separators=(",", ":")) + "\n")
        except json.JSONDecodeError:
            new_lines.append(line)

    with open(path, "w") as f:
        f.writelines(new_lines)

    return stats


def find_all_jsonl() -> list[str]:
    """find all Claude Code conversation JSONL files."""
    claude_dir = Path.home() / ".claude" / "projects"
    files = []
    for path in claude_dir.rglob("*.jsonl"):
        files.append(str(path))
    return sorted(files)


def format_bytes(n: int) -> str:
    if n < 1024:
        return f"{n}B"
    if n < 1024 * 1024:
        return f"{n / 1024:.1f}KB"
    return f"{n / (1024 * 1024):.1f}MB"


def main():
    parser = argparse.ArgumentParser(
        description="strip images from claude code conversation JSONL files"
    )
    parser.add_argument("file", nargs="?", help="specific JSONL file to process")
    parser.add_argument(
        "--scan", action="store_true", help="scan and report only, don't modify"
    )
    parser.add_argument(
        "--auto",
        action="store_true",
        help="automatically strip all files with images",
    )
    parser.add_argument(
        "--no-backup", action="store_true", help="skip creating backup files"
    )
    args = parser.parse_args()

    if args.file:
        if not os.path.exists(args.file):
            print(f"error: file not found: {args.file}", file=sys.stderr)
            sys.exit(1)
        files = [args.file]
    elif args.scan or args.auto:
        files = find_all_jsonl()
    else:
        parser.print_help()
        sys.exit(1)

    if args.scan:
        print(f"scanning {len(files)} file(s)...\n")
        total_images = 0
        total_bytes = 0
        for path in files:
            stats = scan_file(path)
            if stats["count"] > 0:
                total_images += stats["count"]
                total_bytes += stats["bytes"]
                relpath = path.replace(str(Path.home()), "~")
                print(
                    f"  {stats['count']:3d} images  "
                    f"{format_bytes(stats['bytes']):>8s}  "
                    f"{format_bytes(stats['file_size']):>8s} total  "
                    f"{relpath}"
                )
        if total_images == 0:
            print("  no images found.")
        else:
            print(f"\n  total: {total_images} images, {format_bytes(total_bytes)}")
        return

    # fix mode
    for path in files:
        scan = scan_file(path)
        if scan["count"] == 0:
            if not args.auto:
                print(f"no images found in {path}")
            continue

        relpath = path.replace(str(Path.home()), "~")
        print(f"stripping {scan['count']} images from {relpath}...")
        result = fix_file(path, no_backup=args.no_backup)
        print(
            f"  removed {result['count']} images, "
            f"saved {format_bytes(result['bytes'])}"
        )
        if not args.no_backup:
            print(f"  backup: {path}.bak")


if __name__ == "__main__":
    main()
