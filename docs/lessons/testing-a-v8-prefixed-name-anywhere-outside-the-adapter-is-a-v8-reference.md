# Testing: A `v8_`-prefixed name anywhere outside the adapter is a V8 reference to lint-engine

**Date**: 2026-11-04
**Lesson**: lint-engine counts every identifier that starts with `v8_` outside src/runtime/engines/v8/ and tests/v8/, whatever it names - an enum literal like a log scope `.v8_interface` included.

**Why**: The engine-boundary ratchet (tools/lint_engine_boundary.zig) matches V8 references by token, not by meaning: a `v8_*` identifier is how the FFI's functions are spelled, so every such token is counted, and a file with none in the baseline that gains one fails `zig build test`.

**What Happened**: Lane compiletime1's tests/infra/test_log_level_test.zig checked `std.log.logEnabled(.debug, .v8_interface)` - the binding's log scope, the obvious one to name for "a debug log is compiled out". Every `zig build test` step of the next pool run failed on `engine boundary: 1 key(s) above the baseline ... tests/infra/test_log_level_test.zig v8_interface: allowed 0, found 2`, beside the compile results that were otherwise green.

**Fix**: Name a scope of the test's own (`.test_log_level`): the property tested - a debug log is compiled out - does not depend on which scope.

**Takeaway**: **Outside the V8 adapter, never spell a `v8_` token - not even a log scope or a string-free enum literal; lint-engine cannot tell it from an FFI call.**
