const std = @import("std");
const testing = std.testing;
const Runtime = struct {
    pub const Instance = struct { id: u8 };
};
const Engine = struct {
    pub const CallbackFunction = struct {
        pub fn release(_: @This()) void {}
    };
};
const Definition = @import("html_core").custom_element_definition.Definition(Runtime, Engine);

test "CE construction: an empty stack selects fresh construction without allocating a marker" {
    const definition = try Definition.init(testing.allocator, "ce-stack", "ce-stack", .{});
    defer definition.deinit();
    try testing.expectEqual(@as(?*Runtime.Instance, null), try definition.takeConstructionElement());
    try testing.expectEqual(@as(usize, 0), definition.construction_stack.items.len);
}

test "CE construction: a nested new or double super can consume an upgrade entry only once" {
    const definition = try Definition.init(testing.allocator, "ce-stack", "ce-stack", .{});
    defer definition.deinit();
    var element = Runtime.Instance{ .id = 1 };
    try definition.construction_stack.append(testing.allocator, .{ .element = &element });
    try testing.expectEqual(@as(?*Runtime.Instance, &element), try definition.takeConstructionElement());
    try testing.expectError(error.TypeError, definition.takeConstructionElement());
    try testing.expectEqual(@as(usize, 1), definition.construction_stack.items.len);
    try testing.expect(definition.construction_stack.items[0] == .already_constructed);
    _ = definition.construction_stack.pop();
    try testing.expectEqual(@as(?*Runtime.Instance, null), try definition.takeConstructionElement());
}

test "CE construction: a nested upgrade restores the older entry when its marker is popped" {
    const definition = try Definition.init(testing.allocator, "ce-stack", "ce-stack", .{});
    defer definition.deinit();
    var outer = Runtime.Instance{ .id = 1 };
    var inner = Runtime.Instance{ .id = 2 };
    try definition.construction_stack.append(testing.allocator, .{ .element = &outer });
    try definition.construction_stack.append(testing.allocator, .{ .element = &inner });
    try testing.expectEqual(@as(?*Runtime.Instance, &inner), try definition.takeConstructionElement());
    try testing.expectError(error.TypeError, definition.takeConstructionElement());
    _ = definition.construction_stack.pop();
    try testing.expectEqual(@as(?*Runtime.Instance, &outer), try definition.takeConstructionElement());
}
