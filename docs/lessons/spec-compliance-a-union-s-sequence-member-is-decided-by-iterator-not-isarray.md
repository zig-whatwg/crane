# Spec Compliance: A union's sequence member is decided by @@iterator, not IsArray

**Date**: 2026-10-11
**Lesson**: WebIDL hands an Object to a union's sequence member when its @@iterator is not undefined (3.2.25 step 11.2), so an IsArray test silently misroutes every other iterable - a Headers object, a Map, a generator.

**Why**: Most script passes arrays, so an IsArray shortcut passes most tests. But the union algorithm asks GetMethod(V, @@iterator) before it ever considers a dictionary or record member, and the platform's own iterables (Headers, FormData, URLSearchParams, NodeList) are never Arrays. With the shortcut, an iterable that is no Array falls through to the record or dictionary member and is read as an object of its own enumerable properties - usually none - and nothing throws.

**What Happened**: The V8 adapter's HeadersInit converter (`convertHeadersInit`, conversions.zig) tested `v8_Value_IsArray` for the sequence<sequence<ByteString>> member. `new Headers(otherHeaders)`, `new Request(url, {headers: h})` and `fetch(url, {headers: h})` given a Headers object read it as a record with no own properties and sent no headers at all - the most common way real code passes headers. Codex row 19 found it (tmp/plans/codex-mime-questions.md Q11). The generic union path in `fromV8Value` had the same shortcut (`else if (IsArray)` for the sequence arm), so ConstrainDOMString, the GPU dictionaries-or-sequences and VibratePattern misrouted iterables too, and the plain sequence conversion rejected every non-Array iterable with a TypeError. The record member had its own gaps: no TypeError for a primitive (`new Headers("x")` made an empty Headers), V8's GetOwnPropertyNames instead of [[OwnPropertyKeys]] + [[GetOwnProperty]] (a Proxy saw the wrong traps), and no ByteString check.

**Fix**:
1. GetMethod(V, @@iterator) decides: present means the sequence member, created from that method through the iterator protocol (`protocol_conversions.createSequence`, now generic over where it runs so the binding's conversions share it); absent means the record or dictionary member.
2. Each item is converted before the next IteratorStepValue, so what its conversion observes interleaves with the iterator as the spec says.
3. The record member follows 3.2.23 exactly: [[OwnPropertyKeys]] (Symbols included), [[GetOwnProperty]] per key, the key converted before its [[Get]] (`v8_Object_OwnPropertyKeysCatching`, `IsOwnEnumerableCatching`, `GetByKeyCatching`).
4. An Array keeps the index fast path, as Blink's NativeValueTraits<IDLSequence<T>> does for anything IsArray() (crbug.com/715122).

**Takeaway**: **Never route a union by the JavaScript type you expect callers to pass - follow 3.2.25's steps, and test with a non-Array iterable and a Proxy that logs its traps.**
