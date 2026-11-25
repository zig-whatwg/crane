//! Every inline union, in every position, is converted by the binding
//! through a named union typedef (src/webidl/codegen/argument_unions.zig,
//! `nameEveryUnion`; lane bind1 batch B, B2): arguments - the last and a
//! variadic one included -, return types, attributes, dictionary members,
//! callbacks, sequence and record elements. Until
//! B2 only a union argument followed by another, whose members a shape-
//! driven conversion took "faithfully", was named; the rest reached the
//! impl as `runtime.JSValue`. The positions an impl still converts by hand
//! are listed in `unions_converted_by_impl`, a table that only shrinks.

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

const fixture = "tests/codegen/fixtures/argument_unions";

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

const Generated = struct {
    tmp: testing.TmpDir,
    root: [:0]u8,

    fn init() !Generated {
        var tmp = testing.tmpDir(.{});
        errdefer tmp.cleanup();
        const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
        errdefer testing.allocator.free(root);
        var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
        defer cfg.deinit();
        try codegen.processSources(testing.allocator, &.{fixture}, &cfg);
        return .{ .tmp = tmp, .root = root };
    }

    fn deinit(self: *Generated) void {
        testing.allocator.free(self.root);
        self.tmp.cleanup();
    }

    fn read(self: *const Generated, sub_path: []const u8) ![]u8 {
        const path = try std.fs.path.join(testing.allocator, &.{ self.root, sub_path });
        defer testing.allocator.free(path);
        return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
    }
};

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

test "a union argument followed by another becomes a named union, one per member list" {
    var out = try Generated.init();
    defer out.deinit();
    const typedef = try out.read("typedefs/BufferSourceOrPlain.zig");
    defer testing.allocator.free(typedef);
    try expectIn(typedef, "typedefs/BufferSourceOrPlain.zig", "pub const BufferSourceOrPlain = union(enum) {");
    try expectIn(typedef, "typedefs/BufferSourceOrPlain.zig", "buffer_source: typedefs.BufferSource,");
    try expectIn(typedef, "typedefs/BufferSourceOrPlain.zig", "plain: dictionaries.Plain,");

    const root = try out.read("typedefs/root.zig");
    defer testing.allocator.free(root);
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, root, "pub const BufferSourceOrPlain = "));
    try expectIn(root, "typedefs/root.zig", "pub const DOMStringOrBufferSource = ");
    try expectIn(root, "typedefs/root.zig", "pub const DOMStringOrDerived = ");
    try expectIn(root, "typedefs/root.zig", "pub const ThingOrDOMString = ");
}

test "the interface and the impl stub take the named union, in its argument's place" {
    var out = try Generated.init();
    defer out.deinit();
    for ([_][]const u8{ "interfaces/Thing.zig", "impls_tmp/Thing.zig" }) |sub_path| {
        const text = try out.read(sub_path);
        defer testing.allocator.free(text);
        try expectIn(text, sub_path, "BufferSourceOrPlain, after: ");
        try expectIn(text, sub_path, "call_again(instance: *runtime.Instance, data: ");
        try expectIn(text, sub_path, "DOMStringOrBufferSource, options: ");
        try expectIn(text, sub_path, "DOMStringOrDerived, after: ");
        // An `any` member's handle is released with the dictionary.
        try expectIn(text, sub_path, "DOMStringOrWithAny, after: ");
        // Nullability stays on the argument.
        try expectIn(text, sub_path, "data: ?");
        try expectIn(text, sub_path, "ThingOrDOMString, after: ");
    }
}

test "the last argument, a dictionary with a union member and a sequence arm are named too" {
    var out = try Generated.init();
    defer out.deinit();
    const text = try out.read("interfaces/Thing.zig");
    defer testing.allocator.free(text);
    try expectIn(text, "interfaces/Thing.zig", "call_last(instance: *runtime.Instance, first: runtime.DOMString, data: BufferSourceOrPlain)");
    try expectIn(text, "interfaces/Thing.zig", "call_unionDictionary(instance: *runtime.Instance, data: DOMStringOrWithUnion, after: ");
    try expectIn(text, "interfaces/Thing.zig", "call_sequenceArm(instance: *runtime.Instance, data: DOMStringOrSequenceOfDOMString, after: ");
    try expectNotIn(text, "interfaces/Thing.zig", "runtime.JSValue");
    const typedefs_root = try out.read("typedefs/root.zig");
    defer testing.allocator.free(typedefs_root);
    // A Trusted Types union is named too, in every position
    // (trusted_type_unions_test.zig).
    try expectIn(typedefs_root, "typedefs/root.zig", "pub const TrustedHTMLOrDOMString = ");
}

test "every other position is named: attribute, return, variadic, sequence and record elements, callbacks, dictionary members" {
    var out = try Generated.init();
    defer out.deinit();
    const text = try out.read("interfaces/Thing.zig");
    defer testing.allocator.free(text);
    try expectIn(text, "interfaces/Thing.zig", "get_both(instance: *runtime.Instance) anyerror!DOMStringOrLong");
    try expectIn(text, "interfaces/Thing.zig", "set_both(instance: *runtime.Instance, value: DOMStringOrLong)");
    try expectIn(text, "interfaces/Thing.zig", "call_produce(instance: *runtime.Instance) anyerror!DOMStringOrPlain");
    try expectIn(text, "interfaces/Thing.zig", "call_variadic(instance: *runtime.Instance, items: []const DOMStringOrLong)");
    // A record's value union, kept as text by the parser, is named too.
    const record = try out.read("dictionaries/WithRecord.zig");
    defer testing.allocator.free(record);
    try expectIn(record, "dictionaries/WithRecord.zig", "value: typedefs.DOMStringOrSequenceOfDOMString");
    const callback = try out.read("callbacks/Notify.zig");
    defer testing.allocator.free(callback);
    try expectIn(callback, "callbacks/Notify.zig", "callback Notify = undefined (DOMStringOrLong value)");
    const dictionary = try out.read("dictionaries/WithUnion.zig");
    defer testing.allocator.free(dictionary);
    try expectIn(dictionary, "dictionaries/WithUnion.zig", "start: ?typedefs.DOMStringOrLong");
    const sequence = try out.read("dictionaries/WithSequence.zig");
    defer testing.allocator.free(sequence);
    try expectIn(sequence, "dictionaries/WithSequence.zig", "items: ?[]const typedefs.DOMStringOrLong");
    const nullable = try out.read("dictionaries/WithNullable.zig");
    defer testing.allocator.free(nullable);
    try expectIn(nullable, "dictionaries/WithNullable.zig", "typedefs.DOMStringOrLong");
}

