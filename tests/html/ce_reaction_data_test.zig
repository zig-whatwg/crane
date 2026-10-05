//! Owned reaction data can be tested without starting an engine. The test
//! adapter counts retained/released values; std.testing.allocator sees bytes.
const std = @import("std");
const testing = std.testing;
const Counts = struct { retained: usize = 0, released: usize = 0 };
const Runtime = struct {
    pub const Context = *Counts;
    pub const Instance = struct { id: u32 };
    pub const JSValue = union(enum) { instance: *Instance, integer: u32 };
};
const Engine = struct {
    pub const Owned = struct {
        value: Runtime.JSValue,
        counts: ?*Counts = null,
        pub fn release(self: Owned) void {
            if (self.counts) |counts| counts.released += 1;
        }
    };
    pub const CallbackFunction = struct {
        function: Owned,
        context: ?Runtime.Context,
        pub fn release(self: CallbackFunction) void {
            self.function.release();
        }
    };
    pub fn retainValue(context: Runtime.Context, value: Runtime.JSValue) !Owned {
        context.retained += 1;
        // A wrapped platform value remains a JS value after the native
        // Instance ends; model the wrapper by its independent identity.
        return .{ .value = switch (value) {
            .instance => |instance| .{ .integer = instance.id },
            else => value,
        }, .counts = context };
    }
};
const Reaction = @import("html_core").custom_element_reaction.Reaction(Runtime, Engine);

test "CE reaction data: attribute strings are snapshots and callback context is retained" {
    var counts = Counts{};
    const callback = Engine.CallbackFunction{ .function = .{ .value = .{ .integer = 1 } }, .context = &counts };
    var old = "before".*;
    var new = "after".*;
    var reaction = try Reaction.initCallback(testing.allocator, &counts, callback, .attribute_changed, .{ .attribute_changed = .{
        .local_name = "observed",
        .old_value = &old,
        .new_value = &new,
        .namespace = "urn:ce-test",
    } });
    @memset(&old, 'x');
    @memset(&new, 'y');
    const args = reaction.callback_args.?.attribute_changed;
    try testing.expectEqualStrings("before", args.old_value.?);
    try testing.expectEqualStrings("after", args.new_value.?);
    try testing.expectEqualStrings("observed", args.local_name);
    try testing.expectEqualStrings("urn:ce-test", args.namespace.?);
    try testing.expect(reaction.callbackFunction().?.context == &counts);
    reaction.deinit();
    try testing.expectEqual(@as(usize, 1), counts.retained);
    try testing.expectEqual(counts.retained, counts.released);
}

test "CE reaction data: adoption holds both document arguments until dropped" {
    var counts = Counts{};
    const callback = Engine.CallbackFunction{ .function = .{ .value = .{ .integer = 1 } }, .context = &counts };
    var old = Runtime.Instance{ .id = 1 };
    var new = Runtime.Instance{ .id = 2 };
    var reaction = try Reaction.initCallback(testing.allocator, &counts, callback, .adopted, .{ .adopted = .{
        .old_document = &old,
        .new_document = &new,
    } });
    try testing.expectEqual(@as(usize, 3), counts.retained);
    try testing.expectEqual(@as(usize, 0), counts.released);
    reaction.deinit();
    try testing.expectEqual(counts.retained, counts.released);
}

test "CE reaction data: adoption invokes the retained values after document instances retire" {
    var counts = Counts{};
    const callback = Engine.CallbackFunction{ .function = .{ .value = .{ .integer = 1 } }, .context = &counts };
    const old = try testing.allocator.create(Runtime.Instance);
    const new = try testing.allocator.create(Runtime.Instance);
    old.* = .{ .id = 7 };
    new.* = .{ .id = 8 };
    var reaction = try Reaction.initCallback(testing.allocator, &counts, callback, .adopted, .{ .adopted = .{
        .old_document = old,
        .new_document = new,
    } });
    testing.allocator.destroy(old);
    testing.allocator.destroy(new);
    const values = reaction.adoptedValues().?;
    try testing.expectEqual(@as(u32, 7), values[0].integer);
    try testing.expectEqual(@as(u32, 8), values[1].integer);
    reaction.deinit();
    try testing.expectEqual(counts.retained, counts.released);
}

fn allocationFailures(allocator: std.mem.Allocator) !void {
    var counts = Counts{};
    defer std.debug.assert(counts.retained == counts.released);
    const callback = Engine.CallbackFunction{ .function = .{ .value = .{ .integer = 1 } }, .context = &counts };
    var reaction = try Reaction.initCallback(allocator, &counts, callback, .attribute_changed, .{ .attribute_changed = .{
        .local_name = "observed",
        .old_value = "before",
        .new_value = "after",
        .namespace = "urn:test",
    } });
    defer reaction.deinit();
}

test "CE reaction data: every partial snapshot allocation is released on failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailures, .{});
}
