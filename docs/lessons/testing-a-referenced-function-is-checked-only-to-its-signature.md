# Testing: A referenced function is checked only to its signature; its address emits its body

**Date**: 2026-10-18
**Lesson**: `_ = X.member;` resolves the declaration and its signature and nothing else; `_ = &X.member;` analyses the body - and analysing a body means emitting it, so everything it calls must link.

**Why**: Zig analyses a function body when the function is referenced at runtime: taking its address, calling it, or putting it in a table. A bare `_ = f;` needs only the function's type. Analysis and code generation are not separable: a probe with `_ = @TypeOf(&f);`, where `f` calls an undefined extern, failed to LINK (`undefined symbol: _missing_symbol`) - so even `@TypeOf` of the address emits the body.

**What Happened**: Lane impls6 moved tests/streams/integration_test.zig's existence checks from `_ = impls.ReadableStream.call_tee;` (a declaration check of the impl, which the impls boundary forbids) to the generated interface. `_ = interfaces.ReadableStream.call_tee;` would pass even if the impl lost `call_tee`: the interface declares the member from the IDL, and its body - the call into the impl - is never analysed. `_ = &interfaces.ReadableStream.call_tee;` does fail when the impl loses the member (the red check: "no member named 'call_tee'"), but the gate's tests-streams step then failed to link on 326 `_v8_*` symbols: tests/streams is built without V8, and the members' bodies call the engine. The address checks moved to tests/v8/streams_interface_members_test.zig, which links V8; tests/streams kept the checks that need neither impl nor engine.

**Fix**:
1. To check that an impl member exists through its interface, take the member's address (`_ = &interfaces.X.member;`), and put the check in a test directory whose binary links what the body calls.
2. `@TypeOf(interfaces.X.member)` (no `&`) is the way to read a signature without emitting anything.
3. Make it red once: rename the member in the impl and see the test fail to compile.

**Takeaway**: **`_ = f` checks a declaration; `_ = &f` checks the body and emits it - choose by what the test must catch, and build it where the body links.**