test "a sequence element's nullability names another union; a member's makes the position nullable" {
    // One name is one typedef (unionTypedef reuses the first union named).
    // (double? or sequence<double?>) and (double or sequence<double>) were
    // both "DoubleOrSequenceOfDouble": IntersectionObserverInit.threshold
    // took BasePropertyIndexedKeyframe.offset's typedef once both were named
    // (lane bind1 batch B, B5 group 3b).
    var out = try Generated.init();
    defer out.deinit();
    const plain = try out.read("dictionaries/ElementsPlain.zig");
    defer testing.allocator.free(plain);
    try expectIn(plain, "dictionaries/ElementsPlain.zig", "threshold: ?typedefs.DoubleOrSequenceOfDouble = null");
    const nullable = try out.read("dictionaries/ElementsNullable.zig");
    defer testing.allocator.free(nullable);
    try expectIn(nullable, "dictionaries/ElementsNullable.zig", "typedefs.DoubleOrSequenceOfNullableDouble");
    const member = try out.read("dictionaries/MemberNullable.zig");
    defer testing.allocator.free(member);
    try expectIn(member, "dictionaries/MemberNullable.zig", "value: ?typedefs.DoubleOrSequenceOfDouble");
    try expectIn(member, "dictionaries/MemberNullable.zig", "pub const nullable_members = .{\"value\"};");
    const typedef = try out.read("typedefs/DoubleOrSequenceOfDouble.zig");
    defer testing.allocator.free(typedef);
    try expectIn(typedef, "typedefs/DoubleOrSequenceOfDouble.zig", "double_sequence: []const f64,");
    try expectIn(typedef, "typedefs/DoubleOrSequenceOfDouble.zig", "pub const restricted_arms = .{ \"double\", \"double_sequence\" };");
    const other = try out.read("typedefs/DoubleOrSequenceOfNullableDouble.zig");
    defer testing.allocator.free(other);
    try expectIn(other, "typedefs/DoubleOrSequenceOfNullableDouble.zig", "pub const DoubleOrSequenceOfNullableDouble = union(enum) {");
}

test "unionName names an element type's nullability, not a member's" {
    const allocator = testing.allocator;
    var element = codegen.types.IDLType{ .type = "double", .nullable = true };
    var members = [_]codegen.types.IDLType{ .{ .type = "double", .nullable = true }, .{ .type = "sequence", .sequence = &element } };
    const name = try codegen.argument_unions.unionName(allocator, &members);
    defer allocator.free(name);
    try testing.expectEqualStrings("DoubleOrSequenceOfNullableDouble", name);
    var text_members = [_]codegen.types.IDLType{ .{ .type = "DOMString" }, .{ .type = "sequence", .generic = "DOMString?" } };
    const text_name = try codegen.argument_unions.unionName(allocator, &text_members);
    defer allocator.free(text_name);
    try testing.expectEqualStrings("DOMStringOrSequenceOfNullableDOMString", text_name);
    // As the IDL parser writes a sequence's element text: a space before `?`.
    var spaced_members = [_]codegen.types.IDLType{ .{ .type = "double", .nullable = true }, .{ .type = "sequence", .generic = "double ?" } };
    const spaced_name = try codegen.argument_unions.unionName(allocator, &spaced_members);
    defer allocator.free(spaced_name);
    try testing.expectEqualStrings("DoubleOrSequenceOfNullableDouble", spaced_name);
}

test "the IndexedDB source attributes, and only they, keep the object itself" {
    const table = codegen.argument_unions.object_identity_attributes;
    try testing.expectEqual(@as(usize, 2), table.len);
    try testing.expectEqualStrings("IDBCursor", table[0][0]);
    try testing.expectEqualStrings("source", table[0][1]);
    try testing.expectEqualStrings("IDBRequest", table[1][0]);
    try testing.expectEqualStrings("source", table[1][1]);
}

test "the positions an impl still converts by hand only shrink, and are none when batch B is done" {
    // Lane bind1 batch B: each B5 commit moves one area onto its typed
    // unions and lowers this count; batch B is done at zero (main,
    // 2026-11-23 12:39 PM ET).
    try testing.expectEqual(@as(usize, 0), codegen.argument_unions.unions_converted_by_impl.len);
}

test "unionName joins the member names in upper camel case" {
    const allocator = testing.allocator;
    var members = [_]codegen.types.IDLType{ .{ .type = "unsigned long" }, .{ .type = "DOMString" }, .{ .type = "boolean" } };
    const name = try codegen.argument_unions.unionName(allocator, &members);
    defer allocator.free(name);
    try testing.expectEqualStrings("UnsignedLongOrDOMStringOrBoolean", name);
}
