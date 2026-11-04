# PR Review — onecx/onecx-portal-ui-libs #1944

- **Issue:** [onecx/internal-tasks#1266](https://github.com/onecx/internal-tasks/issues/1266) — *OcxTooltipDirective: make the host cursor style configurable*
- **PR:** [onecx/onecx-portal-ui-libs#1944](https://github.com/onecx/onecx-portal-ui-libs/pull/1944) — *fix: make OcxTooltipDirective host cursor configurable (v7)*
- **Branch:** `fix/v7-tooltip-cursor` (local checkout matches `origin/fix/v7-tooltip-cursor`)
- **Reviewed at commit:** `05da6dbf` (2 commits: `9239d7cf` + `05da6dbf`)
- **Author:** bastianjakobi
- **Date:** 2026-11-03
- **Reviewer:** AI review (Claude Code)

---

## TL;DR / Verdict

**✅ APPROVE (Request Changes = none required).** The PR fully implements the story, is non-breaking, passes the new directive + data-table specs, hits 100% line/branch coverage on the changed file (Sonar quality gate is now green), and lint is clean. Both reviewer comments from the prior round are fully resolved. The only observations are two **nit / optional** polish items (a missing trailing newline in one doc file, and one redundant test) — neither blocks the PR.

| Check | Result |
|---|---|
| Issue story implemented | ✅ Yes — all 4 acceptance criteria met |
| Non-breaking (default behavior / API / existing tests) | ✅ Yes |
| Directive spec passes | ✅ 26/26 passed |
| Data-table spec passes | ✅ Passed (incl. new cursor test) |
| Coverage on `tooltip.directive.ts` | ✅ 100% statements / branches / functions / lines |
| Lint (`nx lint angular-accelerator`) | ✅ 0 errors (24 pre-existing warnings in *other* files, none in PR files) |
| Prior review comments resolved | ✅ Both resolved (verified) |
| Sonar quality gate | ✅ Passed (100% new-code coverage) |

---

## 1. The story, in plain terms (for a dev new to this repo)

### What the problem was
`OcxTooltipDirective` (the `ocxTooltip` directive in `@onecx/angular-accelerator`) **always** forced `cursor: pointer` onto the element it is attached to, whenever a tooltip text was set. The old code did this inside the `ocxTooltip` setter:

```ts
// BEFORE (v7 base, commit d7ab0512)
set ocxTooltip(value) {
  this.content = value
  this.setOption({ tooltipLabel: value })
  this.ensureIdAndAriaDescribedBy()
  if (value) {
    this.renderer.setStyle(this.el.nativeElement, 'cursor', 'pointer')
  } else {
    this.renderer.removeStyle(this.el.nativeElement, 'cursor')
  }
}
```

`pointer` (the little hand 🖱️) is a UI signal meaning *"you can click me"*. But the directive is also put on **non-clickable** things — data-table column headers, page-header labels, diagram items, etc. On those, a hand cursor is **misleading** (users expect nothing to happen on click). Because it was applied as an **inline** style, consumers couldn't override it without `!important`.

This was a real bug with an **a11y / UX** angle (the issue is labelled `bug` + `a11y`), discovered while reviewing PR #1827 (tooltips on data-table column headers).

### What the fix asks for
Add an **optional input** `ocxTooltipCursor` so the consumer chooses the cursor:
- **Not set / `undefined`** → keep today's behavior (`pointer`). *(must be non-breaking)*
- **A CSS cursor value** (e.g. `default`, `help`) → apply that instead.
- **`null`** → don't touch the cursor at all; the host's own CSS wins.
- Changing the tooltip **text** must not lose the configured cursor (the old setter re-applied `pointer` on every change).
- And: data-table column-header labels that have a tooltip should use `cursor: default`.

### How the fix works (the "why/what/where/how")

**Where:** `libs/angular-accelerator/src/lib/directives/tooltip.directive.ts`.

The setter no longer hard-codes `pointer`. It calls a new private `applyCursor()`:

```ts
// AFTER (this PR)
set ocxTooltip(value) {
  this.content = value
  this.setOption({ tooltipLabel: value })
  this.ensureIdAndAriaDescribedBy()
  this.applyCursor()          // <-- changed: was the if/else pointer/removeStyle
}

@Input()
get ocxTooltipCursor(): string | null | undefined { return this._ocxTooltipCursor }
set ocxTooltipCursor(value: string | null | undefined) {
  this._ocxTooltipCursor = value
  this.applyCursor()
}

private _ocxTooltipCursor: string | null | undefined = 'pointer'  // default keeps old behavior
private cursorApplied = false
private hostCursor = ''

private applyCursor(): void {
  const cursor = this._ocxTooltipCursor
  if (cursor !== null && this.content) {
    if (!this.cursorApplied) {
      this.hostCursor = this.el.nativeElement.style.cursor  // remember the host's original once
    }
    this.renderer.setStyle(this.el.nativeElement, 'cursor', cursor || 'pointer') // '' falls back to pointer
    this.cursorApplied = true
  } else if (this.cursorApplied) {
    // Only revert a cursor THIS directive applied; host's own styling is left untouched
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

**Why this shape (the subtle parts a new dev would miss):**

1. **`cursor !== null` is the key discriminator.** `null` is the only value that means *"don't touch the cursor"*. `undefined` and `''` are **not** special-cased as "don't touch" — instead `cursor || 'pointer'` makes both fall through to `pointer`. This is intentional and matches the spec: only `null` defers to the host.

2. **`cursorApplied` flag = "did *I* set this cursor?"** This is the crux of the "only ever revert a cursor the directive applied itself" rule. If the host had `cursor: help` set via its own styles and the directive applies `default`, then when the tooltip is cleared the directive must put **`help` back** — not just blindly `removeStyle`. The `hostCursor` field captures the host's pre-existing inline cursor *once* (guarded by `!this.cursorApplied`) so it can be restored later.

3. **The `else if (this.cursorApplied)` guard** prevents the restore path from running when the directive never applied a cursor. That's what makes *"should not remove a host cursor it did not apply"* true — if the tooltip text is empty from the start, the directive does nothing to the host cursor.

4. **Changing tooltip text keeps the configured cursor** because `applyCursor()` re-applies `cursor || 'pointer'` every time, rather than re-applying a hard-coded `pointer` (the old bug).

5. **Both the `ocxTooltip` setter and the `ocxTooltipCursor` setter funnel through `applyCursor()`**, so the cursor stays consistent no matter which input changes — and they share one code path for the restore logic (this was a direct response to the reviewer note).

**Non-breaking proof:** the default of `_ocxTooltipCursor` is `'pointer'`, so with the input unset, `applyCursor()` sets `cursor: pointer` exactly as before. The public API only *adds* an input; nothing existing is removed. The pre-existing display/ID tests are untouched.

**Where the data-table change lands:** `data-table.component.html:311-312` — the column-header label `<span>` gets `ocxTooltipCursor="default"`, so headers with a tooltip show the normal arrow cursor instead of a hand. (v7 is the *only* branch where the column header already has a tooltip; main/v8 don't have #1827/#1940 merged yet — that's why the AC only applies on this branch.)

---

## 2. File-by-file review

### `tooltip.directive.ts` (+50 / −6) — core
- **Correct.** Logic matches the story's three-state model exactly.
- Reviewer items already addressed (see §4): `style?.cursor ?? ''` → `style.cursor` (line 80), and the getter is now exercised by a test.
- TSDoc (lines 20-30) accurately describes all four states + the restore behavior.
- Minor nit (nit, non-blocking): see §5, item N1/N2.

### `tooltip.directive.spec.ts` (+152 / −1)
- New `TestHostComponentCursorComponent` host with a `[style.cursor]="hostCursor"` binding so tests can simulate a host that already carries an inline cursor.
- New `describe('Cursor')` block with **14 tests** covering every documented behavior (see §3).
- Existing tests untouched. 26/26 pass.

### `data-table.component.html` (+1)
- Adds `ocxTooltipCursor="default"` to the column-header label. Correct and minimal.

### `data-table.component.spec.ts` (+7)
- New test `should use the default cursor for column header labels with a tooltip` — directly asserts the acceptance criterion. Correct.

### `docs/.../directives/tooltip.adoc` (+39, new) + `nav.adoc` (+3)
- New "OcxTooltip" directive page + nav entry. Documentation is **good** and complete (inputs table with the cursor state, a dedicated Cursor section with two worked examples, and the data-table note). Satisfies the "Documentation updated" AC.
- Nit: `nav.adoc` loses its trailing newline (`\ No newline at end of file`). See §5, N3.

---

## 3. Test-case review (correctness + coverage)

**Verdict: tests are correct, well-scoped, and cover all the necessary cases including the edge cases. No test is written incorrectly.** There is one arguably-redundant test (N2) but it is harmless.

Mapping of the "Cursor" spec block to the story requirements:

| Test (spec line) | What it proves | Required? |
|---|---|---|
| `apply cursor pointer by default` (338) | Default behavior unchanged (uses `HOST_SELECTOR_1`, no cursor input) | ✅ Must (AC + non-breaking) |
| `apply cursor pointer when ocxTooltipCursor is undefined` (344) | `undefined` ≠ `null` | ✅ Good |
| `apply a custom cursor value` (350) | A CSS value is applied instead of pointer | ✅ Must (AC) |
| `expose the configured cursor` (356) | **Getter** is readable (covers the Sonar getter line) | ✅ Must (quality gate) |
| `fall back to cursor pointer when empty string` (365) | `''` → pointer edge case | ✅ Good |
| `not set an inline cursor when null` (371) | `null` → no inline style | ✅ Must (AC) |
| `keep the host cursor styling when null` (377) | `null` + host cursor survives a text clear | ✅ Good |
| `keep the configured cursor when text changes` (388) | Text change doesn't reset to pointer | ✅ Must (AC) |
| `remove configured cursor when text cleared, reapply when set again` (397) | Clear/re-set cycle | ✅ Good |
| `restore the host cursor styling when text is cleared` (411) | Restore logic (the `cursorApplied`/`hostCursor` path) | ✅ Must |
| `not remove a host cursor it did not apply when no tooltip text` (422) | `else if (cursorApplied)` guard | ✅ Must |
| `apply a changed cursor value` (428) | Input change re-applies | ✅ Good |
| `remove the cursor it applied when input changes to null` (437) | Input→null restore | ✅ Good |
| `restore the host cursor styling when input changes to null` (446) | Input→null with host cursor | ✅ Must |

- **Branch coverage = 100%**, which confirms every branch in `applyCursor`/`restoreHostCursor` is exercised.
- **Edge cases covered:** `undefined`, `''`, `null`, text change, text clear + re-set, restore-with-host-cursor, no-tooltip-text, input change, input→null. This is a *complete* (not bloated) set — good balance.
- **No incorrect tests found.** One observation (not a defect):
  - **N2:** `should not set an inline cursor when ocxTooltipCursor is null` (line 371, asserts `host.style.cursor === ''`) and `should keep the host cursor styling when ocxTooltipCursor is null` (line 377) overlap somewhat — the first is a simpler form of the second. Keeping both is defensible (the first is a crisp "null → empty" unit assertion, the second adds the restore-on-clear behavior), so this is **optional** consolidation, not a required change.

The data-table test correctly mirrors the acceptance criterion and asserts on the real rendered `.column-header-label` element via the existing `getLabel()` helper (spec line 255) — consistent with the surrounding tests.

---

## 4. Prior review comments — resolution status (checked)

### Comment 1 — `SchettlerKoehler` (2026-11-02, on commit `9239d7c`)
Two Sonar blockers on `tooltip.directive.ts`:
1. **Line 30 — getter never read by a test.** → **RESOLVED.** The `should expose the configured cursor` test (spec line 356-362) now asserts `directive.ocxTooltipCursor` for both the default (`'pointer'`) and a custom (`'default'`) value. Getter is covered; 100% coverage confirmed.
2. **Line 84 — unreachable `style?.cursor ?? ''`.** → **RESOLVED.** Current code is `this.hostCursor = this.el.nativeElement.style.cursor` (line 80) — the optional chaining + nullish fallback is gone.

### Comment 2 — `bastianjakobi` (author, 2026-11-02) — self-attestation of the fix
Claims (all verified against the working tree + a test run):
- "Clearing the tooltip text restores the host's previous inline cursor; never removes a cursor it didn't apply." → **Verified** (`restoreHostCursor` + `else if (cursorApplied)`).
- "Replaced `style?.cursor ?? ''` with `style.cursor`." → **Verified** (line 80).
- "New tests cover empty-string fallback, value/getter, restore-on-clear, leave-host-alone." → **Verified** (tests at lines 365, 356, 411, 422).
- "Locally, `tooltip.directive.ts` is now at 100% line and branch coverage." → **Verified**: my run reports 100% statements/branches/functions/lines for that file.
- "The PR body says `Part of` instead of `Fixes`." → **Verified**: PR body reads "Part of ...#1266 (`v7`)" — correct, because the story spans multiple backport PRs and this one alone shouldn't auto-close the umbrella issue.

### Comment 3 — `sonarqubecloud`
**Quality Gate PASSED** — 0 new issues, 0 security hotspots, **100.0% coverage on new code**, 0% duplication. This is the gate that was failing (93.0%) on the first commit; it now passes.

**No open inline comments** remain on the PR (`pr1944-inline-comments.json` is empty; all feedback was in the discussion thread and has been addressed in commit `05da6dbf`).

---

## 5. Repo-standard conformance

- **Naming / style:** `ocxTooltipCursor` follows the existing `ocxTooltip` prefix convention; `string | null | undefined` typed input; `Renderer2` used for style mutation (consistent with the rest of the directive). ✅
- **API pattern:** `@Input()` getter/setter pair matches the sibling `ocxTooltip` input exactly. ✅
- **Docs:** new page added under the correct module with a proper nav entry and matches the AsciiDoc conventions of the neighboring pages. ✅
- **Non-breaking:** confirmed. ✅
- **Lint:** `nx lint angular-accelerator` → **0 errors**. The 24 warnings are all pre-existing in *unrelated* files (e.g. `interactive-data-view.component.spec.ts:1285`, `page-header.component.ts:286`), **none in the PR's changed files**. ✅
- **Trailing newline (nit N3):** `docs/.../partials/nav.adoc` and `tooltip.directive.spec.ts` end without a final newline. Note this is **not a hard repo violation** — several existing `.adoc` files (`column-type.adoc`, `topic.adoc`, `app-state-service-note.adoc`) and the base `nav.adoc`/spec also lack trailing newlines, and no `eol-last` ESLint rule is configured. So it's a pure style nit, not a standards breach. Still worth a one-line tidy-up (see N3).

---

## 6. Before vs After (what changed, behaviorally)

| Scenario (host element with `ocxTooltip`) | **Before** (v7 base) | **After** (this PR) |
|---|---|---|
| No `ocxTooltipCursor`, tooltip text set | `cursor: pointer` (inline) | `cursor: pointer` (inline) — **unchanged** |
| `ocxTooltipCursor="default"`, text set | n/a | `cursor: default` (inline) |
| `ocxTooltipCursor="help"`, text set | n/a | `cursor: help` (inline) |
| `ocxTooltipCursor=""` (empty string), text set | n/a | `cursor: pointer` (falls back) |
| `ocxTooltipCursor=null`, text set | n/a | **no inline cursor set** — host CSS wins |
| `ocxTooltipCursor=null`, host already has `cursor: help` | n/a | stays `help` |
| Change tooltip text after configuring a cursor | resets to `pointer` (the old bug) | **keeps the configured cursor** |
| Clear tooltip text | `removeStyle('cursor')` — **wipes any host cursor too** | restores the host's *previous* inline cursor (only if the directive had applied one) |
| Host has its own `cursor`, no tooltip text | directive did nothing | directive still does nothing (never touches a cursor it didn't set) |
| Data-table column header with tooltip | `cursor: pointer` (misleading hand) | `cursor: default` (normal arrow) |

The most user-visible fixes: (a) column headers no longer show a "clickable" hand, and (b) the directive no longer *deletes* a host's own cursor when a tooltip is cleared — it restores it.

---

## 7. How the developer can test the change

**Unit tests (already run & passing in this review):**
```bash
# Tooltip directive (26 tests, 100% coverage on tooltip.directive.ts)
npx jest libs/angular-accelerator/src/lib/directives/tooltip.directive.spec.ts \
  --config libs/angular-accelerator/jest.config.ts

# Data table (includes the new "default cursor for column header labels" test)
npx jest libs/angular-accelerator/src/lib/components/data-table/data-table.component.spec.ts \
  --config libs/angular-accelerator/jest.config.ts
```

**Lint:**
```bash
npx nx lint angular-accelerator     # 0 errors
```

**Manual / visual (in an app consuming the lib):**
1. **Default (non-breaking check):** any existing `[ocxTooltip]` element (e.g. a button) should still show the hand 🖱️ cursor on hover. Behavior is identical to before the change.
2. **`default` cursor:** a tooltiped element with `ocxTooltipCursor="default"` should show the normal arrow I-beam cursor, not a hand. The **data-table column header** is the concrete in-product case — hover a column header that has a tooltip; the cursor should be the arrow. (Matches the note in `note.md`: *not applied → pointer; applied as default → arrow*.)
3. **`null`:** a tooltiped element with `ocxTooltipCursor="null"` should inherit whatever cursor the host's own CSS defines — the directive should not force a cursor.
4. **Text change keeps cursor:** bind the tooltip text to a variable, toggle the text while `ocxTooltipCursor="default"` is set; the cursor must stay `default` (not snap back to `pointer`).
5. **Clear restores host cursor:** give the host its own `cursor: help` in CSS, set then clear the tooltip text; after clearing, the host should show `help` again (not a wiped cursor).

---

## 8. Suggested PR comments

No blocking comments. If the author wants a tidy, zero-risk finish, these two are the only nits (both optional). I would post them as a single non-blocking "nit" comment and approve.

### (Nit, optional) N3 — `nav.adoc` trailing newline
- **File / line:** `docs/modules/onecx-portal-ui-libs/partials/nav.adoc` — last line (`*** xref:...directives/tooltip.adoc[OcxTooltip]`)
- **Suggested comment:**
  > Nit (non-blocking): the nav file lost its trailing newline (`\ No newline at end of file`). A few other `.adoc` files in the repo also omit it and there's no `eol-last` lint rule, so it's not a standards breach — but it's cleaner to end with a newline (avoids a merge-adjacent diff artifact). Same goes for the end of `tooltip.directive.spec.ts`. Optional.

### (Nit, optional) N2 — redundant cursor test
- **File / line:** `libs/angular-accelerator/src/lib/directives/tooltip.directive.spec.ts:371`
- **Suggested comment:**
  > Nit (non-blocking): `should not set an inline cursor when ocxTooltipCursor is null` overlaps with the `null` + host-cursor test below it. Keeping both is fine (this one is a crisp `null → ''` assertion); just flagging in case you'd prefer to consolidate. No change required.

### (Optional) N1 — `tooltip.directive.ts` trailing newline
- The file ends without a final newline (base did too — `}` is byte 0x7d). Pre-existing; not worth a comment on its own. If N3 is addressed, folding this in is free.

---

## 9. Overall assessment & final recommendation

This is a **well-executed, minimal, non-breaking fix** that:
- Precisely implements every acceptance criterion of the story,
- Introduces a clean single-path cursor manager with correct "only revert what I set" semantics,
- Ships complete documentation,
- Has thorough (and correctly written) tests at 100% coverage on the changed file,
- Resolves every prior review comment and now passes the Sonar quality gate,
- Keeps lint clean.

**Recommendation: ✅ Approve.** No requested-changes or reject triggers. The two nits (N2, N3) are optional polish and do not need to gate merge.

*Note for the backport author:* the reviewer (`SchettlerKoehler`) asked that the `style.cursor` simplification (comment #1 item 2) be mirrored in the sibling backports **#1942 (main), #1943 (v8), #1945 (v6)** to keep them aligned — that is an action on those PRs, not on this one, which already carries the fix.
