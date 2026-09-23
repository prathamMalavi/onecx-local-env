#!/usr/bin/env python3
"""
Copilot Token Usage Report - Monthly/Session breakdown.

Extracts ACTUAL input/output token counts from VS Code chatSessions JSONL files
across ALL workspaces. Includes session metadata from session-store.db.

Scans local desktop installs (macOS/Windows/Linux), VS Code variants
(stable/Insiders/VSCodium/Cursor), and remote/WSL/SSH/container servers
(~/.vscode-server, ~/.vscode-server-insiders). On Windows it also reaches
into WSL distros via the \\wsl$ share.

Usage:
  python3 scripts/copilot_usage_report.py                    # Current month
  python3 scripts/copilot_usage_report.py --month previous   # Previous month
  python3 scripts/copilot_usage_report.py --month 2026-07    # Specific month
  python3 scripts/copilot_usage_report.py --all              # All available data
  python3 scripts/copilot_usage_report.py --csv              # Export to CSV
  python3 scripts/copilot_usage_report.py --daily            # Daily breakdown
  python3 scripts/copilot_usage_report.py --by-workspace     # Group by workspace
  python3 scripts/copilot_usage_report.py --locations        # List scanned dirs
"""

import argparse
import csv
import glob
import json
import os
import platform
import re
import sqlite3
import sys
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

# VS Code editor variants that share the same User-data layout
VSCODE_VARIANTS = ['Code', 'Code - Insiders', 'VSCodium', 'Cursor']
# Remote/WSL/SSH/container server data lives under these home-relative dirs
SERVER_DIRS = ['.vscode-server', '.vscode-server-insiders', '.cursor-server']


def discover_user_dirs() -> list[Path]:
    """Discover every VS Code 'User' data dir across all OSes, installs, and remotes.

    Scans: Linux remote server, Windows (native + via WSL /mnt/c mount),
    macOS, Flatpak/Snap variants, and WSL distro home dirs.
    """
    home = Path.home()
    system = platform.system()
    candidates: list[Path] = []

    bases: list[Path] = [
        home / 'Library' / 'Application Support',            # macOS
        home / 'AppData' / 'Roaming',                        # Windows default
        home / '.config',                                    # Linux XDG default
        home / '.var' / 'app' / 'com.visualstudio.code' / 'config',
        home / '.var' / 'app' / 'com.visualstudio.code-insiders' / 'config',
        home / 'snap' / 'code' / 'current' / '.config',
        home / 'snap' / 'code-insiders' / 'current' / '.config',
    ]
    if os.environ.get('APPDATA'):
        bases.append(Path(os.environ['APPDATA']))
    if os.environ.get('XDG_CONFIG_HOME'):
        bases.append(Path(os.environ['XDG_CONFIG_HOME']))

    for base in bases:
        for v in VSCODE_VARIANTS:
            candidates.append(base / v / 'User')

    portable = os.environ.get('VSCODE_PORTABLE')
    if portable:
        candidates.append(Path(portable) / 'user-data' / 'User')

    # Remote/SSH/container server dirs under current Linux home
    for server in SERVER_DIRS:
        candidates.append(home / server / 'data' / 'User')

    # From Windows host: reach WSL distros via UNC share
    if system == 'Windows':
        for wsl_root in (Path(r'\\wsl$'), Path(r'\\wsl.localhost')):
            try:
                if not wsl_root.exists():
                    continue
                for distro in wsl_root.iterdir():
                    # /home/* users
                    for user_home in _iter_homes(distro / 'home'):
                        for server in SERVER_DIRS:
                            candidates.append(user_home / server / 'data' / 'User')
                    # root user
                    for server in SERVER_DIRS:
                        candidates.append(distro / 'root' / server / 'data' / 'User')
            except OSError:
                continue

    # From Linux/WSL: reach Windows host VS Code data via /mnt/c
    wsl_win = Path('/mnt/c/Users')
    if wsl_win.exists():
        try:
            for user_home in wsl_win.iterdir():
                if user_home.name in ('All Users', 'Default', 'Default User', 'Public', 'defaultuser0') or user_home.name.startswith('.'):
                    continue
                appdata = user_home / 'AppData' / 'Roaming'
                for v in VSCODE_VARIANTS:
                    candidates.append(appdata / v / 'User')
        except OSError:
            pass

    # Other WSL distros mounted under /mnt (Ubuntu, Debian, etc.)
    mnt = Path('/mnt')
    if mnt.exists():
        try:
            for drive in mnt.iterdir():
                if drive.name in ('c', 'wsl', 'wslg') or len(drive.name) != 1:
                    continue
                for user_home in _iter_homes(drive / 'home'):
                    for server in SERVER_DIRS:
                        candidates.append(user_home / server / 'data' / 'User')
        except OSError:
            pass

    seen: set[str] = set()
    out: list[Path] = []
    for d in candidates:
        key = str(d)
        if key not in seen:
            seen.add(key)
            try:
                if d.exists():
                    out.append(d)
            except OSError:
                continue
    return out


