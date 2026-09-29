//! Restricted `double` and `float` are marked for the binding.
//!
//! WebIDL 3.2.7 and 3.2.9: converting to `float` or `double` throws a
//! TypeError for NaN and the infinities; `unrestricted float` and
//! `unrestricted double` do not. Codegen maps all four to f32/f64, so it tells
//! the binding which values are restricted, in the shape of
//! `legacy_null_to_empty`: per interface, `restricted_floats` (the Zig
//! function, bit i for argument i, bit 0 for an attribute setter's value);
//! per dictionary, `restricted_members` (the member names). A typedef of
//! `double` (DOMHighResTimeStamp) is restricted too; a union is not listed -
//! its conversion picks the member type itself.

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

test "restricted attribute setters and operation arguments are listed; unrestricted ones are not" {
    var p = try parse(
        \\typedef double DOMHighResTimeStamp;
        \\interface Meter {
        \\  attribute double value;
        \\  attribute unrestricted double valueAsNumber;
        \\  readonly attribute double low;
        \\  attribute float gain;
        \\  attribute double? optionalValue;
        \\  undefined seek(double time, unrestricted double rate, optional float volume, sequence<double> marks);
        \\  undefined mark(DOMHighResTimeStamp at);
        \\  undefined plain(unrestricted double a, long b);
        \\  undefined many(double... values);
        \\};
    );
    defer p.deinit();
    const members = p.file.interfaces[0].members;
    var attrs: std.ArrayList(types.Attribute) = .empty;
    var ops: std.ArrayList(types.Operation) = .empty;
    for (members) |m| {
        if (m.asAttribute()) |a| try attrs.append(p.arena.allocator(), a);
        if (m.asOperation()) |o| try ops.append(p.arena.allocator(), o);
    }

    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "MeterImpl", null, attrs.items, ops.items, ops.items, .{ .model = &p.model });
    const out = buffer.written();

    try testing.expect(contains(out, "pub const restricted_floats = .{"));
    try testing.expect(contains(out, ".{ \"set_value\", 0b1 },"));
    try testing.expect(contains(out, ".{ \"set_gain\", 0b1 },"));
    try testing.expect(contains(out, ".{ \"set_optionalValue\", 0b1 },"));
    try testing.expect(!contains(out, "\"set_valueAsNumber\", 0b"));
    try testing.expect(!contains(out, "\"set_low\""));
    // seek: time (bit 0), volume (bit 2), marks (bit 3) - not rate (bit 1).
    try testing.expect(contains(out, ".{ \"call_seek\", 0b1101 },"));
    // Through the typedef.
    try testing.expect(contains(out, ".{ \"call_mark\", 0b1 },"));
    try testing.expect(contains(out, ".{ \"call_many\", 0b1 },"));
    try testing.expect(!contains(out, "\"call_plain\", 0b"));
}

test "no table when nothing is restricted" {
    var p = try parse(
        \\interface Point { attribute unrestricted double x; undefined move(unrestricted float dx); };
    );
    defer p.deinit();
    var attrs: std.ArrayList(types.Attribute) = .empty;
    var ops: std.ArrayList(types.Operation) = .empty;
    for (p.file.interfaces[0].members) |m| {
        if (m.asAttribute()) |a| try attrs.append(p.arena.allocator(), a);
        if (m.asOperation()) |o| try ops.append(p.arena.allocator(), o);
    }
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "PointImpl", null, attrs.items, ops.items, ops.items, .{ .model = &p.model });
    try testing.expect(!contains(buffer.written(), "restricted_floats"));
}

test "restricted dictionary members are listed by name" {
    var p = try parse(
        \\typedef double DOMHighResTimeStamp;
        \\dictionary WheelEventInit {
        \\  double deltaX = 0.0;
        \\  unrestricted double spin;
        \\  DOMHighResTimeStamp startTime;
        \\  sequence<float> weights;
        \\  (double or DOMString) duration;
        \\  unsigned long deltaMode = 0;
        \\};
    );
    defer p.deinit();
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeRestrictedMembers(&buffer.writer, p.file.dictionaries[0].members, &p.model);
    const out = buffer.written();
    try testing.expect(contains(out, "pub const restricted_members = .{ \"deltaX\", \"startTime\", \"weights\" };"));

    var none: std.Io.Writer.Allocating = .init(testing.allocator);
    defer none.deinit();
    try writer.writeRestrictedMembers(&none.writer, p.file.dictionaries[0].members[1..2], &p.model);
    try testing.expectEqualStrings("", none.written());
}
