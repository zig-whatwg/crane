//! Interface-typed values are marked for the binding with the interface they
//! convert to.
//!
//! WebIDL 3.2.15: a JavaScript value V is converted to an IDL interface type
//! I by "1. If V implements I, then return the IDL interface type value that
//! represents a reference to that platform object. 2. Throw a TypeError."
//! Codegen maps every interface type to the one Zig type `*runtime.Instance`,
//! so the binding cannot tell from the type WHICH interface a value must
//! implement - `fd.append(name, new URLSearchParams(), filename)` handed a
//! URLSearchParams to FormData as its Blob. Codegen tells it, in the shape of
//! `byte_string_arguments`:
//!
//! - per interface, `interface_arguments`: the Zig function, the argument's
//!   index (0 for an attribute setter's value) and the interface's name;
//! - per interface with a constructor, `constructor_interface_arguments`: the
//!   ConstructorArgs variant ("" for a sole constructor), the argument's
//!   index within it, and the interface;
//! - per dictionary, `interface_members`: the member and the interface.
//!
//! A typedef of an interface names the interface itself, and a nullable,
//! optional, variadic, sequence, FrozenArray or record type names the
//! interface its elements convert to. A union is not listed - its conversion
//! picks the arm by the arm's name - and neither is a callback interface.

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

const fixture = "tests/codegen/fixtures/interface_arguments";

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

fn expectIn(text: []const u8, what: []const u8, needle: []const u8) !void {
    if (!contains(text, needle)) {
        std.debug.print("{s} lacks `{s}`:\n{s}\n", .{ what, needle, text });
        return error.TestExpectedEqual;
    }
}

fn expectNotIn(text: []const u8, what: []const u8, needle: []const u8) !void {
    if (contains(text, needle)) {
        std.debug.print("{s} has `{s}`:\n{s}\n", .{ what, needle, text });
        return error.TestUnexpectedResult;
    }
}

fn readOut(root: []const u8, sub_path: []const u8) ![]u8 {
    const path = try std.fs.path.join(testing.allocator, &.{ root, sub_path });
    defer testing.allocator.free(path);
    return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
}

const Generated = struct {
    tmp: testing.TmpDir,
    root: [:0]u8,

    fn deinit(self: *Generated) void {
        testing.allocator.free(self.root);
        self.tmp.cleanup();
    }

    fn read(self: *const Generated, sub_path: []const u8) ![]u8 {
        return readOut(self.root, sub_path);
    }
};

fn generate() !Generated {
    var tmp = testing.tmpDir(.{});
    errdefer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    errdefer testing.allocator.free(root);
    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer cfg.deinit();
    try codegen.processSources(testing.allocator, &.{fixture}, &cfg);
    return .{ .tmp = tmp, .root = root };
}

test "operation arguments and attribute values of interface type name their interface" {
    var out = try generate();
    defer out.deinit();
    const iface = try out.read("interfaces/Sink.zig");
    defer testing.allocator.free(iface);
    const what = "interfaces/Sink.zig";

    try expectIn(iface, what, "pub const interface_arguments = .{");
    // A writable attribute's value is argument 0; a readonly one has no
    // setter, and a string attribute no interface.
    try expectIn(iface, what, ".{ \"set_target\", 0, \"Node\" },");
    try expectNotIn(iface, what, "\"set_owner\", 0,");
    try expectNotIn(iface, what, "\"set_name\", 0,");
    // Through a typedef of a typedef of an interface.
    try expectIn(iface, what, ".{ \"set_aliased\", 0, \"Blob\" },");
    try expectIn(iface, what, ".{ \"set_static_staticNode\", 0, \"Node\" },");
    // Each overload by its own function: only the Blob overload's argument 1.
    try expectIn(iface, what, ".{ \"call_append__1\", 1, \"Blob\" },");
    try expectNotIn(iface, what, ".{ \"call_append\", ");
    try expectIn(iface, what, ".{ \"call_take\", 0, \"Blob\" },");
    // A sequence, a record and a FrozenArray name their elements' interface.
    try expectIn(iface, what, ".{ \"call_many\", 0, \"Node\" },");
    try expectIn(iface, what, ".{ \"call_many\", 1, \"Blob\" },");
    try expectIn(iface, what, ".{ \"call_many\", 2, \"Node\" },");
    // A variadic argument names its elements' interface, at its own index.
    try expectIn(iface, what, ".{ \"call_rest\", 1, \"Node\" },");
    try expectNotIn(iface, what, ".{ \"call_rest\", 0,");
    // A typedef of a sequence of an interface.
    try expectIn(iface, what, ".{ \"call_aliasedSequence\", 0, \"Node\" },");
    try expectIn(iface, what, ".{ \"call_static_adopt\", 0, \"Node\" },");
    // The anonymous indexed setter's value, by its delegate.
    try expectIn(iface, what, ".{ \"call_setter\", 1, \"Node\" },");
    // An included mixin's members are the includer's.
    try expectIn(iface, what, ".{ \"set_pointed\", 0, \"Node\" },");
    try expectIn(iface, what, ".{ \"call_point\", 0, \"Node\" },");
    // Unions (named or inline), callback interfaces and strings are not
    // listed.
    try expectNotIn(iface, what, ".{ \"call_either\", ");
    try expectNotIn(iface, what, ".{ \"call_inline\", ");
    try expectNotIn(iface, what, ".{ \"call_listen\", ");
    try expectNotIn(iface, what, ".{ \"call_text\", ");
}

