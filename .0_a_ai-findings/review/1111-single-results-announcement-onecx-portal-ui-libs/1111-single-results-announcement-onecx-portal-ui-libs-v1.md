# PR Review — onecx/onecx-portal-ui-libs #1883

**Issue:** `onecx/internal-tasks#1111` — "[A11y] LIB-DATA-07: One owner for result and filter announcements"
**Branch:** `a11y/1111-single-results-announcement` (base `main`)
**PR title:** "fix(a11y): one results announcement per search, filter or sort, none at load"
**Scope in this review:** #1111 announcement logic (commits `121e8678` + `41093230`). This branch is **stacked on #1911 / #1094** (keyboard double-activation); those keyboard hunks are **out of scope** for this review.
**Version:** v1 — 2026-11-03

---

## Verdict: **Approve** ✅

The core feature is **correct and complete**. All acceptance criteria are met and the change is well-designed, cleanly scoped, and well-tested. **420 tests pass** across the 8 touched suites and **`npx nx lint angular-accelerator` reports 0 errors** (the 41 remaining warnings are pre-existing on `main`).

There are **no blocking bugs**. The items below are **test-coverage gaps** (edge cases the acceptance criteria imply but no spec pins), a couple of **documentation nits**, and a small **naming asymmetry**. None require a code change to be correct today; the test gaps are the ones worth closing before merge because they guard the exact behavior this PR exists to guarantee.

### Verification evidence
- **Tests (foreground, exact spec files, per-project jest config):**
  - `results-announcement.service.spec.ts` + `search-header.component.spec.ts` → **44 pass**
  - `data-table` / `data-list-grid` / `filter-view` / `data-list-grid-sorting` / `interactive-data-view` / `data-view` specs → **376 pass**
  - Total **420/420 green** (service 100% covered per SonarCloud quality gate).
- **Lint:** `npx nx lint angular-accelerator` → **0 errors**, 41 pre-existing warnings (verified present on `main` at the same lines).
- **i18n:** removed key `OCX_SEARCH_HEADER.ANNOUNCEMENTS.SEARCHING` has **zero remaining references** (searched `assets/i18n/` + `src/`).
- **Public API:** `src/index.ts:46` exports only `ResultsAnnouncementService` (named, not `export *`), correctly keeping the three `@internal` symbols out of the public surface.

---

## What this PR does (before → after)

**Before (`main`)** — four independent, uncoordinated announce sites:
1. `search-header` effect on `[loading, searchResultsCount]` announced **at load** and on every change: "Searching…" while loading, "No results found" when `!loading && !count`, else "N results found". A count-less page wrongly announced "No results found" at load.
2. `data-table` effect on `rows()` announced `rows.length` — the **raw, unfiltered/unsorted** input length, **at load**, on every change.
3. `data-list-grid` effect on `data()` announced `data.length` — raw, at load, on every change.
4. `filter-view` effect on `filters` announced the **filter** count (0 → "No filters", N → "N active filters") **at load** and on every change, in every context.

Net effect on a page with a search header + data view: **3–4 announcements at load**, and several (sometimes wrong-count) announcements per search. That is the WCAG 4.1.3 defect.

**After (PR head)** — single ownership via a new root `ResultsAnnouncementService`:
- **Page load:** nothing announced anywhere (all four initial emissions suppressed).
- **Search header** announces nothing at load. On a search click (`onSearchClicked`) it either announces the count itself once (when `searchResultsCount` is non-null, gated until `loading=false`, re-announcing even if the count is unchanged) **or** — when `searchResultsCount` is `null` — sets a one-shot "announce the next new data" request for a data component. The "Searching…" key is removed.
- **Data components** (`data-table`, `data-list-grid`) use an `@internal` `DisplayedResultsAnnouncer` over the *displayed* (filtered/sorted) pipeline: first render silent; a client-side filter/sort change announces the **filtered/displayed** count once (debounced to one message per change-detection turn); a server-side filter/sort sets `awaitingNewData` and announces once when new item references arrive. New data is announced **only when no search header owns it** — overridable via the new `announceResults` input (plumbed `interactive-data-view → data-view → data-table/data-list-grid`).
- **Filter view** skips its initial emission and announces the filter count **only when standalone** (no parent `DataViewStateService`); inside a data view the data component owns the filtered-count announcement instead.

