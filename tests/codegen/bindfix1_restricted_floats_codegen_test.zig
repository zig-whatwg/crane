//! Restricted `double` and `float` are marked for the binding on every path
//! that converts one (lane bindfix1): a constructor's arguments, every
//! overload's (`constructor_restricted_floats`, keyed by ConstructorArgs
//! variant, "" for a sole constructor), a namespace's operations (the
//! `restricted_floats` table an interface's operations carry) and a union's
//! arms (`restricted_arms`, written inside the union). restricted_floats_test
//! pins attributes, operations and dictionary members.

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

    fn constructors(self: *Parsed, interface_index: usize) ![]const types.Constructor {
        var list: std.ArrayList(types.Constructor) = .empty;
        for (self.file.interfaces[interface_index].members) |m| {
            if (m.asConstructor()) |c| try list.append(self.arena.allocator(), c);
        }
        return list.items;
    }
};

fn parse(idl: []const u8) !Parsed {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    errdefer arena.deinit();
    const file = try codegen.idl_parser.Parser.parse(arena.allocator(), idl);
    var model = try codegen.ir.IR.init(arena.allocator());
    for (file.typedefs) |t| try model.addTypedef(t, "test.idl");
    for (file.interfaces) |iface| try model.addInterface(iface, "test.idl");
    return .{ .arena = arena, .model = model, .file = file };
}

test "a sole constructor's restricted arguments are listed under the empty variant" {
    var p = try parse(
        \\typedef double DOMHighResTimeStamp;
        \\interface Cue { constructor(double start, unrestricted double end, DOMString text, float volume, DOMHighResTimeStamp at); };
        \\interface Point { constructor(optional unrestricted double x = 0); };
    );
    defer p.deinit();
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeConstructorRestrictedFloats(&buffer.writer, try p.constructors(0), &p.model);
    // start (bit 0), volume (bit 3), at through its typedef (bit 4) - not end.
    try testing.expect(contains(buffer.written(), "pub const constructor_restricted_floats = .{"));
    try testing.expect(contains(buffer.written(), ".{ \"\", 0b11001 },"));

    var none: std.Io.Writer.Allocating = .init(testing.allocator);
    defer none.deinit();
    try writer.writeConstructorRestrictedFloats(&none.writer, try p.constructors(1), &p.model);
    try testing.expectEqualStrings("", none.written());
}

test "an overloaded constructor's restricted arguments are listed per variant" {
    var p = try parse(
        \\dictionary ContextOptions { unsigned long length; };
        \\interface Context {
        \\  constructor(ContextOptions options);
        \\  constructor(unsigned long channels, unsigned long length, float sampleRate);
        \\};
    );
    defer p.deinit();
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    const ctors = try p.constructors(0);
    try writer.writeConstructorRestrictedFloats(&buffer.writer, ctors, &p.model);
    const variant = try codegen.overload.generateConstructorVariantName(testing.allocator, ctors[1]);
    defer testing.allocator.free(variant);
    const entry = try std.fmt.allocPrint(testing.allocator, ".{{ \"{s}\", 0b100 }},", .{variant});
    defer testing.allocator.free(entry);
    try testing.expect(contains(buffer.written(), entry));
    // Only the variant with one.
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, buffer.written(), "0b"));
}

test "a namespace's operations get the operation table" {
    var p = try parse(
        \\interface Holder {
        \\  undefined px(double value);
        \\  undefined escape(DOMString ident);
        \\  undefined raw(unrestricted double value);
        \\};
    );
    defer p.deinit();
    var ops: std.ArrayList(types.Operation) = .empty;
    for (p.file.interfaces[0].members) |m| {
        if (m.asOperation()) |o| try ops.append(p.arena.allocator(), o);
    }
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeRestrictedFloats(&buffer.writer, &.{}, ops.items, &p.model);
    try testing.expect(contains(buffer.written(), ".{ \"call_px\", 0b1 },"));
    try testing.expect(!contains(buffer.written(), "call_escape"));
    try testing.expect(!contains(buffer.written(), "call_raw"));
}

test "a union's restricted arms are written inside the union" {
    var p = try parse(
        \\typedef double DOMHighResTimeStamp;
        \\interface Value {};
        \\typedef (double or Value) Numberish;
        \\typedef (unrestricted double or DOMString) Loose;
        \\typedef (sequence<double> or Value) Colorish;
        \\typedef (DOMHighResTimeStamp or DOMString) Stamp;
    );
    defer p.deinit();
    const Case = struct { name: []const u8, expected: []const u8 };
    const cases = [_]Case{
        .{ .name = "Numberish", .expected = "pub const restricted_arms = .{\"double\"};" },
        .{ .name = "Loose", .expected = "" },
        .{ .name = "Colorish", .expected = "pub const restricted_arms = .{\"double_sequence\"};" },
        // Through the typedef: one arm listed (its name is the typedef's).
        .{ .name = "Stamp", .expected = "pub const restricted_arms = .{\"" },
    };
    for (cases) |case| {
        const typedef = for (p.file.typedefs) |t| {
            if (std.mem.eql(u8, t.name, case.name)) break t;
        } else return error.TypedefMissing;
        var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
        defer buffer.deinit();
        try codegen.generator.writeRestrictedArms(testing.allocator, &buffer.writer, typedef.idlType.unionTypes.?, &p.model);
        if (case.expected.len == 0) {
            try testing.expectEqualStrings("", buffer.written());
        } else if (!contains(buffer.written(), case.expected)) {
            std.debug.print("{s}: {s}\n", .{ case.name, buffer.written() });
            return error.TestUnexpectedResult;
        }
    }
}
