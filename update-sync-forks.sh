#!/usr/bin/env bash
#
# sync-forks.sh
#
# Sync (update) the listed BRANCHES of the listed FORK repos from their origin
# (the fork's parent / upstream repo) using the `gh` CLI + git.
#
# Data model (the "object" you described):
#   {
#     github_url1: [b1, b2, b3],
#     github_url2: [a1, a2]
#   }
#   ->  fork repo URL  ->  list of branch names to sync
#
# Behaviour:
#   * Per-branch / per-repo errors are LOGGED and execution CONTINUES
#     (the script never aborts the whole run because of one bad branch).
#   * Uses `gh` for clone + resolving the fork's parent, and git for the
#     actual fetch / fast-forward / push.
#
# Requirements:
#   * `gh` installed and authenticated:  gh auth login
#   * `git` installed
#
# Tunables (env overrides, or edit the defaults below):
#   SOURCE     = upstream | origin   (default: upstream = the fork's PARENT repo)
#   SYNC_MODE  = ff | reset          (default: ff = merge --ff-only; reset = hard-sync)
#   PUSH       = 0 | 1               (default: 1 = push updated branch back to the fork)
#
set -uo pipefail

# ============================== CONFIG =======================================
# The object to sync, written as a plain JSON object (read it top to bottom):
#   fork repo URL  ->  [branch, branch, ...]
# EDIT THIS to match your forks. Keys may have any name; only the URLs matter.
# (parsed with jq -- requires `jq`; branch names must not contain spaces)
#

# --- Parking spot: same shape as SYNC_SPEC, but intentionally UNUSED. -------
# Move a repo's "url": [branches] line here to skip it; move it back to resume. DATA_SYNC_SPEC is NOT read by the script -- it is only a parking spot.
readonly DATA_SYNC_SPEC='
{
  "https://github.com/prathamMalavi/onecx-portal-ui-libs.git": ["main", "v8", "v7", "v6", "v5", "feat/theme-v2"],
  "https://github.com/prathamMalavi/onecx-shell-ui.git":       ["main", "2.x", "feat/theme-v2"],
  "https://github.com/prathamMalavi/onecx-nx-plugins.git": ["main", "v7", "v6", "v5"],
  "https://github.com/prathamMalavi/onecx-parameter-ui.git":   ["main"],
  "https://github.com/prathamMalavi/onecx-local-env.git": ["main"],
  "https://github.com/prathamMalavi/onecx-announcement-ui.git": ["main"],
  "https://github.com/prathamMalavi/onecx-tenant-ui.git": ["main"],
  "https://github.com/prathamMalavi/onecx-workspace-ui.git": ["main"],
  "https://github.com/prathamMalavi/onecx-ai-refactoring-agents.git": ["main"],
  "https://github.com/prathamMalavi/onecx-data-orchestrator-ui.git": ["main"]
}
'
# =============================================================================

# JSON has no comments, so to temporarily take a repo out of rotation, MOVE its line into DATA_SYNC_SPEC (and back when you want to sync it again).
readonly SYNC_SPEC='
{
  "https://github.com/prathamMalavi/onecx-portal-ui-libs.git": ["main", "v8", "v7", "v6", "v5"]
}
'


SOURCE="${SOURCE:-upstream}"   # "upstream" = fork parent (auto via gh); "origin" = the fork itself
SYNC_MODE="${SYNC_MODE:-ff}"   # "ff" = merge --ff-only ; "reset" = git reset --hard
PUSH="${PUSH:-1}"              # "1" = push updated branch back to the fork ; "0" = local only

SYNC_OK=0
SYNC_FAIL=0
WORKDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$WORKDIR_BASE"' EXIT

log()  { printf '[%s] %s\n'     "$(date '+%H:%M:%S')" "$*"; }
warn() { printf '[%s] WARN: %s\n' "$(date '+%H:%M:%S')" "$*"; }
err()  { printf '[%s] ERROR: %s\n' "$(date '+%H:%M:%S')" "$*" >&2; }

# https://github.com/owner/repo[/]  ->  owner/repo
url_to_owner_repo() {
  printf '%s' "$1" | sed -E 's#^https?://github\.com/##; s#\.git$##; s#/$##'
}