---

## Deep-dive for a developer new to the repo (why / what / where / how)

### 1. Why one root service owns the decision (`results-announcement.service.ts:19-55`)
Screen-reader announcements are a **global side effect** — `@angular/cdk/a11y`'s `LiveAnnouncer` is itself a single root service that every announcement funnels through. On `main`, four independent components each had their own `effect` deciding *when and what* to announce, with no coordination between them — that is exactly how you get 3–4 messages at load. The new root service is the single place that knows the page composition ("is a search header on this page?"), so it can arbitrate ownership:

- `searchHeaders = signal(0)` (`:20`) is a **refcount** of headers, not a page count: `registerSearchHeader(destroyRef)` (`:31`) increments on construction and decrements on destroy. On destroy it also calls `clearSearchResultsAnnouncementRequest()` — if the user clicked search on a count-less header and then navigated away before data arrived, that one-shot request must not leak into the next page (it would make an unrelated data change on another page announce a stale "search result").
- `searchHeaderPresent` (`:24`) is the derived question every data component asks: "do I need to announce new data, or does the header own it?"

### 2. Why a one-shot boolean flag, not an event (`:21, :40-49`)
A header whose `searchResultsCount` is `null` **cannot** announce — it doesn't know the count. It must hand ownership to *"whichever data component first receives new data after this search"*. A simple `requestSearchResultsAnnouncement()` flag plus `consumeSearchResultsAnnouncementRequest()` (`:45`, which reads **and clears** in one synchronous step) is the whole ownership protocol: the first data component whose `items` reference changes sees `true` and announces; a second data view on the same page sees `false` and stays silent. The read-and-clear (not a plain read) is what enforces "exactly one owner" — this is the single most important invariant of the PR.

### 3. Why the data component compares two render states (`DisplayedResultsAnnouncer`, `:81-145`)
The `displayedRows$`/`displayedItems$` pipeline emits on **any** of 7 sources (rows, filters, sort column, sort direction, columns, client-side filter/sort flags). To distinguish "a user action" from "page load", each announcer keeps the previous `DisplayedResultsState` (`:84, :109-114`) and only announces on a meaningful diff:

- **First render is always silent** — `this.previous` is `undefined` at that point (`:110`), so `update()` never fires. This is how "load announces nothing" is guaranteed on the data side.
- **`items` compared by reference (`!==`, `:118`)**: the host app assigns a fresh array on every fetch/page navigation, while a pure filter/sort does *not* reassign `rows` (the same array gets filtered/sorted downstream). So this branch fires only for genuinely new data.
- **Filters compared with `fast-deep-equal` (`:123`)**: the filter array can be reassigned with content-equal objects (or the same values in a new array); deep comparison means "same filters, new reference" does not announce.
- **`displayedCount` is the filtered length, not the raw input length**: the old effects announced `rows.length`/`data.length` — the *unfiltered* count, which is the wrong number whenever a filter is active. Now the `tap` passes `params.filteredRows.length` (`data-table.component.ts:348`), so the announcement matches what the user sees.

### 4. Why `debounceTime(0, asapScheduler)` + `switchMap` inside the announcer (`:98-105`)
One user action can touch several sources within the same change-detection turn (a search sets rows; a filter change retriggers the pipeline for rows *and* filters). Without coalescing you'd hear **two messages for one action**. `debounceTime(0, asapScheduler)` drops everything scheduled in the current tick and keeps only the last count — the comment at `:100` says exactly this: "Several inputs can change in the same turn; announce only the final count." (In Node/jest the `setImmediate` polyfill is microtask-backed, so `fixture.whenStable()` deterministically flushes this — the tests are not timing-fragile.)

