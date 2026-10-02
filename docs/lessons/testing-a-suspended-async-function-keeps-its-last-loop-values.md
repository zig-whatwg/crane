# Testing: A suspended async function can keep its last loop iteration's values - build WeakRef probes in a helper

**Date**: 2026-10-01
**Lesson**: A Crane test that makes objects in a `for` loop inside a `promise_test(async ...)` body, keeps only WeakRefs, then `await`s collections can see the LAST iteration's object survive: the suspended async function's saved registers still hold it.

**Why**: V8 saves a generator's or async function's live registers at each `await`; temporaries of a destructuring (`const { w, kept } = make()`) can stay in that register file after their scope ends. One frame of four survived every collection; making the same frames in a separate (synchronous) function that returns only the WeakRefs, they all went.

**Fix**: `const refs = (() => { ...make, push WeakRefs...; return refs; })();` before the first `await`.

**Takeaway**: **Before blaming the engine for an object a WeakRef still reaches, make sure no suspended function's frame holds it: build retention probes in a helper that returns only WeakRefs.**
