//! WebIDL 2.5.6: codegen records each interface's special operations in its
//! Meta - which generated function implements its indexed and named property
//! getter, setter and deleter, its own or the derived-most one it inherits
//! (3.9), and [LegacyOverrideBuiltIns] / [LegacyUnenumerableNamedProperties].
//! The binding installs a legacy platform object's handlers from that table.
//! It used to guess them from function names (`call_item`, `call_namedItem`,
//! `call_getNamedItem`, `call_setNamedItem`, ...), so Storage's
//! `getter DOMString? getItem(DOMString key)` was never bound and
//! `localStorage[k] = v` made an ordinary property; NamedNodeMap's REGULAR
//! `setNamedItem(Attr)` was taken for a named setter; SVGNumberList's
//! `getter SVGNumber getItem(unsigned long)` was never bound.
//!
//! The default is pinned too: an interface with no special operation has no
//! `special_operations` at all - `item()` and `namedItem()` declared without
//! `getter` are regular operations and nothing else.
const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

fn generated(root: []const u8, name: []const u8) ![]u8 {
    const file = try std.fmt.allocPrint(testing.allocator, "{s}/interfaces/{s}.zig", .{ root, name });
    defer testing.allocator.free(file);
    return std.Io.Dir.cwd().readFileAlloc(testing.io, file, testing.allocator, .limited(65536));
}

const Generated = struct {
    tmp: testing.TmpDir,
    root: [:0]u8,

    fn init() !Generated {
        var tmp = testing.tmpDir(.{});
        errdefer tmp.cleanup();
        const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
        errdefer testing.allocator.free(root);
        var config = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
        defer config.deinit();
        try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/special_operations"}, &config);
        return .{ .tmp = tmp, .root = root };
    }

    fn deinit(self: *Generated) void {
        testing.allocator.free(self.root);
        self.tmp.cleanup();
    }

    /// The generated file of interface `name`; the caller frees it.
    fn file(self: *Generated, name: []const u8) ![]u8 {
        return generated(self.root, name);
    }
};

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

/// The text of Meta's `special_operations` table, or null when there is none.
fn table(source: []const u8) ?[]const u8 {
    const header = "pub const special_operations: webidl.SpecialOperations = .{";
    const start = std.mem.indexOf(u8, source, header) orelse return null;
    const end = std.mem.indexOfPos(u8, source, start, "};") orelse return null;
    return source[start .. end + 2];
}

fn expectTable(source: []const u8, comptime lines: []const []const u8) !void {
    const t = table(source) orelse {
        std.debug.print("no special_operations table in:\n{s}\n", .{source});
        return error.TableMissing;
    };
    // Exactly these entries, in this order.
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(testing.allocator);
    try expected.appendSlice(testing.allocator, "pub const special_operations: webidl.SpecialOperations = .{\n");
    inline for (lines) |line| {
        try expected.appendSlice(testing.allocator, "            " ++ line ++ "\n");
    }
    try expected.appendSlice(testing.allocator, "        };");
    try testing.expectEqualStrings(expected.items, t);
}

/// Inside the Meta struct, not beside it.
fn expectInMeta(source: []const u8) !void {
    const meta = std.mem.indexOf(u8, source, "pub const Meta = struct {") orelse return error.NoMeta;
    const state = std.mem.indexOf(u8, source, "pub const State = ") orelse return error.NoState;
    const at = std.mem.indexOf(u8, source, "pub const special_operations") orelse return error.TableMissing;
    try testing.expect(meta < at and at < state);
}

test "no special operation, no table: item() and namedItem() without `getter` are regular operations" {
    var out = try Generated.init();
    defer out.deinit();
    const plain = try out.file("Plain");
    defer testing.allocator.free(plain);
    try testing.expect(!contains(plain, "special_operations"));
    try testing.expect(!contains(plain, "getSupportedPropertyNames"));
    try testing.expect(contains(plain, "pub fn call_item(instance: *runtime.Instance, index: u32)"));
    try testing.expect(contains(plain, "pub fn call_namedItem(instance: *runtime.Instance, name: "));
}

