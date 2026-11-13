//! N1 for elements (lane cg1 batch 1; node-memory plan v2, B7 then N1): the
//! [SameObject] caches every element of a family carries leave the generated
//! State for the element's sparse rare block (dom.element_rare_data, lane
//! rare1), through dom.same_object_cache.
//!
//! A div's State carried 7 such pointers - Element's classList, attributes,
//! part and (ParentNode's) children, HTMLElement's style, attributeStyleMap
//! and dataset - 56 bytes, null on nearly every element: on the framework
//! pages (tmp/redesign/nodedata/framework-pages.md, table E) only `style`, and
//! in the grid `classList`, are read at all. Blink keeps the same objects in
//! its ElementRareDataVector (kClassList, kDataset, kAttributeMap, kPart,
//! kCssomWrapper, kCssomMapWrapper) and Element::classList() makes and keeps
//! it there; Ladybird and Servo keep them in their rare data too.
//!
//! - An element-level cache is read and written through
//!   `dom.same_object_cache.element*` in the field the codegen names (classList
//!   at bit 0: no popcount on the hot read).
//! - A cache the impl already keeps itself (Element's NamedNodeMap in its rare
//!   data, HTMLElement's inline style object - since lane quick1 the
//!   ElementCSSInlineStyle mixin's impl keeps it) loses its generated copy:
//!   the getter calls the impl (or is the mixin module's, by alias).
//! - Everything else keeps its `cached_<name>`: a non-element (Document's
//!   children), and a leaf element's own attribute (an anchor's relList).
//! - The destruction chain ends the edges of the level's rare-block caches
//!   before the impl's teardown, as it ends the State's.
const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

fn generated(root: []const u8, name: []const u8) ![]u8 {
    const file = try std.fmt.allocPrint(testing.allocator, "{s}/interfaces/{s}.zig", .{ root, name });
    defer testing.allocator.free(file);
    return std.Io.Dir.cwd().readFileAlloc(testing.io, file, testing.allocator, .limited(1 << 20));
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
        try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/cg1_element_same_object"}, &config);
        return .{ .tmp = tmp, .root = root };
    }

    fn deinit(self: *Generated) void {
        testing.allocator.free(self.root);
        self.tmp.cleanup();
    }

    fn file(self: *Generated, name: []const u8) ![]u8 {
        return generated(self.root, name);
    }

    /// A mixin's generated module.
    fn mixin(self: *Generated, name: []const u8) ![]u8 {
        const path = try std.fmt.allocPrint(testing.allocator, "{s}/mixins/{s}.zig", .{ self.root, name });
        defer testing.allocator.free(path);
        return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1 << 20));
    }
};

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

/// The text of `name`'s function in `file`, up to the next blank line.
fn function(file: []const u8, comptime name: []const u8) ![]const u8 {
    const start = std.mem.indexOf(u8, file, "pub fn " ++ name ++ "(") orelse
        std.mem.indexOf(u8, file, "pub inline fn " ++ name ++ "(") orelse return error.NoSuchFunction;
    const end = std.mem.indexOfPos(u8, file, start, "\n\n") orelse file.len;
    return file[start..end];
}

/// The generated State's own-fields struct.
fn stateFields(file: []const u8) ![]const u8 {
    const start = std.mem.indexOf(u8, file, "pub const State = runtime.FlattenedState(") orelse return error.NoState;
    const end = std.mem.indexOfPos(u8, file, start, "    );") orelse return error.NoState;
    return file[start..end];
}

fn expectRareGetter(file: []const u8, comptime getter: []const u8, comptime field: []const u8, comptime attribute: []const u8, comptime impl_call: []const u8) !void {
    const body = try function(file, getter);
    // The hit: the element's rare data, the field at its bit.
    const hit = std.mem.indexOf(u8, body, "@import(\"dom\").same_object_cache.elementGet(instance, ." ++ field ++ ")") orelse {
        std.debug.print("{s}:\n{s}\n", .{ getter, body });
        return error.NoRareRead;
    };
    // The miss: the field's bit first (keeping the child cannot fail after it
    // is made), then the impl's object, kept and traced from its owner.
    const reserve = std.mem.indexOf(u8, body, "try @import(\"dom\").same_object_cache.elementReserve(instance, ." ++ field ++ ");") orelse return error.NoReserve;
    const make = std.mem.indexOf(u8, body, impl_call) orelse return error.NoImplCall;
    const keep = std.mem.indexOf(u8, body, "@import(\"dom\").same_object_cache.elementMade(instance, ." ++ field ++ ", value, \"" ++ attribute ++ "\");") orelse return error.NoKeep;
    try testing.expect(hit < reserve and reserve < make and make < keep);
    // Nothing in the State.
    try testing.expect(!contains(body, "state.own"));
}

