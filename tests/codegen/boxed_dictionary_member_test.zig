//! A dictionary member whose type is its own dictionary is boxed: Zig cannot
//! lay out a struct that contains itself (`not: ?RouterCondition` is "struct
//! depends on itself"), so the member is an optional pointer, listed in
//! `boxed_members` for the converter that allocates and frees it with the
//! dictionary. A sequence of the dictionary is a slice and stays as it is.
//! Service Workers' RouterCondition has both (lane bindtype's finding 5).

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const testing = std.testing;

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

const Parsed = struct {
    arena: std.heap.ArenaAllocator,
    model: codegen.ir.IR,
    file: types.IDLFile,

    fn deinit(self: *Parsed) void {
        self.arena.deinit();
    }
};

fn parse(idl: []const u8) !Parsed {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    errdefer arena.deinit();
    const file = try codegen.idl_parser.Parser.parse(arena.allocator(), idl);
    var model = try codegen.ir.IR.init(arena.allocator());
    for (file.enums) |e| try model.addEnum(e, "test.idl");
    for (file.dictionaries) |d| try model.addDictionary(d, "test.idl");
    return .{ .arena = arena, .model = model, .file = file };
}

const router_condition =
    \\enum RunningStatus { "running", "not-running" };
    \\dictionary RouterCondition {
    \\  ByteString requestMethod;
    \\  RunningStatus runningStatus;
    \\  sequence<RouterCondition> _or;
    \\  RouterCondition not;
    \\};
;

test "a member of the dictionary's own type is an optional pointer; a sequence of it a slice" {
    var p = try parse(router_condition);
    defer p.deinit();
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try codegen.generator.writeDictionary(p.arena.allocator(), &buffer.writer, p.file.dictionaries[0], &p.model);
    const out = buffer.written();
    try testing.expect(contains(out, "not: ?*const RouterCondition = null,"));
    try testing.expect(contains(out, "@\"or\": ?[]const RouterCondition = null,"));
    try testing.expect(contains(out, "pub const boxed_members = .{ \"not\" };"));
    try testing.expect(!contains(out, "not: ?RouterCondition"));
}

test "a dictionary with no member of its own type has no boxed members" {
    var p = try parse(
        \\dictionary Plain { DOMString name; sequence<DOMString> list; };
    );
    defer p.deinit();
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try codegen.generator.writeDictionary(p.arena.allocator(), &buffer.writer, p.file.dictionaries[0], &p.model);
    const out = buffer.written();
    try testing.expect(!contains(out, "boxed_members"));
    try testing.expect(!contains(out, "*const"));
}
