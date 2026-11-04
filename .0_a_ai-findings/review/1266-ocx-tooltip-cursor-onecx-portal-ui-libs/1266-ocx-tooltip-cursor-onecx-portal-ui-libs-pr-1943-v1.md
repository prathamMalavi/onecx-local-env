# PR Review — onecx/onecx-portal-ui-libs #1943 (v8)

- **Issue:** [onecx/internal-tasks#1266](https://github.com/onecx/internal-tasks/issues/1266) — *OcxTooltipDirective: make the host cursor style configurable*
- **PR:** [onecx/onecx-portal-ui-libs#1943](https://github.com/onecx/onecx-portal-ui-libs/pull/1943) — *fix: make OcxTooltipDirective host cursor configurable (v8)*
- **Base branch:** `v8`. Base commit `07e04de8`, head commit `ae309326`.
- **Local checkout:** `fix/v8-tooltip-cursor` at `ae309326` (verified: local HEAD == PR head, and all 6 changed files are clean/identical to the PR head in the working tree — reviewed against live code, not just the diff).
- **Author:** bastianjakobi
- **Date:** 2026-11-03
- **Reviewer:** AI review (Claude Code)
- **Sibling PRs (same story, same logic):** #1942 (v9/main, reference), #1944 (v7), #1945 (v6). This (v8) is a backport.

---

## TL;DR / Verdict

**✅ APPROVE (no Request Changes).** The v8 backport fully realizes the story, is non-breaking, and **resolves both reviewer points from the prior round against the actual head code**. It uses the modern **signals `input()` + `effect()`** API (correct for v8 — the v8 directive already extends the signals-based `primeng/tooltip` Tooltip and already uses `input()`/`effect()` for `ocxTooltip`). All new + existing specs pass with **100% coverage on `tooltip.directive.ts`**, and lint is clean (0 errors; the 36 warnings are all pre-existing, none in the changed region). The Sonar quality gate **passed at 100% new-code coverage**. Docs correctly name **PrimeNG** (correct for v8, unlike v9 which uses Optimus UI).

| Check | Result |
|---|---|
| Story implemented (all AC) | ✅ Yes |
| Non-breaking (default behavior / API / existing tests) | ✅ Yes |
| Directive spec | ✅ **26/26 passed** |
| Data-table spec | ✅ **139/139 passed** (incl. new `default cursor` test) |
| `tooltip.directive.ts` coverage | ✅ **100% Stmts / Branch / Funcs / Lines** |
| Lint (`nx lint angular-accelerator`) | ✅ **0 errors** (36 warnings, all pre-existing; none in changed region) |
| Prior review comments (2) | ✅ Both resolved (verified against head code) |
| Sonar quality gate | ✅ Passed (100% new-code coverage) |
| Docs naming (v8 = PrimeNG) | ✅ Correct |

---

## 1. The story, in plain terms (for a dev new to this repo)

### The problem
`OcxTooltipDirective` (`ocxTooltip`, in `@onecx/angular-accelerator`) **always** forced `cursor: pointer` (the 🖱️ "clickable" hand) onto its host whenever a tooltip text was set. `pointer` is a UI signal meaning *"clickable"*, but the directive is also applied to **non-clickable** elements (data-table column headers, page-header labels, diagram items). On those the hand cursor is misleading, and because it was an **inline** style, consumers couldn't override it without `!important`. The issue is labelled `bug` + `a11y`.

### The fix
Add an **optional input** `ocxTooltipCursor` so the consumer chooses the cursor:
- **Not set / `undefined`** → keep today's `pointer` (non-breaking).
- **A CSS cursor value** (e.g. `default`, `help`) → apply that instead.
- **Empty string `''`** → falls back to `pointer`.
- **`null`** → don't touch the cursor; the host's own CSS wins.
- Changing the tooltip **text** must not lose the configured cursor; clearing it must restore the host's *previous* inline cursor.
- Data-table column-header labels with a tooltip should use `cursor: default`.

### ⚠️ The v8-specific difference vs v7/v6
The cursor **logic** (`applyCursor()` / `restoreHostCursor()`) is identical across all backports. What differs is:

- **v7 / v6** use the classic **`@Input()` getter/setter API** — the `ocxTooltip` setter and the `ocxTooltipCursor` setter each call `applyCursor()` directly.
- **v8 / v9 / main** use the modern **signals API** — `input()` for inputs, `effect()` for reacting (see §2).

Also note: **v8 (like v7/v6) uses PrimeNG** for the tooltip, whereas **v9/main uses Optimus UI**. So this PR's docs must say **PrimeNG** — and they do (see §5). This is the reverse of the naming nit that applied to #1942.

---

## 2. How the fix works (the "why/what/where/how")

**Where:** `libs/angular-accelerator/src/lib/directives/tooltip.directive.ts` (imports `Tooltip` from `primeng/tooltip`, line 2 — PrimeNG, correct for v8).

### The inputs (signals)
```ts
readonly ocxTooltip = input<string | TemplateRef<HTMLElement> | undefined>(undefined)

/** ... TSDoc describing pointer / CSS value / empty-string→pointer / null = hands-off / restore ... */
readonly ocxTooltipCursor = input<string | null | undefined>('pointer')   // line 19 — default keeps old behavior
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
    this.applyCursor()                    // line 37 — cursor logic runs here
  })
}
```

### The cursor logic (lines 61–79)
```ts
private cursorApplied = false   // line 24
private hostCursor = ''          // line 25

private applyCursor(): void {                                     // line 61
  const cursor = this.ocxTooltipCursor()                          // line 62 — read the cursor signal
  if (cursor !== null && this.content) {                          // line 63
    if (!this.cursorApplied) {
      this.hostCursor = this.el.nativeElement.style.cursor        // line 65 — remember host's original once (Point 1 fix)
    }
    this.renderer.setStyle(this.el.nativeElement, 'cursor', cursor || 'pointer')  // line 66 — ''→pointer
    this.cursorApplied = true
  } else if (this.cursorApplied) {                                 // line 69 — Point 2 fix
    // Only revert a cursor THIS directive applied; host's own styling untouched
    this.restoreHostCursor()                                       // line 71
  }
}

private restoreHostCursor(): void {                                // line 75
  if (this.hostCursor) {
    this.renderer.setStyle(this.el.nativeElement, 'cursor', this.hostCursor)
  } else {
    this.renderer.removeStyle(this.el.nativeElement, 'cursor')
  }
  this.cursorApplied = false
}
```

### The subtle parts (a new dev would miss these)
1. **`cursor !== null` is the only "hands-off" gate.** `null` is the *only* value that means "don't touch the cursor". `undefined` and `''` are **not** treated as hands-off — instead `cursor || 'pointer'` (line 66) makes both fall through to `pointer`. This is intentional and matches the spec exactly.
2. **`cursorApplied` = "did *I* set this cursor?"** This is the crux of *"only ever revert a cursor the directive applied itself."* If the host has `cursor: help` in its own CSS and the directive applies `default`, then when the tooltip is cleared the directive must put **`help` back**, not blindly `removeStyle`. `hostCursor` captures the host's pre-existing inline cursor **once** (guarded by `!this.cursorApplied`, line 64) so it can be restored later.
3. **`else if (this.cursorApplied)` guard (line 69)** prevents the restore path when the directive never applied a cursor → *"should not remove a host cursor it did not apply"* is true.
4. **Text change keeps the configured cursor** because `applyCursor()` re-applies `cursor || 'pointer'` every run, instead of a hard-coded `pointer` (the old bug).

### The one genuinely non-obvious thing I verified: does the effect re-run when only the cursor input changes?
Note the `effect()` body directly reads `this.ocxTooltip()` but reads `this.ocxTooltipCursor()` only *inside* `applyCursor()`. A careful reviewer would ask: **if I change only `ocxTooltipCursor` (with the tooltip text unchanged), does the effect re-run at all?**

I did **not** take that on faith — I verified it empirically (see §2.1). The answer is **yes, it works**, and the two relevant tests prove it.

### 2.1 Why the cursor-input-only change works (verified, not assumed)
Angular's `effect()` tracks **every signal read that happens while its body executes** — including reads made inside functions it calls (like `applyCursor()` → `this.ocxTooltipCursor()`), because signal reads are recorded in the *current* reactive context at read time, not at the call site. So:
- The effect reads `ocxTooltip()` **and** `ocxTooltipCursor()` (the latter transitively) during its run → both are tracked as dependencies.
- Changing **either** input invalidates the effect and re-runs it → `applyCursor()` runs → cursor re-applies/restores.

**Empirical proof:** the tests `should apply a changed cursor value` (cursor `default`→`help`, text unchanged) and `should remove the cursor it applied when ocxTooltipCursor changes to null` (cursor `default`→`null`, text unchanged) both change **only the cursor** and assert the cursor style changed. Both **passed** in my local run (26/26) — so the effect does re-run on cursor-only changes. This would *not* be the case if the cursor were read only inside a non-tracked callback; the tests are the safety net that pins this behavior. **The implementation is correct.**

### Non-breaking proof
Default of `ocxTooltipCursor` is `'pointer'` → with the input unset, `applyCursor()` sets `cursor: pointer`, identical to before. The public API only **adds** an input. Existing display/ID tests are untouched.

### Where the data-table change lands (and why it's in *this* PR, not #1939)
`data-table.component.html:340` — the column-header label `<span>` (inside `@if (column.tooltip || column.tooltipKey)`, line 337) gets `ocxTooltipCursor="default"`.

**Reconciling the reviewer's earlier note:** the prior reviewer said *"Leaving the data table header `cursor: default` to #1939 is fine, because v8 has no column header label tooltip yet."* That was written at the older commit `eda1da2`, **before** this PR was rebased onto the merged column-header-tooltip PR (#1939). At the current head `ae309326`:
- The `@if (column.tooltip || column.tooltipKey)` block at `data-table.component.html:337-341` is **context (unchanged) lines in the diff** — i.e. the header-tooltip markup is **already present in the v8 base**.
- Therefore #1939's feature has landed, and this PR's single added line `ocxTooltipCursor="default"` (line 340) + its test are the correct, in-scope follow-up. The reviewer's "leave it to #1939" note is now **moot** (superseded by the rebase), and the author's follow-up comment confirms: *"Rebased onto the merged column header tooltip PR. Header labels with a tooltip now use `ocxTooltipCursor='default'`."*

So the data-table change is **correct and belongs here** — this is the one v8-specific reconciliation a reviewer must make, and it resolves in favor of keeping the line.

---

## 3. Test-case review (correctness + coverage)

**Verdict: tests are correct, well-scoped, and complete for the required behaviors including the edge cases. No test is written incorrectly.** One minor note (N1) is optional.

The new `TestHostComponentCursor` host (spec line 65–83) binds `[style.cursor]="hostCursor"`, `[ocxTooltip]="tooltipText"`, and `[ocxTooltipCursor]="cursor"`, plus `tooltipPosition="top"`. Its defaults: `tooltipText = 'Tooltip with cursor'`, `cursor = 'default'`, `hostCursor = undefined`. Note the v8 host does **not** set `changeDetection: ChangeDetectionStrategy.Eager` — the reviewer confirmed this is **correct for v8** (Angular 21 / PrimeNG 21); it was only needed on the v9 spec. The `setup()` helper (line 330–336) creates the fixture, assigns props via `Object.assign`, runs `detectChanges()`, and returns the host element.

| Test (Cursor block, lines 338–455) | What it proves | Required? |
|---|---|---|
| `apply cursor pointer by default` (338) | Default behavior unchanged (uses `HOST_SELECTOR_1`, the main `TestHostComponent` with `tooltipText='Tooltip works!'`) | ✅ Must |
| `apply cursor pointer when ocxTooltipCursor is undefined` (344) | `undefined` → pointer (distinct from `null`) | ✅ Good |
| `apply a custom cursor value` (350) | A CSS value applied instead of pointer | ✅ Must |
| `expose the configured cursor` (356) | **`ocxTooltipCursor()`** readable (default `pointer`, custom `default`) — covers the signal getter | ✅ Must |
| `fall back to cursor pointer when empty string` (365) | `''` → pointer edge case | ✅ Good |
| `not set an inline cursor when null` (371) | `null` → no inline style (`''`) | ✅ Must |
| `keep the host cursor styling when null` (377) | `null` + host cursor survives a text clear | ✅ Good |
| `keep the configured cursor when the tooltip text changes` (388) | Text change doesn't reset to pointer | ✅ Must |
| `remove the configured cursor when text cleared, reapply when set again` (397) | Clear/re-set cycle | ✅ Good |
| `restore the host cursor styling when the tooltip text is cleared` (411) | The `cursorApplied`/`hostCursor` restore path (this was reviewer Point 2) | ✅ Must |
| `not remove a host cursor it did not apply when no tooltip text` (422) | `else if (cursorApplied)` guard | ✅ Must |
| `apply a changed cursor value` (428) | **cursor-only change re-runs the effect** (verified §2.1) | ✅ Must |
| `remove the cursor it applied when input changes to null` (437) | **cursor-only change to `null`** restore | ✅ Must |
| `restore the host cursor styling when input changes to null` (446) | cursor→null with a host cursor | ✅ Must |

- **Branch coverage = 100%** on `tooltip.directive.ts`, confirming every branch in `applyCursor`/`restoreHostCursor` is exercised.
- **Edge cases covered:** `undefined`, `''`, `null`, text change, text clear + re-set, restore-with-host-cursor (both the text-cleared path and the cursor→null path), no-tooltip-text, cursor change, cursor→null. Complete, not bloated.
- **Note N1 (nit, optional):** `should not set an inline cursor when ocxTooltipCursor is null` (371) and `should keep the host cursor styling when ocxTooltipCursor is null` (377) both exercise the `null` path — the former is a crisp `null → ''` assertion, the latter adds restore-on-clear. Keeping both is defensible; optional consolidation only.
- The data-table test (`data-table.component.spec.ts:290-294`, `should use the default cursor for column header labels with a tooltip`) mirrors the AC and asserts `getLabel().style.cursor === 'default'` on the real rendered header label via the existing `getLabel()` helper — consistent with the surrounding header-tooltip tests. Correct.

---

## 4. Prior review comments — resolution status (both verified against head code)

Reviewer `SchettlerKoehler` (on commit `eda1da2`) raised **2** findings. Both were raised only as **discussion comments** — the PR has **0 inline (review) comments** (verified via `gh api .../pulls/1943/comments` → `inline_count = 0`). Both apply to the sibling PRs too.

| # | Point | Severity | Status |
|---|---|---|---|
| 1 | Sonar gate fails: unreachable `?.`/`?? ''` fallbacks at `style?.cursor ?? ''` (2 uncovered conditions → 94.9% < 100%) | **Medium** | ✅ **RESOLVED** |
| 2 | Clearing tooltip text wiped the host's own inline cursor; only the `null` path restored | **Low** | ✅ **RESOLVED** |

### Point 1 — `style?.cursor ?? ''` → `style.cursor` (Medium) — VERIFIED RESOLVED
The head code at `tooltip.directive.ts:65` reads:
```ts
this.hostCursor = this.el.nativeElement.style.cursor
```
The optional chaining (`?.`) and nullish fallback (`?? ''`) are **gone** — exactly the fix the reviewer asked for. Rationale (reviewer's, confirmed correct): for an `HTMLElement` host, `style` always exists and `style.cursor` is always a string, so the two fallback branches were unreachable and counted against the 100% new-code-coverage gate. **My local run: `tooltip.directive.ts` = 100% Stmts/Branch/Funcs/Lines** — the gate concern is empirically cleared, and it matches the Sonar "Quality Gate Passed" badge (100% new-code coverage).

### Point 2 — Restore-on-clear (Low) — VERIFIED RESOLVED
The head code at `tooltip.directive.ts:69-71` now has:
```ts
} else if (this.cursorApplied) {
  // Only revert a cursor THIS directive applied; the host's own styling stays untouched
  this.restoreHostCursor()
}
```
and `restoreHostCursor()` (line 75–83) re-applies the saved `hostCursor` when present, else `removeStyle`. The author confirmed the `null` path and the cleared-text path **share one branch** — true: both `cursor === null` (fails `cursor !== null`) and `this.content` falsy (fails `&& this.content`) fall into the same `else if (this.cursorApplied)` branch. The exact test the reviewer requested is present at `tooltip.directive.spec.ts:411-420`: `setup({ cursor: 'default', hostCursor: 'help' })`, clears `tooltipText`, expects `'help'` — **passes**. The existing "remove the configured cursor when text cleared" test (397) still passes because its host has no pre-set cursor. **No regression.**

**No open inline comments** remain; both discussion findings are addressed and re-verified against the actual head source.

---

## 5. Repo-standard conformance

- **API choice:** `input()` + `effect()` is the **correct, modern** approach for **v8** — the v8 directive already extends the signals-based `primeng/tooltip` Tooltip and already used `input()`/`effect()` for `ocxTooltip` before this PR (see base). The new `ocxTooltipCursor` input matches that existing style. ✅
- **Input default:** `input<string | null | undefined>('pointer')` (line 19) — typed, with a default, consistent with the sibling `ocxTooltip` input. ✅
- **`Renderer2`** used for all style mutations (`setStyle`/`removeStyle`) — matches the rest of the directive. ✅
- **Docs naming (v8 = PrimeNG):** `docs/.../directives/tooltip.adoc:8` reads *"extends the **PrimeNG** tooltip"* and *"All inputs of the **PrimeNG** tooltip…"*. **No "Optimus UI"** anywhere in the file. This is **correct for v8**, because the directive imports `Tooltip` from `primeng/tooltip` (directive line 2). (This is the *opposite* of the #1942 naming fix, which needed Optimus UI — v9 uses Optimus UI.) ✅
- **Docs completeness:** the new `ocxTooltipCursor` input row (`tooltip.adoc:23`) documents all four behaviors — default/`undefined`→pointer, CSS value, `''`→pointer fallback, `null`→hands-off, and restore-on-clear/`null`. Matches the TSDoc (lines 6–16) and the implementation. ✅
- **Non-breaking:** confirmed (default `pointer`, additive input only). ✅
- **Lint:** `nx lint angular-accelerator` → **0 errors**, 36 warnings. I checked the warnings that touch the two changed spec files:
  - `data-table.component.spec.ts:925-931` — `@typescript-eslint/no-non-null-assertion`. These lines are **far from the PR's change region** (the new test is at lines 290–294) and exist in the base (the +7 line shift from the new test does not reach line 925). **Pre-existing, not a PR regression.**
  - The remaining warnings are in unrelated files (`page-header.component.ts`, `basic.directive.spec.ts`, `if-permission.directive.spec.ts`, etc.). None are in the changed region. ✅
- **Trailing newline (nit N3):** `nav.adoc` ends without a final newline (`*** xref:...directives/tooltip.adoc[OcxTooltip]` with no trailing `\n`). This is **pre-existing** — the base `nav.adoc` already lacked a trailing newline (the diff shows `\ No newline at end of file` on *both* the removed and added final lines), and there's no `eol-last` ESLint rule. Pure style nit. `tooltip.adoc` (new) **does** end with a newline (good).

---

## 6. Before vs After (behavioral)

| Scenario (host with `ocxTooltip`) | **Before** (v8 base) | **After** (this PR) |
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

# Data table (139 tests, includes the new "default cursor for column header labels" test)
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
5. **Cursor change at runtime:** keep the tooltip text constant and change only `ocxTooltipCursor` (e.g. `default` → `null`); the cursor should update via the effect — this exercises the signal-reactivity path.
6. **Clear restores host cursor:** give the host its own `cursor: help`, set then clear the tooltip text; after clearing the host shows `help` again (not a wiped cursor).

---

## 8. Suggested PR comments

No blocking comments. If the author wants a zero-risk tidy-up, these are the only nits (all optional). I would post one non-blocking "nit" comment and **approve**.

### (Nit, optional) N3 — `nav.adoc` trailing newline
- **File / line:** `docs/modules/onecx-portal-ui-libs/partials/nav.adoc` — last line (`*** xref:...directives/tooltip.adoc[OcxTooltip]`)
- **Suggested comment:**
  > Nit (non-blocking, and pre-existing): the nav file ends without a trailing newline. The base file already lacked one and there's no `eol-last` rule, so this isn't a standards breach — just flagging in case you'd like to add a final newline while you're here. Optional.

### (Nit, optional) N1 — redundant cursor test
- **File / line:** `libs/angular-accelerator/src/lib/directives/tooltip.directive.spec.ts:371` — `should not set an inline cursor when ocxTooltipCursor is null`
- **Suggested comment:**
  > Nit (non-blocking): this `null → ''` test overlaps the `null` + host-cursor test just below it (line 377). Keeping both is fine (this is a crisp unit assertion); just flagging in case you'd prefer to consolidate. No change required.

### (Info, not a change) — data-table change is in-scope (reconciles the "#1939" note)
No change needed, but worth a one-line acknowledgment so the reviewer's earlier "leave the header cursor to #1939" note doesn't linger:
  > The column-header `ocxTooltipCursor="default"` is included here (not deferred to #1939) because this branch was rebased onto the merged column-header-tooltip PR, so the header-tooltip markup is already in the base. This line is the correct in-scope follow-up.

---

## 9. Overall assessment & final recommendation

This is a **well-executed, minimal, non-breaking backport** on the modern signals API:
- Precisely implements every acceptance criterion,
- Introduces the same clean single-path cursor manager as the sibling PRs, with correct "only revert what I set" semantics,
- Correctly uses `input()`/`effect()` for v8, and the cursor-input reactivity is verified (not assumed),
- Ships complete, correctly-named documentation (**PrimeNG**, correct for v8),
- Includes the in-scope data-table `ocxTooltipCursor="default"` change (post-rebase) with a matching test,
- Has thorough, correctly-written tests at 100% coverage,
- Resolves both prior review comments (verified against head code) and passes the Sonar quality gate,
- Keeps lint clean.

**Recommendation: ✅ Approve.** No requested-changes or reject triggers. The two nits (N1, N3) are optional polish and don't gate merge.

*Cross-branch note:* the reviewer explicitly asked that the `style.cursor` simplification (Point 1) and the restore-on-clear fix (Point 2) be mirrored across the sibling backports. **#1943 (v8) carries both** (verified here). #1942 (v9) and #1944 (v7) are already confirmed to carry both. Only #1945 (v6) remains to be checked when it is reviewed.