test "Element's classList, part and children are cached in the element's rare data, classList first" {
    var out = try Generated.init();
    defer out.deinit();
    const element = try out.file("Element");
    defer testing.allocator.free(element);

    try expectRareGetter(element, "get_classList", "class_list", "classList", "try ElementImpl.get_classList(instance)");
    try expectRareGetter(element, "get_part", "part", "part", "try ElementImpl.get_part(instance)");
    // ParentNode's children, an inherited mixin member: the mixin's module makes it.
    try expectRareGetter(element, "get_children", "children", "children", "try mixins.ParentNode.get_children(instance)");

    const state = try stateFields(element);
    inline for (.{ "cached_classList", "cached_part", "cached_children", "cached_attributes" }) |name| {
        if (contains(state, name)) {
            std.debug.print("Element's State still has {s}:\n{s}\n", .{ name, state });
            return error.CacheStillInState;
        }
    }
}

test "a cache the impl keeps itself loses its generated copy: Element.attributes, HTMLElement.style" {
    var out = try Generated.init();
    defer out.deinit();
    const element = try out.file("Element");
    defer testing.allocator.free(element);
    const html = try out.file("HTMLElement");
    defer testing.allocator.free(html);

    const attributes = try function(element, "get_attributes");
    try testing.expect(contains(attributes, "return try ElementImpl.get_attributes(instance);"));
    try testing.expect(!contains(attributes, "same_object_cache"));
    try testing.expect(!contains(attributes, "cached"));

    // HTMLElement's style is ElementCSSInlineStyle's, an inherited mixin
    // since lane quick1 (2026-11-12): the getter and setter are the mixin
    // module's, by alias, and the mixin's impl keeps an HTML element's
    // object - no generated cache anywhere.
    try testing.expect(contains(html, "pub const get_style = mixins.ElementCSSInlineStyle.get_style;"));
    try testing.expect(contains(html, "pub const set_style = mixins.ElementCSSInlineStyle.set_style;"));
    try testing.expect(!contains(html, "pub fn get_style("));
    try testing.expect(!contains(try stateFields(html), "cached_style"));
    // Its [PutForwards] setter still forwards through the getter - the
    // mixin module's own.
    const mixin = try out.mixin("ElementCSSInlineStyle");
    defer testing.allocator.free(mixin);
    try testing.expect(contains(try function(mixin, "set_style"), "try get_style(instance)"));
    try testing.expect(!contains(try function(mixin, "get_style"), "same_object_cache"));
}

test "HTMLElement's and SVGElement's family-wide caches go to the rare data; SVG's style has a field of its own" {
    var out = try Generated.init();
    defer out.deinit();
    const html = try out.file("HTMLElement");
    defer testing.allocator.free(html);
    const svg = try out.file("SVGElement");
    defer testing.allocator.free(svg);

    // dataset and attributeStyleMap: inherited mixin members (lane quick1,
    // 2026-11-12), cached by each includer around the mixin module's getter.
    try expectRareGetter(html, "get_dataset", "dataset", "dataset", "try mixins.HTMLOrSVGOrMathMLElement.get_dataset(instance)");
    try expectRareGetter(html, "get_attributeStyleMap", "attribute_style_map", "attributeStyleMap", "try mixins.ElementCSSInlineStyle.get_attributeStyleMap(instance)");
    try testing.expect(!contains(try stateFields(html), "cached_"));

    // An SVG element's style object is made per call (the mixin's impl
    // keeps only an HTML element's): the generated cache keeps it, in a
    // field apart from HTMLElement's kept style object.
    try expectRareGetter(svg, "get_style", "inline_style", "style", "try mixins.ElementCSSInlineStyle.get_style(instance)");
    try expectRareGetter(svg, "get_dataset", "dataset", "dataset", "try mixins.HTMLOrSVGOrMathMLElement.get_dataset(instance)");
    try expectRareGetter(svg, "get_attributeStyleMap", "attribute_style_map", "attributeStyleMap", "try mixins.ElementCSSInlineStyle.get_attributeStyleMap(instance)");
    try expectRareGetter(svg, "get_className", "svg_class_name", "className", "try SVGElementImpl.get_className(instance)");
    try testing.expect(!contains(try stateFields(svg), "cached_"));
}