test "named getter, setter and deleter declared with identifiers (Storage)" {
    var out = try Generated.init();
    defer out.deinit();
    const store = try out.file("KeyStore");
    defer testing.allocator.free(store);
    try expectTable(store, &.{
        ".named_getter = .{ .function = \"call_getItem\" },",
        ".named_setter = .{ .function = \"call_setItem\" },",
        ".named_deleter = .{ .function = \"call_removeItem\" },",
    });
    try expectInMeta(store);
    // The supported property names, through the generated interface.
    try testing.expect(contains(store, "pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {"));
    try testing.expect(contains(store, "return KeyStoreImpl.getSupportedPropertyNames(instance, allocator);"));
}

test "an identified indexed getter not called item, and an anonymous indexed setter, gated (SVGNumberList)" {
    var out = try Generated.init();
    defer out.deinit();
    const list = try out.file("NumberList");
    defer testing.allocator.free(list);
    try expectTable(list, &.{
        ".indexed_getter = .{ .function = \"call_getItem\" },",
        ".indexed_setter = .{ .function = \"call_setter\", .implemented = @hasDecl(NumberListImpl, \"call_setter\") },",
    });
    // An anonymous setter's delegate compiles without the impl's function.
    try testing.expect(contains(list, "if (comptime @hasDecl(NumberListImpl, \"call_setter\")) {"));
    try testing.expect(!contains(list, "getSupportedPropertyNames"));
}

test "anonymous named getter, setter and deleter are gated, with [LegacyOverrideBuiltIns] (DOMStringMap)" {
    var out = try Generated.init();
    defer out.deinit();
    const map = try out.file("StringMap");
    defer testing.allocator.free(map);
    try expectTable(map, &.{
        ".named_getter = .{ .function = \"call_getter\", .implemented = @hasDecl(StringMapImpl, \"call_getter\") },",
        ".named_setter = .{ .function = \"call_setter\", .implemented = @hasDecl(StringMapImpl, \"call_setter\") },",
        ".named_deleter = .{ .function = \"call_deleter\", .implemented = @hasDecl(StringMapImpl, \"call_deleter\") },",
        ".legacy_override_built_ins = true,",
    });
    try testing.expect(contains(map, "if (comptime @hasDecl(StringMapImpl, \"call_getter\")) {"));
    try testing.expect(contains(map, "if (comptime @hasDecl(StringMapImpl, \"call_deleter\")) {"));
}

test "an anonymous indexed getter and an anonymous named getter get one delegate each (HTMLFormElement)" {
    var out = try Generated.init();
    defer out.deinit();
    const form = try out.file("Form");
    defer testing.allocator.free(form);
    try expectTable(form, &.{
        ".indexed_getter = .{ .function = \"call_getter\", .implemented = @hasDecl(FormImpl, \"call_getter\") },",
        ".named_getter = .{ .function = \"call_getter__1\", .implemented = @hasDecl(FormImpl, \"call_getter__1\") },",
        ".legacy_override_built_ins = true,",
        ".legacy_unenumerable_named_properties = true,",
    });
    // Not one union-taking delegate calling functions no impl has.
    try testing.expect(!contains(form, "GetterArgs"));
    try testing.expect(contains(form, "pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!"));
    try testing.expect(contains(form, "pub fn call_getter__1(instance: *runtime.Instance, name: "));
    try testing.expect(contains(form, "if (comptime @hasDecl(FormImpl, \"call_getter\")) {"));
    try testing.expect(contains(form, "if (comptime @hasDecl(FormImpl, \"call_getter__1\")) {"));
}

