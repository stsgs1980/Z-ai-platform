#!/usr/bin/env python3
"""
fix-std-violations.py — Auto-fix STD-DOC-002/003 violations in .md files.

Handles:
1. STD-DOC-003: Replace emoji with text tags
2. STD-DOC-003: Replace Unicode box/line drawing with ASCII
3. STD-DOC-002: Add language to code blocks that are missing it
   (infers language from content when possible, uses 'text' as fallback)

Uses a line-by-line state machine for reliable code block detection
(regex-based splitting fails on nested/overlapping fences).

Usage: python3 fix-std-violations.py [directory]
"""

import os
import re
import sys

# --- STD-DOC-003: Emoji replacements ---
EMOJI_REPLACEMENTS = {
    # Check marks
    '\u2705': '[OK]',       # ✅
    '\u2713':  '[OK]',      # ✓
    '\u2714':  '[OK]',      # ✔
    '\u274C': '[FAIL]',     # ❌
    '\u2717':  '[FAIL]',    # ✗
    '\u2718':  '[FAIL]',    # ✘
    '\u2612':  '[FAIL]',    # ☒
    '\u2611':  '[OK]',      # ☑

    # Warning/info
    '\u26A0\uFE0F': '[WARNING]',  # ⚠️
    '\u26A0':  '[WARNING]',       # ⚠
    '\U0001F4A1': '[TIP]',        # 💡
    '\U0001F525': '[HOT]',        # 🔥
    '\U0001F680': '[LAUNCH]',     # 🚀
    '\u2B50':  '[STAR]',          # ⭐
    '\U0001F31F': '[STAR]',       # 🌟
    '\u2728':  '[SPARKLE]',       # ✨

    # Objects
    '\U0001F4C1': '[FOLDER]',     # 📁
    '\U0001F4C2': '[FOLDER]',     # 📂
    '\U0001F512': '[LOCKED]',     # 🔒
    '\U0001F513': '[UNLOCKED]',   # 🔓
    '\U0001FAB5': '[WOOD]',       # 🪵

    # Other common
    '\u25CB':  '[O]',        # ○
    '\u25CF':  '[*]',        # ●
    '\u2192':  '->',         # →
    '\u2190':  '<-',         # ←
    '\u21D2':  '=>',         # ⇒
    '\u21D0':  '<=',         # ⇐
}

# Build regex for emoji replacement
emoji_pattern = '|'.join(re.escape(k) for k in sorted(EMOJI_REPLACEMENTS, key=len, reverse=True))
EMOJI_RE = re.compile(emoji_pattern)

# Catch-all for regional indicator flags (two regional indicator letters)
FLAG_RE = re.compile(
    '['
    '\U0001F1E0-\U0001F1FF'  # Regional indicators
    ']{2}'
)

# --- STD-DOC-003: Unicode box/line drawing ---
UNICODE_GRAPHICS_RE = re.compile(r'[\u2500-\u257F\u2580-\u259F\u25A0-\u25FF\u2800-\u28FF]')

# Fence pattern: 3 or more backticks at the start of a line
FENCE_OPEN_RE = re.compile(r'^( `{3,})(.*)$')
FENCE_CLOSE_RE = re.compile(r'^ `{3,}\s*$')


def infer_language(code_lines):
    """Infer the language of a code block from its content lines."""
    if not code_lines:
        return 'text'

    stripped = '\n'.join(code_lines).strip()
    if not stripped:
        return 'text'

    first_line = stripped.split('\n')[0].strip()

    # Shell indicators
    if first_line.startswith('$ ') or first_line.startswith('#!/bin/') or first_line.startswith('npm ') or first_line.startswith('npx ') or first_line.startswith('git '):
        return 'bash'
    if first_line.startswith('curl ') or first_line.startswith('echo ') or first_line.startswith('mkdir ') or first_line.startswith('cd '):
        return 'bash'
    if first_line.startswith('chmod ') or first_line.startswith('export ') or first_line.startswith('source '):
        return 'bash'
    if first_line.startswith('pip ') or first_line.startswith('python ') or first_line.startswith('python3 ') or first_line.startswith('uv '):
        return 'bash'
    if first_line.startswith('npx ') or first_line.startswith('yarn ') or first_line.startswith('pnpm ') or first_line.startswith('bun ') or first_line.startswith('node '):
        return 'bash'
    if first_line.startswith('docker ') or first_line.startswith('kubectl '):
        return 'bash'
    if first_line.startswith('cat ') or first_line.startswith('ls ') or first_line.startswith('rm ') or first_line.startswith('cp ') or first_line.startswith('mv '):
        return 'bash'
    if first_line.startswith('./') or first_line.startswith('sh '):
        return 'bash'

    # Python indicators
    if re.match(r'^(import |from \w+|def |class |if __name__|print\(|@)', first_line):
        return 'python'
    if any('def ' in line or 'import ' in line or 'from ' in line for line in code_lines[:3]):
        return 'python'

    # TypeScript indicators
    if re.match(r'^(import .*from|export |interface |type |enum |namespace |declare )', first_line):
        return 'typescript'

    # JavaScript indicators
    if re.match(r'^(import |export |const |let |var |function |class |async |module\.)', first_line):
        return 'javascript'
    if first_line.startswith('require(') or first_line.startswith('module.'):
        return 'javascript'

    # JSON
    if stripped.startswith('{') and stripped.endswith('}'):
        return 'json'
    if stripped.startswith('[') and stripped.endswith(']'):
        return 'json'

    # YAML
    if re.match(r'^[a-z_]+:', first_line) and '{' not in first_line[:50]:
        return 'yaml'

    # SQL
    if re.match(r'^(SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|WITH)\b', first_line, re.IGNORECASE):
        return 'sql'

    # Dockerfile
    if re.match(r'^(FROM|RUN|COPY|WORKDIR|EXPOSE|CMD|ENTRYPOINT|ARG|ENV)\b', first_line):
        return 'dockerfile'

    # HTML/XML
    if re.match(r'^<!DOCTYPE|^<\?xml|^<html|^<div|^<span|^<head|^<body|^<svg', first_line):
        return 'html'

    # CSS/SCSS
    if re.match(r'^[\.#@][a-zA-Z-]', first_line):
        return 'css'

    # TypeScript in the rest of the block
    if any('interface ' in line or 'type ' in line for line in code_lines[:5]):
        return 'typescript'
    if any('export ' in line and (':' in line or '<' in line) for line in code_lines[:5]):
        return 'typescript'

    # Mermaid
    if first_line.startswith('graph ') or first_line.startswith('sequenceDiagram') or first_line.startswith('flowchart') or first_line.startswith('classDiagram'):
        return 'mermaid'

    # Default
    return 'text'


