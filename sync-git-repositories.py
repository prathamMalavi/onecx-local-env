#!/usr/bin/env python3
"""Commit pending changes and push configured repositories to their origin URLs.

Run with: python3 sync-git-repositories.py

This script never force-pushes. If the remote has diverged, it leaves history
untouched and reports the repository that needs manual reconciliation.
"""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys


REPOSITORIES = [
    {
        "path": "/root/onecx/dev-new/onecx-local-env/.0_angular-21-test-apps/onecx-angular-21-module-test-app1",
        "git_url": "https://github.com/prathamMalavi/onecx-angular-21-module-test-app1.git",
        # "commit_message": "Optional per-repository commit message",
    },
    {
        "path": "/root/onecx/dev-new/onecx-local-env/.0_angular-21-test-apps/onecx-angular-21-module-test-app2",
        "git_url": "https://github.com/prathamMalavi/onecx-angular-21-module-test-app2.git",
    },
    {
        "path": "/root/onecx/dev-new/onecx-local-env/.0_angular-21-test-apps/onecx-angular-21-module-test-app3",
        "git_url": "https://github.com/prathamMalavi/onecx-angular-21-module-test-app3.git",
    },
    {
        "path": "/root/onecx/dev-new/onecx-local-env/.0_angular-21-test-apps/onecx-angular-21-module-test-app4",
        "git_url": "https://github.com/prathamMalavi/onecx-angular-21-module-test-app4.git",
    },
    {
        "path": "/root/onecx/dev-new/onecx-local-env/.0_angular-20-test-apps/onecx-angular-20-module-test-app1",
        "git_url": "https://github.com/prathamMalavi/onecx-angular-20-module-test-app1.git",
    },
]

DEFAULT_COMMIT_MESSAGE = "Update repository"


def git(repo_path: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=repo_path,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=check,
    )


def print_git_output(result: subprocess.CompletedProcess[str]) -> None:
    output = result.stdout.strip()
    if output:
        print(output)
    error = result.stderr.strip()
    if error:
        print(error, file=sys.stderr)


def ensure_repository(repo_path: Path) -> None:
    if not repo_path.is_dir():
        raise RuntimeError(f"Directory does not exist: {repo_path}")

    result = git(repo_path, "rev-parse", "--show-toplevel", check=False)
    if result.returncode != 0:
        print("No Git repository found; initializing a new repository on 'main'.")
        print_git_output(git(repo_path, "init", "-b", "main"))
        return

    git_root = Path(result.stdout.strip()).resolve()
    if git_root != repo_path.resolve():
        raise RuntimeError(
            f"The supplied path must be the repository root. Git root is {git_root}"
        )


def set_origin(repo_path: Path, git_url: str) -> None:
    fetch_url = git(repo_path, "remote", "get-url", "origin", check=False)
    if fetch_url.returncode != 0:
        print(f"Adding origin: {git_url}")
        print_git_output(git(repo_path, "remote", "add", "origin", git_url))
    elif fetch_url.stdout.strip() == git_url:
        print("origin fetch URL already matches; skipping.")
    else:
        print(f"Updating origin fetch URL to: {git_url}")
        print_git_output(git(repo_path, "remote", "set-url", "origin", git_url))

    push_url = git(repo_path, "remote", "get-url", "--push", "origin")
    if push_url.stdout.strip() == git_url:
        print("origin push URL already matches; skipping.")
    else:
        print(f"Updating origin push URL to: {git_url}")
        print_git_output(
            git(repo_path, "remote", "set-url", "--push", "origin", git_url)
        )


def commit_pending_changes(repo_path: Path, commit_message: str) -> None:
    print_git_output(git(repo_path, "add", "--all"))
    staged = git(repo_path, "diff", "--cached", "--quiet", check=False)

    if staged.returncode == 1:
        print(f"Committing changes: {commit_message}")
        print_git_output(git(repo_path, "commit", "-m", commit_message))
    elif staged.returncode == 0:
        print("No file changes to commit.")
    else:
        raise RuntimeError("Could not determine whether there are staged changes.")

    head = git(repo_path, "rev-parse", "--verify", "HEAD", check=False)
    if head.returncode != 0:
        raise RuntimeError(
            "There is no commit to push (the repository has no commit and no files were committed)."
        )

    branch = git(repo_path, "symbolic-ref", "--quiet", "--short", "HEAD", check=False)
    if branch.returncode != 0:
        raise RuntimeError("The repository is in detached-HEAD state; check out a branch before pushing.")


def process_repository(entry: dict[str, str | None]) -> None:
    repo_path = Path(entry["path"]).expanduser().resolve()
    git_url = entry["git_url"]
    if not git_url:
        raise RuntimeError("Missing required 'git_url'.")

    print(f"\n=== {repo_path} ===")
    ensure_repository(repo_path)
    set_origin(repo_path, git_url)

    commit_message = (entry.get("commit_message") or "").strip() or DEFAULT_COMMIT_MESSAGE
    commit_pending_changes(repo_path, commit_message)

    print("Pushing current branch to origin (no force push).")
    print_git_output(git(repo_path, "push", "--set-upstream", "origin", "HEAD"))
    print_git_output(git(repo_path, "status", "--short", "--branch"))


def main() -> int:
    failures = 0
    for entry in REPOSITORIES:
        try:
            process_repository(entry)
        except (OSError, subprocess.CalledProcessError, RuntimeError) as error:
            failures += 1
            print(f"ERROR for {entry.get('path', '<unknown path>')}: {error}", file=sys.stderr)
            if isinstance(error, subprocess.CalledProcessError):
                if error.stdout:
                    print(error.stdout.strip(), file=sys.stderr)
                if error.stderr:
                    print(error.stderr.strip(), file=sys.stderr)

    if failures:
        print(f"\nFinished with {failures} repository error(s).", file=sys.stderr)
        return 1

    print("\nAll repositories processed successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
