# Spec Compliance: A browser ships a feature only if its flag's default says so

**Date**: 2026-11-27
**Lesson**: Before writing "browser X ships Y" in a golden-rule-2 comment, read the default of Y's flag in X's own source and check X's stable and experimental wpt.fyi runs. Code that exists, a passing tentative test, or an engine that can parse the syntax does not mean the feature ships.

**Why**: Every engine lands big features behind a switch long before it turns them on: Gecko's `StaticPrefList.yaml` (whose entries can sit inside `#ifdef NIGHTLY_BUILD`), Blink's `runtime_enabled_features.json5` (no `status` means the generated `base::Feature` is disabled by default), WebKit's `UnifiedWebPreferences.yaml` (`status: testable`, `defaultValue: false`), and V8's `src/flags/feature-flags.h` (EXPERIMENTAL / PRE_STAGED / STAGED / SHIPPED lists). Bug trackers and blog posts say "implemented" at landing, not at shipping. Golden rule 2 counts only a browser that ships the feature, so a wrong "ships" picks the wrong case of the rule.

**What Happened**: net-nav1 (3aa9141a9) built Wasm module scripts on a comment that said "Golden rule 2: newer spec + shipping browser (Firefox 153+ ships Wasm ESM module integration by default)". Lane wasm2 read the sources on 2026-11-27:
- Gecko main: `javascript.options.experimental.wasm_esm_integration` is false and exists only under `NIGHTLY_BUILD`. It is off even in Nightly.
- Blink: application/wasm module scripts sit behind `kJavaScriptSourcePhaseImports`, which has no status and so is disabled. Even with it on, evaluation-phase imports throw a SyntaxError.
- WebKit: `WebAssemblyESMIntegrationEnabled` is testable and false.
- wpt.fyi, aligned stable and experimental: all three fail execute-start, wasm-import and worker.

So no browser shipped it. The shim it justified ran script in the page's realm and could panic the engine (audit report D, C1). The user ruled for the browsers' behaviour (option (b), 2026-11-27).

**Fix**: For each browser you cite as shipping, record two things:
1. The flag and its default, with the file and revision you read. Check an enclosing `#ifdef` too.
2. That browser's result on the aligned stable wpt.fyi run, and on the experimental run when the feature is new.

Where the HTML PR lists implementation bugs, read their state: Bugzilla's REST API (`/rest/bug/<id>`) returns status and dependencies, and chromestatus' `/api/v0/features?q=` returns Chrome's development state. "No active development" is not WontFix, but it is not lag either. Write all of this in the comment, as module_script.zig createFromResponse does at fetch-single step 6.

**Takeaway**: **"Ships" is a default you can read: the pref, the runtime feature or the flag list in the browser's own source, confirmed on stable wpt.fyi. Code behind a switch, and tests that pass because they expect a refusal, are not shipping.**
