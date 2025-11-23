//! Integration tests for WebIDL code generator
//!
//! These tests verify end-to-end code generation from WebIDL JSON to Zig code.

const std = @import("std");
const codegen = @import("codegen/root.zig");
const testing = std.testing;

test "generateInterface creates valid Zig code for simple interface" {
    const allocator = testing.allocator;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    // Create a simple EventTarget interface
    const interface: codegen.types.Interface = .{
        .name = "EventTarget",
        .inheritance = null,
        .members = &.{},
    };

    // Generate code
    try codegen.generateInterface(allocator, interface, "dom", tmp_path, null);

    // Read generated file
    const output_path = try std.fs.path.join(allocator, &.{ tmp_path, "EventTarget.zig" });
    defer allocator.free(output_path);

    const content = try std.fs.cwd().readFileAlloc(allocator, output_path, 1024 * 1024);
    defer allocator.free(content);

    // Verify structure
    try testing.expect(std.mem.indexOf(u8, content, "pub const EventTarget = struct {") != null);
    try testing.expect(std.mem.indexOf(u8, content, "pub const Meta = struct {") != null);
    try testing.expect(std.mem.indexOf(u8, content, "pub fn create(") != null);
    try testing.expect(std.mem.indexOf(u8, content, "pub fn deinit(") != null);
    // create() should initialize internally
    try testing.expect(std.mem.indexOf(u8, content, ".init(&full_state.own)") != null);

    // Verify it compiles
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "ast-check", output_path },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term != .Exited or result.term.Exited != 0) {
        std.debug.print("zig ast-check failed:\n{s}\n", .{result.stderr});
        return error.InvalidZigCode;
    }
}

test "generateInterface handles inheritance correctly" {
    const allocator = testing.allocator;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    // Create Node interface that inherits from EventTarget
    const interface: codegen.types.Interface = .{
        .name = "Node",
        .inheritance = "EventTarget",
        .members = &.{},
    };

    try codegen.generateInterface(allocator, interface, "dom", tmp_path);

    const output_path = try std.fs.path.join(allocator, &.{ tmp_path, "Node.zig" });
    defer allocator.free(output_path);

    const content = try std.fs.cwd().readFileAlloc(allocator, output_path, 1024 * 1024);
    defer allocator.free(content);

    // Should import EventTarget
    try testing.expect(std.mem.indexOf(u8, content, "const EventTarget = @import(\"EventTarget.zig\");") != null);
    // Should reference EventTarget in Meta
    try testing.expect(std.mem.indexOf(u8, content, "pub const BaseType = *EventTarget;") != null);
}

test "generateInterface handles attributes" {
    const allocator = testing.allocator;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const members = [_]codegen.types.Member{
        .{
            .type = .attribute,
            .attribute = .{
                .name = "nodeType",
                .idlType = .{ .type = "unsigned short" },
                .readonly = true,
            },
        },
    };

    const interface: codegen.types.Interface = .{
        .name = "Node",
        .members = @constCast(&members),
    };

    try codegen.generateInterface(allocator, interface, "dom", tmp_path);

    const output_path = try std.fs.path.join(allocator, &.{ tmp_path, "Node.zig" });
    defer allocator.free(output_path);

    const content = try std.fs.cwd().readFileAlloc(allocator, output_path, 1024 * 1024);
    defer allocator.free(content);

    // Should have getter
    try testing.expect(std.mem.indexOf(u8, content, "pub fn get_nodeType(") != null);
    // Should use u16 for unsigned short
    try testing.expect(std.mem.indexOf(u8, content, "u16") != null);
}

test "generateFromFile parses and generates from JSON" {
    const allocator = testing.allocator;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    // Create a test JSON file
    const json_content =
        \\{
        \\  "interfaces": [
        \\    {
        \\      "name": "TestInterface",
        \\      "inheritance": null,
        \\      "members": [],
        \\      "extAttrs": [],
        \\      "partial": false,
        \\      "mixin": false,
        \\      "includes": []
        \\    }
        \\  ]
        \\}
    ;

    try tmp_dir.dir.writeFile(.{ .sub_path = "test.json", .data = json_content });

    const input_path = try std.fs.path.join(allocator, &.{ tmp_path, "test.json" });
    defer allocator.free(input_path);

    const output_dir = try std.fs.path.join(allocator, &.{ tmp_path, "output" });
    defer allocator.free(output_dir);

    // Generate code
    try codegen.generateFromFile(allocator, input_path, output_dir);

    // Verify output file exists
    const output_path = try std.fs.path.join(allocator, &.{ output_dir, "TestInterface.zig" });
    defer allocator.free(output_path);

    const file = try std.fs.cwd().openFile(output_path, .{});
    defer file.close();
}

test "generateFromFile handles multiple interfaces" {
    const allocator = testing.allocator;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const json_content =
        \\{
        \\  "interfaces": [
        \\    {
        \\      "name": "EventTarget",
        \\      "inheritance": null,
        \\      "members": [],
        \\      "extAttrs": [],
        \\      "partial": false,
        \\      "mixin": false,
        \\      "includes": []
        \\    },
        \\    {
        \\      "name": "Node",
        \\      "inheritance": "EventTarget",
        \\      "members": [],
        \\      "extAttrs": [],
        \\      "partial": false,
        \\      "mixin": false,
        \\      "includes": []
        \\    }
        \\  ]
        \\}
    ;

    try tmp_dir.dir.writeFile(.{ .sub_path = "dom.json", .data = json_content });

    const input_path = try std.fs.path.join(allocator, &.{ tmp_path, "dom.json" });
    defer allocator.free(input_path);

    const output_dir = try std.fs.path.join(allocator, &.{ tmp_path, "output" });
    defer allocator.free(output_dir);

    try codegen.generateFromFile(allocator, input_path, output_dir);

    // Verify both files exist
    const eventtarget_path = try std.fs.path.join(allocator, &.{ output_dir, "EventTarget.zig" });
    defer allocator.free(eventtarget_path);

    const node_path = try std.fs.path.join(allocator, &.{ output_dir, "Node.zig" });
    defer allocator.free(node_path);

    var file1 = try std.fs.cwd().openFile(eventtarget_path, .{});
    defer file1.close();

    var file2 = try std.fs.cwd().openFile(node_path, .{});
    defer file2.close();
}