def _iter_homes(homes_dir: Path):
    """Yield subdirectories of a /home directory, ignoring errors."""
    try:
        if homes_dir.exists():
            yield from (p for p in homes_dir.iterdir() if p.is_dir())
    except OSError:
        pass


def _iglob_all(globs: list[str]) -> list[str]:
    """Expand a list of glob patterns into a flat list of matching paths."""
    out: list[str] = []
    for g in globs:
        out.extend(glob.glob(g))
    return out


# Discovered VS Code User data dirs (local + remote/WSL)
USER_DIRS = discover_user_dirs()

CHAT_SESSIONS_GLOBS = [
    str(d / 'workspaceStorage' / '*' / 'GitHub.copilot-chat' / 'debug-logs' / '*' / 'main.jsonl') for d in USER_DIRS
]
MODELS_JSON_GLOBS = [
    str(d / 'workspaceStorage' / '*' / 'GitHub.copilot-chat' / 'debug-logs' / '*' / 'models.json')
    for d in USER_DIRS
]
SESSION_DBS = [
    str(d / 'globalStorage' / 'github.copilot-chat' / 'session-store.db') for d in USER_DIRS
]

# Pricing per 1M tokens (dollars) - loaded from models.json or fallback
DEFAULT_PRICING: dict[str, dict[str, float]] = {
    'claude-opus-4.5':       {'input': 5.00, 'output': 25.00},
    'claude-opus-4.6':       {'input': 5.00, 'output': 25.00},
    'claude-sonnet-4.5':     {'input': 3.00, 'output': 15.00},
    'claude-sonnet-4.6':     {'input': 3.00, 'output': 15.00},
    'gpt-4o':                {'input': 2.50, 'output': 10.00},
    'gpt-4o-mini':           {'input': 0.15, 'output': 0.60},
    'gpt-4.1-copilot':       {'input': 2.00, 'output': 8.00},
}


def load_model_pricing() -> dict[str, dict[str, float]]:
    """Load pricing from most recent models.json across all locations."""
    pricing = dict(DEFAULT_PRICING)
    models_files = _iglob_all(MODELS_JSON_GLOBS)
    if not models_files:
        return pricing
    
    models_files.sort(key=os.path.getmtime, reverse=True)
    try:
        with open(models_files[0]) as f:
            data = json.load(f)
            for m in data:
                model_id = m.get('id', '')
                prices = m.get('billing', {}).get('token_prices', {}).get('default', {})
                if prices.get('input_price') is not None:
                    pricing[model_id] = {
                        'input': prices.get('input_price', 0) / 100,
                        'output': prices.get('output_price', 0) / 100,
                    }
    except Exception:
        pass
    return pricing


def load_session_metadata() -> dict[str, dict]:
    """Load session metadata from every session-store.db found."""
    sessions = {}

    for db_path in SESSION_DBS:
        if not os.path.exists(db_path):
            continue
        try:
            conn = sqlite3.connect(db_path)
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()

            cursor.execute("""
                SELECT id, cwd, repository, branch, summary, agent_name, 
                       created_at, updated_at
                FROM sessions
            """)

            for row in cursor.fetchall():
                sessions[row['id']] = {
                    'cwd': row['cwd'] or '',
                    'repository': row['repository'] or '',
                    'branch': row['branch'] or '',
                    'summary': (row['summary'] or '')[:100],
                    'agent_name': row['agent_name'] or '',
                    'created_at': row['created_at'] or '',
                    'updated_at': row['updated_at'] or '',
                }

            conn.close()
        except Exception as e:
            if 'disk I/O' not in str(e):
                print(f"Warning: Could not read {db_path}: {e}", file=sys.stderr)

    return sessions


