//! DOM § 3.3 "abort algorithms", as the hook other specifications reach.
//!
//! An AbortSignal's abort algorithms are spec-internal: no IDL member adds
//! one, yet Streams (`pipeTo`'s step 14), Fetch and `addEventListener`'s
//! `signal` option all need to. The list itself lives in the AbortSignal
//! impl's state and is freed with it; this module is only the seam between
//! that impl and its consumers, so neither imports the other's impl - the
//! same shape as `mutation.zig`'s insertion-steps registry.
//!
//! AbortSignal installs the implementation when the first signal is created,
//! which is necessarily before anyone holds a signal to add an algorithm to.
//!
//! lint-impls: hook for AbortSignal

const runtime = @import("runtime");

/// An abort algorithm: `run(ctx)` once, when the signal is aborted. `ctx`
/// identifies it for removal.
pub const Algorithm = struct {
    ctx: *anyopaque,
    run: *const fn (ctx: *anyopaque) void,
};

/// What AbortSignal supplies.
pub const Implementation = struct {
    add: *const fn (signal: *runtime.Instance, algorithm: Algorithm) anyerror!void,
    remove: *const fn (signal: *runtime.Instance, ctx: *anyopaque) void,
};

/// Per thread: a worker's signals are created, and aborted, on its own thread.
threadlocal var implementation: ?Implementation = null;

/// Called by AbortSignal. Idempotent: every call installs the same functions.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// "Add an algorithm to an AbortSignal": does nothing if the signal is
/// already aborted (step 1), otherwise appends it (step 2).
pub fn add(signal: *runtime.Instance, algorithm: Algorithm) !void {
    const impl = implementation orelse return error.NotSupported;
    return impl.add(signal, algorithm);
}

/// "Remove an algorithm from an AbortSignal": every algorithm whose `ctx`
/// is `ctx`.
pub fn remove(signal: *runtime.Instance, ctx: *anyopaque) void {
    const impl = implementation orelse return;
    impl.remove(signal, ctx);
}

test "add without an installed implementation reports NotSupported, remove is a no-op" {
    const std = @import("std");
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation neither call reaches it.
    var signal: runtime.Instance = undefined;
    var ctx: u8 = 0;
    const noop = struct {
        fn run(_: *anyopaque) void {}
    }.run;
    try std.testing.expectError(error.NotSupported, add(&signal, .{ .ctx = &ctx, .run = noop }));
    remove(&signal, &ctx);
}
