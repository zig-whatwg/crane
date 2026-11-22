# Architecture: A realm is made before its document commits - announce it at the commit

**Date**: 2026-11-21
**Lesson**: Tell an automation client about a new document's execution contexts at the commit, after the commit's own events, never when the engine makes the realm.

**Why**: HTML makes a navigation's new Window realm in "create and initialize a Document object" step 7, while the OLD document is still the navigable's active one. Chrome's clients rely on the order the browser gives at a cross-document commit: `Runtime.executionContextsCleared`, `Page.lifecycleEvent` init, `Page.frameNavigated`, then `Runtime.executionContextCreated` (measured: tmp/plans/cdp1-evidence/seq-vue-e2e-one.txt). Playwright's frame manager drops every context of a frame when the clear arrives; a context announced at realm creation comes BEFORE the clear and is dropped.

**What Happened**: Designing CDP part 1's Page/Runtime split (lane cdph), the obvious hook - register each realm with the inspector inside the engine's createWindowRealm - would have produced executionContextCreated before executionContextsCleared and frameNavigated for every navigation. Blink avoids it because its main-world context is made lazily, after DidCommitNavigation (LocalWindowProxy::Initialize -> MainThreadDebugger::ContextCreated).

**Fix**: The host registers contexts at the navigation observer's `committed` milestone, ordered around the per-session Page events: the FIRST page session on the tab resets the inspector group before its Page events (src/devtools/contexts.zig `beforeCommit`), the LAST session registers the new realms after them (`afterCommit`, from the Runtime domain's onNavigation); scripts a client added for new documents run later still, at the document-start hook, in the contexts already announced.

**Takeaway**: **The engine knows when a realm exists; only the navigation knows when its document is the frame's - announce contexts at the commit, in the order the browser's clients were measured to expect.**
