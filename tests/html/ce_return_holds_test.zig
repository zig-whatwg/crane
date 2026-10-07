const std = @import("std");
const testing = std.testing;
const PendingReturns = @import("html_core").custom_element_returns.PendingReturns;

const Hold = struct {
    released: *usize,
    pub fn release(self: Hold) void {
        self.released.* += 1;
    }
};
const Returns = PendingReturns(u32, Hold);

test "CE return: agent teardown releases holds when the microtask never runs" {
    var first: usize = 0;
    var second: usize = 0;
    var returns = Returns.init(testing.allocator);
    try testing.expect(try returns.append(10, .{ .released = &first }));
    try testing.expect(!try returns.append(20, .{ .released = &second }));
    try testing.expectEqual(@as(usize, 0), first + second);
    returns.deinit();
    try testing.expectEqual(@as(usize, 1), first);
    try testing.expectEqual(@as(usize, 1), second);
}

test "CE return: realm cleanup and a later microtask release each hold once" {
    var first: usize = 0;
    var second: usize = 0;
    var returns = Returns.init(testing.allocator);
    defer returns.deinit();
    _ = try returns.append(10, .{ .released = &first });
    _ = try returns.append(20, .{ .released = &second });
    returns.clearRealm(10);
    try testing.expectEqual(@as(usize, 1), first);
    try testing.expectEqual(@as(usize, 0), second);
    returns.releaseAll();
    try testing.expectEqual(@as(usize, 1), first);
    try testing.expectEqual(@as(usize, 1), second);
    try testing.expect(try returns.append(20, .{ .released = &second }));
    returns.releaseAll();
    try testing.expectEqual(@as(usize, 2), second);
}

test "CE return: a retired realm still owns its independent return handle" {
    var retired: usize = 0;
    var live: usize = 0;
    var returns = Returns.init(testing.allocator);
    _ = try returns.append(99, .{ .released = &retired });
    _ = try returns.append(10, .{ .released = &live });
    returns.deinit();
    try testing.expectEqual(@as(usize, 1), retired);
    try testing.expectEqual(@as(usize, 1), live);
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    var released: usize = 0;
    var accepted: usize = 0;
    var returns = Returns.init(allocator);
    defer {
        returns.deinit();
        std.debug.assert(released == accepted);
    }
    for (0..30) |_| {
        _ = try returns.append(10, .{ .released = &released });
        accepted += 1;
    }
}

test "CE return: allocation failure leaves the unaccepted hold with the caller" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}