sync_repo() {
  local repo_url="$1"
  local branch_list="$2"
  local branches=()
  read -r -a branches <<< "$branch_list"

  local workdir
  workdir="$(mktemp -d "$WORKDIR_BASE/clone.XXXX")"

  log "Cloning $repo_url"
  if ! gh repo clone "$repo_url" "$workdir" >/dev/null 2>&1; then
    err "Failed to clone $repo_url -- skipping repo"
    SYNC_FAIL=$((SYNC_FAIL + ${#branches[@]}))
    return
  fi

  local full_name parent_full_name source_remote
  full_name="$(url_to_owner_repo "$repo_url")"
  source_remote="origin"

  if [ "$SOURCE" = "upstream" ]; then
    parent_full_name="$(gh api "repos/$full_name" --jq '.parent.full_name // empty' 2>/dev/null)"
    if [ -n "$parent_full_name" ]; then
      source_remote="upstream"
      git -C "$workdir" remote add "$source_remote" "https://github.com/${parent_full_name}.git"
      log "  parent (upstream) = $parent_full_name"
    else
      warn "  $full_name is not a fork (no parent) -- falling back to 'origin'"
    fi
  fi

  for br in "${branches[@]}"; do
    log "  sync '$br' (source=$source_remote)"

    if ! git -C "$workdir" fetch -q "$source_remote" "$br" 2>/dev/null; then
      err "    fetch '$br' from $source_remote failed (branch missing upstream?) -- continuing"
      SYNC_FAIL=$((SYNC_FAIL + 1)); continue
    fi

    # Make sure we have a local copy of the branch to update.
    if git -C "$workdir" show-ref --verify --quiet "refs/heads/$br"; then
      git -C "$workdir" checkout -q "$br"
    else
      if ! git -C "$workdir" checkout -q -b "$br" FETCH_HEAD; then
        err "    create local branch '$br' failed -- continuing"
        SYNC_FAIL=$((SYNC_FAIL + 1)); continue
      fi
    fi

    # Apply the update.
    if [ "$SYNC_MODE" = "reset" ]; then
      if ! git -C "$workdir" reset -q --hard FETCH_HEAD; then
        err "    reset '$br' failed -- continuing"
        SYNC_FAIL=$((SYNC_FAIL + 1)); continue
      fi
    else
      if ! git -C "$workdir" merge -q --ff-only FETCH_HEAD; then
        err "    ff-merge '$br' failed (diverged from $source_remote?) -- continuing"
        SYNC_FAIL=$((SYNC_FAIL + 1)); continue
      fi
    fi

    log "    ok: $br -> $(git -C "$workdir" rev-parse --short HEAD)"
    SYNC_OK=$((SYNC_OK + 1))

    if [ "$PUSH" = "1" ]; then
      if git -C "$workdir" push -q origin "$br" >/dev/null 2>&1; then
        log "    pushed $br -> fork"
      else
        err "    push '$br' to fork failed -- continuing"
      fi
    fi
  done
}

main() {
  if ! command -v gh >/dev/null 2>&1; then
    err "'gh' not found in PATH -- install the GitHub CLI first"; exit 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    err "'jq' not found in PATH -- needed to parse the SYNC_SPEC object"; exit 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    err "'gh' is not authenticated -- run: gh auth login"; exit 1
  fi

  # Parse the object into one "URL<TAB>space-separated-branches" line per entry.
  local spec_lines repo_url branch_list
  spec_lines="$(jq -r 'to_entries[] | .key + "\t" + (.value | join(" "))' <<< "$SYNC_SPEC" 2>/dev/null)"
  if [ -z "$spec_lines" ]; then
    warn "SYNC_SPEC is empty -- nothing to do"; exit 0
  fi

  log "Starting sync (SOURCE=$SOURCE, SYNC_MODE=$SYNC_MODE, PUSH=$PUSH)"
  while IFS=$'\t' read -r repo_url branch_list; do
    [ -n "$repo_url" ] || continue
    sync_repo "$repo_url" "$branch_list"
  done <<< "$spec_lines"

  log "Done. branches synced: $SYNC_OK, problems: $SYNC_FAIL"
  [ "$SYNC_FAIL" -eq 0 ]
}

main "$@"