test "a constructor's interface-typed arguments are listed by variant" {
    var out = try generate();
    defer out.deinit();

    const sink = try out.read("interfaces/Sink.zig");
    defer testing.allocator.free(sink);
    try expectIn(sink, "interfaces/Sink.zig", "pub const constructor_interface_arguments = .{");
    try expectIn(sink, "interfaces/Sink.zig", ".{ \"\", 0, \"HTMLFormElement\" },");
    try expectIn(sink, "interfaces/Sink.zig", ".{ \"\", 1, \"Node\" },");

    // An overloaded constructor: each ConstructorArgs variant by its name; a
    // one-argument variant is its argument (index 0).
    const ray = try out.read("interfaces/Ray.zig");
    defer testing.allocator.free(ray);
    try expectIn(ray, "interfaces/Ray.zig", "pub const constructor_interface_arguments = .{");
    try expectIn(ray, "interfaces/Ray.zig", ".{ \"Node\", 0, \"Node\" },");
    try expectIn(ray, "interfaces/Ray.zig", ".{ \"string_Blob\", 1, \"Blob\" },");
    try expectNotIn(ray, "interfaces/Ray.zig", ".{ \"Boundary\", ");
}

test "no table when nothing is of an interface type" {
    var out = try generate();
    defer out.deinit();
    const quiet = try out.read("interfaces/Quiet.zig");
    defer testing.allocator.free(quiet);
    try expectNotIn(quiet, "interfaces/Quiet.zig", "pub const interface_arguments");
    try expectNotIn(quiet, "interfaces/Quiet.zig", "pub const constructor_interface_arguments");

    const plain = try out.read("dictionaries/Plain.zig");
    defer testing.allocator.free(plain);
    try expectNotIn(plain, "dictionaries/Plain.zig", "pub const interface_members");
}

test "a dictionary's interface-typed members name their interface" {
    var out = try generate();
    defer out.deinit();
    const dictionary = try out.read("dictionaries/Boundary.zig");
    defer testing.allocator.free(dictionary);
    const what = "dictionaries/Boundary.zig";
    try expectIn(dictionary, what, "pub const interface_members = .{");
    try expectIn(dictionary, what, ".{ \"container\", \"Node\" },");
    try expectIn(dictionary, what, ".{ \"optionalNode\", \"Node\" },");
    try expectIn(dictionary, what, ".{ \"aliased\", \"Blob\" },");
    try expectIn(dictionary, what, ".{ \"nodes\", \"Node\" },");
    try expectIn(dictionary, what, ".{ \"frozenBlobs\", \"Blob\" },");
    try expectIn(dictionary, what, ".{ \"blobRecord\", \"Blob\" },");
    try expectNotIn(dictionary, what, ".{ \"either\", ");
    try expectNotIn(dictionary, what, ".{ \"listener\", ");
    try expectNotIn(dictionary, what, ".{ \"text\", ");
}

test "interfaceTypeName: through typedefs, nullable and generic types; never a union" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const file = try codegen.idl_parser.Parser.parse(arena.allocator(),
        \\typedef Blob BlobAlias;
        \\typedef sequence<BlobAlias> Blobs;
        \\typedef (Blob or DOMString) BlobOrString;
        \\interface Blob {};
        \\callback interface Listener { undefined handleEvent(); };
    );
    var model = try codegen.ir.IR.init(arena.allocator());
    for (file.typedefs) |t| try model.addTypedef(t, "test.idl");
    for (file.interfaces) |iface| try model.addInterface(iface, "test.idl");
    const reg = &model.type_registry;
    const name = codegen.writer.interfaceTypeName;

    try testing.expectEqualStrings("Blob", name(.{ .type = "Blob" }, reg).?);
    try testing.expectEqualStrings("Blob", name(.{ .type = "Blob", .nullable = true }, reg).?);
    try testing.expectEqualStrings("Blob", name(.{ .type = "BlobAlias" }, reg).?);
    try testing.expectEqualStrings("Blob", name(.{ .type = "Blobs" }, reg).?);
    try testing.expectEqualStrings("Blob", name(.{ .type = "sequence", .generic = "Blob?" }, reg).?);
    try testing.expectEqualStrings("Blob", name(.{ .type = "FrozenArray", .generic = "BlobAlias" }, reg).?);
    try testing.expectEqualStrings("Blob", name(.{ .type = "record", .generic = "DOMString, Blob" }, reg).?);
    try testing.expect(name(.{ .type = "BlobOrString" }, reg) == null);
    try testing.expect(name(.{ .type = "Listener" }, reg) == null);
    try testing.expect(name(.{ .type = "DOMString" }, reg) == null);
    try testing.expect(name(.{ .type = "Promise", .generic = "Blob" }, reg) == null);
    // A sequence of sequences: its innermost elements are the conversions.
    try testing.expectEqualStrings("Blob", name(.{ .type = "sequence", .generic = "sequence<Blob>" }, reg).?);
    try testing.expectEqualStrings("Blob", name(.{ .type = "record", .generic = "DOMString, sequence<Blob>" }, reg).?);
    try testing.expect(name(.{ .type = "sequence", .generic = "(Blob or DOMString)" }, reg) == null);
}
