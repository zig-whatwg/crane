//! Phase 5 exit criterion: two isolates each holding a full interface template set.
//!
//! Verbatim from the migration plan: *"two isolates each hold a full 1,263-interface
//! template set simultaneously (impossible today, `template_registry.zig:166-175`)"*.
//!
//! Two separate things made it impossible, and both are covered here:
//!
//!   1. **Capacity.** `MAX_TEMPLATES` was 2048. One isolate's set already approaches
//!      that, so the second isolate ran off the end of a bounds check that silently
//!      did nothing. The failure surfaced much later, as a lookup miss that looks
//!      exactly like an unimplemented interface.
//!   2. **Keying.** `register` matched on NAME alone, while `getTemplateForIsolate`
//!      required name AND isolate. So isolate B registering "Element" reassigned
//!      isolate A's entry to B - and A then found nothing for an interface it had
//!      itself registered.
//!
//! ## Why synthetic pointers
//!
//! Neither `register` nor `getTemplateForIsolate` dereferences a template or an
//! isolate; they compare addresses and copy slices. Standing up two real V8 isolates
//! would test V8's lifetime rules instead of the registry's logic, would need a
//! platform and a snapshot, and would drag the fragile teardown path into a unit
//! test. The registry's behaviour is what is in question, so the registry is what is
//! tested.
//!
//! ## Why this file is not next to the code
//!
//! Test blocks inside `src/runtime/engines/v8/*.zig` never run: the build collects
//! `tests/**/ *_test.zig` and nothing else. A test written beside the registry is a
//! test that does not exist - the same trap that hid `tests/wpt_runner/main.zig`'s
//! test blocks.

const std = @import("std");
const v8 = @import("v8");
const registry = v8.template_registry;
const ffi = v8.ffi;

/// Number of generated WebIDL interfaces, as of the Phase 5 exit criterion.
///
/// It does not have to track `src/webidl/interfaces/root.zig` exactly. The claim is
/// that two sets of this order fit and stay separable, so a stale constant makes the
/// test weaker, never wrong.
const FULL_INTERFACE_SET = 1263;

/// Borrow the process-global registry and put it back exactly as found.
///
/// `registry.clear()` disposes real V8 handles, which would mean calling
/// `v8_FunctionTemplate_Dispose` on the integers below. `resetForTest` exists for
/// precisely this reason.
fn borrowRegistry() void {
    registry.resetForTest();
}

test "PHASE 5 EXIT: two isolates hold a full interface template set simultaneously" {
    const allocator = std.testing.allocator;

    borrowRegistry();
    defer registry.resetForTest();

    const isolate_a: *ffi.Isolate = @ptrFromInt(0x1000);
    const isolate_b: *ffi.Isolate = @ptrFromInt(0x2000);

    // Names must outlive registration: `register` stores the slice, it does not copy.
    const names = try allocator.alloc([]u8, FULL_INTERFACE_SET);
    defer {
        for (names) |n| allocator.free(n);
        allocator.free(names);
    }
    for (names, 0..) |*n, i| n.* = try std.fmt.allocPrint(allocator, "Interface{d}", .{i});

    // Both sets live at once - B is registered without A being torn down first.
    // That simultaneity is the whole criterion; registering them in sequence with a
    // clear in between would pass even under the old single-isolate registry.
    for (names, 0..) |n, i| registry.register(n, @ptrFromInt(0x10_0000 + i * 8), isolate_a);
    for (names, 0..) |n, i| registry.register(n, @ptrFromInt(0x20_0000 + i * 8), isolate_b);

    try std.testing.expectEqual(@as(usize, FULL_INTERFACE_SET * 2), registry.registeredCount());

    // Each isolate gets ITS OWN template back, for every interface. Under name-only
    // keying every one of these returned B's template or nothing at all.
    for (names, 0..) |n, i| {
        const from_a = registry.getTemplateForIsolate(n, isolate_a) orelse {
            std.log.err("isolate A lost '{s}'", .{n});
            return error.TemplateMissingForIsolateA;
        };
        const from_b = registry.getTemplateForIsolate(n, isolate_b) orelse {
            std.log.err("isolate B lost '{s}'", .{n});
            return error.TemplateMissingForIsolateB;
        };
        try std.testing.expectEqual(@as(usize, 0x10_0000 + i * 8), @intFromPtr(from_a));
        try std.testing.expectEqual(@as(usize, 0x20_0000 + i * 8), @intFromPtr(from_b));
        try std.testing.expect(from_a != from_b);
    }
}

test "a third isolate that registered nothing finds nothing" {
    // Without this, the test above would still pass if lookup quietly fell back to
    // "any template with this name" - which is the old bug wearing a different hat.
    borrowRegistry();
    defer registry.resetForTest();

    const isolate_a: *ffi.Isolate = @ptrFromInt(0x1000);
    const isolate_c: *ffi.Isolate = @ptrFromInt(0x3000);

    registry.register("Element", @ptrFromInt(0x1111), isolate_a);

    try std.testing.expectEqual(
        @as(?*ffi.FunctionTemplate, null),
        registry.getTemplateForIsolate("Element", isolate_c),
    );
}

