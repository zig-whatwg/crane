//! Implementation for WebIDL namespace: TestUtils
//!
//! WHATWG TestUtils Standard: https://testutils.spec.whatwg.org/
//!
//! TestUtils provides in-browser APIs for testing browser implementations.
//! These APIs must NOT be enabled in the default shipping configuration - they
//! are only available with special build flags or non-default preferences.
//!
//! ## Primary API
//!
//! - `gc()`: Triggers garbage collection and returns a Promise that resolves
//!   when GC completes. Per spec, GC runs "in parallel" (on a background thread).
//!
//! ## Compile-time Gating
//!
//! TestUtils should only be available when built with `-Denable-test-utils=true`.
//! This implementation provides the core functionality; build system integration
//! controls whether it's exposed to JavaScript.
//!
//! ## Engine Abstraction
//!
//! GC and the promise both go through the engine protocol
//! (`@import("engine")`), not direct V8 calls (AGENTS.md, "The engine
//! boundary"): static calls into the build's engine adapter.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");

/// Error set for TestUtils operations
pub const TestUtilsError = error{
    /// The realm has no agent recorded: the engine did not create it, so
    /// there is no heap of its to collect.
    NoAgent,
};

/// Operation: gc
///
/// The `gc()` method triggers garbage collection covering at least the entry Realm.
///
/// Per WHATWG TestUtils Standard:
/// 1. Let `p` be a new promise.
/// 2. Run the following in parallel:
///    2.1 Run implementation-defined steps to perform a garbage collection
///        covering at least the entry Realm.
///    2.2 Resolve `p`.
/// 3. Return `p`.
///
/// The collection runs synchronously, before `p` is returned: an engine's
/// collector runs on the thread that owns its heap, and "in parallel" here
/// only asks that script not be blocked from receiving `p`. So step 2.2 has
/// already happened when step 3 returns - `p` is a promise resolved with
/// undefined, made in the current realm.
pub fn call_gc(ctx: runtime.Context) anyerror!runtime.JSValue {
    const realm = engine.currentRealm() orelse ctx;

    // Step 2.1: implementation-defined steps to collect garbage - the whole
    // heap of the realm's agent, which covers the entry realm.
    engine.requestGarbageCollection(realm.agent orelse return TestUtilsError.NoAgent);

    // Steps 1, 2.2 and 3: p, resolved with undefined (Promise<undefined>).
    // OWNED: the binding takes it.
    const p = try engine.createResolvedPromise(realm, runtime.JSValue.jsUndefined);
    return p.take();
}

// ============================================================================
// Tests
// ============================================================================

test "TestUtils - module compiles" {
    // Basic compile test - actual V8 tests need integration test infrastructure
    _ = call_gc;
}
