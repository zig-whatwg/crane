//! Dead attribute storage in generated States (lane cg1 batch 1, step 2):
//! a generated State keeps a slot only for an attribute its impl stores
//! there (writer.zig `state_storage_slots`, from the compile proof: every slot
//! dropped, everything compiled, every error a reader). Every other impl keeps
//! its own storage, as the Node family's always did (perf2 b3).
const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

/// Whether this build has the per-attribute rule.
const has_rule = @hasDecl(writer, "stateSlotsOf");

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

const idl =
    \\interface EventTarget { };
    \\interface Node : EventTarget { readonly attribute unsigned short nodeType; };
    \\interface Event { readonly attribute DOMString type; readonly attribute EventTarget? target; readonly attribute boolean bubbles; readonly attribute boolean isTrusted; };
    \\interface CSSStyleDeclaration { attribute DOMString cssText; readonly attribute unsigned long length; };
;

const Parsed = struct {
    arena: std.heap.ArenaAllocator,
    model: codegen.ir.IR,
    file: types.IDLFile,

    fn attributes(self: *Parsed, name: []const u8) ![]const types.Attribute {
        var list: std.ArrayList(types.Attribute) = .empty;
        for (self.file.interfaces) |iface| {
            if (!std.mem.eql(u8, iface.name, name)) continue;
            for (iface.members) |m| if (m.asAttribute()) |a| try list.append(self.arena.allocator(), a);
        }
        return list.items;
    }
};

fn parse() !Parsed {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    errdefer arena.deinit();
    const file = try codegen.idl_parser.Parser.parse(arena.allocator(), idl);
    var model = try codegen.ir.IR.init(arena.allocator());
    for (file.interfaces) |iface| try model.addInterface(iface, "test.idl");
    return .{ .arena = arena, .model = model, .file = file };
}

test "an interface whose impl stores no attribute in its State keeps no slot; one that does keeps only those" {
    if (comptime !has_rule) return error.NoPerAttributeRule;
    var p = try parse();
    defer p.arena.deinit();
    // CSSStyleDeclaration's impl computes cssText and length (CSSOM 6.6.1).
    try testing.expect(writer.implKeepsAttributeStorage(&p.model, "CSSStyleDeclaration"));
    try testing.expect(writer.stateSlotsOf("CSSStyleDeclaration") == null);
    // The Node family, as before.
    try testing.expect(writer.implKeepsAttributeStorage(&p.model, "Node"));
    // Event's impl stores type, bubbles... in its State, never target or isTrusted.
    try testing.expect(!writer.implKeepsAttributeStorage(&p.model, "Event"));
    const slots = writer.stateSlotsOf("Event").?;
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeGeneratedState(&buffer.writer, try p.attributes("Event"), "EventImpl", &p.model.type_registry, .{ .slots = slots });
    const out = buffer.written();
    try testing.expect(contains(out, "@\"type\": runtime.DOMString = undefined,"));
    try testing.expect(contains(out, "bubbles: bool = undefined,"));
    try testing.expect(!contains(out, "target:"));
    try testing.expect(!contains(out, "isTrusted:"));
    try testing.expect(contains(out, "_internal: ?*EventImpl.InternalState = null,"));
}
