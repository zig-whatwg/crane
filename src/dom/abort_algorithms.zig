//! DOM § 3.3 "abort algorithms", as the hook other specifications reach.
//!
//! An AbortSignal's abort algorithms are spec-internal: no IDL member adds
//! one, yet Streams (`pipeTo`'s step 14), Fetch and `addEventListener`'s
//! `signal` option all need to. The list itself lives in the AbortSignal
//! impl's state and is freed with it; this module is only the seam between
//! that impl and its consumers, so neither imports the other's impl - the
//! same shape as `mutation.zig`'s insertion-steps registry.
//!
//! AbortSignal installs the implementation once, at process start
//! (process_start.zig) - before any page runs. Installed by the first signal
//! instead, `fetch(url)`, which asks for a dependent signal from « » (the
//! Request constructor's step 30), found none on a page that had made no
//! signal yet (docs/lessons/architecture-a-threadlocal-hook-installed-by-the-first-owner.md).
//!
//! lint-impls: hook for AbortSignal

const process_start = @import("process_start.zig");
const runtime = @import("runtime");

/// An abort algorithm: `run(ctx)` once, when the signal is aborted. `ctx`
/// identifies it for removal. The signal holds the algorithm until it runs
/// or is removed; `drop(ctx)`, when given, is called instead of `run` for an
/// algorithm the signal discards unrun because the signal itself is going
/// away - the one place that can free a `ctx` nobody else holds.
pub const Algorithm = struct {
    ctx: *anyopaque,
    run: *const fn (ctx: *anyopaque) void,
    drop: ?*const fn (ctx: *anyopaque) void = null,
};

/// What AbortSignal supplies.
pub const Implementation = struct {
    add: *const fn (signal: *runtime.Instance, algorithm: Algorithm) anyerror!void,
    remove: *const fn (signal: *runtime.Instance, ctx: *anyopaque) void,
    create_dependent: *const fn (ctx: runtime.Context, signals: []const *runtime.Instance) anyerror!*runtime.Instance,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;

/// Called by AbortSignal's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// "Add an algorithm to an AbortSignal": does nothing if the signal is
/// already aborted (step 1), otherwise appends it (step 2).
pub fn add(signal: *runtime.Instance, algorithm: Algorithm) !void {
    const impl = implementation orelse return error.NotSupported;
    return impl.add(signal, algorithm);
}

/// DOM § 3.3 "create a dependent abort signal" from `signals`, using
/// AbortSignal, in `ctx`'s realm - as Fetch's Request constructor and
/// clone() do.
pub fn createDependent(ctx: runtime.Context, signals: []const *runtime.Instance) !*runtime.Instance {
    const impl = implementation orelse return error.NotSupported;
    return impl.create_dependent(ctx, signals);
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