test "a non-element and a leaf element's own attribute keep their State cache" {
    var out = try Generated.init();
    defer out.deinit();
    const document = try out.file("Document");
    defer testing.allocator.free(document);
    const anchor = try out.file("HTMLAnchorElement");
    defer testing.allocator.free(anchor);
    const node = try out.file("Node");
    defer testing.allocator.free(node);

    // Document's children: ParentNode's member, but no element's.
    try testing.expect(contains(try stateFields(document), "cached_children"));
    try testing.expect(contains(try function(document, "get_children"), "state.own.cached_children = value;"));
    try testing.expect(!contains(document, "elementGet"));
    // An anchor's relList is its own interface's: few elements carry it.
    try testing.expect(contains(try stateFields(anchor), "cached_relList"));
    try testing.expect(contains(try function(anchor, "get_relList"), "state.own.cached_relList = value;"));
    // Node's childNodes stays (NodeRareData is lane wr1's this batch).
    try testing.expect(contains(try stateFields(node), "cached_childNodes"));
}

test "the destruction chain ends a level's rare-block edges before the impl's teardown, and the State's only where it has one" {
    var out = try Generated.init();
    defer out.deinit();
    const element = try out.file("Element");
    defer testing.allocator.free(element);
    const anchor = try out.file("HTMLAnchorElement");
    defer testing.allocator.free(anchor);

    const chain = try function(element, "deinitChain");
    const end = std.mem.indexOf(u8, chain, "@import(\"dom\").same_object_cache.endElement(instance, &.{") orelse {
        std.debug.print("deinitChain:\n{s}\n", .{chain});
        return error.NoEndElement;
    };
    try testing.expect(contains(chain, ".{ .field = .class_list, .attribute = \"classList\" }"));
    try testing.expect(contains(chain, ".{ .field = .part, .attribute = \"part\" }"));
    try testing.expect(contains(chain, ".{ .field = .children, .attribute = \"children\" }"));
    try testing.expect(!contains(chain, "\"attributes\""));
    try testing.expect(end < std.mem.indexOf(u8, chain, "ElementImpl.deinit(instance)").?);
    try testing.expect(end < std.mem.indexOf(u8, chain, "ElementImpl.deinitOwn(instance)").?);
    // No State cache left at Element's level: no State walk.
    try testing.expect(!contains(chain, "same_object_cache.end(State, instance)"));

    // The anchor keeps its relList in its State: the State walk, no rare one.
    const anchor_chain = try function(anchor, "deinitChain");
    try testing.expect(contains(anchor_chain, "same_object_cache.end(State, instance)"));
    try testing.expect(!contains(anchor_chain, "endElement"));
}

test "Meta lists every [SameObject] attribute whose child the owner keeps, wherever its cache lives" {
    var out = try Generated.init();
    defer out.deinit();
    // The binding ties a [SameObject] child's wrapper to its owner's, both
    // ways (engines/v8 binding_plumbing.recordSameObjectEdge). It read that
    // from the State's `cached_<name>`, which N1 moved out: the list is the
    // attribute's [SameObject], whether the cache is in the State, the
    // element's rare data or the impl.
    const Case = struct { file: []const u8, names: []const []const u8 };
    const cases = [_]Case{
        .{ .file = "Element", .names = &.{ "classList", "attributes", "part", "children" } },
        .{ .file = "HTMLElement", .names = &.{ "style", "attributeStyleMap", "dataset" } },
        .{ .file = "SVGElement", .names = &.{ "className", "style", "attributeStyleMap", "dataset" } },
        .{ .file = "Document", .names = &.{"children"} },
        .{ .file = "Node", .names = &.{"childNodes"} },
        .{ .file = "HTMLAnchorElement", .names = &.{"relList"} },
    };
    for (cases) |case| {
        const file = try out.file(case.file);
        defer testing.allocator.free(file);
        const start = std.mem.indexOf(u8, file, "pub const same_object_attributes = .{") orelse {
            std.debug.print("{s}: no Meta.same_object_attributes\n", .{case.file});
            return error.NoList;
        };
        const meta = std.mem.indexOf(u8, file, "pub const Meta = struct {").?;
        const meta_end = std.mem.indexOfPos(u8, file, meta, "\n    };\n").?;
        try testing.expect(start > meta and start < meta_end);
        const end = std.mem.indexOfPos(u8, file, start, "};").?;
        const list = file[start..end];
        for (case.names) |name| {
            var buffer: [64]u8 = undefined;
            const quoted = try std.fmt.bufPrint(&buffer, "\"{s}\"", .{name});
            if (!contains(list, quoted)) {
                std.debug.print("{s}: {s} not in\n{s}\n", .{ case.file, name, list });
                return error.NotListed;
            }
        }
    }
    // An interface with no [SameObject] attribute has none.
    const list = try out.file("DOMTokenList");
    defer testing.allocator.free(list);
    try testing.expect(!contains(list, "same_object_attributes"));
}