test "re-registering an interface replaces only that isolate's entry" {
    // The other half of per-(interface, isolate) keying. A genuine re-registration
    // must update in place: appending instead would grow the registry across a run
    // until it fills and starts dropping templates.
    borrowRegistry();
    defer registry.resetForTest();

    const isolate_a: *ffi.Isolate = @ptrFromInt(0x1000);
    const isolate_b: *ffi.Isolate = @ptrFromInt(0x2000);

    registry.register("Element", @ptrFromInt(0x1111), isolate_a);
    registry.register("Element", @ptrFromInt(0x2222), isolate_b);
    try std.testing.expectEqual(@as(usize, 2), registry.registeredCount());

    registry.register("Element", @ptrFromInt(0x3333), isolate_a);
    try std.testing.expectEqual(@as(usize, 2), registry.registeredCount());

    try std.testing.expectEqual(
        @as(usize, 0x3333),
        @intFromPtr(registry.getTemplateForIsolate("Element", isolate_a).?),
    );
    // B must be untouched. This is the exact assertion that failed before the fix.
    try std.testing.expectEqual(
        @as(usize, 0x2222),
        @intFromPtr(registry.getTemplateForIsolate("Element", isolate_b).?),
    );
}

test "isolates alive at once each keep a full set, however many there are" {
    // A file with many shared workers holds one isolate per worker, each with
    // its full set: shared-worker-options-credentials.html made the fixed
    // 8,192-entry table drop 5,058 registrations, and the NEXT file's
    // dedicated worker - its registrations dropped - made a second template
    // for each constructible interface it looked up (createTemplateFresh), so
    // XMLHttpRequestEventTarget.prototype's [[Prototype]] was not that realm's
    // EventTarget.prototype (xhr/idlharness.any.worker.html 151/160 after it,
    // 153/160 alone).
    const allocator = std.testing.allocator;
    borrowRegistry();
    defer registry.resetForTest();

    const isolates = 12; // 12 x 1,263 = 15,156 entries, past the old 8,192
    const names = try allocator.alloc([]u8, FULL_INTERFACE_SET);
    defer {
        for (names) |n| allocator.free(n);
        allocator.free(names);
    }
    for (names, 0..) |*n, i| n.* = try std.fmt.allocPrint(allocator, "Interface{d}", .{i});

    for (0..isolates) |k| {
        const isolate: *ffi.Isolate = @ptrFromInt(0x1000 * (k + 1));
        for (names, 0..) |n, i| registry.register(n, @ptrFromInt(0x100_0000 * (k + 1) + i * 8), isolate);
    }
    try std.testing.expectEqual(@as(usize, FULL_INTERFACE_SET * isolates), registry.registeredCount());
    for (0..isolates) |k| {
        const isolate: *ffi.Isolate = @ptrFromInt(0x1000 * (k + 1));
        for (names, 0..) |n, i| {
            const got = registry.getTemplateForIsolate(n, isolate) orelse return error.TemplateDropped;
            try std.testing.expectEqual(@as(usize, 0x100_0000 * (k + 1) + i * 8), @intFromPtr(got));
        }
    }
}

test "isolates made and ended in sequence leave nothing behind" {
    // An ended isolate's entries go with it (clearForIsolate), so a process
    // that makes and ends isolates one after another never fills anything.
    // `forgetIsolateForTest` is clearForIsolate without disposing the
    // synthetic templates.
    borrowRegistry();
    defer registry.resetForTest();

    for (0..50) |k| {
        const isolate: *ffi.Isolate = @ptrFromInt(0x1000 * (k + 1));
        registry.register("EventTarget", @ptrFromInt(0x10_0000 + k * 8), isolate);
        registry.register("Event", @ptrFromInt(0x20_0000 + k * 8), isolate);
        try std.testing.expectEqual(@as(usize, 2), registry.registeredCount());
        registry.forgetIsolateForTest(isolate);
        try std.testing.expectEqual(@as(usize, 0), registry.registeredCount());
        try std.testing.expectEqual(@as(?*ffi.FunctionTemplate, null), registry.getTemplateForIsolate("Event", isolate));
    }
}

/// One thread's share of the concurrency test: isolates made and ended in
/// turn, each registering and reading back its own set.
const Churn = struct {
    base: usize,
    rounds: usize,
    missing: usize = 0,

    fn run(self: *Churn) void {
        const names = [_][]const u8{ "EventTarget", "Event", "Node", "Element", "Document", "Window", "XMLHttpRequest", "ProgressEvent" };
        for (0..self.rounds) |round| {
            const isolate: *ffi.Isolate = @ptrFromInt(self.base + round * 0x40);
            for (names, 0..) |n, i| registry.register(n, @ptrFromInt(self.base + round * 0x40 + i * 8 + 0x1000_0000), isolate);
            for (names, 0..) |n, i| {
                const got = registry.getTemplateForIsolate(n, isolate) orelse {
                    self.missing += 1;
                    continue;
                };
                if (@intFromPtr(got) != self.base + round * 0x40 + i * 8 + 0x1000_0000) self.missing += 1;
            }
            registry.forgetIsolateForTest(isolate);
        }
    }
};

test "isolates made and ended on two threads at once keep their own sets" {
    // Workers will run on threads of their own: isolates are made, read and
    // ended concurrently, and the registry is shared by all of them.
    borrowRegistry();
    defer registry.resetForTest();

    var a: Churn = .{ .base = 0x10_0000_0000, .rounds = 4000 };
    var b: Churn = .{ .base = 0x20_0000_0000, .rounds = 4000 };
    const ta = try std.Thread.spawn(.{}, Churn.run, .{&a});
    const tb = try std.Thread.spawn(.{}, Churn.run, .{&b});
    ta.join();
    tb.join();
    try std.testing.expectEqual(@as(usize, 0), a.missing);
    try std.testing.expectEqual(@as(usize, 0), b.missing);
    try std.testing.expectEqual(@as(usize, 0), registry.registeredCount());
}
