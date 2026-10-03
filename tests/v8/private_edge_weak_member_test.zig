//! A private-property edge to a wrapper that only a weak handle holds.
//!
//! The wrapper cache holds every wrapper weakly, and a wrapper made a moment
//! ago is reachable from nothing yet - not even from the edge that is about to
//! be drawn to it. `v8_Object_PrivateSetUpdate` (node tracing: a parent's
//! wrapper keeping its children's) used to allocate the holder's Set FIRST and
//! read the member's handle after. A scavenge started by that allocation
//! collected the member, its first-pass callback reset the handle, and the
//! Set was handed an empty Local. `v8_Object_SetPrivateRef`,
//! `PrivateRefUpdate` and `RetainInPrivateArray` had the same order. The
//! cache-hit prototype reset in `template_registry.wrapInstanceAsV8Object` had
//! the same window, and it crashed workers/semantics/structured-clone/
//! dedicated.html (docs/lessons/
//! architecture-a-weakly-held-wrapper-dies-at-the-next-allocation.md).
//!
//! No V8 flag forces a collection at one allocation in this build, so the test
//! makes the window's allocation the common one instead. Each round makes a
//! fresh holder (its first add allocates a Set) and a fresh member armed weak,
//! and does nothing else. Most young-generation bytes are then allocated
//! inside the window, so the scavenges this loop triggers land there. A canary
//! counts how many collections ran, so the test cannot pass vacuously.

const std = @import("std");
const testing = std.testing;
const v8 = @import("v8");
const ffi = v8.ffi;

/// A live isolate with an entered context. One test binary per file
/// (`addTestFilesFromDir`), so this process owns the V8 platform; one isolate
/// for the file, never torn down (see weak_callback_ownership_test.zig).
const Env = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

var env_once: ?Env = null;

fn env() !Env {
    if (env_once) |e| return e;
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(isolate);
    _ = ffi.v8_HandleScope_New(isolate);
    const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    env_once = .{ .isolate = isolate, .context = context };
    return env_once.?;
}

fn noop(_: ?*anyopaque, _: usize) callconv(.c) void {}

fn countCollected(data: ?*anyopaque, _: usize) callconv(.c) void {
    const counter: *usize = @ptrCast(@alignCast(data orelse return));
    counter.* += 1;
}

const children_key = "crane:test:children";

test "a member only a weak handle holds survives its edge being drawn" {
    const e = try env();

    var collected_canaries: usize = 0;
    var canaries: std.ArrayListUnmanaged(*ffi.Object) = .empty;
    defer {
        for (canaries.items) |c| ffi.v8_Object_Dispose(c);
        canaries.deinit(testing.allocator);
    }

    const rounds: usize = 100_000;
    var round: usize = 0;
    while (round < rounds) : (round += 1) {
        const holder = ffi.v8_Object_New(e.isolate) orelse return error.ObjectCreationFailed;
        defer ffi.v8_Object_Dispose(holder);
        const member = ffi.v8_Object_New(e.isolate) orelse return error.ObjectCreationFailed;
        defer ffi.v8_Object_Dispose(member);
        // As the wrapper cache holds a wrapper script has not kept: weakly,
        // and by nothing else.
        ffi.v8_Global_SetWeak(@ptrCast(member), null, noop);

        ffi.v8_Object_PrivateSetUpdate(@ptrCast(holder), children_key.ptr, children_key.len, @ptrCast(member), true);

        // The holder's Set holds the member now, and the holder is held: the
        // member must have survived every collection since it was made.
        try testing.expect(!ffi.v8_Global_IsEmpty(@ptrCast(member)));

        if (round % 1000 == 0) {
            const canary = ffi.v8_Object_New(e.isolate) orelse return error.ObjectCreationFailed;
            ffi.v8_Global_SetWeak(@ptrCast(canary), @ptrCast(&collected_canaries), countCollected);
            try canaries.append(testing.allocator, canary);
        }
    }

    // Collections ran while the loop did: the windows were exercised.
    try testing.expect(collected_canaries > 0);
}
