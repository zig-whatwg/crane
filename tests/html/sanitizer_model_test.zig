const std = @import("std");
const model = @import("html").sanitizer;

fn htmlName(local: []const u8) model.Name {
    return .{ .local = local, .namespace = model.html_namespace };
}

test "Sanitizer canonicalizes processing instruction lists and rejects duplicates" {
    var targets = [_][]const u8{ "z", "a" };
    var allow = try model.Config.fromData(std.testing.allocator, .{ .processing_instructions = &targets }, false);
    defer allow.deinit();
    var remove = try model.Config.fromData(std.testing.allocator, .{ .remove_processing_instructions = targets[0..1] }, true);
    defer remove.deinit();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const config = try allow.toData(arena.allocator());
    try std.testing.expectEqualStrings("a", config.processing_instructions.?[0]);
    try std.testing.expectEqual(@as(?bool, false), config.javascript_urls);
    try std.testing.expectEqual(@as(?bool, true), (try remove.toData(arena.allocator())).javascript_urls);
    var duplicates = [_][]const u8{ "x", "x" };
    try std.testing.expectError(error.TypeError, model.Config.fromData(std.testing.allocator, .{ .processing_instructions = &duplicates }, true));
    try std.testing.expectError(error.TypeError, model.Config.fromData(std.testing.allocator, .{
        .processing_instructions = &.{},
        .remove_processing_instructions = &.{},
    }, true));
}

test "Sanitizer modifiers own inputs and reclaim replaced configurations" {
    var config = try model.Config.fromData(std.testing.allocator, .{ .elements = &.{} }, true);
    defer config.deinit();
    var input = [_]u8{ 'p', 'r', 'e' };
    try std.testing.expect(try config.apply(.{ .allow_element = .{ .name = htmlName(&input) } }));
    input[0] = 'x';
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectEqualStrings("pre", (try config.toData(arena.allocator())).elements.?[0].name.local);
    const capacity = config.arena.queryCapacity();
    for (0..40) |_| {
        try std.testing.expect(try config.apply(.{ .remove_element = htmlName("pre") }));
        try std.testing.expect(try config.apply(.{ .allow_element = .{ .name = htmlName("pre") } }));
        try std.testing.expectEqual(capacity, config.arena.queryCapacity());
    }
}

test "Sanitizer get sorts by UTF16 code units with null namespaces first" {
    var names = [_]model.Name{
        .{ .local = "\u{e000}" },
        .{ .local = "a", .namespace = "urn:z" },
        .{ .local = "\u{10000}" },
    };
    var config = try model.Config.fromData(std.testing.allocator, .{ .remove_attributes = &names }, true);
    defer config.deinit();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const attributes = (try config.toData(arena.allocator())).remove_attributes.?;
    try std.testing.expectEqualStrings("\u{10000}", attributes[0].local);
    try std.testing.expectEqualStrings("\u{e000}", attributes[1].local);
    try std.testing.expectEqualStrings("a", attributes[2].local);
    try std.testing.expect(attributes[0].namespace == null);
}

test "Sanitizer invalid global and local lists fail without leaking" {
    var html = [_]model.Name{htmlName("html")};
    var data = [_]model.Name{.{ .local = "data-a" }};
    var title = [_]model.Name{.{ .local = "title" }};
    var lang = [_]model.Name{.{ .local = "lang" }};
    var elements = [_]model.Element{.{ .name = htmlName("div"), .remove_attributes = &lang }};
    const invalid = [_]model.Data{
        .{ .elements = &.{}, .remove_elements = &.{} },
        .{ .attributes = &.{}, .remove_attributes = &.{} },
        .{ .data_attributes = false },
        .{ .replace_elements = &html },
        .{ .attributes = &data },
        .{ .attributes = &title, .elements = &elements },
    };
    for (invalid) |input| try std.testing.expectError(error.TypeError, model.Config.fromData(std.testing.allocator, input, true));
}

fn allocationFailures(allocator: std.mem.Allocator) anyerror!void {
    var elements = [_]model.Element{.{ .name = htmlName("pre") }};
    var config = try model.Config.fromData(allocator, .{ .elements = &elements }, true);
    defer config.deinit();
    _ = config.apply(.{ .allow_element = .{ .name = htmlName("div") } }) catch |err| {
        try std.testing.expectEqual(@as(usize, 1), config.data.elements.?.len);
        try std.testing.expectEqualStrings("pre", config.data.elements.?[0].name.local);
        return err;
    };
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    _ = try config.toData(arena.allocator());
}

test "Sanitizer allocation failure preserves the preceding configuration" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationFailures, .{});
}

