# PR Review — 514: Disable autofocus in filter-view

| Field | Value |
|---|---|
| **Repo** | `onecx-portal-ui-libs` |
| **Issue** | [onecx/internal-tasks#514](https://github.com/onecx/internal-tasks/issues/514) (private — 404 on public fetch) |
| **PR** | [#1928](https://github.com/onecx/onecx-portal-ui-libs/pull/1928) |
| **Branch** | `fix/autofocus-514` |
| **Review date** | 2026-11-02 |
| **Reviewer** | AI (Claude Code) |
| **Version** | v1 |
| **Verdict** | ✅ **APPROVE** — small, correct, well-scoped fix. 2 minor (non-blocking) observations. |

---

## 1. What this PR changes (TL;DR)

One line of template + one test.

- `add-filter-dialog.component.html:29` — adds `autofocus="false"` to the **value** `p-multiSelect` in the Filter View's *Add filter* dialog.
- `add-filter-dialog.component.spec.ts` — adds one test that asserts the multi-select's `autofocus` input is `false` **and** the inner native input carries no HTML `autofocus` attribute.

Total diff: **17 insertions, 1 deletion** across 2 files.

```
libs/angular-accelerator/src/lib/components/filter-view/add-filter-dialog/add-filter-dialog.component.html   |  1 +
libs/angular-accelerator/src/lib/components/filter-view/add-filter-dialog/add-filter-dialog.component.spec.ts | 17 ++++++++++++++-
```

**The behaviour goal:** when the user opens the *Add filter* dialog, keyboard focus should go to the **column** dropdown (the first control) and *stay* there — the **value** multi-select below it must **not** grab focus on its own.

---

## 2. The story (what was actually going on)

### The issue
The internal issue asks to **disable autofocus in the filter view**. Because the issue lives in a private repo (`internal-tasks`), I could not read its exact body, but the PR description and the commits make the intent unambiguous: the value selector in the filter-view's add-filter dialog was stealing focus.

> **Important scope note (called out explicitly in the PR):** the issue references a `p-pickList`. The PR author verified that the **`p-pickList` is NOT part of the filter view** — it lives in `custom-group-column-selector` (confirmed below). And the installed **Optimus UI `PickList` (v2.0.2) has no `autofocus` input at all**. So the pick-list is intentionally left untouched. The only in-scope autofocus offender in the filter view is the **value `p-multiSelect`**.

I independently confirmed both of these claims:

```
$ grep -c -i "autofocus" node_modules/@openng/optimus-ui/fesm2022/openng-optimus-ui-picklist.mjs
0                                   # ← PickList has zero autofocus references

$ grep -rln "p-pickList" libs --include=*.html --include=*.ts | grep -v spec
.../custom-group-column-selector/custom-group-column-selector.component.html
.../custom-group-column-selector/custom-group-column-selector.component.ts
.../custom-group-column-selector/custom-group-column-selector.component.stories.ts
```

### Why it happens: the Optimus UI `AutoFocus` directive (the crux of this review)

This is the part that's easy to get wrong, so it's worth understanding. The fix does **not** just remove a property — it has to work around a quirk in the third-party **Optimus UI** component library (a fork of PrimeNG).

Every Optimus select-like component (`Select`, `MultiSelect`, `Autocomplete`, …) embeds a hidden native `<input>` and applies an `AutoFocus` **directive** to it:

```html
<!-- inside <p-multiSelect> template (openng-optimus-ui-multiselect.mjs:1848-1867) -->
<input #focusInput
  [attr.id]="inputId"      <!-- ← this is where inputId="ocxAddFilterValueInput" lands -->
  ...
  [pAutoFocus]="autofocus"  <!-- ← the AutoFocus directive, driven by the component's `autofocus` input -->
  ... />
```

The `AutoFocus` directive (`@openng/optimus-ui/autofocus`) has an `@Input() autofocus` and, on `onAfterContentChecked`, does two things (source: `openng-optimus-ui-autofocus.mjs`):

```ts
onAfterContentChecked() {
  // (1) Stamp / remove the *native HTML* autofocus attribute on the host input
  if (this.autofocus === false) {
    this.host.nativeElement.removeAttribute('autofocus');
  } else {
    this.host.nativeElement.setAttribute('autofocus', true);   // ⚠️ the bug
  }
  // (2) If not focused yet, call autoFocus()
  if (!this.focused) this.autoFocus();
}
autoFocus() {
  if (isPlatformBrowser(this.platformId) && this.autofocus) {   // ⚠️ note: truthy check
    setTimeout(() => { /* focus the first focusable element */ this.focused = true; });
  }
}
```

Two subtle, separate behaviours here:

1. **Programmatic focus** — only happens when `this.autofocus` is **truthy**. If the input is `false` or `undefined`, nothing is focused. ✅
2. **The HTML `autofocus` attribute** — is **added on every element that is NOT exactly `false`**. This is the bug: when `autofocus` is **unset (`undefined`)**, the `else` branch runs and stamps `autofocus="true"` onto the inner native `<input>`. A stray native `autofocus` attribute can cause the browser to move focus to it (and re-focus it on certain re-renders), which is exactly the symptom the issue reports.

**So the root cause of the bug is a tri-state (`undefined` / `false` / `true`) being collapsed into a binary by a `=== false` comparison.** When a component is left with `autofocus` unset, it ends up with a stray native `autofocus` attribute even though it never asked for programmatic focus.

### How the repo already handles this elsewhere

The repo ships a **monkey-patch** precisely for this Optimus bug — `libs/angular-accelerator/src/lib/utils/optimus-autofocus-patch.utils.ts` (introduced in issue #708, the PrimeNG→Optimus swap):

```ts
// Rewrites AutoFocus.prototype.onAfterContentChecked so the native attribute is
// only set when `autofocus === true` (explicit), removed otherwise.
proto.onAfterContentChecked = function (this: AutoFocus) {
  if (this.autofocus === true) {
    this.host.nativeElement.setAttribute('autofocus', true)
  } else {
    this.host.nativeElement.removeAttribute('autofocus')   // ← undefined/null no longer stamps autofocus
  }
  if (!this.focused) this.autoFocus()
}
```

It's applied in:
- **Storybook** — `.storybook/preview.ts` calls `patchOptimusAutoFocus()` (because stories import Optimus modules directly).
- **Consumers** — the doc comment says *"Call this on in remoteModule ngOnBootstrap or constructor to apply the Optimus AutoFocus patch."*

**Consequence of the patch:** under the patch, an **unset** (`undefined`) `autofocus` already behaves correctly (no stray attribute). But two facts make the explicit `autofocus="false"` still necessary:

- **Unit tests do not run the patch.** `test-setup.ts` never calls `patchOptimusAutoFocus()`, so the spec executes the *unpatched* Optimus code path. There, `autofocus` unset → `undefined` → the buggy `else` branch would stamp the attribute. Pinning `autofocus="false"` makes the test deterministic **regardless** of whether the patch is loaded.
- **Defensive correctness.** Relying on "the consumer remembered to call the patch" is fragile. Explicitly setting the input to `false` is the correct contract at the component boundary and removes any ambiguity.

### The mechanism of the fix (line by line)

The template change is a **static** attribute, `autofocus="false"`:

```html
<p-multiSelect
  id="ocxAddFilterValueSelect"
  inputId="ocxAddFilterValueInput"
  autofocus="false"        <!-- ← the fix: a static string attribute -->
  ... />
```

Why does the *string* `"false"` become the *boolean* `false`? Because Optimus declares the `autofocus` input with a **transform function** (verified in the installed component):

```js
autofocus: { classPropertyName: "autofocus", publicName: "autofocus", ..., transformFunction: booleanAttribute }
```

And Angular's `booleanAttribute` coercion (`@angular/core`, `core.mjs:2891`):

```ts
function booleanAttribute(value) {
  return typeof value === 'boolean' ? value : value != null && value !== 'false';
  // "false" (a non-null string that !== 'false') → false
  // "true"/"" (any other non-null string)       → true
  // null/undefined                              → false
}
```

So `autofocus="false"` → input value **`false`** → `[pAutoFocus]="autofocus"` passes `false` to the `AutoFocus` directive → **no programmatic focus AND no native attribute**. 

> **The subtle trap this avoids:** had the author written `autofocus="false"` on a component **without** an `autofocus` input (like `p-pickList`), Angular would treat it as a *static host attribute* and literally render `autofocus="false"` in the DOM — and in raw HTML, **the mere presence of the `autofocus` attribute turns it ON** (it's a boolean attribute; its value is ignored). The PR explicitly warns about this in its description. Because `MultiSelect` *does* have the input, the attribute is consumed by the input and never leaks to the DOM. This is a genuinely subtle point and the PR author got it right.

### The dialog flow (so the "where" is clear)

1. User opens a **Filter View** (`filter-view.component.html`) over a data table.
2. A popover panel shows an **Add filter** button (`#ocxFilterViewAddFilter`, lines 131–145) and a **Reset** button (`#ocxFilterViewOverlayReset`, lines 150–164). Each carries `pAutoFocus` with a **conditional** binding — `[autofocus]="filters.length === 0"` / `[autofocus]="filters.length > 0"` — so exactly **one** of the two auto-focuses depending on whether filters already exist.
3. Clicking *Add filter* calls `onAddFilter()` (`filter-view.component.ts:285`), which opens the **`AddFilterDialogComponent`** via `PortalDialogService.openDialog(...)`.
4. Inside that dialog (`add-filter-dialog.component.html`):
   - **Column** `p-select` → `[autofocus]="true"` (line 9) — **deliberately** grabs focus as the dialog's first/primary control.
   - **Value** `p-multiSelect` → now `autofocus="false"` (line 29) — must **not** compete for focus.

The dialog uses **one focus owner at a time**: column select on open, value select never. The fix keeps that invariant.

---

## 3. Functional review

### 3.1 Correctness — ✅ verified empirically

The new spec (`add-filter-dialog.component.spec.ts:456-468`) asserts two things:

```ts
const multiSelect = fixture.debugElement.query(By.directive(MultiSelect)).componentInstance as MultiSelect
expect(multiSelect.autofocus).toBe(false)                       // (A) input is boolean false
const input = fixture.nativeElement.querySelector('#ocxAddFilterValueInput') as HTMLElement
expect(input).toBeTruthy()                                      // (B) the hidden input exists
expect(input.hasAttribute('autofocus')).toBe(false)             // (C) and carries no native autofocus attribute
```

- **(A)** proves the *static* `autofocus="false"` is coerced to the boolean `false` (not left `undefined`).
- **(C)** proves the *user-visible* outcome: the native `<input id="ocxAddFilterValueInput">` (the one that would actually receive focus) has **no** `autofocus` attribute.

I ran the specific spec (not the whole suite, per the performance guidance):

```
npx jest libs/angular-accelerator/src/lib/components/filter-view/add-filter-dialog/add-filter-dialog.component.spec.ts \
  --config libs/angular-accelerator/jest.config.ts
```

**Result: 26/26 passed** (25 pre-existing + 1 new).

### 3.2 The test is a real guard, not a no-op — ✅ proven

I temporarily removed the `autofocus="false"` line (simulating the pre-fix state) and re-ran the **new** test:

```
✕ should not autofocus the value MultiSelect
    Expected: false
    Received: undefined
      at add-filter-dialog.component.spec.ts:464:35
```

It **fails** without the fix (`autofocus` is `undefined`, not `false`) and **passes** with it. So assertion (A) genuinely guards the fix. I then restored the line (file confirmed back to HEAD) and the full spec passes again. (The working tree was left exactly as it started — the only modified files are the pre-existing, unrelated `nx.json` and `package-lock.json`.)

### 3.3 Regression surface — ✅ minimal

- Only a **template attribute** and a **new test** change. No `.ts` logic, no public API, no module wiring.
- No other consumer of `AddFilterDialogComponent` relies on the value select focusing (its focus is owned by the column select).
- The `p-pickList` and the two filter-view panel buttons are untouched.

### 3.4 Story fidelity — ✅

| PR claim | Status |
|---|---|
| Sets `autofocus="false"` on the value `p-multiSelect` | ✅ (line 29) |
| MultiSelect moved here from `filter-view.component.html` since the issue was written | ✅ plausible; value select now lives in the add-filter dialog |
| `p-pickList` unchanged — not part of filter view (it's in `custom-group-column-selector`) | ✅ verified |
| Installed Optimus UI 2.0.2 `PickList` has no `autofocus` input | ✅ verified (0 occurrences) |
| A static `autofocus="false"` would only render the HTML attribute *if there were no input* (and that turns autofocus ON) | ✅ correct reasoning; `MultiSelect` has the input so it's safe |
| No docs change; no public API change; CHANGELOG is semantic-release | ✅ nothing to update in `api-extractor` docs |

---

## 4. Code review (detailed, for a newcomer)

The change is clean and follows the repo's own conventions. A few observations, **none blocking**:

### 🟡 Minor #1 — Mixed attribute style for the same semantic, on adjacent lines
Within the same file, the two controls use **different ways** to express "autofocus on/off":

```html
<p-select    ... [autofocus]="true">       <!-- binding  (line 9)  -->
<p-multiSelect ... autofocus="false">     <!-- static attr (line 29) -->
```

- `p-select` uses a **binding** `[autofocus]="true"`; `p-multiSelect` uses a **static string** `autofocus="false"`.
- Both work (the binding produces boolean `true`; the static string is coerced by `booleanAttribute` to `false`). But a reader has to know Angular's boolean-attribute coercion to trust the static form.
- **Consistency note, not a defect.** If the author wants a uniform style, `p-multiSelect` could also be written as the binding `[autofocus]="false"`. (Both the static and the binding forms yield the boolean `false` here because of the `booleanAttribute` transform — I verified this is why the test sees `false`, not `undefined`.) This is purely cosmetic; **no change required.**

### 🟡 Minor #2 — The test depends on the *unpatched* Optimus code path
The assertion `expect(multiSelect.autofocus).toBe(false)` is what makes the fix necessary (verified: it fails when the line is removed). Note this test **does not** load `patchOptimusAutoFocus()`, so it validates the *explicit* `autofocus="false"` contract. That is actually the **right** thing to test — it guarantees the component is correct even for consumers who do *not* call the patch. (Conversely, if someone later "cleans up" and removes the explicit `autofocus="false"` thinking "the patch handles `undefined`," this test would catch it. Good.)
- **Suggestion (optional):** the second assertion (`input.hasAttribute('autofocus') === false`) is also a *nice* guarantee that holds **both** with and without the patch (the native attr is only ever added when `autofocus` is truthy). Keeping both is good; no action needed.

### 🟢 Nit (informational) — pre-existing, unrelated
The patch util `optimus-autofocus-patch.utils.ts:30-31` has a **duplicated comment line** ("Apply the autofocus attribute only when explicitly true…") appearing twice in a row. Not introduced by this PR, and unrelated to the fix. Flagging only in case it's handy to clean up at some point.

### ✅ Style / conventions
- Template attribute placed sensibly (right after `inputId`, grouping the focus-related attrs).
- Test is co-located with the component, uses the project's `makeColumn` helper, the standard `fixture.componentRef.setInput(...)` + `fixture.detectChanges()` + `await fixture.whenStable()` idiom, and `By.directive(MultiSelect)` — consistent with the rest of the spec.
- Commit message follows Conventional Commits (`fix(angular-accelerator):`) and references the issue (`Fixes onecx/internal-tasks#514`).

---

## 5. How to test the changes (before → after)

The change is a **keyboard-focus** behaviour in a real browser; unit tests only assert the attribute. Do both.

### 5.1 Automated (unit)

Run **only this spec** (do **not** run the full suite — it will stall the machine):

```bash
npx jest libs/angular-accelerator/src/lib/components/filter-view/add-filter-dialog/add-filter-dialog.component.spec.ts \
  --config libs/angular-accelerator/jest.config.ts
```

- **Expected:** 26 tests pass, including the new one: `✓ should not autofocus the value MultiSelect`.
- To *prove* the test guards the fix, temporarily delete the `autofocus="false"` line in `add-filter-dialog.component.html`, re-run with `-t "should not autofocus the value MultiSelect"`, and you'll see it **fail** with `Expected: false / Received: undefined`. Restore the line to go green. (I already did this — file is back to HEAD.)

### 5.2 Manual (browser) via Storybook

The repo has a dedicated story: `interactive-data-view-filter-view.component.stories.ts`.

1. Start Storybook:
   ```bash
   npx nx run angular-accelerator:storybook        # or the repo's standard storybook command
   ```
   (Storybook's `preview.ts` applies the Optimus autofocus patch, so this reflects the *patched* consumer path.)
2. Open the **Filter View / Interactive Data View** story that renders a data table with a filterable column.
3. Click the **Manage filters** / **Add filter** button to open the *Add filter* dialog.

| | **Before the fix** | **After the fix** |
|---|---|---|
| Dialog opens | Column dropdown is focused **and** the value multi-select's hidden input also carries a native `autofocus` (focus can land on / jump to the value control) | Column dropdown is focused; **value multi-select does not grab focus** |
| Tab order | First tab may jump into the value control unexpectedly | First tab moves Column → Value predictably |
| DevTools | Inspect `#ocxAddFilterValueInput` → it has an `autofocus` attribute (or is the active element) | Inspect `#ocxAddFilterValueInput` → **no** `autofocus` attribute; column select is the active element |

**Quick DOM check in the browser console** (with the dialog open):
```js
document.getElementById('ocxAddFilterValueInput').hasAttribute('autofocus')
// Before: true (bug)   →   After: false (fixed)
```

> Note: in Storybook (patched) the *native-attribute* symptom is already suppressed by the patch, so the most visible difference is the **focus location** — the value control should no longer steal focus. To see the raw (unpatched) attribute behaviour, the unit test is the authoritative check.

### 5.3 Lint / build
- **Lint** is safe to run (allowed for any repo):
  ```bash
  npx nx run angular-accelerator:lint
  ```
- **Build** — the change is template-only, so a full library build is not strictly required. If you build, prefer the per-project command over the monorepo-wide build (which would build all 5 preloaders + shell and can tax the machine). No build failure is expected from a template attribute.

---

## 6. PR comments so far & resolution status

| # | Author | Comment | Status |
|---|---|---|---|
| 1 | `sonarqubecloud[bot]` | **"Quality Gate passed for 'onecx-portal-ui-libs-angular-accelerator'"** | ✅ Resolved (passed) |

No human review comments exist yet. The only automated signal is SonarCloud, which reports the **quality gate passed**. Nothing is flagged as outstanding.

**Reviewer notes (this review):**
- No blocking issues.
- Two **non-blocking** observations (§4, Minor #1 and #2) are style/robustness notes, not defects.
- The fix is **correct and complete** for the stated scope. The deliberate exclusion of `p-pickList` is well-justified and verified.

---

## 7. Bottom line for the developer (newcomer summary)

1. **What & why:** The value selector in the Filter View's *Add filter* dialog was stealing keyboard focus. The fix pins its `autofocus` input to `false` so only the **column** dropdown (the dialog's first control) focuses on open.
2. **Why it's subtle:** Optimus UI's `AutoFocus` directive has a tri-state bug — an *unset* `autofocus` still stamps a native `autofocus` attribute (because it checks `=== false`, not truthiness). This repo works around it with a global patch (`optimus-autofocus-patch.utils.ts`) in Storybook/consumers. Setting the input to an **explicit `false`** here is the robust, test-able way to be correct *without* depending on that patch.
3. **Why `autofocus="false"` is safe (and not a trap):** `MultiSelect` has a real `autofocus` input, so Angular consumes the attribute and coerces the string `"false"` → boolean `false` via `booleanAttribute`. (On a component *without* the input — e.g. `p-pickList` — a static `autofocus` would leak to the DOM and *turn it on*.)
4. **What was proven:** 26/26 unit tests pass; the new test **fails** without the fix line and **passes** with it; the change is 1 template line + 1 test with no logic/API/dependency impact.
5. **How to verify:** run the single spec above; open the Filter View Storybook story and confirm the column dropdown (not the value multi-select) holds focus, and that `#ocxAddFilterValueInput` has no `autofocus` attribute.