def get_workspace_name(filepath: str) -> str:
    """Extract workspace identifier from file path."""
    # Path like: .../workspaceStorage/HASH/chatSessions/...
    parts = Path(filepath).parts
    try:
        ws_idx = parts.index('workspaceStorage')
        return parts[ws_idx + 1][:8]  # Return first 8 chars of hash
    except (ValueError, IndexError):
        return 'unknown'


def parse_month_arg(month_str: str) -> tuple[datetime, datetime]:
    """Parse month argument and return (start_date, end_date)."""
    now = datetime.now()
    
    if month_str == 'current':
        start = datetime(now.year, now.month, 1)
        if now.month == 12:
            end = datetime(now.year + 1, 1, 1)
        else:
            end = datetime(now.year, now.month + 1, 1)
    elif month_str == 'previous':
        if now.month == 1:
            start = datetime(now.year - 1, 12, 1)
            end = datetime(now.year, 1, 1)
        else:
            start = datetime(now.year, now.month - 1, 1)
            end = datetime(now.year, now.month, 1)
    else:
        # Parse YYYY-MM format
        try:
            parts = month_str.split('-')
            year, month = int(parts[0]), int(parts[1])
            start = datetime(year, month, 1)
            if month == 12:
                end = datetime(year + 1, 1, 1)
            else:
                end = datetime(year, month + 1, 1)
        except (ValueError, IndexError):
            print(f"Error: Invalid month format '{month_str}'. Use YYYY-MM, 'current', or 'previous'.")
            sys.exit(1)
    
    return start, end


def extract_usage_from_jsonl(filepath: str, session_metadata: dict[str, dict] = None) -> list[dict]:
    """Extract all usage records from a debug-logs main.jsonl file."""
    records = []
    # Path: .../debug-logs/<session_id>/main.jsonl
    session_id = Path(filepath).parent.name
    workspace = get_workspace_name(filepath)
    meta = (session_metadata or {}).get(session_id, {})
    
    try:
        with open(filepath, errors='replace') as f:
            for raw_line in f:
                raw_line = raw_line.strip()
                if not raw_line or 'inputTokens' not in raw_line:
                    continue
                try:
                    obj = json.loads(raw_line)
                except Exception:
                    continue
                if obj.get('type') != 'llm_request':
                    continue
                attrs = obj.get('attrs', {})
                input_tokens = attrs.get('inputTokens', 0)
                output_tokens = attrs.get('outputTokens', 0)
                if not input_tokens and not output_tokens:
                    continue
                ts = datetime.fromtimestamp(obj['ts'] / 1000) if obj.get('ts') else datetime.now()
                model = attrs.get('model', obj.get('name', 'unknown').replace('chat:', ''))
                records.append({
                    'session_id': session_id,
                    'workspace': workspace,
                    'timestamp': ts,
                    'date': ts.strftime('%Y-%m-%d'),
                    'model': model,
                    'prompt_tokens': input_tokens,
                    'completion_tokens': output_tokens,
                    'total_tokens': input_tokens + output_tokens,
                    'source_file': filepath,
                    'cwd': meta.get('cwd', ''),
                    'branch': meta.get('branch', ''),
                    'summary': meta.get('summary', ''),
                })
    except Exception as e:
        print(f"Warning: Error parsing {filepath}: {e}", file=sys.stderr)
    
    return records


def extract_nano_aiu(filepath: str) -> list[dict]:
    """Extract nano-AIU cost data if available."""
    records = []
    
    try:
        with open(filepath, errors='replace') as f:
            content = f.read()
            
            # Look for copilot_usage with nano_aiu
            aiu_pattern = re.compile(r'"total_nano_aiu"\s*:\s*(\d+)')
            
            for match in aiu_pattern.finditer(content):
                nano_aiu = int(match.group(1))
                aic = nano_aiu / 1_000_000_000  # Convert to AIC
                records.append({
                    'nano_aiu': nano_aiu,
                    'aic': aic,
                })
    except:
        pass
    
    return records


