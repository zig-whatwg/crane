# Architecture: A shared V8 security token is a cached access decision

**Date**: 2026-10-12
**Lesson**: Give every Window realm its own security token, and answer V8's access check from the host on every access. Two contexts that share a token reach each other without V8 asking anything.

**Why**: `Isolate::MayAccess` grants access to another context's global proxy outright when the two contexts' security tokens are equal. Only on a mismatch does it call the template's access-check callback. A token shared between realms is therefore an access decision taken once and kept. HTML's IsPlatformObjectSameOrigin is a different kind of answer: it compares origins, and document.domain changes them. The answer for the same pair of realms can flip between two accesses, in either direction.

**What Happened**: Crane's frames took their parent's security token so that V8 would let a page reach its iframes. No access check was installed. So V8 ran none of HTML 7.2.1's cross-origin internal methods, and every cross-origin WindowProxy and Location behaved as a same-origin one. Only Window.get_document ran a check of its own, against the incumbent realm. When the access checks were added (lane xorigin2), copying the token would have defeated them: V8 would never ask about a frame that shared its parent's token, even after the frame set document.domain.

**Fix**:
1. In `createWindowRealm`, keep V8's default token (the realm's own global object) for every realm, frames included.
2. Install `ObjectTemplate::SetAccessCheckCallbackAndHandler` on the Window global template and on Location's instance template. The callback answers the current realm itself in C++. For any other realm it asks the host's `WindowRealmOptions.is_platform_object_same_origin` (`dom.cross_origin`, over the documents' origin records) and keeps nothing.
3. A failed check reaches the handler's interceptors, which implement CrossOriginGet/Set/GetOwnProperty/OwnPropertyKeys. Cache only the cross-origin *functions*, per (current realm, object realm); never cache a decision.
4. A Location has no same-context shortcut in V8: its access check runs on every property access, so its fast path (same creation context) belongs in C++.

**Takeaway**: **An engine fast path that skips a check is a cache of that check's answer. When the answer can change (document.domain), the fast path must not apply: one token per realm, and the host asked on every access.** Blink takes its token fast path only for documents that have not set document.domain, and falls back to the default token otherwise (LocalWindowProxy::SetSecurityToken).
