//! A generated union says what each of its member types is (lane bind1
//! batch B, B3): codegen writes `pub const arms`, one `webidl.UnionArm` per
//! field - the field and its member type's kind - and the binding's union
//! conversion (WebIDL 3.2.25) reads that table instead of guessing from Zig
//! type shapes and arm names. An interface member is named (a typedef of one
//! resolved to the interface); a typed array by its [[TypedArrayName]]; a
//! member that is itself a union typedef is `.union`, flattened by the
//! binding through that union's own table.

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

/// The fixture's generated typedef `name`, read whole.
fn generatedTypedef(name: []const u8) ![]u8 {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer cfg.deinit();
    try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/bind1_union_arms"}, &cfg);
    const file = try std.fmt.allocPrint(testing.allocator, "typedefs/{s}.zig", .{name});
    defer testing.allocator.free(file);
    const path = try std.fs.path.join(testing.allocator, &.{ root, file });
    defer testing.allocator.free(path);
    return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
}

/// `name`'s generated file holds each of `entries` - `.{ .field = ..., .kind
/// = ... }` - in its arms table.
fn expectArms(name: []const u8, entries: []const []const u8) !void {
    const output = try generatedTypedef(name);
    defer testing.allocator.free(output);
    const table = std.mem.indexOf(u8, output, "pub const arms = [_]webidl.UnionArm{") orelse {
        std.debug.print("no arms table in typedefs/{s}.zig:\n{s}\n", .{ name, output });
        return error.TestExpectedEqual;
    };
    try testing.expect(std.mem.indexOf(u8, output, "const webidl = @import(\"webidl\");") != null);
    var from = table;
    for (entries) |entry| {
        const line = try std.fmt.allocPrint(testing.allocator, "        .{{ {s} }},\n", .{entry});
        defer testing.allocator.free(line);
        // In field order.
        const at = std.mem.indexOfPos(u8, output, from, line) orelse {
            std.debug.print("expected `{s}` (in order) in typedefs/{s}.zig:\n{s}\n", .{ line, name, output });
            return error.TestExpectedEqual;
        };
        from = at + line.len;
    }
}

test "an interface member is named, a typedef of one resolved to the interface" {
    try expectArms("Things", &.{
        \\.field = "thing", .kind = .{ .interface = "Thing" }
        ,
        \\.field = "other_thing", .kind = .{ .interface = "OtherThing" }
        ,
    });
    try expectArms("AliasOptionsMode", &.{
        \\.field = "thing_alias", .kind = .{ .interface = "Thing" }
        ,
        \\.field = "options", .kind = .dictionary
        ,
        \\.field = "mode", .kind = .enumeration
        ,
    });
}

test "a union typedef among the members is a nested union, flattened by the binding" {
    try expectArms("NestedThings", &.{
        \\.field = "things", .kind = .@"union"
        ,
        \\.field = "domstring", .kind = .string
        ,
    });
}

test "callback function and callback interface members" {
    try expectArms("NotifyOrString", &.{
        \\.field = "notify", .kind = .callback_function
        ,
        \\.field = "usvstring", .kind = .string
        ,
    });
    try expectArms("ListenerOrString", &.{
        \\.field = "listener", .kind = .callback_interface
        ,
        \\.field = "byte_string", .kind = .string
        ,
    });
}

test "sequence, record and frozen array members" {
    try expectArms("SequenceOrThing", &.{
        \\.field = "domstring_sequence", .kind = .sequence
        ,
        \\.field = "thing", .kind = .{ .interface = "Thing" }
        ,
    });
    try expectArms("RecordOrLong", &.{
        \\.field = "domstring_domstring_record", .kind = .record
        ,
        \\.field = "long", .kind = .numeric
        ,
    });
    try expectArms("FrozenOrThing", &.{
        \\.field = "domstring_frozen_array", .kind = .frozen_array
        ,
        \\.field = "thing", .kind = .{ .interface = "Thing" }
        ,
    });
}

test "object, a string typedef, the buffer types and a typed array by its name" {
    try expectArms("ObjectOrString", &.{
        \\.field = "object", .kind = .object
        ,
        \\.field = "string_alias", .kind = .string
        ,
    });
    try expectArms("Views", &.{
        \\.field = "float32array", .kind = .{ .typed_array = "Float32Array" }
        ,
        \\.field = "data_view", .kind = .data_view
        ,
        \\.field = "array_buffer", .kind = .array_buffer
        ,
        \\.field = "domstring", .kind = .string
        ,
    });
    try expectArms("SharedOrBoolean", &.{
        \\.field = "shared_array_buffer", .kind = .shared_array_buffer
        ,
        \\.field = "boolean", .kind = .boolean
        ,
    });
    try expectArms("Buffers", &.{
        \\.field = "buffer_source", .kind = .buffer_source
        ,
        \\.field = "domstring", .kind = .string
        ,
    });
    try expectArms("SharedBuffers", &.{
        \\.field = "allow_shared_buffer_source", .kind = .allow_shared_buffer_source
        ,
        \\.field = "long", .kind = .numeric
        ,
    });
}

test "bigint, a numeric typedef and undefined" {
    try expectArms("Numbers", &.{
        \\.field = "bigint", .kind = .bigint
        ,
        \\.field = "number_alias", .kind = .numeric
        ,
    });
    try expectArms("MaybeString", &.{
        \\.field = "undefined", .kind = .undefined
        ,
        \\.field = "domstring", .kind = .string
        ,
    });
}
