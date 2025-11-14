//! Tests migrated from src/webidl/wrappers.zig
//! Per WHATWG specifications

const std = @import("std");

const webidl = @import("webidl");
const source = @import("../../src/webidl/wrappers.zig");

test "Nullable - null value" {
    var value = Nullable(u32).null_value();
    try testing.expect(value.isNull());
    try testing.expectEqual(@as(?u32, null), value.get());
}
test "Nullable - some value" {
    var value = Nullable(u32).some(42);
    try testing.expect(!value.isNull());
    try testing.expectEqual(@as(?u32, 42), value.get());
}
test "Nullable - set and get" {
    var value = Nullable(u32).null_value();
    value.set(100);
    try testing.expect(!value.isNull());
    try testing.expectEqual(@as(u32, 100), value.value);

    value.setNull();
    try testing.expect(value.isNull());
}
test "Optional - not passed" {
    const opt = Optional(i32).notPassed();
    try testing.expect(!opt.wasPassed());
    try testing.expectEqual(@as(i32, 42), opt.getOrDefault(42));
}
test "Optional - passed" {
    const opt = Optional(i32).passed(100);
    try testing.expect(opt.wasPassed());
    try testing.expectEqual(@as(i32, 100), opt.getValue());
}
test "Sequence - basic operations" {
    const allocator = testing.allocator;

    var seq = Sequence(u32).init(allocator);
    defer seq.deinit();

    try testing.expect(seq.isEmpty());
    try testing.expectEqual(@as(usize, 0), seq.len());

    try seq.append(1);
    try seq.append(2);
    try seq.append(3);

    try testing.expectEqual(@as(usize, 3), seq.len());
    try testing.expectEqual(@as(u32, 1), seq.get(0));
    try testing.expectEqual(@as(u32, 2), seq.get(1));
    try testing.expectEqual(@as(u32, 3), seq.get(2));
}
test "Sequence - remove" {
    const allocator = testing.allocator;

    var seq = Sequence(u32).init(allocator);
    defer seq.deinit();

    try seq.append(10);
    try seq.append(20);
    try seq.append(30);

    const removed = try seq.remove(1);
    try testing.expectEqual(@as(u32, 20), removed);
    try testing.expectEqual(@as(usize, 2), seq.len());
    try testing.expectEqual(@as(u32, 30), seq.get(1));
}
test "Record - basic operations" {
    const allocator = testing.allocator;

    var rec = Record([]const u8, u32).init(allocator);
    defer rec.deinit();

    try testing.expect(rec.isEmpty());

    try rec.set("apples", 5);
    try rec.set("oranges", 3);

    try testing.expectEqual(@as(usize, 2), rec.len());
    try testing.expect(rec.has("apples"));
    try testing.expectEqual(@as(?u32, 5), rec.get("apples"));
    try testing.expectEqual(@as(?u32, 3), rec.get("oranges"));
    try testing.expectEqual(@as(?u32, null), rec.get("bananas"));
}
test "Record - remove" {
    const allocator = testing.allocator;

    var rec = Record([]const u8, i32).init(allocator);
    defer rec.deinit();

    try rec.set("key1", 100);
    try rec.set("key2", 200);

    rec.remove("key1");
    try testing.expect(!rec.has("key1"));
    try testing.expect(rec.has("key2"));
    try testing.expectEqual(@as(usize, 1), rec.len());
}
test "Promise - states" {
    const pending = Promise(u32).pending();
    try testing.expect(pending.isPending());
    try testing.expect(!pending.isFulfilled());
    try testing.expect(!pending.isRejected());

    const fulfilled = Promise(u32).fulfilled(42);
    try testing.expect(fulfilled.isFulfilled());
    try testing.expectEqual(@as(u32, 42), fulfilled.state.fulfilled);

    const rejected = Promise(u32).rejected("Error occurred");
    try testing.expect(rejected.isRejected());
    try testing.expectEqualStrings("Error occurred", rejected.state.rejected);
}