`switchMap` over `translateService.get(...)` (`:102`) is **latest-wins**: if a second count arrives before the first translation resolves, the in-flight translation is cancelled, so a stale translated number can never overtake a newer one. This is the same reasoning the commit applied to the item-translation pipeline in both data components (`data-table.component.ts:339`, `data-list-grid.component.ts:455`): `combineLatest` re-emits on any source change, and under the old `mergeMap` two overlapping `translateItems` streams could interleave; `switchMap` cancels the older stream. For the common case (no `TRANSLATION_KEY` columns) `translateItems` returns `of({})` synchronously, so there is no observable difference — it matters for slow async translation.

`takeUntilDestroyed(inject(DestroyRef))` (`:103`) unsubscribes when the data component is destroyed, so a removed component never announces later.

### 5. Why `isViewChangeDue` / `awaitingNewData` (`:127-140`)
- **Client-side** filter/sort: the displayed count changes *immediately* → announce now (the debounce merges it into one message).
- **Server-side** filter/sort: the currently displayed data is **not** the result of the action yet; the correct count only exists when the server's new rows arrive. So `isViewChangeDue(false)` sets `awaitingNewData = true` (`:137`) and returns `false` (don't announce now); the *next* `items` change then announces via `due = this.awaitingNewData || ...` (`:120`) — note this fires **even when a search header owns search announcements**, because a filter action is a different action from a search.
- Commit `41093230` deliberately rewrote the boolean composition as `due = due || filterDue` / `due = due || sortDue` instead of relying on `||` short-circuit evaluation order — a defensive style choice (the commit message: "Evaluate filter and sort ownership without relying on || evaluation order"), since `isViewChangeDue` has the side effect of setting `awaitingNewData`.

### 6. Why the search header uses a counter signal + `effect` (`search-header.component.ts:79, :251-282`)
- **`searchRequests = signal(0)` incremented on every search (`:257`)**: an `effect` re-runs only when its read signals change. A second search with the *same* count changes neither `loading` nor `count`, so without the counter the effect would not re-fire and the second search would announce nothing. The counter forces "one effect run per search".
- **`searchResultsAnnouncementPending` (`:77, :256`)** is set *only* by a click (`prepareSearchResultsAnnouncement`), never at construction — that is the "nothing at load" guarantee on the header side.
- **The `loading` gate (`:268-272`)**: for async searches the count visible at click time is stale; the announcement fires when `loading` flips back to `false`, i.e. after the response replaced the data. That is a **consumer contract** documented at `:60-63` — bind `loading` for async searches. This contract has one untested direction (see F2).
- **`count ? … : …` (`:274-276`)**: count `0` is falsy → the `NO_RESULTS` key; `{ count: count || null }` (`:278`) interpolates `null` instead of the string `"0"` where the key has no placeholder. The `RESULTS_FOUND` key is only reachable when `count` is truthy, so `0` never hits it.
- **`prepareSearchResultsAnnouncement()` (`:251-259`)**: `count === null` → hand off to a data component (one-shot request); otherwise **clear** any stale request (this search will be announced by the header itself) and arm the pending flag + counter.

### 7. Why the filter view uses `skipSelf` + `initialFilters` (`filter-view.component.ts:66, :238-247`)
- The component declares `providers: [DataViewStateService]` (`:55`) — every filter view has its **own** service. `parentService = inject(DataViewStateService, { skipSelf: true, optional: true })` (`:66`) walks **past the component's own provider** up the injector tree: if an ancestor data view provides one, `parentService` is that ancestor; if the filter view is standalone, the inject is `undefined`. This is a cheap, DI-native "am I nested in a data view?" probe — no template or flag plumbing needed.
- **Nested** → the data component announces the *filtered result count* ("N Results Found"), which is more useful than "N filters active", so the filter view stays silent. **Standalone** → nobody else announces filter changes, so the filter view owns them.
- **`initialFilters` (`:238, :246`)**: an `effect` runs once at construction — that first run *is* page load; the flag suppresses exactly that run, so only subsequent filter changes announce.
- (The method is misspelled `annouceFilterCount`, `:244/:392` — pre-existing on `main`; see F10.)

