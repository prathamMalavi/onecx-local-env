# 1265 — Header (`<th>`) is focusable from v8 onwards

- **Issue:** [onecx/internal-tasks#1265](https://github.com/onecx/internal-tasks/issues/1265)
- **Repo:** `onecx-portal-ui-libs`
- **Version under investigation:** v8 = `8.9.0` (branch `v8`, PrimeNG `21.1.3`)
- **Reference version:** v7 (PrimeNG `20.4.0`)
- **Component:** `libs/angular-accelerator/src/lib/components/data-table/data-table.component`
- **Status:** Investigated — root cause confirmed. Fix approach awaiting product/a11y decision (see §7). No code changed yet.

---

## 1. What the report says

> Until v7 the table header cell (`<th>`) was **not** keyboard-focusable. From v8 onwards it **is** focusable — even though "we don't apply anything."
> Because of this, on **v8** the Tab key stops **twice** on a column header: **first on the header `<th>`, then on the filter / sort button inside it**. On **v7** it stopped **only once** (directly on the filter / sort button).
> **Is this a bug?**

DOM evidence provided by the reporter:

| | v7 `<th>` | v8 `<th>` |
|---|---|---|
| attributes | `scope="col"` only | `role="columnheader" scope="col" tabindex="0" aria-sort="none" class="p-datatable-sortable-column"` |
| focusable? | **No** | **Yes** (`tabindex="0"`) |

---

## 2. Is the issue real? (reproduction)

**Yes — the issue is real and fully explained.** The v8 `<th>` carries `tabindex="0"`, which puts the header cell on the tab order. The inner filter control (`<p-multiselect>` hidden input) and/or the sort `<button>` are *also* focusable, so a keyboard user hits **two** tab stops in the same column header.

### How to reproduce (browser, visual)
1. Build/serve a page that renders `<ocx-data-table>` with at least one **sortable or filterable** column (any story in `data-table.component.stories.ts` qualifies).
2. Click into the table area, then press **Tab** until you reach the header row.
3. **v8:** the **first** Tab lands a focus ring on the **header cell** (`<th>`, `class="p-datatable-sortable-column"`). The **next** Tab lands on the **filter** control (or the sort button). → **two stops.**
4. **v7:** the first Tab goes **straight to the filter/sort control** — the `<th>` itself is skipped. → **one stop.**

### How to reproduce (DOM / logs)
- Open DevTools and inspect a sortable column header.
  - **v8:** `<th role="columnheader" tabindex="0" aria-sort="none" class="p-datatable-sortable-column" ...>`
  - **v7:** `<th scope="col" ...>` (no `role`, no `tabindex`, no `aria-sort`).
- In the console: `document.querySelectorAll('th.p-datatable-sortable-column[tabindex="0"]').length` → **≥ 1 on v8, 0 on v7**.
- `console.trace` is not needed — this is purely DOM/tab-order behaviour, no app failure or error is thrown. There is **no runtime error**; the "double focus" is a UX/a11y side effect.

### Why it looks like "we don't apply anything"
We *do* apply it, but implicitly, via a PrimeNG directive attribute on the `<th>` (see §4). It's a one-line template change that isn't visually obvious.

---

## 3. Where the change came from (git history)

The `<th>` became focusable in a single, deliberate commit:

```
c51a16012  fix: a11y for table (#1345)   by priyankaSandeepRade  (Tue Apr 21 2026)
```

That commit is the **only** place `[pSortableColumn]` was introduced on the data-table header (confirmed via `git log -S 'pSortableColumn'`). Its diff to `data-table.component.html`:

- Added `scope="col"` to expansion / action / selection headers.
- Added **screen-reader-only** labels: `<span class="sr-only">` for the expansion, selection columns.
- Added `aria-expanded` / `aria-controls` to the row expand/collapse button.
- Added a `<caption>` template.
- **Added `[pSortableColumn]` to the sortable/filterable `<th>`:**
  ```html
  - <th scope="col">
  + <th scope="col" [pSortableColumn]="column.sortable ? column.nameKey : undefined">
  ```
- Later, commit `ea5d43157 feat: v8 custom column header (#1491) (#1504)` refactored the header into a "custom column header" branch but **kept** `[pSortableColumn]` (now bound to `column.id` on the custom-header path). Current v8 template applies it on **both** header paths:

  ```
  line 180:  <th scope="col" [pSortableColumn]="column.sortable ? column.id : undefined">
  line 188:  <th scope="col" [pSortableColumn]="column.sortable ? column.nameKey : undefined">
  ```

**Conclusion:** the focusable header is an **intentional accessibility improvement** (making the column header a real, focusable `role="columnheader"` control), not an accidental regression. Whether the *double* tab stop is acceptable is a product/a11y call (see §7).

---

## 4. Root cause — the exact mechanism

The `role` / `tabindex` / `aria-sort` on the `<th>` are **not** written by our code. They are injected by PrimeNG's **`[pSortableColumn]` directive** (`SortableColumn`), whose host bindings (PrimeNG `21.1.3`, `node_modules/primeng/fesm2022/primeng-table.mjs`) are:

```js
host: {
  attributes: { role: "columnheader" },
  listeners:  { click: "onClick($event)", "keydown.space": "onEnterKey($event)", "keydown.enter": "onEnterKey($event)" },
  properties: {
    class: "cx('sortableColumn')",            // → class="p-datatable-sortable-column"
    tabindex: "isEnabled() ? \"0\" : null",   // → tabindex="0"  ← makes the <th> focusable
    "attr.aria-sort": "sortOrder"             // → aria-sort="none"/"ascending"/"descending"
  }
}
```

So **any `<th>` that carries `[pSortableColumn]` becomes `role="columnheader" tabindex="0" aria-sort=…`**. That is precisely the v8 DOM the reporter saw.

### Does the directive exist in v7 / PrimeNG 17 / 19?
**Yes — in all of them.** The `[pSortableColumn]` directive and its `tabindex`/`role`/`aria-sort` host bindings are present in:

| PrimeNG version | `pSortableColumn` | `tabindex` | `role="columnheader"` | `aria-sort` |
|---|---|---|---|---|
| 17.0.0 | ✅ | ✅ | ✅ | ✅ |
| 19.0.0 | ✅ | ✅ (`[attr.tabindex]: isEnabled() ? "0" : null`) | ✅ | ✅ |
| 20.4.0 (v7's installed) | ✅ | ✅ | ✅ | ✅ |
| 21.1.3 (v8's installed) | ✅ | ✅ | ✅ | ✅ |

So the directive is available in v7's PrimeNG too — **v7 simply never puts it on the `<th>`**, which is the sole reason v7's header isn't focusable.

### An important subtlety: does the focusable header actually *do* anything?
Mostly **no, in this component.** PrimeNG's `SortableColumn` is enabled by default (`isEnabled()` → `pSortableColumnDisabled !== true`). When enabled, its `onClick` / `onEnterKey` call PrimeNG's **internal** `dataTable.sort({ field })`.

But this data-table component **does not use PrimeNG's internal sorting at all:**
- The `<p-table>` has **no** `sortField`, `sortOrder`, or `(onSort)` binding (grep-confirmed in the template).
- Sorting is driven **entirely by the inner sort `<button>`** → `(click)="onSortColumnClick(column.id)"` (data-table.component.ts:646), which updates the component's own `sortColumn`/`sortDirection` signals and its own sort pipeline.

Consequences:
1. Clicking the focusable `<th>` **does not sort** (PrimeNG internal sort is disconnected from our pipeline). Only the inner button sorts.
2. The `aria-sort` attribute is **stuck at `"none"`** (PrimeNG reads its own un-set `sortField`, which is never set). So the header advertises `aria-sort="none"` even after the user sorts via the button — a minor a11y inaccuracy.
3. **The `tabindex="0"` is the only thing that matters here** — it adds the extra tab stop but the header performs no sort action of its own. This is the crux of the "double focus" the reporter sees.

---

## 5. Why the double focus happens (DOM order)

Within one sortable+filterable header cell the tab order is:

```
<th role="columnheader" tabindex="0">          ← STOP 1 (v8 only)
   <span>Product</span>
   <p-multiselect><input role="combobox" tabindex="0">   ← STOP 2 (filter)
   <button class="sortButton">                              ← STOP 2' (sort, if no filter)
</th>
```

- **v7:** the `<th>` has no `tabindex`, so the first Tab lands directly on the inner filter input / sort button (one stop).
- **v8:** the `<th>` itself is a tab stop, so Tab lands on it *first*, then on the inner control (two stops).

Note: `aria-sort="none"` + a non-functional click on the header means Stop 1 is **focus with no associated action** — a classic "focusable but non-interactive" a11y smell.

---

## 6. Files involved

| File | Role |
|---|---|
| `libs/angular-accelerator/src/lib/components/data-table/data-table.component.html` | **The change.** `[pSortableColumn]` on the header `<th>` (lines 180, 188). Also the `#columnHeaderSortButton` / `#columnHeaderFilter` templates that provide the inner controls. |
| `libs/angular-accelerator/src/lib/components/data-table/data-table.component.ts` | `onSortColumnClick` / `columnNextSortDirection` / `sortColumn` / `sortDirection` — the *real* sort pipeline (PrimeNG-independent). Not the source of the focus. |
| `libs/angular-accelerator/src/lib/components/data-table/data-table.component.scss` | `.sr-only` class; `:focus-within` styling for the multiselect. No rule removes focusability from the `<th>`. |
| `node_modules/primeng/fesm2022/primeng-table.mjs` | PrimeNG `SortableColumn` directive — the source of `role`/`tabindex`/`aria-sort`. (Not ours to edit.) |
| `libs/angular-accelerator/src/lib/components/data-table/data-table.component.spec.ts` | **No** existing coverage of header `tabindex`/`role`/`aria-sort`/focus (grep-confirmed). A new a11y test belongs here. |
| `libs/angular-accelerator/testing/data-table.harness.ts` | `DataTableHarness` — test helper. Provides `locatorForAll(selector)()` returning `TestElement`s (`.getAttribute`, `.getProperty`, `.hasClass`). New assertions should follow this idiom. |

---

## 7. Is it a bug? & fix approaches

**Verdict:** It is **not a defect** — the focusable `<th>` is an intentional a11y improvement from PR #1345. The *double* tab stop is a **legitimate a11y trade-off**, not a crash. The decision is a product/a11y one: **do we want a keyboard user to tab through the header cell itself before reaching the inner controls?**

Three coherent options:

### Option A — Keep v8 as-is (no change) ✅ *recommended as the safe default*
- The `<th role="columnheader" tabindex="0">` is the **standard PrimeNG accessible-table pattern** (exposed column header on the tab order). Removing it regresses the a11y work that #1345 deliberately added.
- The "double stop" is the cost of having a real, announced column-header control. Most accessible-data-table patterns do exactly this.
- If we keep it, the **correct follow-up** is to make the header *genuinely* interactive so Stop 1 isn't a dead stop:
  - Wire the component's sort pipeline to PrimeNG's sort so clicking/Enter/Space on the header actually sorts (bind `(onSort)` on `<p-table>`, or have `onSortColumnClick` also update PrimeNG state), and set the real `sortField`/`sortOrder` so `aria-sort` reflects the actual state.
- **Risk:** lowest (no behavioural change). **Effort:** ~0 for "keep"; +1–2 days if we also wire real sorting.

### Option B — Remove the header tab stop (revert to v7 single-stop), keep the ARIA roles
- Replace `[pSortableColumn]` with **explicit attributes only**, so we keep the semantics (`role="columnheader"`, `aria-sort`, sortable class) but drop `tabindex`:
  ```html
  <th
    scope="col"
    role="columnheader"
    [attr.aria-sort]="sortColumn() === column.id ? (sortDirection() === 'ASCENDING' ? 'ascending' : 'descending') : 'none'"
    [class.p-datatable-sortable-column]="column.sortable"
  >
  ```
- Tab now goes straight to the inner control (restores v7 single-stop), but the header still exposes `role="columnheader"` and a *correct* `aria-sort` (computed from our real `sortColumn`/`sortDirection` signals — fixing the `aria-sort="none"` inaccuracy from §4).
- This is the **most surgical** way to eliminate the double focus while keeping screen-reader value.
- **Risk:** medium — a keyboard user loses the ability to focus/sort the column from the header cell directly; a11y reviewers may push back. **Effort:** ~0.5 day + 1 spec.

### Option C — Make the header the single primary control (consolidate to one stop)
- Give the `<th>` `[pSortableColumn]` (keep focus + sort) and **remove `tabindex` from the inner controls** (or make the inner sort button non-focusable when the header is the accessible sort target), so the header cell is the *only* tab stop and it performs the sort.
- Larger behavioural change; interacts with the filter multiselect (which must stay focusable). **Risk:** highest (could hurt filter keyboard access). **Effort:** 2–3 days.

### Recommendation
**Option A (keep as-is)** is the safest and aligns with the deliberate #1345 a11y work. If the product owner's real complaint is "an extra, useless tab stop," **Option B** is the cleanest targeted fix and also corrects the `aria-sort` inaccuracy. I recommend we confirm intent with the reporter/product before changing anything.

---

## 8. Proposed test (whichever option we pick)

New spec file scope (never run the whole suite — run this exact file):

```bash
npx jest libs/angular-accelerator/src/lib/components/data-table/data-table.component.spec.ts \
  --config libs/angular-accelerator/jest.config.ts
```

Suggested assertion (using the existing `DataTableHarness` idiom — `locatorForAll(selector)()` → `TestElement`):
- **Option A:** for a sortable column, the header `<th>` has `role="columnheader"` and `tabindex="0"`, and `aria-sort` reflects the real sort state after a sort.
- **Option B:** the header `<th>` has `role="columnheader"` and a correct `aria-sort`, but **no** `tabindex`; the inner filter input / sort button is the first focusable element in the header.

Harness helper to add (mirrors existing `getActionColumnHeader`):
```ts
// data-table.harness.ts
getColumnHeader(columnId: string): TestElementLocator {
  return this.locatorFor(`th[scope="col"] #${columnId}-header-name`)  // or a stable selector
}
```

---

## 8B. Option B — detailed investigation ("drop the header tab-stop, keep ARIA + fix aria-sort")

**Goal:** restore the v7 single tab stop (keyboard focus lands directly on the inner filter/sort control, not the `<th>`), while keeping the screen-reader semantics (`role="columnheader"`) **and** fixing the `aria-sort="none"` inaccuracy.

### B.1 What `pSortableColumn` actually contributes today (so we know what to replace)
Per the installed PrimeNG 21.1.3 directive host + `@primeuix` theme:
| Concern | Source today | Value today |
|---|---|---|
| `role="columnheader"` | directive `attributes.role` | always (even for filter-only columns) |
| `tabindex="0"` | directive `properties.tabindex` (`isEnabled()`) | **always** → the extra tab stop |
| `aria-sort` | directive `attr.aria-sort` = `sortOrder` | **always `"none"`** (PrimeNG reads its own un-bound `sortField`) |
| `class="p-datatable-sortable-column"` | directive `properties.class` | always |
| `cursor: pointer; user-select: none; outline-color: transparent` | theme CSS on that class | **only visual effect** = pointer cursor (and it *hides* the focus outline) |
| click / Enter / Space listener | directive `listeners` | calls PrimeNG `Table.sort()` — **dead** (not our pipeline) |

### B.2 Exact template change
Replace `[pSortableColumn]` with **explicit attributes** and **drop the directive** (so `tabindex` disappears). Both header paths:

Line **180** (custom-column-header branch) and line **188** (standard branch):
```html
<!-- BEFORE (line 180 / 188) -->
<th scope="col" [pSortableColumn]="column.sortable ? column.id : undefined">
<th scope="col" [pSortableColumn]="column.sortable ? column.nameKey : undefined">

<!-- AFTER (identical on both branches) -->
<th
  scope="col"
  role="columnheader"
  [class.p-datatable-sortable-column]="column.sortable"
  [attr.aria-sort]="column.sortable ? (sortColumn() === column.id ? (sortDirection() === 'ASCENDING' ? 'ascending' : 'descending') : 'none') : null"
>
```

Rationale for each attribute:
- **`role="columnheader"`** — kept for explicit, screen-reader-announced column header (harmless on a native `<th>`; PrimeNG renders a native `<table>`, not an ARIA grid).
- **no `tabindex`** — this is the whole point: the `<th>` is no longer a tab stop → focus goes straight to the inner control (v7 single-stop behaviour restored).
- **`[attr.aria-sort]`** — now **driven by our real `sortColumn()`/`sortDirection()` signals**, so it reads `"ascending"`/`"descending"` after the user sorts via the button. This fixes the `aria-sort="none"` bug. `null` for non-sortable columns (cleaner than a spurious `"none"`).
- **`[class.p-datatable-sortable-column]="column.sortable"`** — keeps the PrimeNG visual affordance (`cursor: pointer`) **only on genuinely sortable** columns. Side benefit: filter-only columns (your "Product" example) no longer show a pointer cursor / non-selectable text they shouldn't.

### B.3 What B loses vs. keeps
| Aspect | Today (v8, `pSortableColumn`) | After B |
|---|---|---|
| Header is a keyboard tab stop | ✅ (2 stops) | ❌ (1 stop — matches v7) |
| `role="columnheader"` for SR | ✅ | ✅ (kept) |
| `aria-sort` reflects real sort | ❌ stuck `"none"` | ✅ accurate |
| `cursor: pointer` on header | ✅ (all sortable/filterable) | ✅ (only truly sortable) |
| Click/Enter on header sorts | ❌ (dead PrimeNG internal sort) | ❌ (removed; button still sorts) |
| Focus ring visible on header | ❌ (theme `outline-color: transparent`) | n/a — no longer focusable |

**Net:** B removes one redundant, non-functional tab stop, keeps all screen-reader value, fixes the `aria-sort` bug, and tightens the pointer-cursor to only real sortable columns. The only thing "lost" is the (currently non-functional) ability to focus the header cell itself.

### B.4 Edge cases / scope
- **Filterable-only columns** (sortable=false, filterable=true — e.g. "Product"): `aria-sort` → `null`, class off (no pointer). They were never sortable, so this is strictly more correct.
- **Both header branches must change** (180 + 188) — the custom-header branch (`ea5d43157`) and the standard branch both carry the directive.
- **`interactive-data-view` / `data-view`** wrap `<ocx-data-table>` (`data-view.component.html:123`), so **all** consumers inherit the fix automatically — no per-consumer change needed.
- **No TypeScript change** — `sortColumn()` and `sortDirection()` are already public signals; `column.id`/`column.sortable` are on the column model. Nothing in `.ts`/`.scss` needs editing.
- **Back-porting to v7 (out of scope unless asked):** the same patch applies to the v7 single-`<th>` at `data-table.component.html:166`, but v7 uses plain properties (no signals) so the `aria-sort` binding would differ (`sortColumn`/`sortDirection` are model-backed). Noted, not done.

### B.5 Spec to add (single file, matches repo idiom)
File: `libs/angular-accelerator/src/lib/components/data-table/data-table.component.spec.ts`
New `describe('header cell accessibility (issue #1265)', ...)`:
```ts
// query the header th via its stable inner id (see template: [id]="column.id + '-header-name'")
const th = fixture.nativeElement.querySelector('th#name-header-name, th:has(#name-header-name)')
// 1. not focusable
expect(th.getAttribute('tabindex')).toBeNull()
// 2. SR semantics retained
expect(th.getAttribute('role')).toBe('columnheader')
// 3. aria-sort accurate
expect(th.getAttribute('aria-sort')).toBe('none')               // before any sort
// click the inner sort button
fixture.nativeElement.querySelector('th .sortButton').click()
fixture.detectChanges()
expect(th.getAttribute('aria-sort')).toBe('ascending')          // after sort
// 4. first focusable element in the header is the inner control (not the th)
const firstFocusable = th.querySelector('[tabindex="0"], button, input')
expect(firstFocusable).not.toBeNull()
```
Run exactly:
```bash
npx jest libs/angular-accelerator/src/lib/components/data-table/data-table.component.spec.ts \
  --config libs/angular-accelerator/jest.config.ts
```

### B.6 Risks / review points
- **Product/a11y sign-off required:** this *removes* a tab stop that #1345 deliberately added. If an a11y reviewer's original intent was "the header cell itself must be tab-focusable," B contradicts that. (Most accessible-table guidance does **not** require the `<th>` to be a tab stop — only the interactive controls — so B is generally the more correct pattern, but confirm intent.)
- **Native-`<th>` semantics:** since PrimeNG renders a native table, some a11y teams prefer to rely on native semantics and *drop* the explicit `role` too. Keeping `role` is the conservative choice (no downside).
- **`user-select: none` on header text** comes with the `p-datatable-sortable-column` class; if header text should remain selectable, drop the class and add `cursor: pointer` via a targeted SCSS rule instead. Minor.

---

## 8a. Empirical proof (temporary probe, removed after run)

A throwaway spec (`_th-focus-probe.spec.ts`, run then deleted) rendered a single
`sortable+filterable` column and observed the DOM + sort state. Results:

- **Rendered `<th>` (verbatim):**
  `<th role="columnheader" scope="col" tabindex="0" aria-sort="none" class="p-datatable-sortable-column">` — matches the reported v8 DOM exactly. Inner controls (in DOM order): **sort `<button>`** *first*, then **`<p-multiselect>` filter** (hidden input `tabindex="0"`).
- **`th.click()`** →
  - before: `{ primeSortOrder: 1, ourSortColumn: "", ourSortDirection: "NONE" }`
  - after:  `{ primeSortField: "COLUMN_HEADER_NAME.NAME", primeSortOrder: 1, ourSortColumn: "", ourSortDirection: "NONE" }`
  - → **PrimeNG's internal `sortField` DID change (to the `nameKey`), but our `sortColumn`/`sortDirection` stayed empty/NONE.** The visible rows did **not** re-sort. Confirms the `<th>` triggers *PrimeNG* sort only, disconnected from our pipeline.
- **Inner sort-button `.click()`** →
  - before: `{ ourSortColumn: "", ourSortDirection: "NONE" }`
  - after:  `{ primeSortField: "COLUMN_HEADER_NAME.NAME", ourSortColumn: "name", ourSortDirection: "ASCENDING" }`
  - → The **button** is what actually sorts (our `sortColumn`→`name`, `sortDirection`→`ASCENDING`). PrimeNG's internal sort also fired here via **event bubbling** (the `<th>`'s `onClick` listens on the header and receives the bubbled button click too) — but the *effective* sort is ours.

**Conclusions proven:** (1) the `<th>` is focusable (`tabindex="0"`) with a stale `aria-sort="none"`; (2) the `<th>` click calls PrimeNG's real (but unused-by-us) `Table.sort()`; (3) only the inner button drives the component's actual sort. So the extra tab stop is currently **focus with no user-visible effect** (except an orphan PrimeNG internal state change).

---

## 8C. Option B — IMPLEMENTED ✅ (v8 / 8.9.0)

Chosen & applied. **No push** (per instruction).

**Files changed (2, +58 / -2):**
- `data-table.component.html` — both header branches (was lines 180 & 188): replaced `[pSortableColumn]=…` with explicit `role="columnheader"`, `[class.p-datatable-sortable-column]="column.sortable"`, and `[attr.aria-sort]` driven by the real `sortColumn()`/`sortDirection()` signals. **`tabindex` removed** (directive no longer applied).
- `data-table.component.spec.ts` — new `describe('header cell accessibility (issue #1265 …)')` with 3 tests (not focusable / role kept; th is not the first focusable element; `aria-sort` none→ascending→descending after sorts).

**Verification (ran the single spec only):**
- `npx jest libs/angular-accelerator/src/lib/components/data-table/data-table.component.spec.ts --config libs/angular-accelerator/jest.config.ts`
- **Result: 133/133 passing** (130 pre-existing + 3 new).
- Live DOM probe (temporary, deleted): header now renders
  - before sort: `{ tabindex: null, role: "columnheader", ariaSort: "none" }`
  - after sort:  `{ tabindex: null, role: "columnheader", ariaSort: "ascending" }`
  - first focusable element inside the header = **`<button>`** (sort button), never the `<th>`.

**Before → After (a11y / UX):**
| | Before (v8 shipped) | After (Option B) |
|---|---|---|
| `<th>` `tabindex` | `"0"` (tab stop → **double focus**) | `null` (**single focus**, v7 behaviour) |
| `<th>` `role` | `columnheader` | `columnheader` (kept) |
| `aria-sort` | stuck `"none"` | accurate `none`/`ascending`/`descending` |
| `cursor: pointer` on header | all sortable/filterable cols | only truly-sortable cols |
| Inner sort still works | ✅ | ✅ (unchanged) |

**How to test (developer):**
1. Build/serve a page rendering `ocx-data-table` with a sortable+filterable column (any story in `data-table.component.stories.ts`).
2. Tab into the header row → focus now lands **directly on the filter/sort control**, skipping the `<th>` (was: header first, then control).
3. Click the sort icon → DevTools shows the `<th aria-sort>` update `none → ascending → descending`.
4. Run: `npx jest libs/angular-accelerator/src/lib/components/data-table/data-table.component.spec.ts --config libs/angular-accelerator/jest.config.ts` (133 green).

**Open review point (unchanged):** B removes a tab stop that PR #1345 added. Confirm with the product/a11y owner that the header cell itself is not required to be tab-focusable (standard accessible-table guidance says only the interactive controls need to be).

---

## 9. Decision needed from the developer

1. Confirm which option (A / B / C) to proceed with.
2. Confirm whether the "double focus" is a **must-fix** (product/a11y requirement) or an **acceptable trade-off** of the #1345 a11y improvement.
3. If Option A + wiring real sort: confirm we're allowed to touch the `<p-table>` sort bindings / `onSortColumnClick`.

Once confirmed, I will implement the chosen fix + spec, run the single spec file, and document before/after. **No code will be pushed.**