def extract_usage_from_copilot_log() -> list[dict]:
    """DEPRECATED - do not use.

    The GitHub Copilot Chat.log does NOT contain real API token responses.
    Its only 'prompt_tokens' occurrences come from edit-tool payloads (e.g.
    when this very script gets edited), so scanning it yields false data.
    Kept as a stub to document this finding.
    """
    return []


def collect_all_usage(
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    include_logs: bool = False
) -> list[dict]:
    """Collect usage from all chatSessions files.

    Note: include_logs is False by default. The GitHub Copilot Chat.log does
    not contain real API token responses - only edit-tool payloads that may
    coincidentally contain the string 'prompt_tokens'. Enabling it produces
    false data, so it stays disabled.
    """
    all_records = []
    seen_tokens = set()  # Deduplicate by (timestamp, model, prompt_tokens)
    
    # Load session metadata once
    session_metadata = load_session_metadata()
    
    # Extract from chatSessions JSONL files (the only reliable source)
    for jsonl_path in _iglob_all(CHAT_SESSIONS_GLOBS):
        records = extract_usage_from_jsonl(jsonl_path, session_metadata)
        
        for r in records:
            # Filter by date if specified
            if start_date and r['timestamp'] < start_date:
                continue
            if end_date and r['timestamp'] >= end_date:
                continue
            
            # Dedupe key
            key = (r['timestamp'].strftime('%Y-%m-%d %H:%M'), r['model'], r['prompt_tokens'])
            if key not in seen_tokens:
                seen_tokens.add(key)
                all_records.append(r)
    
    # Sort by timestamp
    all_records.sort(key=lambda r: r['timestamp'])
    
    return all_records