### 8. Why the named export in `src/index.ts:46`
Sibling services use `export * from …`, but this service file also declares three `@internal` symbols (`DisplayedResultsState`, `DisplayedResultsTranslationKeys`, `DisplayedResultsAnnouncer`). A star export would re-export those into the package's public API. The named `export { ResultsAnnouncementService }` is the deliberately narrow surface; the only importers of `DisplayedResultsAnnouncer` are the two data components via internal relative imports.

### 9. Why the new `announceResults` input and its template chain
`interactive-data-view.component.ts:130` → `interactive-data-view.component.html:93` → `data-view.component.ts:129` → `data-view.component.html:14` (list-grid branch) / `:132` (table branch) → the leaf components. The semantics live in `announcesNewData()` (`results-announcement.service.ts:142-144`): `this.announceResults() ?? !this.ownership.searchHeaderPresent()` — an explicit value wins; otherwise the data component announces new data **only when no search header is on the page**. So: page with header + no input → header speaks; page without header → data component speaks new data; `true`/`false` overrides either default. Note it gates **new data only**, not filter/sort announcements (see F6). Because the value travels through four template hops, a silently dropped binding degrades to the default behavior — which is why the end-to-end `true` test (F4) matters.

### 10. Scoping note: what is NOT this PR
This branch is stacked on `a11y/1094-double-activation` (#1911, commit `d608b158` et al.): the delegated `keydown.enter` handling with IME/`isComposing`/`defaultPrevented`/`aria-expanded`/`listbox`-or-`dialog` guards in `search-header`, the removed per-button keydown handlers, and the "keyboard activation" spec blocks all belong to that PR. They appear in the `main` diff of #1883 but were reviewed out of scope here (F9).

---

## Findings (ranked)

### 🔶 F1 — (test gap, the most important) No-count search + **unchanged data reference** can silently consume the request and announce nothing
`results-announcement.service.ts:110-121`

When `searchResultsCount` is `null`, `prepareSearchResultsAnnouncement()` sets the one-shot flag and a data component must announce the next *new* data. But `update()`/`isAnnouncementDue()` only act when `current.items !== previous.items`, and **consume the request on that branch**:

```ts
if (this.previous && this.isAnnouncementDue(this.previous, state)) this.counts.next(displayedCount)
...
if (current.items !== previous.items) {
  const searchRequested = this.ownership.consumeSearchResultsAnnouncementRequest()  // consumed even if not due
  ...
}
```

`searchRequested` is consumed whenever the items **reference changes**, even if `due` ends up `false`. The real trap is the case where the post-search fetch returns the **same array reference** (a legitimate server response that leaves the visible rows unchanged, e.g. same page). Then `update()` sees no items change, never enters the branch, and **nothing announces for that search** — while the one-shot flag (set by the search header) is still pending and will be consumed by the *next* unrelated data change, announcing a stale "result" for a later action.

No spec covers this: `service.spec.ts:284` ("lets the data component announce a search when the search header has no count") and the search-header "search header requests it" data-table test both assign **fresh** arrays.

**Why it matters:** this is precisely the AC "one search → exactly one message," and the edge produces *zero* messages.
**Suggested comment (file `results-announcement.service.ts`, line 118):**
> The one-shot search request is only consumed when `items` changes reference. If a count-less search returns data with the same array reference (unchanged rows), nothing is announced for that search, and the pending flag will be consumed by the next unrelated data change. Either consume the request only when an announcement actually fires, or add a spec pinning this path (search where the rows reference is unchanged → assert the announced count, or assert the documented "no announcement" behavior).

### 🔶 F2 — (test gap) Stale-count race in the `loading`-gated header announcement is only tested in one direction
`search-header.component.ts:265-282`

The `announceSearchResults()` effect captures `count` at the instant `loading===false && pending`, then announces that captured value **asynchronously** (`firstValueFrom(...).then(...)`). Every page-level spec sets `loading=true` **before** the response arrives, so the "loading not driven first" window is never exercised. If a consumer does not set `loading=true` before the previous search's data is replaced, the announcement fires with the **pre-response (stale) count** — i.e. "exactly one message" with the *wrong* count.

This is **documented as a consumer contract** (`search-header.component.ts:60-63`: "For asynchronous searches, bind `loading` and set it to true while the search runs"), so it is a contract gap, not a code bug. But the protective behavior is only tested in the `loading=true` direction.
**Suggested comment (file `search-header.component.ts`, line 269):**
> All page-level specs set `loading=true` before the response, so the case where `loading` is not driven first (async response lands while `loading` is still false) is untested. Consider a search-header spec asserting the announced count is the one present when `loading` becomes false, and re-read `count` at announce time (or in the same CD turn `pending` is set) to avoid announcing a stale value.

### 🔶 F3 — (test gap) Filter-view "inside a data view" silence is not asserted through a real data-view hierarchy
`filter-view.component.ts:243-246` + `filter-view.component.spec.ts:425-435`

The suppression gate is `if (!initialFilters && !this.parentService)`, where `parentService = inject(DataViewStateService, { skipSelf: true, optional: true })` (`filter-view.component.ts:66`). The spec test named "does not announce filter changes inside a data view…" (`spec:425`) runs the **standalone** `FilterViewComponent` fixture. Note the main spec block provides `DataViewStateService` at the **root** injector (`spec:44`) and the component also declares it in its own `providers` (`filter-view.component.ts:55`) — so `skipSelf` resolves `parentService` to the root-provided instance (truthy) and the test genuinely exercises the "suppressed because a parent exists" branch, and it passes for the right reason.

The gap is that **no spec builds the real `ocx-interactive-data-view`/`ocx-data-view` → `ocx-filter-view` hierarchy** and asserts the filter-view stays silent *there* while the data component announces the filtered count. A regression in `skipSelf` resolution (e.g. a provider rewiring in `interactive-data-view`) would make an in-data-view filter-view announce the filter count **and** the data component announce the result count — a double announcement — that no spec would catch.
**Suggested comment (file `filter-view.component.spec.ts`, line 425):**
> This test verifies silence in a standalone fixture (root `DataViewStateService` satisfies `skipSelf`), but not through the real data-view hierarchy. Add an integration spec: `ocx-interactive-data-view` with its filter-view; drive filters via the view's state service; assert `LiveAnnouncer.announce` is called **exactly once** (by the data component, with the filtered count) and never with the "active filters" text.

### 🟡 F4 — (test gap) `announceResults=true` override is untested through the full `interactive-data-view` chain
`interactive-data-view.component.html:93` / `data-view.component.html`

The "optional `announceResults` input can override" AC is tested at the leaf (data-table / data-list-grid `true` next to a search header) and as `false`/`undefined` through `ocx-interactive-data-view` (`service.spec.ts:200` "forwards `announceResults`"), but **`true` through the full `interactive-data-view → data-view → data-table` chain** has no spec. If the `[announceResults]` binding at `data-view.component.html` were dropped, the silent-default path would still pass every existing test.
**Suggested comment (file `data-view.component.html`, at the `[announceResults]` binding):**
> The `announceResults=true` override is only tested at the leaf and as `false` through the view. Add an `interactive-data-view` spec with `announceResults=true` + a registered search header (no count) + a rows change, asserting exactly one announcement — so a dropped `[announceResults]` binding here is caught.

### 🟡 F5 — (test gap) Server-side filter/sort announcement is covered only for data-table, not data-list-grid
`data-list-grid.component.ts:464-468` vs `data-table.component.spec.ts`

`data-list-grid.component.spec.ts` "results announcement ownership" covers page-load silence, client-side filter/sort, and new-data ownership — but **not** the server-side path (`clientSideFiltering/Sorting=false` → `awaitingNewData` → announce on new data) that `data-table.component.spec.ts` covers with two explicit specs. Both components share `DisplayedResultsAnnouncer` (low risk), but the grid's distinct pipeline (`data` input vs `rows` input, `sortField` vs `sortColumn` key, `translatedItems` vs `translations`) is a realistic place for an asymmetry.
**Suggested comment (file `data-list-grid.component.spec.ts`, in the ownership block):**
> Mirror the two data-table server-side specs ("announce a server-side filter change when the new rows arrive", "…server-side sort…") here so a grid-only pipeline reordering that breaks server-side announcement is caught.

### 🟡 F6 — (docs nit) `announceResults` reads like a blanket opt-out but only gates new data
`results-announcement.service.ts:142-144`

`announcesNewData()` honors the `announceResults` input, but the filter- and sort-due branches in `isAnnouncementDue()` do **not** — a component with `[announceResults]=false` still announces client-side filter and sort changes. The JSDoc says only new rows are gated, so this is intentional, but the input name is reasonably read as a full screen-reader opt-out.
**Suggested comment (file `results-announcement.service.ts`, line 142, or the `announceResults` input doc):**
> Clarify the `announceResults` input docs: it gates **new data only**; client-side filter/sort changes are always announced. If blanket silence is ever desired, gate view-change announcements behind the same input.

### ⚪ F7 — (docs nit) Two data views: only the first announces the requested search
`results-announcement.service.ts:39-42`

The one-shot request is consumed by the first data component whose items change, so with two data views on one page the second never announces (pinned by the "two data views and one search header" spec: exactly 1 call). Intended single-ownership design, but consumer-visible — worth a one-line doc note so multi-view pages aren't surprised that only one speaks.

### ⚪ F8 — (consistency nit, optional) i18n param + casing differ across the four count-announcement keys
`en.json:64-65, 100-101` vs `en.json:201-202`

Data components use `{{results}}` + title case ("… **R**esults Found"); the search header uses `{{count}}` + sentence case ("… **r**esults found"). Both sets are **pre-existing and internally consistent**, so this is not a defect introduced here — but this PR is the natural point to unify the two surfaces under one ownership model, so aligning the param name and casing would be tidy. (The `DisplayedResultsAnnouncer` JSDoc correctly documents `{results}` for the data path.)

### ⚪ F9 — (out of scope, note only) Keyboard double-activation work rides along in this branch
`search-header.component.ts` (delegated `keydown.enter`, IME/composition/listbox/`defaultPrevented` guards), the removed per-button keydown handlers, and the "keyboard activation" spec blocks are **#1094/#1911** work stacked into this branch, not #1111. No announcement finding here. Keep or document these hunks as inherited from `origin/a11y/1094-double-activation` at merge time.

### ⚪ F10 — (nit, pre-existing) Misspelled method `annouceFilterCount`
`filter-view.component.ts:244, 392` — missing the "n" (`announce`). Pre-existing (present on `main`); this PR only changes the guard around the call. Optional cleanup.

### ⚪ F11 — (nit, observation) Duplicated `displayed*$` pipeline + announcer wiring
`data-table.component.ts:327-358` vs `data-list-grid.component.ts:443-479` — the two displayed pipelines are near-identical (same 7-source `combineLatest`, `switchMap(translateItems)`, `filterItems`, `tap(resultsAnnouncer.update)`, `sortItems`), differing only in i18n keys and `flattenItems`/`sortField`. Predating duplication, but the new announcement hook was added to both. Extracting the pipeline + announcer factory into a shared helper (e.g. on `DataSortBase`) would keep the two subtle announcement paths in lockstep. Judgment call; not required for correctness.

---

## Cross-check notes — two sub-review findings **invalidated on verification**
An independent multi-agent review (4 lenses) surfaced these; I verified each against the source and **do not** include them as real issues:

- ❌ **"Unexplained `mergeMap`→`switchMap` behavior change"** (raised by two lenses): **Incorrect framing.** The change *is* documented and intentional — commit `41093230`: *"Use switchMap for the item translations of data table and list grid so a stale translation cannot overtake a newer state."* This is the correct, latest-wins choice for a pipeline whose outputs feed `sortItems`. It is a defensible improvement, not an unexplained regression. (A very slow async translation could be cancelled by a faster follow-up source tick, but `translateItems` is synchronous for the common no-`TRANSLATION_KEY`-column case, and the announcement debounce absorbs ordering. No change needed.)
- ❌ **"Filter-view 'inside a data view' test passes by DI coincidence (`parentService` undefined)"** (GAP-3 mechanism claim): **Incorrect.** Because `DataViewStateService` is `@Injectable()` (not root) but the main spec block provides it at the root injector (`spec:44`) and the component also declares it in its own `providers` (`filter-view.component.ts:55`), `skipSelf` resolves `parentService` to the root instance (truthy). The test passes for the *right* reason. Only the *coverage* gap (no real hierarchy spec — F3) remains; the "coincidence" mechanism does not.

---

## Conventions check
- ✅ Named export of `ResultsAnnouncementService` (avoids leaking `@internal` symbols) — correct and deliberate.
- ✅ `@internal` JSDoc on the three helper symbols; internal relative imports in the two data components.
- ✅ Removed i18n key has zero dangling references. No dead code / unused imports introduced.
- ✅ `effect()` + signal usage, `takeUntilDestroyed`, `untracked`-free reads, `debounceTime(0, asapScheduler)` — idiomatic and consistent with the repo.
- ⚠️ i18n param/casing inconsistency (F8) and duplicated pipeline (F11) — minor.

---

## How to test the changes (manual + automated)

**Automated (run the specific spec files — do NOT run the whole suite):**
```bash
cd /root/reviews/jan/onecx-portal-ui-libs

npx jest libs/angular-accelerator/src/lib/services/results-announcement.service.spec.ts \
         --config libs/angular-accelerator/jest.config.ts
npx jest libs/angular-accelerator/src/lib/components/search-header/search-header.component.spec.ts \
         --config libs/angular-accelerator/jest.config.ts
npx jest libs/angular-accelerator/src/lib/components/data-table/data-table.component.spec.ts \
         --config libs/angular-accelerator/jest.config.ts
npx jest libs/angular-accelerator/src/lib/components/data-list-grid/data-list-grid.component.spec.ts \
         --config libs/angular-accelerator/jest.config.ts
npx jest libs/angular-accelerator/src/lib/components/filter-view/filter-view.component.spec.ts \
         --config libs/angular-accelerator/jest.config.ts
npx jest libs/angular-accelerator/src/lib/components/data-list-grid/data-list-grid-sorting.component.spec.ts \
         --config libs/angular-accelerator/jest.config.ts
npx jest libs/angular-accelerator/src/lib/components/interactive-data-view/interactive-data-view.component.spec.ts \
         --config libs/angular-accelerator/jest.config.ts
npx jest libs/angular-accelerator/src/lib/components/data-view/data-view.component.spec.ts \
         --config libs/angular-accelerator/jest.config.ts

npx nx lint angular-accelerator
```
(All 420 assertions currently pass; lint is 0 errors.)

**Manual (screen reader / Live Region):** Build a page with `ocx-search-header` + `ocx-interactive-data-view` (or the Storybook host) and, with a screen reader or the browser's live-region inspector:
1. **Load the page** → hear/observe **nothing**.
2. **Click search** (async: bind `loading`; drive `loading=true` then `false` with the new `searchResultsCount`) → hear **exactly one** "N results found", with the correct count. Repeat the same search with the same count → still exactly one.
3. **Apply a client-side filter** → one "N Results Found" (filtered count). **Sort** → one announcement.
4. **Server-side** filter/sort → one announcement *when the new rows arrive*.
5. **Standalone filter view** (no data view) → no announcement at load; one "N filters" on change. **Inside a data view** → filter view stays silent; the data component announces the filtered count.
6. **Header has no `searchResultsCount`** → the data component announces the next new data; with **two** data views, only the first announces.
7. **`announceResults`** on the view overrides the data component's new-data behavior.

**How to read the before/after:** on `main`, step 1 alone produced 3–4 announcements (including a spurious "No results found") and step 2 produced multiple, sometimes wrong-count, messages. On this branch, each action produces at most one correct message.

---

## Suggested PR review comments (paste-ready, with locations)

> **1.** `libs/angular-accelerator/src/lib/services/results-announcement.service.ts:118` (major — test gap): "The one-shot search request is only consumed when `items` changes reference. If a count-less search returns data with the same array reference (unchanged rows), nothing is announced for that search, and the pending flag is consumed by the next unrelated data change. Add a spec for this path, or consume the request only when an announcement actually fires."
>
> **2.** `libs/angular-accelerator/src/lib/components/search-header/search-header.component.ts:269` (minor — test gap): "The `loading`-gated announcement captures `count` at flush and announces it async. All specs set `loading=true` first, so the stale-count case (response lands while `loading` is still false) is untested. Add a spec asserting the announced count is the one present when `loading` becomes false, and consider re-reading `count` at announce time."
>
> **3.** `libs/angular-accelerator/src/lib/components/filter-view/filter-view.component.spec.ts:425` (minor — test gap): "This 'inside a data view' test runs a standalone fixture (root `DataViewStateService` satisfies `skipSelf`). Add an integration spec through a real `ocx-interactive-data-view`→`ocx-filter-view` hierarchy asserting `announce` is called exactly once (by the data component) and never with the 'active filters' text."
>
> **4.** `libs/angular-accelerator/src/lib/components/data-view/data-view.component.html` (at the `[announceResults]` binding) (minor — test gap): "`announceResults=true` through the full `interactive-data-view → data-view → data-table` chain is untested (only `false` and leaf-level `true`). Add an end-to-end spec so a dropped binding here is caught."
>
> **5.** `libs/angular-accelerator/src/lib/components/data-list-grid/data-list-grid.component.spec.ts` (ownership block) (minor — test gap): "Mirror the two data-table server-side filter/sort announcement specs here — server-side path is only covered for data-table today."
>
> **6.** `libs/angular-accelerator/src/lib/services/results-announcement.service.ts:142` (nit — docs): "`announceResults` gates new data only; client-side filter/sort are always announced. Add a doc line so the input isn't read as a blanket screen-reader opt-out."
>
> **7.** `libs/angular-accelerator/assets/i18n/en.json:64` / `:201` (nit, optional): "Param (`results` vs `count`) and casing ('Results Found' vs 'results found') differ across the four count-announcement keys. Pre-existing, but a natural moment to unify now that both surfaces share one ownership model."
>
> **8.** `libs/angular-accelerator/src/lib/components/search-header/search-header.component.ts` (note, out of scope): "The delegated-keydown/IME/listbox guards and removed per-button keydown handlers here are #1094/#1911 (keyboard double-activation) stacked on this branch, not #1111. Fine to keep; just note the provenance at merge."

**Verdict: Approve** — no correctness blockers. Strongly recommend closing F1 (the silent same-reference search) and F2 (stale-count) as test additions before merge; F3–F5 are worthwhile coverage of the exact guarantees this PR introduces. F6–F11 are optional.
