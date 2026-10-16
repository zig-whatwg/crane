# Spec Compliance: A secure context is the document's own URL and every ancestor's

**Date**: 2026-10-16
**Lesson**: Decide "is a secure context" from the window's current document - its own URL potentially trustworthy AND its parent a secure context, about:blank/srcdoc taking the creator's answer - not from a flag some creation path is supposed to set.

**Why**: HTML 8.1.3.5 reads only the top-level creation URL, which would make an http: frame in an https: page secure. WebKit (Document::computeIsSecureContext), Blink (SecurityContext::SetSecurityOrigin + LocalDOMWindow::HasInsecureContextInAncestors) and Firefox all check the document's own origin and every ancestor's, and wpt.fyi's secure-contexts/basic-popup-and-iframe-tests pass in all three on that rule.

**What Happened**: `Window.InternalState.is_secure_context` defaulted to `true` and its setter had no caller, so every http: page answered `isSecureContext === true` (found by Codex row 42 Q5 through Permissions). Windows are made on several paths (the page's Context, iframe realms, popups through the iframe integration, frame navigations) and a Crane top-level Window keeps its object across loads, so any "set it at creation" fix would have missed one path. Workers decided by a URL prefix and ignored their owner.

**Fix**:
1. `html.secure_context.ofDocument(url, parent, creator)` - Secure Contexts 3.2 on the document URL, AND the parent's answer; about:blank/about:srcdoc/javascript: take the parent's, else the creator's (a popup's opener, snapshotted when the popup is made).
2. Window's settings hook computes it on each call from `internal.document` and the navigable's parent's active window.
3. Workers: the owner's answer is read on the owner's thread when the worker starts (`ScopeSettings.owner_is_secure_context`), AND the worker's own URL (`ofWorker`; data: is trustworthy).

**Takeaway**: **An environment fact with a stored default and no writer is a bug waiting for its first reader - derive it from the state that decides it, at the moment it is asked.**
