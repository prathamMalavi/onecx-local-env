# PR Review — 514: Disable autofocus in filter-view

| Field | Value |
|---|---|
| **Repo** | `onecx-portal-ui-libs` |
| **Issue** | [onecx/internal-tasks#514](https://github.com/onecx/internal-tasks/issues/514) (private — 404 on public fetch) |
| **PR** | [#1928](https://github.com/onecx/onecx-portal-ui-libs/pull/1928) |
| **Branch** | `fix/autofocus-514` |
| **Review date** | 2026-11-02 |
| **Reviewer** | AI (Claude Code) |
| **Version** | **v2** (supersedes v1 — adds §8: "Does the existing patch cover this? Can we close it?") |
| **Verdict** | ✅ **APPROVE** — correct, complete, non-redundant. See §8 for the redundancy analysis. |

> **v1 → v2 change:** v1 covered the code/functional review. v2 adds the answer to the follow-up question — *"the existing `patchOptimusAutoFocus()` already fixes this, so is this PR redundant / can we close it?"* — with an **empirical probe** of the real component.

---

# PART A — Core review (carried forward from v1)

## 1. What this PR changes (TL;DR)

One line of template + one test.

- `add-filter-dialog.component.html:29` — adds `autofocus="false"` to the **value** `p-multiSelect` in the Filter View's *Add filter* dialog.
- `add-filter-dialog.component.spec.ts:456-468` — one test asserting the multi-select's `autofocus` input is `false` **and** the inner native input carries no HTML `autofocus` attribute.

**The behaviour goal:** when the user opens the *Add filter* dialog, keyboard focus goes to the **column** dropdown (first control) and *stays* there — the **value** multi-select must **not** grab focus on its own.

## 2. The mechanism (why it's subtle)

Optimus UI's `AutoFocus` directive (`@openng/optimus-ui/autofocus`) has a **tri-state bug**: it stamps a native HTML `autofocus` attribute on the inner `<input>` for **anything that is not exactly `false`** — i.e. an **unset (`undefined`)** `autofocus` still turns it on. (Source: `openng-optimus-ui-autofocus.mjs`; the repo documents this in its own spec, `optimus-autofocus-patch.utils.spec.ts:43-54`.)

```ts
// Unpatched Optimus:
onAfterContentChecked() {
  if (this.autofocus === false) { /* remove attr */ }
  else { this.host.nativeElement.setAttribute('autofocus', true) }  // ⚠️ undefined → adds it
  if (!this.focused) this.autoFocus();                               // programmatic focus only if truthy
}
```

The fix pins the value select's input to an **explicit `false`**, so `[pAutoFocus]="autofocus"` gets `false` → no programmatic focus **and** no native attribute. The static string `autofocus="false"` is coerced to boolean `false` by Angular's `booleanAttribute` transform (the `MultiSelect` declares `autofocus` with `transformFunction: booleanAttribute`).

**Trap avoided:** on a component *without* an `autofocus` input (e.g. `p-pickList`), a static `autofocus="false"` would leak to the DOM and *turn it ON* (HTML boolean attribute; presence wins). `MultiSelect` has the input, so it's safe.

## 3. Functional review

- **26/26 unit tests pass** (`add-filter-dialog.component.spec.ts`).
- **The new test is a real guard:** with the fix line removed, it fails (`Expected: false / Received: undefined`); with it, it passes. Verified.
- **No logic/API/dependency impact** — 1 template attr + 1 test. `p-pickList` correctly left untouched (not in the filter view; it's in `custom-group-column-selector`; and Optimus `PickList` v2.0.2 has **0** `autofocus` refs — verified).

## 4. PR comments so far

Only: **sonarqubecloud bot — "Quality Gate passed"** (resolved). No human comments, nothing outstanding.

---

# PART B — The follow-up: does the existing patch cover this? Can we close it?

## 5. The existing patch (`patchOptimusAutoFocus`)

The repo ships a monkey-patch (`libs/angular-accelerator/src/lib/utils/optimus-autofocus-patch.utils.ts`) that **overwrites `AutoFocus.prototype.onAfterContentChecked`** so the native `autofocus` attribute is only set when `autofocus === true` (explicit), removed otherwise. It is idempotent and guarded.

**Where it is actually applied:**

```
$ grep -rn "patchOptimusAutoFocus" . --include=*.ts | grep -v node_modules
  .../optimus-autofocus-patch.utils.ts        (definition + log line)
  .../optimus-autofocus-patch.utils.spec.ts   (its own tests)
  .../index.ts:92                             export *  (exported, not invoked)
  .../.storybook/preview.ts:5                 patchOptimusAutoFocus()   ← ONLY real invocation
```

**Key fact: the only place it's *invoked* in the repo is Storybook.** There is **no `ngOnBootstrap`** in the library that auto-applies it — the sole `ngOnBootstrap` mention is a *comment* telling consumers to call it there. **So in a real consumer app the patch is active only if that consumer's module explicitly calls `patchOptimusAutoFocus()`. It is opt-in, not automatic.**

## 6. Empirical probe (rendering the real component)

To answer "is the value select's focus actually still wrong now, after the patch?" I rendered a **real `p-multiSelect` with no `autofocus` binding** (i.e. `autofocus === undefined` — the exact pre-fix state of the value select) and inspected the inner `#…Input`:

| Scenario | `multiSelect.autofocus` | native `hasAttribute('autofocus')` | `document.activeElement` |
|---|---|---|---|
| **Unpatched** | `undefined` | **`true`** ← stray attr (the reported symptom) | none |
| **Patched** | `undefined` | **`false`** ← attr removed by the patch | none |

**Conclusion of the probe:**
1. **With the patch applied, the stray-attribute symptom on the value select is already gone** — the patch *does* neutralize it.
2. **In both cases `activeElement` stays unfocused**, confirming the *programmatic* focus was never triggered (it's gated on a truthy `autofocus`, and the value select never sets it). So the "value select steals live keyboard focus on open" symptom is not reproducible by simply leaving `autofocus` unset — the observable defect is the **stray native `autofocus` attribute**.

## 7. So is the PR redundant? **No — not on "the patch covers it" grounds.**

| # | Reason the explicit `autofocus="false"` still adds value | Evidence |
|---|---|---|
| **(a)** | **The unit test can't rely on the patch.** `test-setup.ts` never calls `patchOptimusAutoFocus()`, so the spec runs the *unpatched* path. Without the explicit `false`, the new assertion `multiSelect.autofocus).toBe(false)` fails against `undefined`. The explicit value is what makes the component's contract testable **independently** of the patch. | Verified: removing the line → `Expected: false / Received: undefined` |
| **(b)** | **Per-instance correctness vs. a global side effect.** The patch works by overwriting a third-party prototype process-wide, and only if the consumer called it. A declarative `autofocus="false"` at the point of use is **per-instance, self-documenting, and independent of patch application order/timing.** | Design property |
| **(c)** | **The value select ships to real consumers**, not just Storybook. It is rendered via `onAddFilter()` → `PortalDialogService` in `angular-accelerator`. So the "Storybook-only, so the patch is always there" escape hatch doesn't apply. | `filter-view.component.ts:285` |

**Therefore the PR is *complementary* to the patch, not a duplicate of it.** It hardens the specific control and gives it a testable, patch-independent contract.

## 8. Recommendation

- **Merge as-is.** 1 line + 1 test, no behavior risk, makes the control correct whether or not a consumer applies the global patch. **Do not close on redundancy grounds.**
- **Do NOT replace the patch with this one-liner** — the patch is needed for *all* Optimus `pAutoFocus` usages across the app (buttons, inputs, etc.); this PR is a single control.
- **Separate follow-up (out of scope for this PR):** the library *ships* a required monkey-patch but does **not** auto-apply it (no `ngOnBootstrap`); consumers must remember to call `patchOptimusAutoFocus()`. If that's a real gap, the right fix is to auto-apply the patch in the library's bootstrap (or document it loudly) — not to revert this PR. Flag for a dedicated discussion.

### Minor non-blocking notes (from v1, unchanged)
1. **Mixed attribute style** on adjacent lines: `p-select` uses `[autofocus]="true"` (binding) vs `p-multiSelect` `autofocus="false"` (static string). Both correct; cosmetic only.
2. **The spec asserts the patch-independent contract** — which is the *right* thing to test (catches someone later removing the explicit `false` assuming the patch handles `undefined`).
3. (Informational, pre-existing, unrelated) `optimus-autofocus-patch.utils.ts:30-31` has a duplicated comment line.

---

# PART C — How to test

## Automated (unit) — run only these specific specs (not the full suite)
```bash
npx jest libs/angular-accelerator/src/lib/components/filter-view/add-filter-dialog/add-filter-dialog.component.spec.ts \
  --config libs/angular-accelerator/jest.config.ts          # 26/26 pass (incl. new autofocus test)

npx jest libs/angular-accelerator/src/lib/components/filter-view/add-filter-dialog/add-filter-dialog.component.integration.spec.ts \
  --config libs/angular-accelerator/jest.config.ts          # 5/5 pass (incl. focus-return-on-close)

npx jest libs/angular-accelerator/src/lib/utils/optimus-autofocus-patch.utils.spec.ts \
  --config libs/angular-accelerator/jest.config.ts          # documents the bug + proves the patch
```

## Proving the patch-vs-fix question
- To see the **bug** without the patch: render `p-multiSelect` with no `autofocus` binding → inner input has `autofocus="true"`.
- To see the **patch alone** fix it: call `patchOptimusAutoFocus()` first → same input has no `autofocus` attr. (This is what my probe in §6 did.)
- To see **this PR's** guarantee (patch-independent): the value select now sets explicit `false`, so the inner input has no `autofocus` attr *regardless* of patch state — and `multiSelect.autofocus` is `false` (not `undefined`).

## Manual (browser) via Storybook
Story (`interactive-data-view-filter-view.component.stories.ts`). Open the Filter View story → click *Add filter* → column dropdown holds focus, value multi-select does not. In Storybook the patch is applied, so the most visible difference is focus location; the authoritative attribute check is the unit test. Console check (dialog open):
```js
document.getElementById('ocxAddFilterValueInput').hasAttribute('autofocus')  // → false (fixed)
```

## Lint / build
- Lint is safe: `npx nx run angular-accelerator:lint`.
- Change is template-only; a full monorepo build (all 5 preloaders + shell) is not required and can be heavy — prefer a per-project build if needed. No build failure expected from a template attribute.

---

# Bottom line (newcomer-friendly)
1. The value selector in the Add-filter dialog was getting a **stray native `autofocus` attribute** because Optimus's `AutoFocus` treats *unset* as *on*.
2. This PR pins it to an explicit `false` → no stray attribute, no competing focus — the column dropdown is the sole focus owner.
3. **The global patch does fix the same attribute for patch-applied consumers, but it's opt-in (only Storybook applies it in-repo) and the unit test can't use it.** So the one-line explicit fix is not redundant: it's the testable, patch-independent, per-instance guarantee for a control that ships to real apps.
4. **Verdict: approve & merge; don't close on redundancy.** The bigger issue (library doesn't auto-apply its own patch) is a separate follow-up.
