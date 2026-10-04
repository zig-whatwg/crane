//! The engine-neutral records of HTML 2.7.1's serialization and
//! deserialization steps (src/runtime/serialization_record.zig): what one
//! writes the other reads back in order, doubles by their bits, byte
//! sequences copied, sub-serializations in order, and a record shorter than
//! its reader expects is a DataCloneError rather than a read past its end.

const std = @import("std");
const runtime = @import("runtime");
const SerializationRecord = runtime.SerializationRecord;
const DeserializationRecord = runtime.DeserializationRecord;

test "fields read back in the order they were written" {
    var serialized = SerializationRecord.init(std.testing.allocator, false);
    defer serialized.deinit();
    try serialized.writeUint32(0xDEADBEEF);
    try serialized.writeBool(true);
    try serialized.writeString("NotFoundError");
    try serialized.writeUint64(1 << 40);
    try serialized.writeInt64(-42);
    try serialized.writeBool(false);
    try serialized.writeBytes(&.{ 0, 255, 7 });

    var reader: DeserializationRecord = .{ .bytes = serialized.bytes.items };
    try std.testing.expectEqual(@as(u32, 0xDEADBEEF), try reader.readUint32());
    try std.testing.expect(try reader.readBool());
    try std.testing.expectEqualStrings("NotFoundError", try reader.readString());
    try std.testing.expectEqual(@as(u64, 1 << 40), try reader.readUint64());
    try std.testing.expectEqual(@as(i64, -42), try reader.readInt64());
    try std.testing.expect(!try reader.readBool());
    try std.testing.expectEqualSlices(u8, &.{ 0, 255, 7 }, try reader.readBytes());
    try std.testing.expectEqual(serialized.bytes.items.len, reader.position);
}

test "a double keeps its bits: -0, the infinities and NaN" {
    var serialized = SerializationRecord.init(std.testing.allocator, false);
    defer serialized.deinit();
    const values = [_]f64{ -0.0, std.math.inf(f64), -std.math.inf(f64), std.math.nan(f64), 3.25, -1e300 };
    for (values) |v| try serialized.writeDouble(v);

    var reader: DeserializationRecord = .{ .bytes = serialized.bytes.items };
    for (values) |v| {
        const got = try reader.readDouble();
        try std.testing.expectEqual(@as(u64, @bitCast(v)), @as(u64, @bitCast(got)));
    }
}

test "a byte sequence is copied into the record, not referenced" {
    var serialized = SerializationRecord.init(std.testing.allocator, true);
    defer serialized.deinit();
    var source = [_]u8{ 1, 2, 3 };
    try serialized.writeBytes(&source);
    source[0] = 9;
    var reader: DeserializationRecord = .{ .bytes = serialized.bytes.items };
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, try reader.readBytes());
    try std.testing.expect(serialized.for_storage);
}

test "sub-serializations come back in order, and no more than were written" {
    var serialized = SerializationRecord.init(std.testing.allocator, false);
    defer serialized.deinit();
    try serialized.subSerialize(.{ .number = 1 });
    try serialized.subSerialize(.{ .boolean = true });
    try std.testing.expectEqual(@as(usize, 2), serialized.sub_values.items.len);

    var reader: DeserializationRecord = .{ .bytes = &.{}, .sub_values = serialized.sub_values.items };
    try std.testing.expectEqual(@as(f64, 1), (try reader.subDeserialize()).number);
    try std.testing.expect((try reader.subDeserialize()).boolean);
    try std.testing.expectError(error.DataCloneError, reader.subDeserialize());
}

test "a record shorter than its reader expects is a DataCloneError" {
    var reader: DeserializationRecord = .{ .bytes = &.{ 1, 2, 3 } };
    try std.testing.expectError(error.DataCloneError, reader.readUint32());
    // A length that claims more bytes than the record holds.
    var serialized = SerializationRecord.init(std.testing.allocator, false);
    defer serialized.deinit();
    try serialized.writeUint64(1000);
    try serialized.writeUint32(7);
    var lying: DeserializationRecord = .{ .bytes = serialized.bytes.items };
    try std.testing.expectError(error.DataCloneError, lying.readBytes());
    var bad_bool: DeserializationRecord = .{ .bytes = &.{2} };
    try std.testing.expectError(error.DataCloneError, bad_bool.readBool());
}
