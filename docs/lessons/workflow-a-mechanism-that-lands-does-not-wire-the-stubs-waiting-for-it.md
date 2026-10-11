# Workflow: A mechanism that lands does not wire the stubs waiting for it

**Date**: 2026-10-10
**Lesson**: When an answer says "use X when it lands", the stub that waits for X stays a stub until someone owns the wiring - grep for its TODO when X lands.

**Why**: A design question answered across lanes splits one change in two: the lane that builds the mechanism, and the stub in another lane's code that will call it. The first lands with its own tests green; nothing fails when the second never happens, because the stub's rejection is the behaviour everybody already measured.

**What Happened**: WebCrypto's Q18 (2026-10-02) decided that a BufferSource argument arrives as a borrowed reference to its JS object and each method copies it at its own step. SubtleCrypto got a helper, `copyTypedBufferSource`, that returned `NotSupportedError` with `TODO(Q18): use the adapter's exact accessor`, and a "row-3 follow-up" was queued to wire it. The accessor (`BufferSource.jsValue`) landed the same evening in dfa3b038fd; importKey started using it; the follow-up never ran. For eight days every encrypt, decrypt, sign, verify, digest and unwrapKey call rejected `NotSupportedError` - 2,886 + 1,242 + 596 non-passing subtests in encrypt_decrypt, sign_verify and wrapKey_unwrapKey alone - and engfix's JWK fix (53e5563602) sat dormant behind it. The fix was one line (lane bufsrc, b55f683b68).

**Fix**:
1. When a mechanism lands, `grep -rn "TODO(Q<n>)"` (and the question's name) across `src/` and wire every waiting stub in the same change, or name each one in the merge report as a queued row.
2. A stub that waits for another lane's work says so in a form a search finds: `TODO(Q<n>)` plus the exact accessor it will call.

**Takeaway**: **Landing a mechanism is half the change; the stubs that wait for it are the other half - find them by their TODO when it lands.**
