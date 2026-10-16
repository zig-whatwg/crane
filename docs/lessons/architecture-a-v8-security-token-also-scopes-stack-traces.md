# Architecture: A V8 security token also scopes stack traces

**Date**: 2026-10-16
**Lesson**: When realms stop sharing a V8 security token, every V8 feature keyed on the token changes with the access checks - stack traces first. A stack read that means "the agent's stack" must pass `StackTrace::kExposeFramesAcrossSecurityOrigins`.

**Why**: `StackTrace::CurrentStackTrace` (isolate.cc, VisitStack) skips every frame whose native context has another security token than the CURRENT context, unless the options include `kExposeFramesAcrossSecurityOrigins`. The current context is the realm of the function running now, so a page's script that calls into its frame's realm (a native member of the frame, the frame's eval) is invisible from inside that call once page and frame have different tokens. `Function.prototype.caller` is keyed the same way (accessors.cc AllowAccessToFunction); `Error.stack` is not (its builder has no token check).

**What Happened**: Lane xorigin2 gave every Window realm its own token so V8 would run its access check on every cross-realm access ([A shared V8 security token is a cached access decision](architecture-a-shared-security-token-is-a-cached-access-decision.md)). `v8_Isolate_HasJavaScriptOnStack` counted frames with the default options. The page's `iframe.contentDocument.open()` ran "clean up after running script" in the frame's realm (aborting the frame's fetch); with the page's frames hidden the stack read as empty, and it performed a microtask checkpoint in the middle of the page's script. abort-while-navigating.window.js "(fetch())" saw the fetch's rejection one statement early (9/9 -> 8/9). Nothing about access checks pointed at microtasks: a probe that logged the order of `micro`, the rejection and each statement found it.

**Fix**:
1. `v8_Isolate_HasJavaScriptOnStack`: `CurrentStackTrace(isolate, 1, kExposeFramesAcrossSecurityOrigins)`.
2. `v8_Isolate_RunningScriptLocation` (CSP's running script position, the protocol's "agent's topmost frame"): `kDetailed | kExposeFramesAcrossSecurityOrigins`.
3. A tests/v8 test in which the frame's code generation hook, run by the page's `w.eval()`, must see the page's frame.

**Takeaway**: **A per-realm security token is not only an access-check switch: grep the V8 source for HasSameSecurityTokenAs and security_token() before changing tokens, and give every agent-wide stack read kExposeFramesAcrossSecurityOrigins.** Blink gives same-origin documents one token, so its stack reads see same-origin frames without the flag; Crane's realms have one token each by design.
