# PR Review — onecx/onecx-portal-ui-libs #1945 (v6)

- **Issue:** [onecx/internal-tasks#1266](https://github.com/onecx/internal-tasks/issues/1266) — *OcxTooltipDirective: make the host cursor style configurable*
- **PR:** [onecx/onecx-portal-ui-libs#1945](https://github.com/onecx/onecx-portal-ui-libs/pull/1945) — *fix: make OcxTooltipDirective host cursor configurable (v6)*
- **Base branch:** `v6`. Base commit `891f5a1d`, head commit `5a537086`.
- **Local checkout:** `fix/v6-tooltip-cursor` at `5a537086` (verified: local HEAD == PR head == `origin/fix/v6-tooltip-cursor`; all 4 changed files are clean/identical to the PR head in the working tree — reviewed against live code, not just the diff).
- **Author:** bastianjakobi
- **Date:** 2026-11-03
- **Reviewer:** AI review (Claude Code)
- **Sibling PRs (same story, same logic):** #1942 (v9/main, reference), #1943 (v8), #1944 (v7). This (v6) is the last backport.

---

## TL;DR / Verdict

**✅ APPROVE (no Request Changes).** The v6 backport fully realizes the story, is non-breaking, and **resolves the single prior review finding (2 sub-points) against the actual head code**. It uses the **classic `@Input()` getter/setter API** — the correct approach for v6 (Angular 19 / PrimeNG 19), exactly as the reviewer prescribed ("swapping the signal `input()` for an `@Input()` getter/setter is the right way to do it on v6"). All new + existing specs pass with **100% coverage on `tooltip.directive.ts`**, lint is clean (0 errors; the 24 warnings are all pre-existing, none in the changed region), and the Sonar quality gate **passed at 100% new-code coverage** on `angular-accelerator`.

| Check | Result |
|---|---|
| Story implemented (all AC) | ✅ Yes |
| Non-breaking (default behavior / API / existing tests) | ✅ Yes |
| Directive spec | ✅ **26/26 passed** |
| Data-table spec | ✅ **97/97 passed** (incl. new `default cursor` test) |
| `tooltip.directive.ts` coverage | ✅ **100% Stmts / Branch / Funcs / Lines** |
| Lint (`nx lint angular-accelerator`) | ✅ **0 errors** (24 warnings, all pre-existing; none in changed region) |
| Prior review finding (1, with 2 sub-points) | ✅ Resolved (verified against head code) |
| Sonar quality gate (angular-accelerator) | ✅ Passed (100.0% new-code coverage) |
| Docs handling (v6 = no docs module → TSDoc only) | ✅ Correct |

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

### ⚠️ The v6-specific differences (the most important thing about *this* PR)
The cursor **logic** (`applyCursor()` / `restoreHostCursor()`) is identical across all five branches. What differs on **v6** specifically:

1. **Classic `@Input()` getter/setter API — NOT signals.** v6 uses Angular 19 / PrimeNG 19. The directive declares:
   ```ts
   @Input()
   get ocxTooltipCursor(): string | null | undefined { return this._ocxTooltipCursor }
   set ocxTooltipCursor(value: string | null | undefined) {
     this._ocxTooltipCursor = value
     this.applyCursor()
   }
   private _ocxTooltipCursor: string | null | undefined = 'pointer'
   ```
   Both the `ocxTooltip` setter and the `ocxTooltipCursor` setter call `applyCursor()`. So the trigger model is: *whenever either input is set, recompute the cursor.* This means the **order** in which Angular assigns the two inputs doesn't matter (the second assignment re-runs the cursor logic with both values present). This is the v6 equivalent of v8/v9's `effect()` — and the reviewer explicitly confirmed it's the right choice here.

2. **The getter must be tested (v6-only concern).** Because v6 exposes `ocxTooltipCursor` as a **public getter property** (`directive.ocxTooltipCursor`, *no call* — unlike v8/v9's signal `directive.ocxTooltipCursor()`), Sonar counts the getter line as new code that needs a hit. The main branch's signal input has no such standalone getter line, so this sub-point applies **only to v6**. (See §4, finding 1a.)

3. **No docs module → TSDoc-only documentation.** v6 has **no** `docs/modules/onecx-portal-ui-libs` AsciiDoc module at all (verified: only `contributions`/`general` exist; `tooltip.adoc` does not exist in the base). So the "Documentation updated" AC is satisfied by the **TSDoc on the `ocxTooltipCursor` input** (directive lines 23–34) instead of a new adoc page. Correct handling of a branch-specific constraint.

4. **Data-table test uses v6's component API.** v6's `DataTableComponent` uses `component.columns = [...]` (a **plain property**, not the `columns.set()` signal used on v8) and the header label is addressed by its **id attribute** `#<column.id>-header-name` (not the `.column-header-label` CSS class used on v8). The new data-table test (`data-table.component.spec.ts:401-408`) uses both of these correctly.

---

## 2. How the fix works (the "why/what/where/how")

**Where:** `libs/angular-accelerator/src/lib/directives/tooltip.directive.ts` (imports `Tooltip` from `primeng/tooltip`, line 2 — PrimeNG, correct for v6).

### The inputs (classic `@Input()`, lines 32–41)
```ts
@Input()
get ocxTooltipCursor(): string | null | undefined {
  return this._ocxTooltipCursor                              // line 33 — the getter Sonar needs a hit on
}

set ocxTooltipCursor(value: string | null | undefined) {
  this._ocxTooltipCursor = value
  this.applyCursor()                                          // line 38
}

private _ocxTooltipCursor: string | null | undefined = 'pointer'  // line 41 — default keeps old behavior
private cursorApplied = false                                 // line 42
private hostCursor = ''                                       // line 43
```
The default value of `_ocxTooltipCursor` is `'pointer'` — that alone guarantees the non-breaking requirement (unset → pointer).

### The trigger (both setters call `applyCursor()`)
The existing `ocxTooltip` setter (lines 14–18) now ends with `this.applyCursor()` (line 17) instead of the old hard-coded `if (value) setStyle(pointer) else removeStyle`. The new `ocxTooltipCursor` setter (line 38) also calls `applyCursor()`. So:
- setting/changing the **text** → recompute cursor,
- setting/changing the **cursor input** → recompute cursor.
Both paths funnel through the same `applyCursor()`, so there's no ordering hazard and no separate reactivity to reason about.

### The cursor logic (lines 76–100)
```ts
private applyCursor(): void {                                // line 76
  const cursor = this._ocxTooltipCursor                      // line 77 — read the backing field
  if (cursor !== null && this.content) {                     // line 78
    if (!this.cursorApplied) {
      this.hostCursor = this.el.nativeElement.style.cursor   // line 80 — remember host's original once (finding 1b fix)
    }
    this.renderer.setStyle(this.el.nativeElement, 'cursor', cursor || 'pointer')  // line 82 — ''→pointer
    this.cursorApplied = true
  } else if (this.cursorApplied) {                           // line 84
    // Only revert a cursor THIS directive applied; host's own styling stays untouched
    this.restoreHostCursor()                                 // line 86
  }
}

private restoreHostCursor(): void {                          // line 90
  if (this.hostCursor) {
    this.renderer.setStyle(this.el.nativeElement, 'cursor', this.hostCursor)
  } else {
    this.renderer.removeStyle(this.el.nativeElement, 'cursor')
  }
  this.cursorApplied = false
}
```

### The subtle parts (a new dev would miss these)
1. **`cursor !== null` is the only "hands-off" gate.** `null` is the *only* value that means "don't touch the cursor". `undefined` and `''` are **not** treated as hands-off — instead `cursor || 'pointer'` (line 82) makes both fall through to `pointer`. This is intentional and matches the spec exactly.
2. **`cursorApplied` = "did *I* set this cursor?"** This is the crux of *"only ever revert a cursor the directive applied itself."* If the host has `cursor: help` in its own CSS and the directive applies `default`, then when the tooltip is cleared the directive must put **`help` back**, not blindly `removeStyle`. `hostCursor` captures the host's pre-existing inline cursor **once** (guarded by `!this.cursorApplied`, line 79) so it can be restored later.
3. **`else if (this.cursorApplied)` guard (line 84)** prevents the restore path when the directive never applied a cursor → *"should not remove a host cursor it did not apply"* is true.
4. **Text change keeps the configured cursor** because `applyCursor()` re-applies `cursor || 'pointer'` every run, instead of a hard-coded `pointer` (the old bug).

### The v6-specific thing I verified: cursor-only change via the setter
Unlike v8/v9 (where I had to verify the `effect()` re-runs when only the cursor signal changes, since the cursor is read transitively inside `applyCursor()`), v6 is simpler and needs no such worry: changing `ocxTooltipCursor` **directly invokes the setter**, which **synchronously** calls `applyCursor()`. There is no dependency-tracking to get wrong. The tests `should apply a changed cursor value` (cursor `default`→`help`) and `should remove the cursor it applied when ocxTooltipCursor changes to null` (cursor `default`→`null`) both change only the cursor and assert the style changed — both **passed** in my local run (26/26). The reactivity is trivially correct here.

### Non-breaking proof
Default of `_ocxTooltipCursor` is `'pointer'` → with the input unset, `applyCursor()` sets `cursor: pointer`, identical to before. The public API only **adds** an input. Existing display/ID tests are untouched.

### Where the data-table change lands
`data-table.component.html:185` — the column-header label element (with `id="{{column.id}}-header-name"`, `class="flex"`) gets `ocxTooltipCursor="default"`. This satisfies the "column header labels use `cursor: default`" AC on this branch. The matching test queries `#${mockColumns[0].id}-header-name` and asserts `.style.cursor === 'default'` (`data-table.component.spec.ts:401-408`).

---

## 3. Test-case review (correctness + coverage)

**Verdict: tests are correct, well-scoped, and complete for the required behaviors including the edge cases. No test is written incorrectly.** One minor note (N1) is optional.

The new `TestHostComponentCursorComponent` host (spec line ~65–84) binds `[style.cursor]="hostCursor"`, `[ocxTooltip]="tooltipText"`, and `[ocxTooltipCursor]="cursor"`, plus `tooltipPosition="top"`. Defaults: `tooltipText = 'Tooltip with cursor'`, `cursor = 'default'`, `hostCursor = undefined`. It is declared in `TestBed` (spec line ~98) alongside the other hosts. The `setup()` helper creates the fixture, assigns props via `Object.assign`, runs `detectChanges()`, and returns the host element.

| Test (Cursor block) | What it proves | Required? |
|---|---|---|
| `apply cursor pointer by default` | Default behavior unchanged (uses `HOST_SELECTOR_1`, the main `TestHostComponent` with `tooltipText='Tooltip works!'`) | ✅ Must |
| `apply cursor pointer when ocxTooltipCursor is undefined` | `undefined` → pointer (distinct from `null`) | ✅ Good |
| `apply a custom cursor value` | A CSS value applied instead of pointer | ✅ Must |
| `expose the configured cursor` | **`directive.ocxTooltipCursor`** getter readable (default `pointer`, custom `default`) — **covers the v6-specific getter line (finding 1a)** | ✅ Must |
| `fall back to cursor pointer when empty string` | `''` → pointer edge case | ✅ Good |
| `not set an inline cursor when null` | `null` → no inline style (`''`) | ✅ Must |
| `keep the host cursor styling when null` | `null` + host cursor survives a text clear | ✅ Good |
| `keep the configured cursor when the tooltip text changes` | Text change doesn't reset to pointer | ✅ Must |
| `remove the configured cursor when text cleared, reapply when set again` | Clear/re-set cycle | ✅ Good |
| `restore the host cursor styling when the tooltip text is cleared` | The `cursorApplied`/`hostCursor` restore path | ✅ Must |
| `not remove a host cursor it did not apply when no tooltip text` | `else if (cursorApplied)` guard | ✅ Must |
| `apply a changed cursor value` | **cursor-only change re-runs the setter** | ✅ Must |
| `remove the cursor it applied when input changes to null` | **cursor-only change to `null`** restore | ✅ Must |
| `restore the host cursor styling when input changes to null` | cursor→null with a host cursor | ✅ Must |

- **Branch coverage = 100%** on `tooltip.directive.ts` (my local run), confirming every branch in `applyCursor`/`restoreHostCursor` and the getter is exercised.
- **Edge cases covered:** `undefined`, `''`, `null`, text change, text clear + re-set, restore-with-host-cursor (both the text-cleared path and the cursor→null path), no-tooltip-text, cursor change, cursor→null. Complete, not bloated.
- **Note N1 (nit, optional):** `should not set an inline cursor when ocxTooltipCursor is null` (`null → ''`) and `should keep the host cursor styling when ocxTooltipCursor is null` (null + host cursor) both exercise the `null` path — the former is a crisp `null → ''` assertion, the latter adds restore-on-clear. Keeping both is defensible; optional consolidation only.
- The data-table test (`data-table.component.spec.ts:401-408`, `should use the default cursor for column header labels with a tooltip`) uses v6's API correctly: `component.columns = [...]` (plain property) and queries the label by its `#<id>-header-name` attribute. It asserts on the real rendered header element. Correct.

---

## 4. Prior review comments — resolution status (verified against head code)

Reviewer `SchettlerKoehler` (on commit `f603fa3`) raised **1 finding with 2 sub-points**. Both were raised only as **discussion comments** — the PR has **0 inline (review) comments** (verified via `gh api .../pulls/1945/comments` → `inline_count = 0`).

> *Context for the reviewer's framing:* v6's Sonar gate was failing at **92.5%** new-code coverage (100% required). The reviewer's two sub-points are the two things pulling that below 100%: an **untested getter** (line 30 at the time) and **two unreachable branch conditions** in `style?.cursor ?? ''` (line 84 at the time).

| # | Sub-point | Severity | Status |
|---|---|---|---|
| 1a | Line 30: `ocxTooltipCursor` getter never called by a test (0 hits) — v6-specific | **Low** | ✅ **RESOLVED** |
| 1b | Line 84: 2 of 8 conditions in `style?.cursor ?? ''` uncovered → use `style.cursor` | **Low** | ✅ **RESOLVED** |

### 1a — Untested getter (v6-specific) — VERIFIED RESOLVED
The reviewer's exact fix request: *"add a test that reads the getter, for example `expect(directive.ocxTooltipCursor).toBe('pointer')` on the default host and `toBe('default')` on the cursor host."*

The test `should expose the configured cursor` now does exactly this:
```ts
const defaultDirective = fixture.debugElement.query(By.css(HOST_SELECTOR_1)).injector.get(OcxTooltipDirective)
const { cursorFixture } = setup({ cursor: 'default' })
const cursorDirective = cursorFixture.debugElement.query(By.css(HOST_SELECTOR_CURSOR)).injector.get(OcxTooltipDirective)

expect(defaultDirective.ocxTooltipCursor).toBe('pointer')   // ← reads the getter (no call — v6 property)
expect(cursorDirective.ocxTooltipCursor).toBe('default')
```
Note it uses `directive.ocxTooltipCursor` (**property access, no `()`**) — correct for v6's classic `@Input` getter. (On v8/v9 this is `directive.ocxTooltipCursor()` because it's a signal input.) The getter line is now hit by the tests, and my run shows the file at **100% Stmts/Branch/Funcs/Lines** — so the "0 hits" condition is gone. **Resolved.**

### 1b — `style?.cursor ?? ''` → `style.cursor` — VERIFIED RESOLVED
The head code at `tooltip.directive.ts:80` reads:
```ts
this.hostCursor = this.el.nativeElement.style.cursor
```
The optional chaining (`?.`) and nullish fallback (`?? ''`) are **gone** — exactly the fix the reviewer asked for. Rationale (reviewer's, confirmed correct): for an `HTMLElement` host, `style` always exists and `style.cursor` is always a string, so the two fallback branches were unreachable and counted against the 100% new-code-coverage gate (they were the "2 of 8 conditions" the reviewer flagged). The reviewer also asked this change be mirrored across #1942/#1943/#1944 — **all three already carry `style.cursor`** (confirmed in those reviews), so the branches are consistent across the whole family. **My local run: `tooltip.directive.ts` = 100% Stmts/Branch/Funcs/Lines** — matches the Sonar "100.0% Coverage on New Code, Quality Gate Passed" badge for `angular-accelerator`.

**No open inline comments** remain; the single discussion finding (both sub-points) is addressed and re-verified against the actual head source. The author's follow-up (2026-11-02) confirms: replacing `style?.cursor ?? ''` with `style.cursor`, adding the getter/value tests, and the restore-on-clear behavior.

---

## 5. Repo-standard conformance

- **API choice:** `@Input()` getter/setter is the **correct** approach for **v6** (Angular 19 / PrimeNG 19) — the v6 directive already used `@Input()` getter/setter for `ocxTooltip` before this PR (lines 9–18), so the new `ocxTooltipCursor` input matches the file's existing style exactly. The reviewer explicitly endorsed this ("swapping the signal `input()` for an `@Input()` getter/setter is the right way to do it on v6"). ✅
- **Input default:** backing field `_ocxTooltipCursor: string | null | undefined = 'pointer'` (line 41) — typed, with a default. Consistent with the sibling input. ✅
- **`Renderer2`** used for all style mutations (`setStyle`/`removeStyle`) — matches the rest of the directive. ✅
- **Docs (v6 = TSDoc only):** verified v6 has **no** `docs/modules/onecx-portal-ui-libs` module (only `contributions`/`general`), and no `tooltip.adoc` exists in the base. The "Documentation updated" AC is therefore satisfied by the **TSDoc** on `ocxTooltipCursor` (directive lines 23–34), which documents all four behaviors (default/`undefined`→pointer, CSS value, `''`→pointer fallback, `null`→hands-off, restore-on-clear). The PR body correctly states: *"v6 has no component documentation module, so the input is documented via TSDoc only."* ✅ — this is the correct, honest handling of a branch-specific constraint (v8/v9 additionally get an adoc page; v6 cannot).
- **Non-breaking:** confirmed (default `pointer`, additive input only). ✅
- **Lint:** `nx lint angular-accelerator` → **0 errors**, 24 warnings. I checked the warnings in the two changed spec files:
  - `data-table.component.spec.ts:791-793` — `@typescript-eslint/no-non-null-assertion` on `overflowMenu!.getAllMenuItems()` / `menuItems!` lines. These are **far from the PR's change region** (the new `describe('column header tooltips')` block is at lines 401–408) and I confirmed the same non-null assertions exist at the **base** commit (base line ~781). **Pre-existing, not a PR regression.**
  - `tooltip.directive.spec.ts` — no warnings. ✅
- **Trailing newline (nit N2):** `tooltip.directive.spec.ts` ends without a final newline (`\ No newline at end of file`). This is **pre-existing** — I confirmed the **base** file's last byte was `)` (no `\n`), and the diff only adds the new Cursor block before the same final `})`. There's no `eol-last` ESLint rule in effect. Pure style nit.

---

## 6. Before vs After (behavioral)

| Scenario (host with `ocxTooltip`) | **Before** (v6 base) | **After** (this PR) |
|---|---|---|
| No `ocxTooltipCursor`, text set | `cursor: pointer` (inline) | `cursor: pointer` (inline) — **unchanged** |
| `ocxTooltipCursor="default"`, text set | n/a | `cursor: default` |
| `ocxTooltipCursor="help"`, text set | n/a | `cursor: help` |
| `ocxTooltipCursor=""`, text set | n/a | `cursor: pointer` (fallback) |
| `ocxTooltipCursor=null`, text set | n/a | **no inline cursor** — host CSS wins |
| `null` + host `cursor: help` | n/a | stays `help` |
| Change tooltip text after configuring a cursor | reset to `pointer` (old bug) | **keeps the configured cursor** |
| **Change cursor input only** (text unchanged) | n/a | **setter fires; cursor updates** |
| Clear tooltip text | `removeStyle` — **wiped any host cursor** | restores the host's *previous* inline cursor (only if the directive applied one) |
| Host has own cursor, no tooltip text | directive did nothing | directive still does nothing |
| Data-table column header with tooltip | `pointer` (misleading hand) | `default` (normal arrow) |

Most user-visible: (a) column headers no longer show a "clickable" hand; (b) the directive no longer *deletes* a host's own cursor when a tooltip is cleared — it restores it; (c) changing the cursor input at runtime now works.

---

## 7. How the developer can test the change

**Unit tests (already run & passing in this review):**
```bash
# Tooltip directive (26 tests, 100% coverage on tooltip.directive.ts)
npx jest libs/angular-accelerator/src/lib/directives/tooltip.directive.spec.ts \
  --config libs/angular-accelerator/jest.config.ts

# Data table (97 tests, includes the new "default cursor for column header labels" test)
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
5. **Cursor change at runtime:** keep the tooltip text constant and change only `ocxTooltipCursor` (e.g. `default` → `null`); the cursor should update via the setter.
6. **Clear restores host cursor:** give the host its own `cursor: help`, set then clear the tooltip text; after clearing the host shows `help` again (not a wiped cursor).

---

## 8. Suggested PR comments

No blocking comments. Both prior findings are resolved and re-verified; Sonar gate passed; specs + lint clean. If the author wants a zero-risk tidy-up, these are the only nits (all optional). I would post one non-blocking "nit" comment and **approve**.

### (Nit, optional) N2 — `tooltip.directive.spec.ts` trailing newline
- **File / line:** `libs/angular-accelerator/src/lib/directives/tooltip.directive.spec.ts` — last line (`})`)
- **Suggested comment:**
  > Nit (non-blocking, and pre-existing): the spec file ends without a trailing newline. The base file already lacked one and there's no `eol-last` rule, so this isn't a standards breach — just flagging in case you'd like to add a final newline while you're here. Optional.

### (Nit, optional) N1 — redundant cursor test
- **File / line:** `libs/angular-accelerator/src/lib/directives/tooltip.directive.spec.ts` — `should not set an inline cursor when ocxTooltipCursor is null`
- **Suggested comment:**
  > Nit (non-blocking): this `null → ''` test overlaps the `null` + host-cursor test just below it. Keeping both is fine (this is a crisp unit assertion); just flagging in case you'd prefer to consolidate. No change required.

### (Info, not a change) — v6-specific items confirmed correct
No change needed, but worth a short acknowledgment so the v6-specific choices don't get mis-read as drift from the sibling PRs:
  > Confirmed correct for v6: (1) `ocxTooltipCursor` is a classic `@Input()` getter/setter (not a signal) — matching this branch's existing `ocxTooltip` input; (2) the getter is tested via `directive.ocxTooltipCursor` (no call) to satisfy the v6-only Sonar coverage on that line; (3) documentation is TSDoc-only because v6 has no `onecx-portal-ui-libs` docs module; (4) the data-table test uses `component.columns = [...]` and the `#<id>-header-name` selector, matching v6's component API.

---

## 9. Overall assessment & final recommendation

This is a **well-executed, minimal, non-breaking backport** on the classic `@Input()` API:
- Precisely implements every acceptance criterion,
- Introduces the same clean single-path cursor manager as the sibling PRs, with correct "only revert what I set" semantics,
- Correctly uses `@Input()` getter/setter for v6 (both setters funnel through `applyCursor()`; no ordering hazard),
- Documents via TSDoc (the correct handling given v6 has no docs module),
- Includes the in-scope data-table `ocxTooltipCursor="default"` change with a matching test using v6's component API,
- Has thorough, correctly-written tests at 100% coverage,
- Resolves the single prior review finding (both sub-points, verified against head code) and passes the Sonar quality gate (100.0% new-code coverage on `angular-accelerator`),
- Keeps lint clean.

**Recommendation: ✅ Approve.** No requested-changes or reject triggers. The two nits (N1, N2) are optional polish and don't gate merge.

*Cross-branch note (final of the family):* the reviewer asked that the `style.cursor` simplification and the restore-on-clear behavior be mirrored across all siblings. Status of the whole family:
- **#1942 (v9/main)** — carries both ✅
- **#1944 (v7)** — carries both ✅
- **#1943 (v8)** — carries both ✅
- **#1945 (v6)** — carries both ✅ (this review)

All four backports are consistent. The family is complete and aligned.
