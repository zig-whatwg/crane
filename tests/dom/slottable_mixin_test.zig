//! Tests migrated from webidl/src/dom/Slottable.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

test "Slottable - initial state" {
    const TestSlottable = struct {
        slottable: Slottable = .{},
    };

    var obj = TestSlottable{};

    try std.testing.expectEqualStrings("", obj.slottable.getSlottableName());
    try std.testing.expectEqual(false, obj.slottable.isAssigned());
    try std.testing.expectEqual(@as(?*anyopaque, null), obj.slottable.getAssignedSlotInternal());
}
test "Slottable - set name" {
    const TestSlottable = struct {
        slottable: Slottable = .{},
    };

    var obj = TestSlottable{};

    obj.slottable.setSlottableName("test-slot");
    try std.testing.expectEqualStrings("test-slot", obj.slottable.getSlottableName());
}
test "Slottable - assign to slot" {
    const TestSlottable = struct {
        slottable: Slottable = .{},
    };

    var obj = TestSlottable{};
    var mock_slot: u32 = 42;

    obj.slottable.setAssignedSlot(@ptrCast(&mock_slot));
    try std.testing.expect(obj.slottable.isAssigned());
    try std.testing.expect(obj.slottable.getAssignedSlotInternal() != null);
}
test "Slottable - manual slot assignment" {
    const TestSlottable = struct {
        slottable: Slottable = .{},
    };

    var obj = TestSlottable{};
    var mock_slot: u32 = 42;

    obj.slottable.setManualSlotAssignment(@ptrCast(&mock_slot));
    try std.testing.expect(obj.slottable.getManualSlotAssignment() != null);
}