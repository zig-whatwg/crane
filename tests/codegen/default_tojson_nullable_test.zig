//! A [Default] toJSON result keeps a nullable attribute nullable.
//!
//! WebIDL's default toJSON steps (3.7.4.1) set map[id] to every JSON-typed
//! attribute's value and then CreateDataProperty every entry - null
//! included. The generated ToJSON struct typed every member from the
//! attribute's type name alone, so `NotRestoredReasons? notRestoredReasons`
//! became a non-optional `*runtime.Instance` the impl could not leave
//! null, and the struct conversion (a dictionary's) left a null member out
//! of the object altogether. Codegen now keeps the `?` and marks the struct
//! `default_to_json`, which the binding reads to define null members.

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

test "a ToJSON struct types a nullable attribute as optional and is marked default_to_json" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const file = try codegen.idl_parser.Parser.parse(a,
        \\typedef double DOMHighResTimeStamp;
        \\interface NotRestoredReasons { [Default] object toJSON(); };
        \\interface Timing {
        \\  readonly attribute DOMHighResTimeStamp start;
        \\  readonly attribute NotRestoredReasons? notRestoredReasons;
        \\  readonly attribute NotRestoredReasons reasons;
        \\  readonly attribute DOMString? label;
        \\  readonly attribute unsigned short? code;
        \\  [Default] object toJSON();
        \\};
    );
    var model = try codegen.ir.IR.init(a);
    for (file.typedefs) |t| try model.addTypedef(t, "test.idl");
    for (file.interfaces) |iface| try model.addInterface(iface, "test.idl");

    const attrs = try codegen.ir.collectToJSONAttributes(a, "Timing", &model);
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try codegen.writer.writeToJSONStruct(&buffer.writer, "Timing", attrs, &model);
    const out = buffer.written();

    try testing.expect(contains(out, "        start: DOMHighResTimeStamp,\n"));
    try testing.expect(contains(out, "        notRestoredReasons: ?*runtime.Instance,\n"));
    try testing.expect(contains(out, "        reasons: *runtime.Instance,\n"));
    try testing.expect(contains(out, "        label: ?runtime.DOMString,\n"));
    try testing.expect(contains(out, "        code: ?u16,\n"));
    try testing.expect(contains(out, "        pub const default_to_json = true;\n"));
}
