//! Node and every interface that inherits from it keep their attribute
//! storage in their impls, so their generated State holds only `_internal`
//! and the `cached_*` [SameObject] caches (lane perf2, batch 3: Z1).
//!
//! An IDL attribute is an accessor (WebIDL 3.7.6: its getter runs the
//! attribute's getter steps on the object). Every Node-family impl reads its
//! attributes from its InternalState, ElementData or NodeBase - Blink's
//! Element::id() reads its ElementData, WebKit's the same - and none reads a
//! generated State field of the attribute's name, so a slot per attribute is
//! memory every node pays and nothing reads (a div's State was 1,376 B in a
//! 2,048-byte block). Other families keep their slots: Events and geometry
//! store their attributes there.

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
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

    fn attributes(self: *Parsed, name: []const u8) ![]const types.Attribute {
        var list: std.ArrayList(types.Attribute) = .empty;
        for (self.file.interfaces) |iface| {
            if (!std.mem.eql(u8, iface.name, name)) continue;
            for (iface.members) |m| if (m.asAttribute()) |a| try list.append(self.arena.allocator(), a);
        }
        return list.items;
    }
};

fn parse(idl: []const u8) !Parsed {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    errdefer arena.deinit();
    const file = try codegen.idl_parser.Parser.parse(arena.allocator(), idl);
    var model = try codegen.ir.IR.init(arena.allocator());
    for (file.interfaces) |iface| try model.addInterface(iface, "test.idl");
    return .{ .arena = arena, .model = model, .file = file };
}

const family_idl =
    \\interface EventTarget { };
    \\interface Node : EventTarget { readonly attribute unsigned short nodeType; [SameObject] readonly attribute NodeList childNodes; };
    \\interface NodeList { };
    \\interface Element : Node { attribute DOMString id; [SameObject] readonly attribute DOMTokenList classList; };
    \\interface DOMTokenList { };
    \\interface HTMLElement : Element { attribute DOMString title; attribute (boolean or unrestricted double or DOMString)? hidden; attribute EventHandler onclick; };
    \\interface HTMLDivElement : HTMLElement { attribute DOMString align; };
    \\interface CharacterData : Node { attribute DOMString data; };
    \\interface Text : CharacterData { readonly attribute DOMString wholeText; };
    \\interface Event { readonly attribute DOMString label; readonly attribute boolean bubbles; };
    \\interface MouseEvent : Event { readonly attribute long screenX; };
;

test "Node and its descendants keep their attribute storage in their impls; the impls that store slots keep them" {
    var p = try parse(family_idl);
    defer p.deinit();
    for ([_][]const u8{ "Node", "Element", "HTMLElement", "HTMLDivElement", "CharacterData", "Text" }) |name| {
        if (!writer.implKeepsAttributeStorage(&p.model, name)) {
            std.debug.print("{s} should keep its attribute storage in its impl\n", .{name});
            return error.TestUnexpectedResult;
        }
    }
    // Lane cg1 step 2: only the interfaces whose impls store attributes in
    // their State keep slots (writer.stateSlotsOf; tests/codegen/
    // cg1_state_slots_test.zig); EventTarget and an unknown name keep none.
    for ([_][]const u8{ "NodeList", "DOMTokenList", "Event", "MouseEvent" }) |name| {
        if (writer.implKeepsAttributeStorage(&p.model, name)) {
            std.debug.print("{s} should keep its attribute slots in its State\n", .{name});
            return error.TestUnexpectedResult;
        }
    }
}

test "a Node-family State keeps only _internal and its [SameObject] caches" {
    var p = try parse(family_idl);
    defer p.deinit();
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeGeneratedState(&buffer.writer, try p.attributes("Element"), "ElementImpl", &p.model.type_registry, .{ .attribute_storage = .impl });
    const out = buffer.written();
    try testing.expect(contains(out, "_internal: ?*ElementImpl.InternalState = null,"));
    try testing.expect(contains(out, "cached_classList: ?"));
    try testing.expect(!contains(out, "id: "));
    try testing.expect(!contains(out, "classList: *runtime.Instance"));

    var html: std.Io.Writer.Allocating = .init(testing.allocator);
    defer html.deinit();
    try writer.writeGeneratedState(&html.writer, try p.attributes("HTMLElement"), "HTMLElementImpl", &p.model.type_registry, .{ .attribute_storage = .impl });
    // Strings, a union and an event handler alike: no slot.
    try testing.expect(!contains(html.written(), "title:"));
    try testing.expect(!contains(html.written(), "hidden:"));
    try testing.expect(!contains(html.written(), "onclick:"));
    try testing.expect(contains(html.written(), "_internal: ?*HTMLElementImpl.InternalState = null,"));
}

test "any other State keeps a slot per attribute" {
    var p = try parse(family_idl);
    defer p.deinit();
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeGeneratedState(&buffer.writer, try p.attributes("Event"), "EventImpl", &p.model.type_registry, .{});
    const out = buffer.written();
    try testing.expect(contains(out, "label: runtime.DOMString = undefined,"));
    try testing.expect(contains(out, "bubbles: bool = undefined,"));
    try testing.expect(contains(out, "_internal: ?*EventImpl.InternalState = null,"));
}
