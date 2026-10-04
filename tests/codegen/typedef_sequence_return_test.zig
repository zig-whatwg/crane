//! An operation returning a typedef'd sequence returns a runtime.JSValue, as a
//! direct sequence return does.
//!
//! A `sequence<T>` return maps to anyopaque, which the operation writer turns
//! into runtime.JSValue: the impl makes the Array (engine.createSequenceOf...)
//! and the binding hands it to script. A typedef of a sequence -
//! `typedef sequence<PerformanceEntry> PerformanceEntryList;` - kept its
//! typedef's name instead, `typedefs.PerformanceEntryList`, a Zig slice the
//! binding's return conversion has no case for, so getEntries() and friends
//! reached script as undefined (perftimeline, 2026-10-04).

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

test "a typedef'd sequence return is a runtime.JSValue, like a direct sequence return" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const file = try codegen.idl_parser.Parser.parse(a,
        \\typedef sequence<PerformanceEntry> PerformanceEntryList;
        \\typedef double DOMHighResTimeStamp;
        \\interface PerformanceEntry {};
        \\interface Timeline {
        \\  PerformanceEntryList getEntries();
        \\  PerformanceEntryList? maybeEntries();
        \\  sequence<PerformanceEntry> direct();
        \\  DOMHighResTimeStamp now();
        \\};
    );
    var model = try codegen.ir.IR.init(a);
    for (file.typedefs) |t| try model.addTypedef(t, "test.idl");
    for (file.interfaces) |iface| try model.addInterface(iface, "test.idl");

    var ops: std.ArrayList(types.Operation) = .empty;
    for (file.interfaces[1].members) |m| if (m.asOperation()) |o| try ops.append(a, o);

    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "TimelineImpl", &model.type_registry, &.{}, ops.items, ops.items, .{ .model = &model });
    const out = buffer.written();

    try testing.expect(contains(out, "pub fn call_direct(instance: *runtime.Instance) anyerror!runtime.JSValue"));
    try testing.expect(contains(out, "pub fn call_getEntries(instance: *runtime.Instance) anyerror!runtime.JSValue"));
    try testing.expect(contains(out, "pub fn call_maybeEntries(instance: *runtime.Instance) anyerror!?runtime.JSValue"));
    try testing.expect(!contains(out, "anyerror!PerformanceEntryList"));
    // A typedef of a non-sequence keeps its typedef.
    try testing.expect(contains(out, "pub fn call_now(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp"));
}