test "an heir inherits the derived-most special operations and its ancestor's extended attributes (HTMLOptionsCollection)" {
    var out = try Generated.init();
    defer out.deinit();
    const options = try out.file("OptionsCollection");
    defer testing.allocator.free(options);
    try expectTable(options, &.{
        ".indexed_getter = .{ .function = \"call_item\" },",
        ".indexed_setter = .{ .function = \"call_setter\", .implemented = @hasDecl(OptionsCollectionImpl, \"call_setter\") },",
        ".named_getter = .{ .function = \"call_namedItem\" },",
        ".legacy_unenumerable_named_properties = true,",
    });
    // The inherited functions are the heir's to name: its parent's.
    try testing.expect(contains(options, "pub const call_item = Collection.call_item;"));
    try testing.expect(contains(options, "pub const get_length = Collection.get_length;"));
    try testing.expect(contains(options, "pub const call_namedItem = Collection.call_namedItem;"));
    try testing.expect(contains(options, "pub const getSupportedPropertyNames = Collection.getSupportedPropertyNames;"));
}

test "an inherited anonymous operation is implemented when its declarer's is" {
    var out = try Generated.init();
    defer out.deinit();
    const heir = try out.file("OptionsHeir");
    defer testing.allocator.free(heir);
    try expectTable(heir, &.{
        ".indexed_getter = .{ .function = \"call_item\" },",
        ".indexed_setter = .{ .function = \"call_setter\", .implemented = OptionsCollection.Meta.special_operations.indexed_setter.?.implemented },",
        ".named_getter = .{ .function = \"call_namedItem\" },",
        ".legacy_unenumerable_named_properties = true,",
    });
    try testing.expect(contains(heir, "pub const call_setter = OptionsCollection.call_setter;"));
    try testing.expect(contains(heir, "pub const call_namedItem = OptionsCollection.call_namedItem;"));
}

test "an heir that redeclares the named getter has its own (HTMLFormControlsCollection)" {
    var out = try Generated.init();
    defer out.deinit();
    const controls = try out.file("ControlsCollection");
    defer testing.allocator.free(controls);
    try expectTable(controls, &.{
        ".indexed_getter = .{ .function = \"call_item\" },",
        ".named_getter = .{ .function = \"call_namedItem\" },",
        ".legacy_unenumerable_named_properties = true,",
    });
    try testing.expect(contains(controls, "return ControlsCollectionImpl.getSupportedPropertyNames(instance, allocator);"));
    try testing.expect(!contains(controls, "pub const call_namedItem = Collection.call_namedItem;"));
}

test "TouchEvent's getModifierState is a regular operation only, as in every browser" {
    var out = try Generated.init();
    defer out.deinit();
    const touch = try out.file("TouchEvent");
    defer testing.allocator.free(touch);
    try testing.expect(!contains(touch, "special_operations"));
    try testing.expect(!contains(touch, "getSupportedPropertyNames"));
    try testing.expect(contains(touch, ".{ \"getModifierState\", \"call_getModifierState\", 1 }"));
}

test "Document's named getter, and an XMLDocument without it, as in every browser" {
    var out = try Generated.init();
    defer out.deinit();
    const document = try out.file("Document");
    defer testing.allocator.free(document);
    try expectTable(document, &.{
        ".named_getter = .{ .function = \"call_getter\", .implemented = @hasDecl(DocumentImpl, \"call_getter\") },",
        ".legacy_override_built_ins = true,",
    });
    const xml = try out.file("XMLDocument");
    defer testing.allocator.free(xml);
    try testing.expect(!contains(xml, "special_operations"));
    try testing.expect(!contains(xml, "call_getter"));
    try testing.expect(!contains(xml, "getSupportedPropertyNames"));
}

test "a CSS declaration interface's named properties are Crane's camel-cased attributes, and say so" {
    var out = try Generated.init();
    defer out.deinit();
    const style = try out.file("CSSStyleDeclaration");
    defer testing.allocator.free(style);
    try expectTable(style, &.{
        ".indexed_getter = .{ .function = \"call_item\" },",
        ".named_getter = .{ .function = \"call_namedItem\" },",
        ".named_setter = .{ .function = \"call_setNamedItem\" },",
        ".crane_css_properties = true,",
    });
}
