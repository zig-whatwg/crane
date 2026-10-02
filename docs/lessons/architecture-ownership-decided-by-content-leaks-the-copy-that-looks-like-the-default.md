# Architecture: Ownership decided by content leaks the copy that looks like the default

**Date**: 2026-10-02
**Lesson**: `Window.InternalState.origin` defaults to the literal `"null"`, and both its free in `setOrigin` and the one in `deinit` asked `!eql(origin, "null")` - "is this allocated?" answered by the string's contents. `setOrigin` copied every origin, `"null"` included, and that copy was never freed.

**Why**: Contents cannot say who owns a string. Any value the caller can pass that equals the default sentinel makes an allocation the check calls static.

**What Happened**: A frame nested in a sandboxed document gets the opaque origin's serialization, `"null"`, from HTMLIFrameElement.attachRealm: one copy when the frame is made and one per navigation that replaces its realm. 2 leaks per cookies/samesite/sandbox-iframe-nested.https.html and content-security-policy/frame-ancestors/frame-ancestors-sandbox-same-origin-self.html run alone.

**Fix**: Keep the invariant the check relies on at the only writer: `setOrigin` stores `"null"` as the literal and copies anything else, so "not `"null"`" is exactly "allocated". (Deciding by identity - a named default compared by pointer - is the other sound answer.)

**Takeaway**: **Ownership is a fact recorded where the value is stored, not a property read off the value later. A check by contents is right only if the writer guarantees the sentinel is never a copy.**