def fix_file(filepath):
    """Fix all violations in a single file. Returns (fixed, count) tuple."""
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()

    original = content
    changes = 0

    # 1. Fix emoji (STD-DOC-003)
    def replace_emoji(match):
        nonlocal changes
        emoji = match.group(0)
        replacement = EMOJI_REPLACEMENTS.get(emoji, '[ICON]')
        if replacement != emoji:
            changes += 1
        return replacement

    content = EMOJI_RE.sub(replace_emoji, content)

    # Fix flags (regional indicator pairs)
    def replace_flag(match):
        nonlocal changes
        changes += 1
        flag_str = match.group(0)
        code_points = [ord(c) for c in flag_str]
        country = ''.join(chr(cp - 0x1F1E6 + ord('A')) for cp in code_points)
        return f'[{country}]'

    content = FLAG_RE.sub(replace_flag, content)

    # 2. Fix Unicode graphics (STD-DOC-003)
    def replace_unicode_graphics(match):
        nonlocal changes
        changes += 1
        return '-'

    content = UNICODE_GRAPHICS_RE.sub(replace_unicode_graphics, content)

    # 3. Fix code blocks without language (STD-DOC-002)
    # Line-by-line state machine — handles nested fences correctly
    lines = content.split('\n')
    new_lines = []
    in_code = False
    code_lines = []
    fence_len = 0
    open_fence_idx = -1

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not in_code:
            # Check for opening fence
            m = re.match(r'^(`{3,})(.*)?$', stripped)
            if m:
                fence_len = len(m.group(1))
                lang_part = m.group(2) or ''
                if lang_part.strip() == '':
                    # No language — collect code block content first
                    in_code = True
                    code_lines = []
                    open_fence_idx = len(new_lines)  # where to insert fixed fence
                    # Don't add the fence line yet — we'll add it after collecting content
                    i += 1
                    continue
                else:
                    # Has language — keep as is
                    new_lines.append(line)
                    in_code = True
                    code_lines = []
                    fence_len = len(m.group(1))
                    open_fence_idx = -1  # don't need to fix
                    i += 1
                    continue
            else:
                new_lines.append(line)
                i += 1
        else:
            # Inside code block
            # Check for closing fence
            close_m = re.match(r'^(`{3,})\s*$', stripped)
            if close_m and len(close_m.group(1)) >= fence_len:
                # Closing fence found
                if open_fence_idx >= 0:
                    # Need to fix the opening fence — infer language
                    lang = infer_language(code_lines)
                    new_lines.insert(open_fence_idx, '```' + lang)
                    changes += 1
                    open_fence_idx = -1
                else:
                    # Opening fence was already correct
                    pass
                new_lines.append(line)
                in_code = False
                code_lines = []
                i += 1
                continue
            else:
                code_lines.append(line)
                new_lines.append(line)
                i += 1

    # Handle unclosed code block at end of file
    if in_code and open_fence_idx >= 0:
        lang = infer_language(code_lines)
        new_lines.insert(open_fence_idx, '```' + lang)
        changes += 1

    content = '\n'.join(new_lines)

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        return True, changes
    return False, 0


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else '.'
    total_files = 0
    total_changes = 0

    for root, dirs, files in os.walk(target):
        dirs[:] = [d for d in dirs if d not in ('node_modules', '.next', 'dist', 'build', '.git')]
        for f in sorted(files):
            if not f.endswith('.md'):
                continue
            filepath = os.path.join(root, f)
            fixed, count = fix_file(filepath)
            if fixed:
                total_files += 1
                total_changes += count
                print(f'  Fixed {count} violation(s): {filepath}')

    print(f'\nTotal: {total_changes} violations fixed in {total_files} files')


if __name__ == '__main__':
    main()