test "Sanitizer safe baseline removes base and leaves arbitrary on-prefixed attributes" {
    var config = try model.Config.fromData(std.testing.allocator, .{}, true);
    defer config.deinit();
    try std.testing.expect(try config.apply(.remove_unsafe));
    try std.testing.expect(!try config.apply(.{ .remove_element = htmlName("base") }));
    try std.testing.expect(!try config.apply(.{ .remove_attribute = .{ .local = "onclick" } }));
    try std.testing.expect(try config.apply(.{ .remove_attribute = .{ .local = "onmadeup" } }));
    try std.testing.expect(!try config.apply(.remove_unsafe));
}

test "Sanitizer modifiers keep global and element attribute lists consistent" {
    var global = [_]model.Name{.{ .local = "title" }};
    var config = try model.Config.fromData(std.testing.allocator, .{
        .elements = &.{},
        .attributes = &global,
        .data_attributes = false,
    }, true);
    defer config.deinit();
    var local = [_]model.Name{ .{ .local = "lang" }, .{ .local = "lang" }, .{ .local = "title" }, .{ .local = "data-x" } };
    var removed = [_]model.Name{ .{ .local = "title" }, .{ .local = "ghost" }, .{ .local = "title" } };
    const change = model.Change{ .allow_element = .{ .name = htmlName("div"), .attributes = &local, .remove_attributes = &removed } };
    try std.testing.expect(try config.apply(change));
    try std.testing.expect(!try config.apply(change));
    try std.testing.expectEqual(@as(usize, 2), config.data.elements.?[0].attributes.?.len);
    try std.testing.expectEqual(@as(usize, 1), config.data.elements.?[0].remove_attributes.?.len);
    try std.testing.expect(try config.apply(.{ .allow_attribute = .{ .local = "lang" } }));
    try std.testing.expectEqual(@as(usize, 1), config.data.elements.?[0].attributes.?.len);
    try std.testing.expect(try config.apply(.{ .data_attributes = true }));
    try std.testing.expectEqual(@as(usize, 0), config.data.elements.?[0].attributes.?.len);
    try std.testing.expect(try config.apply(.{ .remove_attribute = .{ .local = "title" } }));
    try std.testing.expectEqual(@as(usize, 0), config.data.elements.?[0].remove_attributes.?.len);
    try std.testing.expect(try config.apply(.{ .replace_element = htmlName("div") }));
    try std.testing.expectEqual(@as(usize, 0), config.data.elements.?.len);
    try std.testing.expect(try config.apply(.{ .remove_element = htmlName("div") }));
    try std.testing.expectEqual(@as(usize, 0), config.data.replace_elements.?.len);
    try std.testing.expect(!try config.apply(.{ .replace_element = htmlName("html") }));
}

test "Sanitizer remove-list modifiers distinguish namespaces and reject local rules" {
    var config = try model.Config.fromData(std.testing.allocator, .{}, true);
    defer config.deinit();
    var attributes = [_]model.Name{.{ .local = "title" }};
    try std.testing.expect(!try config.apply(.{ .allow_element = .{ .name = htmlName("div"), .attributes = &attributes } }));
    try std.testing.expect(try config.apply(.{ .remove_element = htmlName("div") }));
    try std.testing.expect(try config.apply(.{ .remove_element = .{ .local = "div" } }));
    try std.testing.expectEqual(@as(usize, 2), config.data.remove_elements.?.len);
    try std.testing.expect(try config.apply(.{ .allow_element = .{ .name = htmlName("div") } }));
    try std.testing.expectEqual(@as(usize, 1), config.data.remove_elements.?.len);
    try std.testing.expect(config.data.remove_elements.?[0].namespace == null);
    try std.testing.expect(try config.apply(.{ .remove_attribute = .{ .local = "title" } }));
    try std.testing.expect(try config.apply(.{ .allow_attribute = .{ .local = "title" } }));
    try std.testing.expect(!try config.apply(.{ .data_attributes = false }));
}

test "setDataAttributes(true) may leave data-* names in an element's removeAttributes (row 41 review M1: no panic)" {
    // The spec's setDataAttributes steps 3-7 do not remove a data-* name from
    // an element's removeAttributes, so the result fails the constructor's
    // validity check - which a modifier must not assert (Gecko asserts it
    // only in debug builds; a script-reachable panic in Crane).
    var global = [_]model.Name{.{ .local = "data-x" }};
    var removed = [_]model.Name{.{ .local = "data-x" }};
    var elements = [_]model.Element{.{ .name = htmlName("div"), .remove_attributes = &removed }};
    var config = try model.Config.fromData(std.testing.allocator, .{
        .elements = &elements,
        .attributes = &global,
        .data_attributes = false,
    }, false);
    defer config.deinit();
    try std.testing.expect(try config.apply(.{ .data_attributes = true }));
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectEqual(@as(?bool, true), (try config.toData(arena.allocator())).data_attributes);
}