def get_file_stats() -> dict:
    """Get statistics about debug-log main.jsonl files."""
    all_files = _iglob_all(CHAT_SESSIONS_GLOBS)
    files_with_tokens = 0

    for f in all_files:
        try:
            with open(f, errors='replace') as fp:
                if 'inputTokens' in fp.read():
                    files_with_tokens += 1
        except:
            pass

    return {
        'total_files': len(all_files),
        'files_with_tokens': files_with_tokens,
        'coverage_pct': (files_with_tokens * 100 // len(all_files)) if all_files else 0,
    }


def get_db_stats() -> dict:
    """Get session and turn counts summed across all databases."""
    stats = {'sessions': 0, 'turns': 0}

    for db_path in SESSION_DBS:
        if not os.path.exists(db_path):
            continue
        try:
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM sessions")
            stats['sessions'] += cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM turns")
            stats['turns'] += cursor.fetchone()[0]
            conn.close()
        except Exception as e:
            if 'disk I/O' not in str(e):
                print(f"Warning: Could not query {db_path}: {e}", file=sys.stderr)

    return stats


def render_daily_breakdown(records: list[dict], pricing: dict) -> None:
    """Render daily usage breakdown."""
    if not records:
        return
    
    by_day: dict[str, dict] = defaultdict(lambda: {
        'requests': 0,
        'prompt_tokens': 0,
        'completion_tokens': 0,
    })
    
    for r in records:
        day = r['date']
        by_day[day]['requests'] += 1
        by_day[day]['prompt_tokens'] += r.get('prompt_tokens', 0)
        by_day[day]['completion_tokens'] += r.get('completion_tokens', 0)
    
    print(f"\n  DAILY BREAKDOWN")
    print(f"  {'-'*70}")
    print(f"  {'Date':<12} {'Requests':>10} {'Input Tok':>14} {'Output Tok':>14} {'Est. Cost':>12}")
    print(f"  {'-'*10} {'-'*10} {'-'*14} {'-'*14} {'-'*12}")
    
    for day in sorted(by_day.keys()):
        stats = by_day[day]
        # Calculate cost for this day
        day_records = [{'model': r['model'], **stats} for r in records if r['date'] == day]
        day_cost = calculate_cost([r for r in records if r['date'] == day], pricing)
        print(
            f"  {day:<12} "
            f"{stats['requests']:>10,} "
            f"{stats['prompt_tokens']:>14,} "
            f"{stats['completion_tokens']:>14,} "
            f"{f'${day_cost:.2f}':>12}"
        )


def render_workspace_breakdown(records: list[dict], pricing: dict, session_metadata: dict) -> None:
    """Render usage breakdown by workspace/repository."""
    if not records:
        return
    
    # Group by cwd (repository path)
    by_repo: dict[str, dict] = defaultdict(lambda: {
        'requests': 0,
        'prompt_tokens': 0,
        'completion_tokens': 0,
        'sessions': set(),
    })
    
    for r in records:
        repo = r.get('cwd', 'Unknown') or 'Unknown'
        # Shorten path to just the last 2 components
        repo_short = '/'.join(Path(repo).parts[-2:]) if repo != 'Unknown' else repo
        by_repo[repo_short]['requests'] += 1
        by_repo[repo_short]['prompt_tokens'] += r.get('prompt_tokens', 0)
        by_repo[repo_short]['completion_tokens'] += r.get('completion_tokens', 0)
        by_repo[repo_short]['sessions'].add(r['session_id'])
    
    print(f"\n  WORKSPACE BREAKDOWN")
    print(f"  {'-'*90}")
    print(f"  {'Repository':<35} {'Sessions':>10} {'Requests':>10} {'Input Tok':>14} {'Est. Cost':>12}")
    print(f"  {'-'*33} {'-'*10} {'-'*10} {'-'*14} {'-'*12}")
    
    for repo, stats in sorted(by_repo.items(), key=lambda x: -x[1]['prompt_tokens']):
        repo_records = [r for r in records if (r.get('cwd', '') or 'Unknown').endswith(repo.split('/')[-1])]
        repo_cost = calculate_cost(repo_records, pricing)
        print(
            f"  {repo[:33]:<35} "
            f"{len(stats['sessions']):>10,} "
            f"{stats['requests']:>10,} "
            f"{stats['prompt_tokens']:>14,} "
            f"{f'${repo_cost:.2f}':>12}"
        )


def calculate_cost(records: list[dict], pricing: dict[str, dict[str, float]]) -> float:
    """Calculate estimated cost in dollars."""
    total_cost = 0.0
    
    for r in records:
        model = r.get('model', 'unknown')
        prompt = r.get('prompt_tokens', 0)
        completion = r.get('completion_tokens', 0)
        
        # Find matching pricing (try exact match, then partial match)
        price = None
        for model_id, p in pricing.items():
            if model_id in model or model in model_id:
                price = p
                break
        
        if price:
            input_cost = (prompt / 1_000_000) * price['input']
            output_cost = (completion / 1_000_000) * price['output']
            total_cost += input_cost + output_cost
    
    return total_cost


def render_sources() -> None:
    """Print all scanned source directories and file counts."""
    rows = []
    total_files = 0
    total_with_tokens = 0
    for d in USER_DIRS:
        globs = [str(d / 'workspaceStorage' / '*' / 'GitHub.copilot-chat' / 'debug-logs' / '*' / 'main.jsonl')]
        files = _iglob_all(globs)
        with_tokens = sum(1 for f in files if _file_has_tokens(f))
        rows.append((len(files), with_tokens, _source_label(d), str(d)))
        total_files += len(files)
        total_with_tokens += with_tokens

    max_label = max((len(r[2]) for r in rows), default=10)
    max_path  = max((len(r[3]) for r in rows), default=10)
    w = max(max_label, 10)
    p = max(max_path, 10)

    print(f"\n  SCANNED SOURCES")
    print(f"  {'-'*(w+p+26)}")
    print(f"  {'Source':<{w}}  {'Files':>7}  {'w/tokens':>8}  Path")
    print(f"  {'-'*w}  {'-'*7}  {'-'*8}  {'-'*p}")
    for label, files, wt, path in [(r[2], r[0], r[1], r[3]) for r in rows]:
        print(f"  {label:<{w}}  {files:>7}  {wt:>8}  {path}")
    print(f"  {'-'*w}  {'-'*7}  {'-'*8}")
    print(f"  {'TOTAL':<{w}}  {total_files:>7}  {total_with_tokens:>8}")
    print()


def _file_has_tokens(path: str) -> bool:
    try:
        with open(path, errors='replace') as f:
            return 'inputTokens' in f.read()
    except:
        return False


def _source_label(d: Path) -> str:
    """Human-readable label for a User data dir."""
    s = str(d)
    if '/mnt/c/Users/' in s:
        parts = s.split('/')
        user_idx = parts.index('Users') + 1
        variant = parts[user_idx + 3] if len(parts) > user_idx + 3 else 'Code'
        return f"Windows ({parts[user_idx]}) / {variant}"
    if '.vscode-server' in s:
        server = next((seg for seg in d.parts if seg.startswith('.vscode-server')), '.vscode-server')
        return f"Remote server ({d.parts[2]}) / {server}"
    if '.config' in s:
        for v in VSCODE_VARIANTS:
            if v in s:
                return f"Local / {v}"
    return s[-60:]


def render_report(
    records: list[dict],
    pricing: dict[str, dict[str, float]],
    title: str = "Usage Report"
) -> None:
    """Render a formatted report to stdout."""
    # Get coverage stats
    file_stats = get_file_stats()
    db_stats = get_db_stats()
    
    # Aggregate by model
    by_model: dict[str, dict] = defaultdict(lambda: {
        'requests': 0,
        'prompt_tokens': 0,
        'completion_tokens': 0,
        'total_tokens': 0,
    })
    
    for r in records:
        model = r.get('model', 'unknown')
        by_model[model]['requests'] += 1
        by_model[model]['prompt_tokens'] += r.get('prompt_tokens', 0)
        by_model[model]['completion_tokens'] += r.get('completion_tokens', 0)
        by_model[model]['total_tokens'] += r.get('total_tokens', 0)
    
    # Totals
    total_prompt = sum(r.get('prompt_tokens', 0) for r in records)
    total_completion = sum(r.get('completion_tokens', 0) for r in records)
    total_tokens = total_prompt + total_completion
    total_requests = len(records)
    total_cost = calculate_cost(records, pricing)
    
    print(f"\n{'='*90}")
    print(f"  {title}")
    print(f"{'='*90}")
    
    # Data coverage section
    print(f"\n  DATA COVERAGE")
    print(f"  {'-'*50}")
    print(f"  Session files total:       {file_stats['total_files']:>10}")
    print(f"  Files with token data:     {file_stats['files_with_tokens']:>10}")
    print(f"  Token data coverage:       {file_stats['coverage_pct']:>9}%")
    print(f"  Sessions in DB (all time): {db_stats['sessions']:>10}")
    print(f"  Turns in DB (all time):    {db_stats['turns']:>10}")
    
    if file_stats['coverage_pct'] < 50:
        print(f"\n  !! WARNING: Only {file_stats['coverage_pct']}% of sessions have token data.")
        print(f"     Token counts below are INCOMPLETE - actual usage is higher.")
    
    if not records:
        print(f"\n  No token data found for this period.\n")
        return
    
    # Per-model breakdown
    print(f"\n  TOKEN USAGE BY MODEL")
    print(f"  {'-'*75}")
    print(f"  {'Model':<35} {'Requests':>10} {'Input Tok':>12} {'Output Tok':>12} {'Est. Cost':>12}")
    print(f"  {'-'*33} {'-'*10} {'-'*12} {'-'*12} {'-'*12}")
    
    for model, stats in sorted(by_model.items()):
        model_cost = calculate_cost([{'model': model, **stats}], pricing)
        print(
            f"  {model[:33]:<35} "
            f"{stats['requests']:>10,} "
            f"{stats['prompt_tokens']:>12,} "
            f"{stats['completion_tokens']:>12,} "
            f"{f'${model_cost:.2f}':>12}"
        )
    
    print(f"  {'-'*33} {'-'*10} {'-'*12} {'-'*12} {'-'*12}")
    print(
        f"  {'TOTAL':<35} "
        f"{total_requests:>10,} "
        f"{total_prompt:>12,} "
        f"{total_completion:>12,} "
        f"{f'${total_cost:.2f}':>12}"
    )
    
    # Summary stats
    print(f"\n  SUMMARY")
    print(f"  {'-'*40}")
    print(f"  Total Requests:      {total_requests:>15,}")
    print(f"  Total Input Tokens:  {total_prompt:>15,}")
    print(f"  Total Output Tokens: {total_completion:>15,}")
    print(f"  Total Tokens:        {total_tokens:>15,}")
    print(f"  Estimated Cost:      {f'${total_cost:.2f}':>15}")
    
    # Date range
    if records:
        min_ts = min(r['timestamp'] for r in records)
        max_ts = max(r['timestamp'] for r in records)
        print(f"\n  Date Range: {min_ts.strftime('%Y-%m-%d %H:%M')} to {max_ts.strftime('%Y-%m-%d %H:%M')}")
    
    print(f"\n  Note: Cost estimates use model pricing from GitHub Copilot.")
    print(f"        Actual billing may differ based on caching and plan.\n")


def write_csv(records: list[dict], output_path: str) -> None:
    """Write records to CSV file."""
    if not records:
        print(f"  No data to write to CSV.")
        return
    
    fields = [
        'date', 'timestamp', 'session_id', 'model',
        'prompt_tokens', 'completion_tokens', 'total_tokens',
        'cwd', 'branch', 'summary',
    ]
    
    with open(output_path, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction='ignore')
        w.writeheader()
        for r in records:
            row = dict(r)
            row['timestamp'] = r['timestamp'].isoformat() if r.get('timestamp') else ''
            w.writerow(row)
    
    print(f"  📄 CSV written → {output_path}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        '--month', '-m',
        default='current',
        help="Month to report: 'current', 'previous', or YYYY-MM format (default: current)"
    )
    parser.add_argument(
        '--all', '-a',
        action='store_true',
        help="Report all available data (ignore --month)"
    )
    parser.add_argument(
        '--csv', '-c',
        action='store_true',
        help="Also write results to copilot_usage_YYYY-MM.csv"
    )
    parser.add_argument(
        '--detailed', '-d',
        action='store_true',
        help="Show per-request details (verbose)"
    )
    parser.add_argument(
        '--daily',
        action='store_true',
        help="Show daily breakdown"
    )
    parser.add_argument(
        '--by-workspace', '-w',
        action='store_true',
        help="Show breakdown by workspace/repository"
    )
    parser.add_argument(
        '--locations',
        action='store_true',
        help="List the VS Code data directories being scanned and exit"
    )
    args = parser.parse_args()
    
    # List scanned locations and exit
    if args.locations:
        print("\n  Scanned VS Code User data directories:")
        print(f"  {'-'*60}")
        if USER_DIRS:
            for d in USER_DIRS:
                print(f"  {d}")
        else:
            print("  (none found)")
        print()
        return
    
    # Load pricing
    pricing = load_model_pricing()
    
    # Load session metadata for workspace info
    session_metadata = load_session_metadata()
    
    # Determine date range
    if args.all:
        start_date, end_date = None, None
        title = "COPILOT USAGE REPORT (All Time)"
        csv_suffix = "all"
    else:
        start_date, end_date = parse_month_arg(args.month)
        month_str = start_date.strftime('%Y-%m')
        title = f"COPILOT USAGE REPORT ({start_date.strftime('%B %Y')})"
        csv_suffix = month_str
    
    # Collect data
    records = collect_all_usage(start_date, end_date)
    
    # Detailed per-request output
    if args.detailed and records:
        print(f"\n{'─'*100}")
        print(f"  {'Timestamp':<20} {'Model':<30} {'Input':>10} {'Output':>10} {'Total':>10} {'Session'}")
        print(f"  {'─'*18} {'─'*28} {'─'*10} {'─'*10} {'─'*10} {'─'*20}")
        for r in records[:50]:  # Limit to 50 for readability
            print(
                f"  {r['timestamp'].strftime('%Y-%m-%d %H:%M'):<20} "
                f"{r['model'][:28]:<30} "
                f"{r['prompt_tokens']:>10,} "
                f"{r['completion_tokens']:>10,} "
                f"{r['total_tokens']:>10,} "
                f"{r['session_id'][:18]}"
            )
        if len(records) > 50:
            print(f"  ... and {len(records) - 50} more records")
    
    # Render summary report
    render_report(records, pricing, title)
    
    # Daily breakdown
    if args.daily:
        render_daily_breakdown(records, pricing)
    
    # Workspace breakdown
    if args.by_workspace:
        render_workspace_breakdown(records, pricing, session_metadata)
    
    render_sources()

    # Write CSV if requested
    if args.csv:
        csv_path = f'copilot_usage_{csv_suffix}.csv'
        write_csv(records, csv_path)


if __name__ == '__main__':
    main()
