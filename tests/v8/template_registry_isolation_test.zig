//! Phase 5 exit criterion: two isolates each holding a full interface template set.
//!
//! Verbatim from the migration plan: *"two isolates each hold a full 1,263-interface
//! template set simultaneously (impossible today, `template_registry.zig:166-175`)"*.
//!
//! Three things made it impossible or fragile, and each is covered here:
//!
//!   1. **Capacity.** `MAX_TEMPLATES` was 2048. One isolate's set already approaches
//!      that, so the second isolate ran off the end of a bounds check that silently
//!      did nothing. The failure surfaced much later, as a lookup miss that looks
//!      exactly like an unimplemented interface.
//!   2. **Keying.** `register` matched on NAME alone, while `getTemplateForIsolate`
//!      required name AND isolate. So isolate B registering "Element" reassigned
//!      isolate A's entry to B - and A then found nothing for an interface it had
//!      itself registered.
//!   3. **Ownership** (instances B2). The per-isolate maps lived in one process-wide
//!      table under a mutex, beside a process-wide generation every isolate's end
//!      bumped. Each isolate's registry is now its own template storage, in the
//!      isolate's data slot (isolate_templates.zig): nothing of another isolate
//!      reaches it, and it ends with its isolate.
//!
//! ## Why synthetic templates
//!
//! Neither `register` nor `getTemplateForIsolate` dereferences a template; they
//! compare addresses and copy slices. The isolates are real - each one's registry
//! lives in its data slot - but the templates are integers, which
//! `forgetIsolateForTest` ends without disposing.
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

fn newIsolate() !*ffi.Isolate {
    return ffi.v8_Isolate_New() orelse error.IsolateCreationFailed;
}

/// End an isolate whose registry holds synthetic templates: its storage goes
/// without disposing them, then the isolate.
fn endIsolate(isolate: *ffi.Isolate) void {
    registry.forgetIsolateForTest(isolate);
    ffi.v8_Isolate_Dispose(isolate);
}

fn interfaceNames(allocator: std.mem.Allocator) ![][]u8 {
    // Names must outlive registration: `register` stores the slice, it does not copy.
    const names = try allocator.alloc([]u8, FULL_INTERFACE_SET);
    for (names, 0..) |*n, i| n.* = try std.fmt.allocPrint(allocator, "Interface{d}", .{i});
    return names;
}

fn freeNames(allocator: std.mem.Allocator, names: [][]u8) void {
    for (names) |n| allocator.free(n);
    allocator.free(names);
}

test "PHASE 5 EXIT: two isolates hold a full interface template set simultaneously" {
    const allocator = std.testing.allocator;
    const isolate_a = try newIsolate();
    defer endIsolate(isolate_a);
    const isolate_b = try newIsolate();
    defer endIsolate(isolate_b);

    const names = try interfaceNames(allocator);
    defer freeNames(allocator, names);

    // Both sets live at once - B is registered without A being torn down first.
    // That simultaneity is the whole criterion; registering them in sequence with a
    // clear in between would pass even under the old single-isolate registry.
    for (names, 0..) |n, i| registry.register(n, @ptrFromInt(0x10_0000 + i * 8), isolate_a);
    for (names, 0..) |n, i| registry.register(n, @ptrFromInt(0x20_0000 + i * 8), isolate_b);

    try std.testing.expectEqual(@as(usize, FULL_INTERFACE_SET), registry.registeredCount(isolate_a));
    try std.testing.expectEqual(@as(usize, FULL_INTERFACE_SET), registry.registeredCount(isolate_b));

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
    const isolate_a = try newIsolate();
    defer endIsolate(isolate_a);
    const isolate_c = try newIsolate();
    defer endIsolate(isolate_c);

    registry.register("Element", @ptrFromInt(0x1111), isolate_a);

    try std.testing.expectEqual(
        @as(?*ffi.FunctionTemplate, null),
        registry.getTemplateForIsolate("Element", isolate_c),
    );
    try std.testing.expectEqual(@as(usize, 0), registry.registeredCount(isolate_c));
}

