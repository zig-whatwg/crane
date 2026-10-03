# Architecture: Two release rules that can both claim a type release its handle twice

**Date**: 2026-10-02
**Lesson**: When a code path releases a handle under one ownership predicate and, separately, under another, the two predicates must be disjoint by construction; a type both claim is released twice.

**Why**: The binding's dictionary member loop releases a member's Get handle in a `defer` when `argHandleIsCopied(T)` (the conversion copied out of it), and in a separate branch when the value no longer refers to it (`argumentHandleIsKeptInValue(T)` and `keptArgumentHandle(T, value) == null`). Each predicate was right on its own. A recursive "kept in value" rule over unions - every arm copied or a buffer source - also matched BodyInit, whose XMLHttpRequestBodyInit arm holds a BufferSource; but `convertBodyInit` copies the bytes, so BodyInit is (correctly) copied too. Both branches ran for a RequestInit's `body` member.

**What Happened**: A targeted WPT run after the buffer-source change: 108 CRASH, 98 of them fetch/api (every `fetch(url, init)` and `new Request(url, init)` converts RequestInit), the rest FileAPI files that fetch. The unit tests were green - none converted a dictionary with a copied member that the new rule also matched. streams/, WebCryptoAPI/, webidl/, compression/ were identical to the baseline, which is what made the cause easy to see: only RequestInit was different.

**Fix**: `argumentHandleIsKeptInValue(T)` (and `bufferHandleIsKeptInValue`) answer false for any type `argHandleIsCopied` accepts - the rules are disjoint by definition, not by luck - and a test pins it over a list of copied types, BodyInit and ?BodyInit among them, plus a handle count for `new Request(url, { body })` against a control.

**Takeaway**: **Two predicates that each license a release must exclude each other in their own definitions; write the exclusion into the newer one and pin it with the type that would satisfy both.**
