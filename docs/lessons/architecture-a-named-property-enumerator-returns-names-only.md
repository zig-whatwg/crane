# Architecture: A named property enumerator returns names only

**Date**: 2026-10-12
**Lesson**: A V8 named interceptor's enumerator must return Strings only. A number in its array aborts V8 the first time a filtered key collection (Object.keys, for-in, spread) reaches an unproxied object.

**Why**: KeyAccumulator::FilterForEnumerableProperties asks the named query interceptor about each key the named enumerator returned, after `CHECK(IsName(*element))` (src/objects/keys.cc). The check runs only for a filtered collection, and only when the interceptor has a query: Object.keys, for-in, `{...o}` and Object.entries filter, while Reflect.ownKeys and Object.getOwnPropertyNames do not. Indices belong to the indexed interceptor's enumerator. KeyAccumulator::CollectOwnKeys collects those before property names, which is WebIDL 3.9.6's order.

**What Happened**: Crane's named enumerator returned step 2's indices as Integers, then step 3's names. Every interface with both getters was a legacy platform object proxy, and the proxy's ownKeys trap calls Reflect.ownKeys on its target, which does not filter. So nothing hit the CHECK. Codex row 23 bound HTMLFormElement's indexed and named getters, and a form is not proxied. `Object.keys(form)` then aborted the runner with "Check failed: IsName(*element)" (lpo-form-named.html, bl-named-property-own-keys.html, lane bindlpo's combined run).

**Fix**: The named enumerator lists only the visible supported property names. The indexed enumerator, installed wherever the named one listed indices (an indexed getter and `length`), lists the indices. Where codegen records that browsers list no names (HTMLFormElement), no named enumerator is installed, as Blink does for a [NotEnumerable] named getter.

**Takeaway**: **An interceptor returns the key type its kind names, and a proxy in front of an object can hide what the object's own callbacks do wrong: test an unproxied object of every interceptor shape.**
