# PR Review — onecx/onecx-portal-ui-libs #1942 (v9 / main)

- **Issue:** [onecx/internal-tasks#1266](https://github.com/onecx/internal-tasks/issues/1266) — *OcxTooltipDirective: make the host cursor style configurable*
- **PR:** [onecx/onecx-portal-ui-libs#1942](https://github.com/onecx/onecx-portal-ui-libs/pull/1942) — *fix: make OcxTooltipDirective host cursor configurable (v9)*
- **Base branch:** `main` (v9). Base commit `5d942c9b`, head commit `862f0711`.
- **Local checkout:** `fix/v9-tooltip-cursor` at `862f0711` (verified: all 6 PR files match the PR head in the working tree — reviewed against live code, not just the diff).
- **Author:** bastianjakobi
- **Date:** 2026-11-03
- **Reviewer:** AI review (Claude Code)
- **Sibling PRs (same story, same logic):** #1943 (v8), #1944 (v7), #1945 (v6). This (main) is the reference — the backports copy it.

---

## TL;DR / Verdict

**✅ APPROVE (no Request Changes).** The v9 implementation fully realizes the story, is non-breaking, resolves all 4 reviewer points from the prior round, uses the **modern signals `input()` API** (correctly for main), and passes all new + existing specs with 100% coverage on the changed file. Lint is clean (0 errors; all warnings pre-existing). Sonar quality gate passed at 100% new-code coverage. The only observations are two **nit / optional** items (see §7).

| Check | Result |
|---|---|
| Story implemented (all 4 AC) | ✅ Yes |
| Non-breaking (default behavior / API / existing tests) | ✅ Yes |
| Directive spec | ✅ **26/26 passed** |
| Data-table spec | ✅ **142/142 passed** (incl. new cursor test) |
| `tooltip.directive.ts` coverage | ✅ **100% Stmts / Branch / Funcs / Lines** |
| Lint (`nx lint angular-accelerator`) | ✅ **0 errors** (42 warnings, all pre-existing / env-artifact) |
| Prior review comments (4) | ✅ All 4 resolved (verified) |
| Sonar quality gate | ✅ Passed (100% new-code coverage) |
| Docs naming (v9 = Optimus UI) | ✅ Correct |

---

## 1. The story, in plain terms (for a dev new to this repo)

### The problem
`OcxTooltipDirective` (`ocxTooltip`, in `@onecx/angular-accelerator`) **always** forced `cursor: pointer` (the 🖱️ "clickable" hand) onto its host whenever a tooltip text was set. `pointer` is a UI signal meaning *"clickable"*, but the directive is also applied to **non-clickable** elements (data-table column headers, page-header labels, diagram items). On those the hand cursor is misleading, and because it was an **inline** style, consumers couldn't override it without `!important`. The issue is labelled `bug` + `a11y`.

### The fix
Add an **optional input** `ocxTooltipCursor` so the consumer chooses the cursor:
- **Not set / `undefined`** → keep today's `pointer` (non-breaking).
- **A CSS cursor value** (e.g. `default`, `help`) → apply that instead.
- **`null`** → don't touch the cursor; the host's own CSS wins.
- Changing the tooltip **text** must not lose the configured cursor.
- Data-table column-header labels with a tooltip should use `cursor: default`.

### ⚠️ The important v9-vs-backport difference: the API is different
This is the single most important thing a reviewer must understand about **this** PR versus the v6–v8 backports:

- **v9 / main (this PR)** uses the modern **Angular signals API**: `input()` for inputs and `effect()` for reacting to them. No `@Input()` decorators, no getters/setters.
- **v7 (and by extension v6/v8)** use the classic **`@Input()` getter/setter API**.

So the *logic* of `applyCursor()` / `restoreHostCursor()` is **identical** across all branches, but **how `applyCursor()` gets triggered is different**:

- v7: the `ocxTooltip` setter and the `ocxTooltipCursor` setter **each** call `applyCursor()` directly.
- v9: an `effect()` runs when its inputs change and calls `applyCursor()` (see §2).

That difference is exactly why the v9 spec was adjusted (see §3) and why this PR needed its own review rather than just copying v7.

---

## 2. How the fix works (the "why/what/where/how")

**Where:** `libs/angular-accelerator/src/lib/directives/tooltip.directive.ts`.

### The inputs (signals)
```ts
readonly ocxTooltip = input<string | TemplateRef<HTMLElement> | undefined>(undefined)

/** ... TSDoc describing pointer / CSS value / empty-string→pointer / null = hands-off ... */
readonly ocxTooltipCursor = input<string | null | undefined>('pointer')  // ← default keeps old behavior
```
The default value of `ocxTooltipCursor` is `'pointer'` — that alone guarantees the non-breaking requirement (unset → pointer).

### The effect (the trigger)
```ts
constructor() {
  ...
  effect(() => {
    const value = this.ocxTooltip()      // directly reads the tooltip input
    this.content = value
    this.setOption({ tooltipLabel: value })
    this.ensureIdAndAriaDescribedBy()
    this.applyCursor()                    // ← cursor logic runs here
  })
}
```

### The cursor logic
```ts
private cursorApplied = false
private hostCursor = ''

private applyCursor(): void {
  const cursor = this.ocxTooltipCursor()          // read the cursor signal
  if (cursor !== null && this.content) {
    if (!this.cursorApplied) {
      this.hostCursor = this.el.nativeElement.style.cursor  // remember host's original once
    }
    this.renderer.setStyle(this.el.nativeElement, 'cursor', cursor || 'pointer')  // ''→pointer
    this.cursorApplied = true
  } else if (this.cursorApplied) {
    // Only revert a cursor THIS directive applied; host's own styling untouched
    this.restoreHostCursor()
  }
}

private restoreHostCursor(): void {
  if (this.hostCursor) {
    this.renderer.setStyle(this.el.nativeElement, 'cursor', this.hostCursor)
  } else {
    this.renderer.removeStyle(this.el.nativeElement, 'cursor')
  }
  this.cursorApplied = false
}
```

### The subtle parts (a new dev would miss these)
1. **`cursor !== null` is the only "hands-off" gate.** `null` is the *only* value that means "don't touch the cursor". `undefined` and `''` are **not** treated as hands-off — instead `cursor || 'pointer'` makes both fall through to `pointer`. This is intentional and matches the spec exactly.
2. **`cursorApplied` = "did *I* set this cursor?"** This is the crux of *"only ever revert a cursor the directive applied itself."* If the host has `cursor: help` in its own CSS and the directive applies `default`, then when the tooltip is cleared the directive must put **`help` back**, not blindly `removeStyle`. `hostCursor` captures the host's pre-existing inline cursor **once** (guarded by `!this.cursorApplied`) so it can be restored later.
3. **`else if (this.cursorApplied)` guard** prevents the restore path when the directive never applied a cursor → *"should not remove a host cursor it did not apply"* is true.
4. **Text change keeps the configured cursor** because `applyCursor()` re-applies `cursor || 'pointer'` every run, instead of a hard-coded `pointer` (the old bug).

### The one genuinely non-obvious thing I verified: does the effect re-run when only the cursor input changes?
Note the `effect()` body directly reads `this.ocxTooltip()` but reads `this.ocxTooltipCursor()` only *inside* `applyCursor()`. A careful reviewer would ask: **if I change only `ocxTooltipCursor` (with the tooltip text unchanged), does the effect re-run at all?**

I did **not** take that on faith — I verified it empirically (see §2.1). The answer is **yes, it works**, and the two relevant tests prove it.

### 2.1 Why the cursor-input-only change works (verified, not assumed)
Angular's `effect()` tracks **every signal read that happens while its body executes** — including reads made inside functions it calls (like `applyCursor()` → `this.ocxTooltipCursor()`), because signal reads are recorded in the *current* reactive context at read time, not at the call site. So:
- The effect reads `ocxTooltip()` **and** `ocxTooltipCursor()` (the latter transitively) during its run → both are tracked as dependencies.
- Changing **either** input invalidates the effect and re-runs it → `applyCursor()` runs → cursor re-applies/restores.

**Empirical proof:** the tests `should apply a changed cursor value` (cursor `default`→`help`, text unchanged) and `should remove the cursor it applied when ocxTooltipCursor changes to null` (cursor `default`→`null`, text unchanged) both change **only the cursor** and assert the cursor style changed. Both **passed** in my local run — so the effect does re-run on cursor-only changes. This would *not* be the case if the cursor were read only inside a non-tracked callback; the tests are the safety net that pins this behavior. **The implementation is correct.**

### Non-breaking proof
Default of `ocxTooltipCursor` is `'pointer'` → with the input unset, `applyCursor()` sets `cursor: pointer`, identical to before. The public API only **adds** an input. Existing display/ID tests are untouched.

### Where the data-table change lands
`data-table.component.html:337-338` — the column-header label `<span>` (inside `@if (column.tooltip || column.tooltipKey)`) gets `ocxTooltipCursor="default"`. On v9 the column-header tooltip already exists (it came with the merged #1940), so this PR wires up `ocxTooltipCursor="default"` — unlike main/v8 in the v7 branch note. This satisfies the "column header labels use `cursor: default`" AC on this branch.

---

## 3. Test-case review (correctness + coverage)

**Verdict: tests are correct, well-scoped, and complete for the required behaviors including the edge cases. No test is written incorrectly.** One minor note (N2) is optional.

The new `TestHostComponentCursor` host (spec line 68-87) uses `changeDetection: ChangeDetectionStrategy.Eager` and binds both `[ocxTooltip]="tooltipText"` and `[ocxTooltipCursor]="cursor"`, plus a `[style.cursor]="hostCursor"` so tests can simulate a host that already carries an inline cursor. The `setup()` helper (line 330-336) creates the fixture, assigns props, runs `detectChanges()`, and returns the host element.

| Test (Cursor block) | What it proves | Required? |
|---|---|---|
| `apply cursor pointer by default` | Default behavior unchanged (uses `HOST_SELECTOR_1`, no cursor input) | ✅ Must |
| `apply cursor pointer when ocxTooltipCursor is undefined` | `undefined` ≠ `null` | ✅ Good |
| `apply a custom cursor value` | A CSS value applied instead of pointer | ✅ Must |
| `expose the configured cursor` | **`ocxTooltipCursor()`** readable (default `pointer`, custom `default`) | ✅ Must (covers the signal getter) |
| `fall back to cursor pointer when empty string` | `''` → pointer edge case | ✅ Good |
| `not set an inline cursor when null` | `null` → no inline style | ✅ Must |
| `keep the host cursor styling when null` | `null` + host cursor survives a text clear | ✅ Good |
| `keep the configured cursor when the tooltip text changes` | Text change doesn't reset to pointer | ✅ Must |
| `remove the configured cursor when text cleared, reapply when set again` | Clear/re-set cycle | ✅ Good |
| `restore the host cursor styling when the tooltip text is cleared` | The `cursorApplied`/`hostCursor` restore path (this was reviewer point #1) | ✅ Must |
| `not remove a host cursor it did not apply when no tooltip text` | `else if (cursorApplied)` guard | ✅ Must |
| `apply a changed cursor value` | **cursor-only change re-runs the effect** (verified §2.1) | ✅ Must |
| `remove the cursor it applied when input changes to null` | **cursor-only change to `null`** restore | ✅ Must |
| `restore the host cursor styling when input changes to null` | cursor→null with a host cursor | ✅ Must |

- **Branch coverage = 100%** on `tooltip.directive.ts`, confirming every branch in `applyCursor`/`restoreHostCursor` is exercised.
- **Edge cases covered:** `undefined`, `''`, `null`, text change, text clear + re-set, restore-with-host-cursor, no-tooltip-text, cursor change, cursor→null. Complete, not bloated.
- **Note N2 (nit, optional):** `should not set an inline cursor when ocxTooltipCursor is null` overlaps the `null` + host-cursor test below it (the former is a crisp `null → ''` assertion; the latter adds restore-on-clear). Keeping both is defensible — optional consolidation only.
- **A small v9-specific nit (N1):** the new `TestHostComponentCursor` host explicitly sets `changeDetection: ChangeDetectionStrategy.Eager`. That's appropriate here (the tests assert cursor changes that are driven by an `effect`, and Eager CD makes the assertions deterministic), and it's a reasonable, non-harmless choice. Just noting it's intentional — it's not a bug.

The data-table test (`data-table.component.spec.ts:324-330`) mirrors the AC and asserts on the real rendered `.column-header-label` via the existing `getLabel()` helper — consistent with surrounding tests. Correct.

---

## 4. Prior review comments — resolution status (all verified)

Reviewer `SchettlerKoehler` (on commit `d114295`) raised **4** points. This PR's logic is copied by #1943/#1944/#1945, so fixing them here first matters.

| # | Point | Severity | Status |
|---|---|---|---|
| 1 | Clearing text wiped the host's inline cursor instead of restoring it | **Medium** | ✅ **RESOLVED** |
| 2 | `Fixes` would close #1266 too early | **Medium** | ✅ **RESOLVED** |
| 3 | New-code coverage < 100% gate (94.9%); `''` fallback uncovered; `?.`/`?? ''` unreachable | **Low** | ✅ **RESOLVED** |
| 4 | Docs name the wrong base lib (said PrimeNG; v9 uses Optimus UI) | **Low** | ✅ **RESOLVED** |

### #1 — Restore-on-clear (Medium) — VERIFIED RESOLVED
The old code called `removeStyle('cursor')` unconditionally on clear. Now the restore path is `else if (this.cursorApplied) { this.restoreHostCursor() }` (directive line 69-72), and `restoreHostCursor()` re-applies the saved `hostCursor` when present. The author confirmed the `null` path and the cleared-text path **share one branch**. The added test `should restore the host cursor styling when the tooltip text is cleared` (host cursor `help`, cursor `default`, text cleared → expects `help`) proves it — **passes**.

### #2 — `Fixes` → `Part of` (Medium) — VERIFIED RESOLVED
PR body now reads **"Part of https://github.com/onecx/internal-tasks/issues/1266 (`main`)"**. Correct: the umbrella issue has sibling backports and a shared AC, so no single backport should auto-close it. (Consistent across the backport family.)

### #3 — 100% new-code coverage (Low) — VERIFIED RESOLVED
- `''` fallback: `cursor || 'pointer'` (line 67) — now covered by `should fall back to cursor pointer when ocxTooltipCursor is an empty string`.
- Unreachable `style?.cursor ?? ''`: replaced with `this.el.nativeElement.style.cursor` (line 65). The optional chaining + nullish fallback are gone.
- Documented: TSDoc (lines 8-18) and the adoc inputs table (line 23) both describe the `''`→`pointer` fallback.
- **My local run: `tooltip.directive.ts` = 100% Stmts/Branch/Funcs/Lines.** Matches Sonar "100.0% Coverage on New Code, Quality Gate Passed".

### #4 — Docs naming (Low) — VERIFIED RESOLVED
`docs/.../directives/tooltip.adoc:8` now reads: *"extends the **Optimus UI** tooltip (`@openng/optimus-ui/tooltip`)"* and *"All inputs of the **Optimus UI** tooltip…"*. **No "PrimeNG"** remains in the file. This is correct because v9's directive imports `Tooltip` from `@openng/optimus-ui/tooltip` (directive line 2) — PrimeNG is only correct for the v6–v8 backports. The author reworded exactly as asked.

Also, the author's follow-up (2026-11-02) confirms the rebase onto the merged column-header-tooltip PR, so the header labels now carry `ocxTooltipCursor="default"` — consistent with the data-table change.

**No open inline comments** remain; all feedback is in the discussion thread and has been addressed.

---

## 5. Repo-standard conformance

- **API choice:** `input()` + `effect()` is the **correct, modern** approach for **main/v9** (the codebase uses signals on this branch — note `userService.permissionsTopic$` etc. are elsewhere, but the directive itself is signals-based and this matches the file's existing `ocxTooltip` input style). ✅
- **Input default:** `input<string | null | undefined>('pointer')` — typed, with a default. Consistent with the sibling input. ✅
- **`Renderer2`** used for all style/attribute mutations (matches the rest of the directive). ✅
- **Docs:** new page + nav entry under the correct module, AsciiDoc conventions matched, correct "Optimus UI" naming. ✅
- **Non-breaking:** confirmed. ✅
- **Lint:** `nx lint angular-accelerator` → **0 errors**. The 42 warnings are all **pre-existing / environment artifacts**, none introduced by this PR:
  - `data-table.component.spec.ts:960-966` — `@typescript-eslint/no-non-null-assertion` on lines that **existed in the base** (shifted +7 by the new test); e.g. `overflowMenu!.getAllMenuItems()` at base line ~958.
  - `tooltip.directive.spec.ts:11/31/51/69` — "Unused eslint-disable directive" for `@angular-eslint/prefer-standalone`. The base file already had **3** such disables; this PR adds the 4th component's disable. The "unused" flag is a local artifact (the rule definition isn't resolved when lint runs standalone in this environment) — the same directives are present and legitimate in the base. **Not a PR regression.**
- **Trailing newline (nit N3):** `nav.adoc` ends without a final newline. This is **pre-existing** (the base `nav.adoc` also lacked a trailing newline) and there's no `eol-last` ESLint rule, and several sibling `.adoc` files omit it. Pure style nit, not a standards breach. `tooltip.adoc` (new) **does** end with a newline (good).

---

## 6. Before vs After (behavioral)

| Scenario (host with `ocxTooltip`) | **Before** (main base) | **After** (this PR) |
|---|---|---|
| No `ocxTooltipCursor`, text set | `cursor: pointer` (inline) | `cursor: pointer` (inline) — **unchanged** |
| `ocxTooltipCursor="default"`, text set | n/a | `cursor: default` |
| `ocxTooltipCursor="help"`, text set | n/a | `cursor: help` |
| `ocxTooltipCursor=""`, text set | n/a | `cursor: pointer` (fallback) |
| `ocxTooltipCursor=null`, text set | n/a | **no inline cursor** — host CSS wins |
| `null` + host `cursor: help` | n/a | stays `help` |
| Change tooltip text after configuring a cursor | reset to `pointer` (old bug) | **keeps the configured cursor** |
| **Change cursor input only** (text unchanged) | n/a | **effect re-runs; cursor updates** (verified §2.1) |
| Clear tooltip text | `removeStyle` — **wiped any host cursor** | restores the host's *previous* inline cursor (only if the directive applied one) |
| Host has own cursor, no tooltip text | directive did nothing | directive still does nothing |
| Data-table column header with tooltip | `pointer` (misleading hand) | `default` (normal arrow) |

Most user-visible: (a) column headers no longer show a "clickable" hand; (b) the directive no longer *deletes* a host's own cursor when a tooltip is cleared — it restores it; (c) changing the cursor input at runtime now works correctly.

---

## 7. How the developer can test the change

**Unit tests (already run & passing in this review):**
```bash
# Tooltip directive (26 tests, 100% coverage on tooltip.directive.ts)
npx jest libs/angular-accelerator/src/lib/directives/tooltip.directive.spec.ts \
  --config libs/angular-accelerator/jest.config.ts

# Data table (142 tests, includes the new "default cursor for column header labels" test)
npx jest libs/angular-accelerator/src/lib/components/data-table/data-table.component.spec.ts \
  --config libs/angular-accelerator/jest.config.ts
```

**Lint:**
```bash
npx nx lint angular-accelerator      # 0 errors
```

**Manual / visual (in an app consuming the lib):**
1. **Default (non-breaking):** any existing `[ocxTooltip]` element still shows the hand 🖱️ cursor. Identical to before.
2. **`default` cursor:** a tooltiped element with `ocxTooltipCursor="default"` shows the normal arrow. The concrete in-product case is the **data-table column header** (hover a header with a tooltip → arrow cursor).
3. **`null`:** a tooltiped element with `ocxTooltipCursor="null"` inherits its host CSS cursor (directive doesn't force one).
4. **Text change keeps cursor:** bind tooltip text to a variable, toggle it while `ocxTooltipCursor="default"` is set; cursor must stay `default`.
5. **Cursor change at runtime (the v9-specific case):** keep the tooltip text constant and change only `ocxTooltipCursor` (e.g. `default` → `null`); the cursor should update via the effect — this exercises the signal-reactivity path.
6. **Clear restores host cursor:** give the host its own `cursor: help`, set then clear the tooltip text; after clearing the host shows `help` again (not a wiped cursor).

---

## 8. Suggested PR comments

No blocking comments. If the author wants a zero-risk tidy-up, these are the only nits (all optional). I would post one non-blocking "nit" comment and **approve**.

### (Nit, optional) N3 — `nav.adoc` trailing newline
- **File / line:** `docs/modules/onecx-portal-ui-libs/partials/nav.adoc` — last line (`*** xref:...directives/tooltip.adoc[OcxTooltip]`)
- **Suggested comment:**
  > Nit (non-blocking, and pre-existing): the nav file ends without a trailing newline. The base file already lacked one and there's no `eol-last` rule, so this isn't a standards breach — just flagging in case you'd like to add a final newline while you're here. Optional.

### (Nit, optional) N2 — redundant cursor test
- **File / line:** `libs/angular-accelerator/src/lib/directives/tooltip.directive.spec.ts` — `should not set an inline cursor when ocxTooltipCursor is null`
- **Suggested comment:**
  > Nit (non-blocking): this `null → ''` test overlaps the `null` + host-cursor test just below it. Keeping both is fine (this is a crisp unit assertion); just flagging in case you'd prefer to consolidate. No change required.

### (Info, not a change) — signal-reactivity is correct
No comment needed, but the author may appreciate that the cursor-only-change behavior (the `effect()` reading `ocxTooltipCursor()` transitively via `applyCursor()`) is **correct and covered** by the "changed cursor value" / "changes to null" tests. If they'd like extra clarity for future readers, a one-line comment near the `effect()` noting that `applyCursor()` reads the cursor signal (so the effect tracks it) would help — optional, not required.

---

## 9. Overall assessment & final recommendation

This is a **well-executed, minimal, non-breaking fix** on the modern signals API:
- Precisely implements every acceptance criterion,
- Introduces the same clean single-path cursor manager as the backports, with correct "only revert what I set" semantics,
- Correctly uses `input()`/`effect()`, and the cursor-input reactivity is verified (not assumed),
- Ships complete, correctly-named documentation (Optimus UI),
- Has thorough, correctly-written tests at 100% coverage,
- Resolves all 4 prior review comments and passes the Sonar quality gate,
- Keeps lint clean.

**Recommendation: ✅ Approve.** No requested-changes or reject triggers. The two nits (N2, N3) are optional polish and don't gate merge.

*Cross-branch note:* the reviewer explicitly asked that the `style.cursor` simplification (point #3) and the restore-on-clear fix (point #1) be mirrored across the sibling backports **#1943 (v8), #1944 (v7), #1945 (v6)** to keep them aligned. #1944 (v7) is already confirmed to carry both. The same should be verified on #1943 and #1945 when those are reviewed.
