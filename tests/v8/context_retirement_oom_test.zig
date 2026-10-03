//! A torn-down realm's runtime.Context stays a valid, inert record until its
//! agent ends - even when memory runs out at the moment it is retired.
//!
//! engine_protocol.zig's Context contract lets work queued on a realm's own
//! agent keep the Context across turns and ask `hasEngine()` whether the
//! realm still lives (src/webcrypto/tasks.zig, csp_violations.zig,
//! Location.zig, IndexedDB's queued requests). context_manager keeps every
//! retired entry on its `retired` list until the manager ends; retireEntry
//! used to fall back to FREEING the entry when appending to that list failed,
//! so a kept Context read freed memory instead of `hasEngine() == false`
//! (codex-indexeddb Q23, 2026-10-03). Retirement must not allocate.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

test "a realm retired while its manager's allocator fails stays readable, hasEngine() false" {
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    defer ffi.v8_Isolate_Exit(i);
    const scope = ffi.v8_HandleScope_New(i);
    defer if (scope) |s| ffi.v8_HandleScope_Dispose(s);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    defer ffi.v8_Context_Dispose(context);
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);

    // The manager's own allocator (its entries and its retired list) fails on
    // demand; under it, std.testing.allocator, so a freed entry is poisoned
    // and anything left behind at the end is reported as a leak.
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    try v8.context_manager.init(failing.allocator());
    defer v8.context_manager.deinit();
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);

    const realm = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    try std.testing.expect(realm.hasEngine());

    // From here on every allocation through the manager's allocator fails.
    failing.fail_index = failing.alloc_index;
    failing.resize_fail_index = failing.resize_index;

    v8.context_manager.removeContext(context);

    // Work that kept `realm` across turns asks this: the record must still be
    // the manager's (not freed and poisoned), retired and inert.
    try std.testing.expect(!realm.hasEngine());
    try std.testing.expect(realm.getRealm() == null);
    try std.testing.expect(v8.context_manager.get(context) == null);
}
