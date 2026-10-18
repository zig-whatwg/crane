//! WebIDL 3.7.12: a setlike declaration's members are the binding's, never
//! operations. Codegen once added size, has, forEach, add, delete and clear
//! to CustomStateSet's members, so its impl implemented them as `call_*`
//! operations - and values, keys, entries and %Symbol.iterator% were never
//! defined at all (custom-elements/state/ElementInternals-states.html 2/4:
//! `[...states]` threw). Now the declaration stays a declaration: Meta records
//! it (`Meta.setlike`) and the generated interface hands the impl's set
//! entries to the binding (`setlikeEntries`).

const std = @import("std");
const codegen = @import("codegen");
const setlike = codegen.setlike;
const testing = std.testing;

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

test "a setlike declaration adds no member to the merged model" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const parsed = try codegen.idl_parser.Parser.parse(arena.allocator(),
        \\[Exposed=Window] interface CustomStateSet { setlike<DOMString>; };
    );
    var model = try codegen.ir.IR.init(testing.allocator);
    defer model.deinit();
    try model.addInterface(parsed.interfaces[0], "ce2.idl");
    try model.finish();
    const members = model.interfaces.get("CustomStateSet").?.members.items;
    try testing.expectEqual(@as(usize, 1), members.len);
    try testing.expect(members[0].type == .setlike);
    try testing.expectEqualStrings("DOMString", members[0].setlike.?.value_type.type);
    try testing.expect(!members[0].setlike.?.readonly);
}

test "Meta.setlike records the value type and readonly" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try setlike.writeMeta(&buffer.writer, .{ .value_type = .{ .type = "DOMString" } });
    try testing.expect(contains(buffer.written(), "pub const setlike = .{ .value_type = \"DOMString\", .readonly = false };"));
    buffer.clearRetainingCapacity();
    try setlike.writeMeta(&buffer.writer, .{ .value_type = .{ .type = "DOMString" }, .readonly = true });
    try testing.expect(contains(buffer.written(), ".readonly = true };"));
}

test "the generated interface hands the impl's set entries to the binding" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try setlike.writeEntriesDelegate(&buffer.writer, "CustomStateSetImpl", .{ .value_type = .{ .type = "DOMString" } });
    const out = buffer.written();
    try testing.expect(contains(out, "pub fn setlikeEntries(instance: *runtime.Instance) ?*webidl.setlike.Strings {"));
    try testing.expect(contains(out, "return CustomStateSetImpl.setlikeEntries(instance);"));
}

test "string values are kept as strings; any other value type is not supported yet" {
    try testing.expectEqualStrings("webidl.setlike.Strings", try setlike.entriesType(.{ .type = "DOMString" }));
    try testing.expectEqualStrings("webidl.setlike.Strings", try setlike.entriesType(.{ .type = "USVString" }));
    // An interface value needs a traced edge per entry (FontFaceSet, Highlight).
    try testing.expectError(error.UnsupportedSetlikeValueType, setlike.entriesType(.{ .type = "FontFace" }));
    try testing.expectError(error.UnsupportedSetlikeValueType, setlike.entriesType(.{ .type = "DOMString", .nullable = true }));
}

test "only the interfaces whose impls keep set entries are opted in" {
    try testing.expect(setlike.isImplemented("CustomStateSet"));
    try testing.expect(!setlike.isImplemented("FontFaceSet"));
    try testing.expect(!setlike.isImplemented("Highlight"));
}
