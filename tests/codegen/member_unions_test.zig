//! A dictionary member listed in member_unions.zig's table gets a named
//! union typedef, which the binding converts in the member's place during
//! the dictionary's conversion (WebIDL 3.2.18 step 4), instead of the
//! runtime.JSValue an impl converts later by hand. The table is empty until
//! its first consumer moves (the sanitizer options); this pins the mechanism
//! on a fixture.

const std = @import("std");
const codegen = @import("codegen");
const member_unions = codegen.member_unions;
const testing = std.testing;

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

const fixture =
    \\enum Presets { "default" };
    \\[Exposed=Window] interface Sanitizer {};
    \\dictionary Config { boolean comments; sequence<DOMString> elements; };
    \\dictionary Options { (Sanitizer or Config or Presets) sanitizer = "default"; };
    \\dictionary Unconverted { (sequence<DOMString> or DOMString) either; };
;

const Model = struct {
    // On the heap: the IR keeps `arena.allocator()`, which points at the
    // arena, and allocates through it after init returns (nameMemberUnions).
    // An arena returned by value would leave that pointer at init's dead
    // stack frame (Zig 0.17's arena faults on it).
    arena: *std.heap.ArenaAllocator,
    ir: codegen.ir.IR,
    file: codegen.types.IDLFile,

    fn init() !Model {
        const arena = try testing.allocator.create(std.heap.ArenaAllocator);
        errdefer testing.allocator.destroy(arena);
        arena.* = .init(testing.allocator);
        errdefer arena.deinit();
        const file = try codegen.idl_parser.Parser.parse(arena.allocator(), fixture);
        var model = try codegen.ir.IR.init(arena.allocator());
        for (file.enums) |e| try model.addEnum(e, "test.idl");
        for (file.interfaces) |i| try model.addInterface(i, "test.idl");
        for (file.dictionaries) |d| try model.addDictionary(d, "test.idl");
        return .{ .arena = arena, .ir = model, .file = file };
    }

    fn deinit(self: *Model) void {
        self.arena.deinit();
        testing.allocator.destroy(self.arena);
    }

    fn dictionaryFile(self: *Model, name: []const u8) ![]u8 {
        var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
        errdefer buffer.deinit();
        try codegen.generator.writeDictionary(self.arena.allocator(), &buffer.writer, self.ir.dictionaries.get(name).?, &self.ir);
        return buffer.toOwnedSlice();
    }
};

test "a listed member's union becomes a named typedef the dictionary uses" {
    var model = try Model.init();
    defer model.deinit();
    try member_unions.nameMemberUnions(&model.ir, &.{.{ .dictionary = "Options", .member = "sanitizer" }});
    const typedef = model.ir.typedefs.get("SanitizerOrConfigOrPresets") orelse return error.NoTypedef;
    try testing.expectEqual(@as(usize, 3), typedef.idlType.unionTypes.?.len);
    const out = try model.dictionaryFile("Options");
    defer testing.allocator.free(out);
    try testing.expect(contains(out, "sanitizer: ?typedefs.SanitizerOrConfigOrPresets = null,"));
    // Converted by the binding: no JSValue whose present null the impl reads.
    try testing.expect(!contains(out, "jsvalue_union_members"));
}

test "an unlisted member keeps its runtime.JSValue" {
    var model = try Model.init();
    defer model.deinit();
    try member_unions.nameMemberUnions(&model.ir, &.{});
    const out = try model.dictionaryFile("Options");
    defer testing.allocator.free(out);
    try testing.expect(contains(out, "sanitizer: ?runtime.JSValue = null,"));
    try testing.expect(contains(out, "pub const jsvalue_union_members = .{ \"sanitizer\" };"));
}

test "a union with an arm the binding cannot convert, or an unknown member, fails the regeneration" {
    var model = try Model.init();
    defer model.deinit();
    try testing.expectError(error.MemberUnionNotConverted, member_unions.nameMemberUnions(&model.ir, &.{.{ .dictionary = "Unconverted", .member = "either" }}));
    try testing.expectError(error.UnknownMemberUnion, member_unions.nameMemberUnions(&model.ir, &.{.{ .dictionary = "Options", .member = "missing" }}));
    try testing.expectError(error.UnknownMemberUnion, member_unions.nameMemberUnions(&model.ir, &.{.{ .dictionary = "Missing", .member = "sanitizer" }}));
}

test "an enumeration arm converts faithfully as a string type; argument_unions' rule is its own" {
    var model = try Model.init();
    defer model.deinit();
    const arms = [_]codegen.types.IDLType{ .{ .type = "Sanitizer" }, .{ .type = "Presets" } };
    try testing.expect(member_unions.convertsFaithfully(&model.ir, &arms));
    try testing.expect(!codegen.argument_unions.convertsFaithfully(&model.ir, &arms));
}