test "re-registering an interface replaces only that isolate's entry" {
    // The other half of per-(interface, isolate) keying. A genuine re-registration
    // must update in place: appending instead would grow the registry across a run
    // until it fills and starts dropping templates.
    const isolate_a = try newIsolate();
    defer endIsolate(isolate_a);
    const isolate_b = try newIsolate();
    defer endIsolate(isolate_b);

    registry.register("Element", @ptrFromInt(0x1111), isolate_a);
    registry.register("Element", @ptrFromInt(0x2222), isolate_b);
    registry.register("Element", @ptrFromInt(0x3333), isolate_a);
    try std.testing.expectEqual(@as(usize, 1), registry.registeredCount(isolate_a));
    try std.testing.expectEqual(@as(usize, 1), registry.registeredCount(isolate_b));

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
    const names = try interfaceNames(allocator);
    defer freeNames(allocator, names);

    const count = 12; // 12 x 1,263 = 15,156 entries, past the old 8,192
    var isolates: [count]*ffi.Isolate = undefined;
    for (&isolates) |*isolate| isolate.* = try newIsolate();
    defer for (isolates) |isolate| endIsolate(isolate);

    for (isolates, 0..) |isolate, k| {
        for (names, 0..) |n, i| registry.register(n, @ptrFromInt(0x100_0000 * (k + 1) + i * 8), isolate);
    }
    for (isolates, 0..) |isolate, k| {
        try std.testing.expectEqual(@as(usize, FULL_INTERFACE_SET), registry.registeredCount(isolate));
        for (names, 0..) |n, i| {
            const got = registry.getTemplateForIsolate(n, isolate) orelse return error.TemplateDropped;
            try std.testing.expectEqual(@as(usize, 0x100_0000 * (k + 1) + i * 8), @intFromPtr(got));
        }
    }
}

test "an isolate's registry ends with it" {
    // An ended isolate's entries go with it (clearForIsolate), so a process
    // that makes and ends isolates one after another never fills anything.
    // `forgetIsolateForTest` is clearForIsolate without disposing the
    // synthetic templates.
    for (0..20) |k| {
        const isolate = try newIsolate();
        defer ffi.v8_Isolate_Dispose(isolate);
        registry.register("EventTarget", @ptrFromInt(0x10_0000 + k * 8), isolate);
        registry.register("Event", @ptrFromInt(0x20_0000 + k * 8), isolate);
        try std.testing.expectEqual(@as(usize, 2), registry.registeredCount(isolate));
        registry.forgetIsolateForTest(isolate);
        try std.testing.expectEqual(@as(usize, 0), registry.registeredCount(isolate));
        try std.testing.expectEqual(@as(?*ffi.FunctionTemplate, null), registry.getTemplateForIsolate("Event", isolate));
    }
}

/// One thread's share of the concurrency test: isolates made and ended in
/// turn, each registering and reading back its own set.
const Churn = struct {
    base: usize,
    rounds: usize,
    missing: usize = 0,
    failed: bool = false,

    fn run(self: *Churn) void {
        const names = [_][]const u8{ "EventTarget", "Event", "Node", "Element", "Document", "Window", "XMLHttpRequest", "ProgressEvent" };
        for (0..self.rounds) |round| {
            const isolate = ffi.v8_Isolate_New() orelse {
                self.failed = true;
                return;
            };
            defer endIsolate(isolate);
            for (names, 0..) |n, i| registry.register(n, @ptrFromInt(self.base + round * 0x40 + i * 8 + 0x1000_0000), isolate);
            for (names, 0..) |n, i| {
                const got = registry.getTemplateForIsolate(n, isolate) orelse {
                    self.missing += 1;
                    continue;
                };
                if (@intFromPtr(got) != self.base + round * 0x40 + i * 8 + 0x1000_0000) self.missing += 1;
            }
        }
    }
};

test "isolates made and ended on two threads at once keep their own sets" {
    // Every Browser and every worker runs its agents on a thread of its own:
    // isolates are made, read and ended concurrently, and no lock is shared.
    var a: Churn = .{ .base = 0x10_0000_0000, .rounds = 100 };
    var b: Churn = .{ .base = 0x20_0000_0000, .rounds = 100 };
    const ta = try std.Thread.spawn(.{}, Churn.run, .{&a});
    const tb = try std.Thread.spawn(.{}, Churn.run, .{&b});
    ta.join();
    tb.join();
    try std.testing.expect(!a.failed and !b.failed);
    try std.testing.expectEqual(@as(usize, 0), a.missing);
    try std.testing.expectEqual(@as(usize, 0), b.missing);
}
