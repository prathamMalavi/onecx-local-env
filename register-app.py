#!/usr/bin/env python3
"""Generate OneCX local-env registration data from one JSON app object.

Usage:
  python3 register-app.py register-app.template.json
  python3 register-app.py apps.json --dry-run
  python3 register-app.py apps.json --overwrite

The script writes Product Store product/MFE data and adds the app to a workspace
JSON file. It does not call live OneCX services or import/recreate a workspace.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Any

DEFAULTS: dict[str, Any] = {
    "productVersion": "xxx",
    "productIconName": "pi-briefcase",
    "multitenancy": True,
    "appVersion": "xxx",
    "technology": "WEBCOMPONENTMODULE",
    "type": "MODULE",
    "exposedModule": "./RemoteModule",
    "contact": "onecx@1000kit.org",
    "workspace": "ADMIN",
    "tenant": "default",
    "workspaceAppBasePath": "/",
}
VALID_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.-]*$")


class RegistrationError(Exception):
    """Invalid or conflicting registration input."""


def normalize_base_path(value: Any, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise RegistrationError(f"'{field_name}' must be a non-empty path string")
    value = value.strip()
    if "://" in value:
        raise RegistrationError(
            f"'{field_name}' must be a OneCX path, not an absolute URL"
        )
    value = "/" + value.strip("/")
    return value if value != "" else "/"


def normalize_remote_base(value: Any, mfe_route: str) -> str:
    if value is None:
        value = f"/mfe/{mfe_route}/"
    if not isinstance(value, str) or not value.strip():
        raise RegistrationError("'remoteBaseUrl' must be a non-empty URL or path")
    value = value.strip()
    if not value.endswith("/"):
        value += "/"
    return value


def read_entries(path: Path) -> list[dict[str, Any]]:
    try:
        content = json.loads(path.read_text(encoding="utf-8"))
    except OSError as error:
        raise RegistrationError(f"Cannot read input file {path}: {error}") from error
    except json.JSONDecodeError as error:
        raise RegistrationError(f"Input is not valid JSON: {error}") from error

    entries = content if isinstance(content, list) else [content]
    if not entries or any(not isinstance(entry, dict) for entry in entries):
        raise RegistrationError("Input must be a JSON object or a non-empty array of objects")
    return entries


def validate_name(value: Any, field: str) -> str:
    if not isinstance(value, str) or not VALID_NAME.fullmatch(value):
        raise RegistrationError(
            f"'{field}' must contain only letters, digits, dots, or hyphens; "
            "underscores are unsupported by the existing import filename parser"
        )
    return value


def normalize_permissions(raw: Any) -> list[dict[str, str]]:
    if raw is None:
        return []
    permissions: list[dict[str, str]] = []
    if isinstance(raw, dict):
        for resource, actions in raw.items():
            action_values = [actions] if isinstance(actions, str) else actions
            if not isinstance(action_values, list):
                raise RegistrationError("Permission mapping values must be action strings or lists")
            for action in action_values:
                permissions.append({"resource": str(resource), "action": str(action)})
    elif isinstance(raw, list):
        for permission in raw:
            if not isinstance(permission, dict) or not permission.get("resource") or not permission.get("action"):
                raise RegistrationError(
                    "Each permission must be an object with non-empty 'resource' and 'action'"
                )
            permissions.append(
                {"resource": str(permission["resource"]), "action": str(permission["action"])}
            )
    else:
        raise RegistrationError("'permission'/'permissions' must be a list or resource-to-actions object")

    seen: set[tuple[str, str]] = set()
    for permission in permissions:
        pair = (permission["resource"], permission["action"])
        if pair in seen:
            raise RegistrationError(f"Duplicate permission {pair[0]}#{pair[1]}")
        seen.add(pair)
    return permissions


def app_artifacts(entry: dict[str, Any]) -> dict[str, Any]:
    product_name = validate_name(entry.get("productName"), "productName")
    app_id = validate_name(entry.get("appID", entry.get("appId")), "appID")
    base_url = normalize_base_path(entry.get("base-url", entry.get("baseUrl")), "base-url")
    mfe_route = validate_name(entry.get("mfeRoute", product_name), "mfeRoute")
    product_display_name = str(entry.get("displayName") or product_name)
    app_name = str(entry.get("appName") or app_id)
    remote_base_url = normalize_remote_base(entry.get("remoteBaseUrl"), mfe_route)

    product = {
        "version": entry.get("productVersion", DEFAULTS["productVersion"]),
        "description": str(entry.get("description") or product_display_name),
        "imageUrl": entry.get("imageUrl", ""),
        "iconName": entry.get("iconName", DEFAULTS["productIconName"]),
        "displayName": product_display_name,
        "basePath": base_url,
        "classifications": entry.get("classifications", []),
        "multitenancy": entry.get("multitenancy", DEFAULTS["multitenancy"]),
        "undeployed": entry.get("undeployed", False),
    }

    mfe = {
        "appVersion": entry.get("appVersion", DEFAULTS["appVersion"]),
        "appName": app_name,
        "description": str(entry.get("appDescription") or f"{product_display_name} UI"),
        "contact": entry.get("contact", DEFAULTS["contact"]),
        "remoteBaseUrl": remote_base_url,
        "remoteEntry": entry.get("remoteEntry", remote_base_url + "remoteEntry.js"),
        "note": entry.get("note", "Imported MFE"),
        "exposedModule": entry.get("exposedModule", DEFAULTS["exposedModule"]),
        "technology": entry.get("technology", DEFAULTS["technology"]),
        "remoteName": entry.get("remoteName", app_id),
        "tagName": entry.get("tagName", app_id),
        "type": entry.get("type", DEFAULTS["type"]),
        "deprecated": entry.get("deprecated", False),
        "undeployed": entry.get("appUndeployed", False),
    }
    # shareScope is deliberately omitted unless supplied: it is not consistent
    # across current OneCX records and depends on the app's Angular sharing setup.
    share_scope = entry.get("shareScope", entry.get("sharescope"))
    if share_scope is not None:
        mfe["shareScope"] = share_scope

    permissions = normalize_permissions(entry.get("permissions", entry.get("permission")))
    role_values = entry.get("assignPermissionsToRoles", [])
    if isinstance(role_values, str):
        role_values = [role_values]
    if not isinstance(role_values, list) or any(not isinstance(role, str) or not role for role in role_values):
        raise RegistrationError("'assignPermissionsToRoles' must be a role name or list of role names")
    if role_values and not permissions:
        raise RegistrationError("'assignPermissionsToRoles' requires at least one permission")

    tenant = validate_name(entry.get("tenant", DEFAULTS["tenant"]), "tenant")
    workspace = validate_name(entry.get("workspace", DEFAULTS["workspace"]), "workspace")
    workspace_app_base = normalize_base_path(
        entry.get("workspaceAppBasePath", DEFAULTS["workspaceAppBasePath"]),
        "workspaceAppBasePath",
    )

    return {
        "productName": product_name,
        "appID": app_id,
        "baseUrl": base_url,
        "tenant": tenant,
        "workspace": workspace,
        "workspaceAppBasePath": workspace_app_base,
        "mfeRoute": mfe_route,
        "product": product,
        "mfe": mfe,
        "permissions": permissions,
        "assignmentRoles": role_values,
        "menuItem": entry.get("menuItem"),
        "menuGroupKey": entry.get("menuGroupKey", "CORE_CUSTOM_APP"),
    }


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RegistrationError(f"Cannot load JSON {path}: {error}") from error


def write_json(path: Path, value: Any, overwrite: bool, dry_run: bool) -> str:
    if path.exists() and not overwrite:
        existing = load_json(path)
        if existing == value:
            return f"unchanged: {path}"
        return f"preserved existing file (use --overwrite to replace): {path}"
    if dry_run:
        return f"would write: {path}"

    path.parent.mkdir(parents=True, exist_ok=True)
    serialized = json.dumps(value, indent=2, ensure_ascii=False) + "\n"
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(serialized)
        os.replace(temp_name, path)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)
    return f"wrote: {path}"


def find_menu_items(items: list[dict[str, Any]], key: str) -> list[dict[str, Any]]:
    matches: list[dict[str, Any]] = []
    for item in items:
        if item.get("key") == key:
            matches.append(item)
        children = item.get("children", [])
        if isinstance(children, list):
            matches.extend(find_menu_items(children, key))
    return matches


def update_workspace(workspace_path: Path, app: dict[str, Any], dry_run: bool) -> str:
    if not workspace_path.is_file():
        raise RegistrationError(f"Workspace JSON not found: {workspace_path}")
    document = load_json(workspace_path)
    try:
        workspace_data = document["workspaces"][app["workspace"]]
        products = workspace_data["products"]
    except (KeyError, TypeError) as error:
        raise RegistrationError(
            f"Workspace file {workspace_path} has no workspaces.{app['workspace']}.products"
        ) from error

    matching_products = [p for p in products if p.get("productName") == app["productName"]]
    if len(matching_products) > 1:
        raise RegistrationError(f"Workspace has duplicate product entries for {app['productName']}")
    product_entry = matching_products[0] if matching_products else None
    if product_entry is None:
        product_entry = {"productName": app["productName"], "baseUrl": app["baseUrl"], "microfrontends": []}
        products.append(product_entry)
    else:
        product_entry["baseUrl"] = app["baseUrl"]

    microfrontends = product_entry.setdefault("microfrontends", [])
    matching_apps = [m for m in microfrontends if m.get("appId") == app["appID"]]
    if len(matching_apps) > 1:
        raise RegistrationError(f"Workspace has duplicate app entries for {app['appID']}")
    microfrontend_entry = {"appId": app["appID"], "basePath": app["workspaceAppBasePath"]}
    if matching_apps:
        matching_apps[0].update(microfrontend_entry)
    else:
        microfrontends.append(microfrontend_entry)

    menu = app["menuItem"]
    if menu is not None:
        if not isinstance(menu, dict) or not menu.get("name"):
            raise RegistrationError("'menuItem' must be an object with a non-empty 'name'")
        menu_groups = find_menu_items(workspace_data.get("menuItems", []), app["menuGroupKey"])
        if len(menu_groups) != 1:
            raise RegistrationError(
                f"Expected exactly one menu group {app['menuGroupKey']!r} in {workspace_path}; found {len(menu_groups)}"
            )
        group = menu_groups[0]
        children = group.setdefault("children", [])
        menu_key = str(menu.get("key") or f"{app['productName']}_{app['appID']}").upper().replace("-", "_").replace(".", "_")
        menu_item = {
            "key": menu_key,
            "name": str(menu["name"]),
            "url": str(menu.get("url", app["baseUrl"] + "/")),
            "applicationId": app["appID"],
            "disabled": bool(menu.get("disabled", False)),
            "position": menu.get("position", len(children)),
            "badge": menu.get("badge", "briefcase"),
            "external": bool(menu.get("external", False)),
            "target": str(menu.get("target", "_self")),
            "i18n": menu.get("i18n", {"en": str(menu["name"])}),
            "roles": menu.get("roles", ["onecx-admin"]),
            "children": [],
        }
        existing_items = [item for item in children if item.get("key") == menu_key]
        if len(existing_items) > 1:
            raise RegistrationError(f"Menu group has duplicate menu key {menu_key}")
        if existing_items:
            existing_items[0].update(menu_item)
        else:
            children.append(menu_item)

    if dry_run:
        return f"would update workspace: {workspace_path}"
    serialized = json.dumps(document, indent=2, ensure_ascii=False) + "\n"
    fd, temp_name = tempfile.mkstemp(prefix=f".{workspace_path.name}.", dir=workspace_path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(serialized)
        os.replace(temp_name, workspace_path)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)
    return f"updated workspace: {workspace_path}"


def prepare(root: Path, raw_entry: dict[str, Any], overwrite: bool, dry_run: bool) -> list[str]:
    app = app_artifacts(raw_entry)
    product_name, app_id = app["productName"], app["appID"]
    data = root / "onecx-data"
    outputs: list[tuple[Path, Any, bool]] = [
        (data / "product-store" / "products" / f"{product_name}.json", app["product"], False),
        (
            data / "product-store" / "microfrontends" / f"{product_name}_{app_id}_main.json",
            app["mfe"],
            False,
        ),
    ]
    if app["permissions"]:
        outputs.append(
            (data / "permission" / f"{product_name}_{app_id}.json", {"name": app_id, "permissions": app["permissions"]}, False)
        )
    if app["assignmentRoles"]:
        assignments: dict[str, dict[str, list[str]]] = {}
        for role in app["assignmentRoles"]:
            role_assignments = assignments.setdefault(role, {})
            for permission in app["permissions"]:
                actions = role_assignments.setdefault(permission["resource"], [])
                if permission["action"] not in actions:
                    actions.append(permission["action"])
        assignment = {
            "id": f"onecx-local-env-import-assignments-{product_name}",
            "assignments": {product_name: {app_id: assignments}},
        }
        assignment_path = data / "permission-assignment" / f"{product_name}.json"
        if assignment_path.exists():
            existing_assignment = load_json(assignment_path)
            root_assignments = existing_assignment.setdefault("assignments", {})
            product_assignments = root_assignments.setdefault(product_name, {})
            app_assignments = product_assignments.setdefault(app_id, {})
            for role, resources in assignments.items():
                role_assignments = app_assignments.setdefault(role, {})
                for resource, actions in resources.items():
                    current_actions = role_assignments.setdefault(resource, [])
                    for action in actions:
                        if action not in current_actions:
                            current_actions.append(action)
            existing_assignment["id"] = assignment["id"]
            assignment = existing_assignment
        outputs.append((assignment_path, assignment, True))

    results = [
        write_json(path, value, overwrite or merge_existing, dry_run)
        for path, value, merge_existing in outputs
    ]
    workspace_file = data / "workspace" / f"{app['tenant']}_{app['workspace']}.json"
    results.append(update_workspace(workspace_file, app, dry_run))
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="JSON file containing one app object or an array of app objects")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent, help="Local-env repository root")
    parser.add_argument("--dry-run", action="store_true", help="Validate inputs and print planned output paths without writing")
    parser.add_argument("--overwrite", action="store_true", help="Replace existing generated Product Store/permission files")
    args = parser.parse_args()

    try:
        entries = read_entries(args.input)
        plans = [app_artifacts(entry) for entry in entries]
        identities = [(plan["productName"], plan["appID"]) for plan in plans]
        if len(identities) != len(set(identities)):
            raise RegistrationError("Input contains duplicate productName/appID pairs")

        print("Default path:", args.root.resolve())
        if args.dry_run:
            print("DRY RUN: no files will be changed.")
        for index, entry in enumerate(entries, start=1):
            print(f"\n[{index}/{len(entries)}] {entry.get('productName')} / {entry.get('appID', entry.get('appId'))}")
            for result in prepare(args.root.resolve(), entry, args.overwrite, args.dry_run):
                print(" ", result)
        print("\nRegistration data prepared. To import after reviewing the changes:")
        print("  ./import-onecx.sh -d product")
        print("  ./import-onecx.sh -d mfe")
        print("  ./import-onecx.sh -d permission  # only if permissions were supplied")
        print("  ./import-onecx.sh -d assignment # only if assignPermissionsToRoles was supplied")
        print("  ./import-onecx.sh -d workspace # recreates the selected workspace; review before running")
    except (OSError, RegistrationError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
