//! The computed custom property record (lane vars1): shared by reference,
//! chained after WebKit's Style::CustomPropertyData (reference the root
//! record, reference a parent with more than 8 values, copy a smaller one,
//! at most 4 ancestors), a guaranteed-invalid entry hiding an inherited
//! value, and the computed-style enumeration order (integrator Q3).
const std = @import("std");
const css = @import("css");

const testing = std.testing;
const Allocator = std.mem.Allocator;
const cp = css.custom_properties;
const Record = cp.CustomProperties;
const Entry = Record.Entry;

/// Owned entries for a record's changes: names and values made here, the
/// caller releases them after create() retained what it keeps.
const Changes = struct {
    allocator: Allocator,
    items: std.ArrayList(Entry) = .empty,

    fn add(self: *Changes, name: []const u8, value: ?[]const u8) !void {
        const n = try cp.Text.create(self.allocator, name);
        errdefer n.release();
        const v = if (value) |text| try cp.Text.create(self.allocator, text) else null;
        errdefer if (v) |t| t.release();
        try self.items.append(self.allocator, .{ .name = n, .value = v });
    }

    fn deinit(self: *Changes) void {
        for (self.items.items) |e| {
            e.name.release();
            if (e.value) |v| v.release();
        }
        self.items.deinit(self.allocator);
    }
};

fn expectValue(record: *const Record, name: []const u8, expected: ?[]const u8) !void {
    const got = record.get(name);
    if (expected) |e| {
        try testing.expect(got != null);
        try testing.expectEqualStrings(e, got.?.bytes);
    } else try testing.expect(got == null);
}

test "lookup walks the chain; a guaranteed-invalid entry hides the inherited value" {
    var root_changes: Changes = .{ .allocator = testing.allocator };
    defer root_changes.deinit();
    try root_changes.add("--a", "1");
    try root_changes.add("--b", "2");
    const root = try Record.create(testing.allocator, null, root_changes.items.items);
    defer root.release();
    var child_changes: Changes = .{ .allocator = testing.allocator };
    defer child_changes.deinit();
    try child_changes.add("--b", null);
    try child_changes.add("--c", "3");
    const child = try Record.create(testing.allocator, root, child_changes.items.items);
    defer child.release();
    try expectValue(child, "--a", "1");
    try expectValue(child, "--b", null);
    try testing.expect(child.lookup("--b") == .invalid);
    try testing.expect(child.lookup("--z") == .absent);
    try expectValue(child, "--c", "3");
    try expectValue(root, "--b", "2");
    // The root record is referenced, never copied.
    try testing.expectEqual(root, child.parent.?);
    try testing.expectEqual(@as(usize, 2), child.entries.len);
}

test "a small non-root parent is copied, a large one referenced, chains capped at 4" {
    var root_changes: Changes = .{ .allocator = testing.allocator };
    defer root_changes.deinit();
    try root_changes.add("--root", "r");
    const root = try Record.create(testing.allocator, null, root_changes.items.items);
    defer root.release();
    var small_changes: Changes = .{ .allocator = testing.allocator };
    defer small_changes.deinit();
    try small_changes.add("--s", "s");
    const small = try Record.create(testing.allocator, root, small_changes.items.items);
    defer small.release();
    var next_changes: Changes = .{ .allocator = testing.allocator };
    defer next_changes.deinit();
    try next_changes.add("--n", "n");
    const next = try Record.create(testing.allocator, small, next_changes.items.items);
    defer next.release();
    // `small` (one value, not the root) was folded in: `next` points past it.
    try testing.expectEqual(root, next.parent.?);
    try testing.expectEqual(@as(usize, 2), next.entries.len);
    try expectValue(next, "--s", "s");
    try expectValue(next, "--root", "r");

    // A chain of large records: each references the last, up to 4 deep.
    var records: std.ArrayList(*Record) = .empty;
    defer {
        for (records.items) |r| r.release();
        records.deinit(testing.allocator);
    }
    var parent: *Record = root;
    for (0..7) |level| {
        var changes: Changes = .{ .allocator = testing.allocator };
        defer changes.deinit();
        for (0..Record.reference_threshold + 1) |i| {
            var name_buffer: [32]u8 = undefined;
            try changes.add(try std.fmt.bufPrint(&name_buffer, "--l{d}-{d}", .{ level, i }), "v");
        }
        const record = try Record.create(testing.allocator, parent, changes.items.items);
        try records.append(testing.allocator, record);
        try testing.expect(record.ancestors <= Record.max_ancestors);
        parent = record;
    }
    // Every value of every level is still found.
    try expectValue(parent, "--l0-0", "v");
    try expectValue(parent, "--l6-8", "v");
    try expectValue(parent, "--root", "r");
}

test "names: valid values only, overridden once, in code-point order" {
    var root_changes: Changes = .{ .allocator = testing.allocator };
    defer root_changes.deinit();
    try root_changes.add("--b", "1");
    try root_changes.add("--gone", "x");
    try root_changes.add("--Z", "z");
    const root = try Record.create(testing.allocator, null, root_changes.items.items);
    defer root.release();
    var child_changes: Changes = .{ .allocator = testing.allocator };
    defer child_changes.deinit();
    try child_changes.add("--a", "2");
    try child_changes.add("--b", "3");
    try child_changes.add("--gone", null);
    const child = try Record.create(testing.allocator, root, child_changes.items.items);
    defer child.release();
    const names = try child.names(testing.allocator);
    defer testing.allocator.free(names);
    try testing.expectEqual(@as(usize, 3), names.len);
    try testing.expectEqualStrings("--Z", names[0]);
    try testing.expectEqualStrings("--a", names[1]);
    try testing.expectEqualStrings("--b", names[2]);
}

test "values are shared by reference, not copied" {
    const text = try cp.Text.create(testing.allocator, "shared");
    defer text.release();
    const name = try cp.Text.create(testing.allocator, "--x");
    defer name.release();
    const record = try Record.create(testing.allocator, null, &.{.{ .name = name, .value = text }});
    try testing.expectEqual(text, record.get("--x").?);
    try testing.expectEqual(@as(u32, 2), text.refs);
    record.retain();
    record.release();
    record.release();
    try testing.expectEqual(@as(u32, 1), text.refs);
}

test "Text equality is by bytes and taint" {
    const a = try cp.Text.create(testing.allocator, "x y");
    defer a.release();
    const b = try cp.Text.create(testing.allocator, "x y");
    defer b.release();
    const c = try cp.Text.create(testing.allocator, "x  y");
    defer c.release();
    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
}

fn buildAll(allocator: Allocator) !void {
    var root_changes: Changes = .{ .allocator = allocator };
    defer root_changes.deinit();
    try root_changes.add("--a", "1");
    try root_changes.add("--b", null);
    const root = try Record.create(allocator, null, root_changes.items.items);
    defer root.release();
    var child_changes: Changes = .{ .allocator = allocator };
    defer child_changes.deinit();
    try child_changes.add("--a", "2");
    try child_changes.add("--c", "3");
    const child = try Record.create(allocator, root, child_changes.items.items);
    defer child.release();
    const names = try child.names(allocator);
    allocator.free(names);
}

test "allocation failure leaks nothing" {
    try testing.checkAllAllocationFailures(testing.allocator, buildAll, .{});
}
