# PR Review — 1093: html lang in standalone mode + translation fallback

| Field | Value |
|---|---|
| **Repo** | `onecx-portal-ui-libs` |
| **Issue** | [onecx/internal-tasks#1093](https://github.com/onecx/internal-tasks/issues/1093) — `[A11y] LIB-A11Y-02: html lang in standalone mode and translation fallback` (parent #1053, WCAG 3.1.1 A / Low) |
| **PR** | [#1900](https://github.com/onecx/onecx-portal-ui-libs/pull/1900) — `fix(a11y): set html lang for standalone shell apps` |
| **Branch** | `a11y/1093-html-lang` (base `main`) |
| **Author** | `SchettlerKoehler` (2 commits, Claude-Code assisted) |
| **Review date** | 2026-11-02 |
| **Reviewer** | AI (Claude Code) |
| **Version** | v1 |
| **Verdict** | ✅ **APPROVE** — correct, minimal, well-scoped, well-tested. 3 non-blocking observations (1 of which is the open PO decision the issue itself flags). No blocking issues. |

---

## 0. Verification summary (ran locally on branch `a11y/1093-html-lang`)

| Check | Result |
|---|---|
| Spec `standalone-html-lang.utils.spec.ts` (4 tests) | ✅ **4/4 pass** (`npx jest <spec> --config libs/angular-standalone-shell/jest.config.ts`) |
| Mutation A — make fallback override unconditional (`if (true)`) | ✅ test 3 **fails** → the "don't clobber app fallback" guard is a real guard |
| Mutation B — remove `setAttribute('lang', lang)` | ✅ test 1 **fails** (`Expected: "de" / Received: null`) → the html-lang write is a real guard |
| Lint (`nx run angular-standalone-shell:lint`) | ✅ clean |
| Build (`nx run angular-standalone-shell:build`) | ✅ passes; built `.d.ts` + `.mjs` export `provideStandaloneHtmlLang` & `STANDALONE_FALLBACK_LANGUAGE` |
| Scope check — other `html lang` writers in libs | ✅ **only** this file writes `html lang` (`grep setAttribute('lang'` → 1 hit) |
| Shell-mode boundary (ref `onecx-shell-ui`) | ✅ shell's `AppComponent` owns `document.documentElement.lang` + every shell/`pre_loaders/index.html` has static `<html lang="en">` — so "libs never write it in shell mode" is a true separation |

No PR comments/reviews exist yet (verified via `gh pr` comments + GraphQL). No prior review doc for 1093 existed; this is **v1**.

> **Local working-tree noise (NOT part of this PR):** `libs/angular-accelerator/.storybook/preview.ts` (patches `patchOptimusAutoFocus()` commented out), `nx.json` (`"analytics": false`), and `package-lock.json` have local uncommitted edits. They do **not** touch `angular-standalone-shell` and do **not** affect this review. Flag them to the author so they aren't accidentally committed to the PR branch.

---

## 1. What the PR changes (TL;DR)

**+97 lines, 0 deletions, 5 files, all in `libs/angular-standalone-shell`:**

| File | Change |
|---|---|
| `src/lib/utils/standalone-html-lang.utils.ts` | **NEW** — `STANDALONE_FALLBACK_LANGUAGE = 'en'` + `provideStandaloneHtmlLang()` (an `EnvironmentProviders` factory) |
| `src/lib/utils/standalone-html-lang.utils.spec.ts` | **NEW** — 4 specs |
| `src/lib/utils/expose-standalone.utils.ts` | +2 — import + wire `provideStandaloneHtmlLang()` into `provideStandaloneProviders()` |
| `src/index.ts` | +1 — re-export the new util (public API) |
| `README.md` | +5 — documents the behavior + the "pending PO confirmation" note |

**The behavior goal:** a standalone OneCX app must (a) have a valid, **live** `lang` attribute on `<html>` that follows the user language (WCAG 3.1.1 `html-has-lang` / `valid-lang`), and (b) fall back to a defined language for missing translations instead of showing raw keys or mixed languages. **Inside the shell, nothing changes** — the shell keeps owning `<html lang>`.

---

## 2. The story — explained for a developer new to this repo

### 2.1 Two ways an app runs here

- **Shell mode:** the app is a micro-frontend hosted inside the OneCX Shell. The shell renders the `<html>` element.
- **Standalone mode:** the app runs on its own (dev/preview) via `@onecx/angular-standalone-shell`, whose `provideStandaloneProviders()` (`expose-standalone.utils.ts:101`) bootstraps everything a shell would normally provide (app state, user profile, theme, router, i18n, auth, …).

This whole PR exists only to serve **standalone mode**. That's the single most important mental model.

### 2.2 Why the shell must keep `<html lang>` to itself

Verified in the reference repo `onecx-shell-ui`:

```ts
// onecx-shell-ui/src/app/app.component.ts:22
this.userService.lang$.subscribe((lang) => {
  document.documentElement.lang = lang   // ← the shell owns html lang
  this.translateService.use(lang)
})
```

and every `src/index.html` + `pre_loaders/*/index.html` ships a static `<html lang="en">`.

So in shell mode there is already exactly one writer of `html lang` — the shell. If the libs *also* wrote it, you'd have two competing writers. The issue is explicit: **"inside the shell the libs never write the document language."** The PR honors that by only activating the new writer on the standalone path (see §2.4).

### 2.3 Why an *environment initializer* (and why that specific one)

`provideStandaloneHtmlLang()` returns:

```ts
provideEnvironmentInitializer(() => {
  const document = inject(DOCUMENT)
  const userService = inject(UserService)
  const translateService = inject(TranslateService)
  const destroyRef = inject(DestroyRef)
  ...
})
```

Reasons a new dev should understand:

1. **When it runs.** An environment initializer runs once at application bootstrap, in the root environment, after the injector is ready but before the app renders. That's the right moment to (a) read the initial user language and set `lang`, and (b) subscribe to `UserService.lang$` so it stays in sync on every change.
2. **Why `provideEnvironmentInitializer` and not the old `ENVIRONMENT_INITIALIZER` token.** The first commit used `ENVIRONMENT_INITIALIZER` directly; the **second commit switched to `provideEnvironmentInitializer`** (Angular 21+ API) because the token is deprecated. Confirmed available on the repo's **Angular 22.2.0** (`typeof provideEnvironmentInitializer === 'function'`). Under the hood `provideEnvironmentInitializer` just registers a `useValue` onto the `ENVIRONMENT_INITIALIZER` multi-token (`node_modules/@angular/core/.../_pending_tasks-chunk.mjs:897`), so behavior is identical, minus the deprecation.
3. **Why `DOCUMENT` instead of raw `document`.** Injecting `@angular/common`'s `DOCUMENT` token makes the write testable and SSR-safe (no global side effect at module scope).
4. **Why `takeUntilDestroyed(destroyRef)`.** The `lang$` subscription is tied to the injector lifetime and unsubscribes automatically — no manual `unsubscribe()`, no leak.

### 2.4 The two jobs, line by line

```ts
// Job 1 — fallback language (idempotent, non-clobbering)
if (!translateService.getFallbackLang()) {
  translateService.setFallbackLang(STANDALONE_FALLBACK_LANGUAGE) // 'en'
}
```
`ngx-translate` needs a fallback language so a key missing in the active language resolves to the fallback's translation rather than the raw key or a mixed string. The guard `if (!getFallbackLang())` means **the lib only fills the gap when the app hasn't already set one** — an app that wants `de` as fallback keeps it. This is the "decided with the PO" part: `en` is the *proposed* default (comment + README both say so).

```ts
// Job 2 — keep <html lang> in sync with the user language
userService.lang$.pipe(takeUntilDestroyed(destroyRef)).subscribe((lang) => {
  if (lang) {
    document.documentElement.setAttribute('lang', lang)
  }
})
```
`UserService.lang$` is a `BehaviorSubject` (seeded from `determineBrowserLanguage() ?? DEFAULT_LANG` — `user.service.ts:20`), so the subscription fires **immediately** with the current language at bootstrap (initial `lang`) and again on every change (live update). The `if (lang)` guard avoids writing an empty attribute if the stream ever emits a falsy value.

### 2.5 Wiring: why it's *only* standalone

```ts
// expose-standalone.utils.ts:121  (inside provideStandaloneProviders())
provideStandaloneHtmlLang(),
```

`provideStandaloneHtmlLang()` is added **only** to `provideStandaloneProviders()`, the standalone-only entry point. The shell never calls `provideStandaloneProviders()`, so it never registers this initializer — hence "libs never write `html lang` in shell mode." This is enforced structurally (provider composition), not by an `if` — which is why it's hard to break. (Test 4 pins this down — see §3.)

### 2.6 Public API

`src/index.ts:4` re-exports the util, so consumers can call `provideStandaloneHtmlLang()` on its own (e.g. a host that wires i18n differently) or just rely on `provideStandaloneProviders()`. Both symbols (`provideStandaloneHtmlLang`, `STANDALONE_FALLBACK_LANGUAGE`) are present in the built `.d.ts` and `.mjs` (verified).

---

## 3. Functional review — the 4 tests, and why they're *real* guards

Ran `npx jest libs/angular-standalone-shell/src/lib/utils/standalone-html-lang.utils.spec.ts --config libs/angular-standalone-shell/jest.config.ts` → **4/4 pass.**

Each test asserts one distinct requirement:

1. **`should set html lang from the user language and update it on change`** — `lang$.next('de')` → `lang="de"`; `lang$.next('fr')` → `lang="fr"`. Proves initial set **and** live update. *(Mutation B: remove the `setAttribute` → fails with `Expected: "de" / Received: null`.)*
2. **`should set the fallback language when none is configured`** — with no app fallback, `getFallbackLang()` is `STANDALONE_FALLBACK_LANGUAGE` (`en`).
3. **`should not override a fallback language configured by the app`** — registers an app-level `provideEnvironmentInitializer` that sets fallback to `de` **before** `provideStandaloneHtmlLang()`; expects `de` to survive. *(Mutation A: make the override unconditional → fails.)*
4. **`should not write html lang when the provider is not used (shell mode)`** — no `provideStandaloneHtmlLang()`, `lang$.next('de')` → `hasAttribute('lang')` is **false**. Proves the shell-mode boundary.

**A subtle point the reviewer confirmed (test 3 rests on it):** environment initializers run in **provider-array order**. `provideEnvironmentInitializer` appends a `useValue` to the `ENVIRONMENT_INITIALIZER` **multi-token**, and the runtime resolves+iterates that token in registration order (`_pending_tasks-chunk.mjs:1243-1252`). In test 3 the app initializer is listed *earlier* in the providers array, so it runs first (sets `de`), then the standalone initializer runs and — because `getFallbackLang()` is now truthy — leaves it alone. So the "runs before the standalone initializer, like an app-level configuration would" comment in the spec is **accurate**, not aspirational. Caveat: this relies on the consumer actually listing the app's fallback initializer before `provideStandaloneHtmlLang()`/`provideStandaloneProviders()`; a real host wiring it the other way round would get `en`. That's an ordering contract, not a bug — see Observation #3.

---

## 4. Code review

**Correctness — solid.**
- Idempotent, non-clobbering fallback (§2.4).
- `takeUntilDestroyed` avoids the leak a naive `subscribe` would cause.
- `DOCUMENT` injection is testable/SSR-safe.
- No shell-mode regression (structural isolation, test 4).
- Uses the current (non-deprecated) `provideEnvironmentInitializer` on Angular 22.

**Naming / structure — good.** File name, symbol names, JSDoc, and README all consistent and accurate. The "pending PO confirmation" caveat is stated in the code comment *and* the README — good transparency.

**Minor, non-blocking observations:**

1. **`STANDALONE_FALLBACK_LANGUAGE = 'en'` is still "pending product-owner confirmation"** (code comment + README). This is the *one* acceptance-criterion dependency of the story: *"Fallback language decided with the PO, set (for example English) and documented."* `en` is chosen and documented, but the PO sign-off is not recorded. **Not a code blocker** — it's a process/gate item. The PR is safe to merge; the fallback can be a one-line change if the PO picks a different language. *(This is also the natural "request changes vs approve" pivot point — see verdict.)*
2. **No `valid-lang` (format) guard.** The code writes `lang` = the raw `UserService.lang$` value as-is, so `html-has-lang` is satisfied. But if a language token were ever a BCP-47 tag like `de-DE` or contained whitespace, `valid-lang` could flag it. The shell's existing writer (`onecx-shell-ui` `app.component.ts:22`) has the *same* unguarded behavior, so the lib is at parity with the shell (consistency is a plus, not a regression). Optional hardening: `lang.trim()` and/or a small validity check before `setAttribute`. Low priority given the shell does the same and `UserService.lang$` is a clean single token in practice.
3. **Ordering contract is implicit.** Test 3 depends on the app's fallback initializer being registered *before* `provideStandaloneHtmlLang()` (see §3). If a real standalone host calls `provideTranslateService({ fallbackLang: 'de' })` or its own initializer *after* `provideStandaloneProviders()`, it would be overridden to `en`. The guard protects against the common case (app configured earlier), but the README could note that "the app should set its fallback before/within its own providers" if we want to be explicit. Non-blocking; worth a one-line doc note.

No logic bugs, no scope leaks, no shell-mode impact.

---

## 5. Before / After

**Before (standalone app):**
- `<html>` had **no `lang`** (or a stale static one) → axe `html-has-lang` **fail**, `valid-lang` **n/a**.
- Missing translation in the active language → **raw key / mixed language** (no fallback configured) → `valid-lang`-adjacent content issue.

**After (standalone app):**
- `<html lang>` = current user language, **updated live** on language change → `html-has-lang` **pass**, `valid-lang` **pass**.
- Missing translation → resolved via fallback (`en`, or the app's own if set earlier) → no raw keys / mixed languages.

**Shell mode:** unchanged in both cases (shell still owns `html lang`; libs write nothing).

---

## 6. How to test the change (for the developer)

### 6.1 Unit (done here — the fast, precise path)

```bash
npx jest libs/angular-standalone-shell/src/lib/utils/standalone-html-lang.utils.spec.ts \
  --config libs/angular-standalone-shell/jest.config.ts
# → Tests: 4 passed, 4 total

npx nx run angular-standalone-shell:lint
npx nx run angular-standalone-shell:build
```

Do **not** run the whole suite; run the specific spec with the exact `--config` as above.

### 6.2 Manual / functional (standalone app)

Because the standalone lib is intended for local dev, build a tiny standalone host:

```ts
// main.ts (standalone app)
bootstrapApplication(App, [provideStandaloneProviders(), provideRouter(routes)])
```

1. **Initial + change:** open the app → `<html lang>` should match the detected user/browser language. Switch the user language (drive `UserService.lang$`, e.g. via the app's language switcher) → `<html lang>` updates without a reload. Inspect in DevTools: `document.documentElement.getAttribute('lang')`.
2. **Fallback:** remove a translation key from the active language's bundle → the UI should show the `en` (or app-configured) fallback text, not the raw key.
3. **App-configured fallback:** add `provideEnvironmentInitializer(() => inject(TranslateService).setFallbackLang('de'))` *before* `provideStandaloneProviders()` → confirm fallback stays `de`, not `en` (mirrors spec test 3).
4. **Shell mode sanity:** the same app running inside the shell should show the **shell's** `lang` and the lib should not have touched it (no double-write). Verify via `onecx-shell-ui` — `document.documentElement.lang` is set only by the shell's `AppComponent`.
5. **axe (acceptance criterion):** run the axe devtools / `@axe-core/playwright` on a standalone page and confirm **`html-has-lang`** and **`valid-lang`** are both clean.

### 6.3 Negative guard (mutation testing — what I did to prove the tests bite)

- Temporarily change the guard `if (!translateService.getFallbackLang())` to `if (true)` → test 3 should **fail** (proves non-clobber).
- Temporarily delete `document.documentElement.setAttribute('lang', lang)` → test 1 should **fail** (`Expected: "de" / Received: null`), proving the write is real.
(Both mutations were reverted; the tree is clean and 4/4 green again.)

---

## 7. Verdict & suggested PR comments

### Verdict: **✅ APPROVE**

The change is correct, minimal, well-isolated (no shell-mode regression), well-tested (4 meaningful, mutation-verified guards), documented, and lint/build clean. It meets the two substantive acceptance criteria. The **only** open story dependency is the **PO sign-off on the fallback language** (`en` is chosen + documented but marked "pending confirmation") — that is a process gate, not a code defect, so it does not block merge.

If your team policy requires the PO decision to be recorded *before* merge, then instead **Request Changes** with a single ask: "please confirm the PO-approved fallback language (or confirm `en`) and note it on the story" — the code itself needs no change. Otherwise **Approve**.

### Suggested PR comments (exact locations)

**1. Overall review (PR-level) — Approve**
> Reviewed — logic is correct and minimal, tests are meaningful (verified by mutation), no shell-mode regression, lint/build clean. Approving. Two non-blocking follow-ups below (PO fallback confirmation; optional `valid-lang` hardening + doc note on fallback ordering).

**2. `standalone-html-lang.utils.ts:12` (on `export const STANDALONE_FALLBACK_LANGUAGE = 'en'`)**
> `en` is correctly the *proposed* default and is documented as pending PO confirmation. Before this lands in a release, please record the PO decision on #1093 (or confirm `en`) so the acceptance criterion "Fallback language decided with the PO" is closed. If the PO picks a different language it's a one-line change here. Non-blocking for merge.

**3. `standalone-html-lang.utils.ts:33` (on `document.documentElement.setAttribute('lang', lang)`)**
> Consider hardening for `valid-lang`: `lang` is written verbatim. If `UserService.lang$` could ever yield a BCP-47 tag (`de-DE`) or padded value, `valid-lang` could flag it. The shell's writer (`onecx-shell-ui` `app.component.ts:22`) has the same unguarded write, so you're at parity — but a `lang.trim()` (or a light validity check) would make the standalone path bulletproof. Low priority / optional.

**4. `expose-standalone.utils.ts:121` (on `provideStandaloneHtmlLang(),`)**
> Good — wiring it only into `provideStandaloneProviders()` is what guarantees "libs never write `html lang` in shell mode" structurally. One doc note for the README: the *non-clobber* fallback behavior (spec test 3) holds when the app sets its own fallback in providers registered before `provideStandaloneProviders()`. Worth a sentence so hosts don't expect to override after the fact.

**5. `standalone-html-lang.utils.spec.ts:37` (on the app-level `provideEnvironmentInitializer`)**
> The ordering assumption here (app initializer runs before the standalone one) is valid and matches Angular's multi-token env-initializer execution order — nice that it's pinned with a test. Just flagging: this is an implicit contract; a real host that configures fallback *after* `provideStandaloneProviders()` would get `en` instead. Covered by comment #4.

**6. Housekeeping (not code)**
> The local working tree has unrelated edits (`libs/angular-accelerator/.storybook/preview.ts`, `nx.json` `analytics:false`, `package-lock.json`). These aren't part of this PR — make sure they don't get committed to `a11y/1093-html-lang`.

---

## 8. Files touched by the PR (for reference)

```
libs/angular-standalone-shell/README.md                                            | +5
libs/angular-standalone-shell/src/index.ts                                         | +1
libs/angular-standalone-shell/src/lib/utils/expose-standalone.utils.ts             | +2
libs/angular-standalone-shell/src/lib/utils/standalone-html-lang.utils.spec.ts     | +51 (new)
libs/angular-standalone-shell/src/lib/utils/standalone-html-lang.utils.ts          | +38 (new)
```

## 9. Reproduce commands

```bash
cd /root/reviews/jan/onecx-portal-ui-libs
git checkout a11y/1093-html-lang

# unit (specific spec + config; NEVER the full suite)
npx jest libs/angular-standalone-shell/src/lib/utils/standalone-html-lang.utils.spec.ts \
  --config libs/angular-standalone-shell/jest.config.ts

# lint + build
npx nx run angular-standalone-shell:lint
npx nx run angular-standalone-shell:build
```

### Cached artifacts (this review)
- PR body/commits: `/tmp/onecx_pr_1900.json`
- Issue body: `/tmp/onecx_issue_1093.json`
- Full PR diff: `/tmp/onecx_pr_1900.diff`
- PR comments/reviews: **none** (verified empty via `gh api .../pulls/1900/comments` and GraphQL conversation)
