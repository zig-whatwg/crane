//! runtime.TabScope (lane tab1; docs/instances.md rule 2): a tab's scope
//! ends its slots in their order when the tab closes, takes nothing once
//! closed, and is freed by its last holder.
const std = @import("std");
const runtime = @import("runtime");
const TabScope = runtime.TabScope;
const testing = std.testing;

/// A slot's state for the tests: it records its end.
const Probe = struct {
    ended: *std.ArrayListUnmanaged(u8),
    tag: u8,
    fn deinit(self: *Probe) void {
        self.ended.append(testing.allocator, self.tag) catch {};
    }
};

fn probe(scope: *TabScope, ended: *std.ArrayListUnmanaged(u8), tag: u8) !*Probe {
    const value = try scope.allocator.create(Probe);
    value.* = .{ .ended = ended, .tag = tag };
    return value;
}

test "a tab's close ends its slots in Slot order, and its last holder frees it" {
    const before = TabScope.liveCount();
    var ended: std.ArrayListUnmanaged(u8) = .empty;
    defer ended.deinit(testing.allocator);
    const scope = try TabScope.create(testing.allocator, 7);
    try testing.expectEqual(before + 1, TabScope.liveCount());
    // Put in another order than they end.
    try testing.expect(scope.put(.session_storage, Probe, try probe(scope, &ended, 's')));
    try testing.expect(scope.put(.session_history, Probe, try probe(scope, &ended, 'h')));
    try testing.expect(scope.put(.traversal_queue, Probe, try probe(scope, &ended, 'q')));
    try testing.expectEqual(@as(u8, 'h'), scope.get(.session_history, Probe).?.tag);
    try testing.expect(scope.get(.frames, Probe) == null);

    // A realm holds it past the record's end.
    _ = scope.retain();
    scope.close();
    try testing.expectEqualStrings("qhs", ended.items);
    try testing.expect(scope.closed);
    try testing.expect(scope.get(.session_history, Probe) == null);
    scope.release();
    try testing.expectEqual(before + 1, TabScope.liveCount());
    // A closed tab takes nothing more: what is handed over ends at once.
    try testing.expect(!scope.put(.frames, Probe, try probe(scope, &ended, 'f')));
    try testing.expectEqualStrings("qhsf", ended.items);
    scope.release();
    try testing.expectEqual(before, TabScope.liveCount());
}

test "a tab scope freed unclosed ends its slots" {
    var ended: std.ArrayListUnmanaged(u8) = .empty;
    defer ended.deinit(testing.allocator);
    const scope = try TabScope.create(testing.allocator, 1);
    try testing.expect(scope.put(.frames, Probe, try probe(scope, &ended, 'f')));
    scope.release();
    try testing.expectEqualStrings("f", ended.items);
}

test "system focus answers for emulation too" {
    const scope = try TabScope.create(testing.allocator, 1);
    defer scope.release();
    try testing.expect(scope.hasSystemFocus());
    scope.system_focus = false;
    try testing.expect(!scope.hasSystemFocus());
    scope.focus_emulation = 1;
    try testing.expect(scope.hasSystemFocus());
}
