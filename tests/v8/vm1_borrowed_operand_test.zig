//! The protocol's Get and HasProperty borrow a `.handle` operand - the
//! caller's own Global - instead of cloning it into a Global of their own
//! (protocol_values.zig `BorrowedObject`, lane vm1: one Global fewer made for
//! every property read). Two things that must hold of a borrowed operand:
//!
//! - the operation answers as before and leaves the handle the caller's:
//!   alive, and usable for the next operation;
//! - a handle whose object the collector has taken - a weak one, emptied -
//!   is not read. The clone refused it (v8_Global_Clone answers null for an
//!   empty handle, so the operation failed with OperationFailed); the borrow
//!   must refuse it too, before it asks V8 whether the value is an Object,
//!   which dereferences an empty Local.
//!
//! The second is a pin of the refactor, not of main: main passes it. What it
//! guards is shown by a mutant (the emptiness check removed), which must
//! fail it.

const std = @import("std");
const testing = std.testing;
const rounds_lib = @import("handle_rounds.zig");
const runtime = @import("runtime");
const protocol = @import("engine");
const ffi = @import("v8").ffi;

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

fn noopCollected(_: ?*anyopaque, _: usize) callconv(.c) void {}

/// A new object `{ a: 7 }` of `realm`, held by nothing but the Global this
/// answers. Made in a frame of its own, so no Local of it is left on the
/// test's stack for a collection to find. OWNED: `release()`.
noinline fn makeObject(realm: runtime.Context) !protocol.Owned {
    var reports: Reports = .{};
    const made = try protocol.evaluateClassicScript(realm, .{ .utf8 = "({ a: 7 })" }, "", null, reports.reporter());
    if (reports.count != 0) {
        made.release();
        return error.ScriptThrew;
    }
    return made;
}

fn globalOf(value: runtime.JSValue) *ffi.Value {
    return @ptrCast(@alignCast(value.handle.ptr));
}

test "Get and HasProperty of a handle operand answer the property and leave the handle the caller's" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://borrowed-operand-alive.test");
    defer page.end();

    const object = try makeObject(page.realm);
    defer object.release();
    const operand = object.borrow();

    try testing.expect(try protocol.hasProperty(page.realm, operand, "a"));
    try testing.expect(!try protocol.hasProperty(page.realm, operand, "b"));
    {
        const got = try protocol.getProperty(page.realm, operand, "a");
        defer got.release();
        try testing.expectEqual(protocol.ValueType.number, protocol.typeOf(page.realm, got.borrow()));
    }
    {
        const missing = try protocol.getProperty(page.realm, operand, "b");
        defer missing.release();
        try testing.expectEqual(protocol.ValueType.undefined, protocol.typeOf(page.realm, missing.borrow()));
    }
    // A non-object is still a TypeError, whatever kind of value names it.
    try testing.expectError(error.TypeError, protocol.getProperty(page.realm, .{ .number = 1 }, "a"));
    try testing.expectError(error.TypeError, protocol.hasProperty(page.realm, .undefined, "a"));

    // The handle is the caller's as it was: not emptied, not disposed, and
    // good for another round of both operations.
    try testing.expect(!ffi.v8_Global_IsEmpty(globalOf(operand)));
    try testing.expect(try protocol.hasProperty(page.realm, operand, "a"));
    const again = try protocol.getProperty(page.realm, operand, "a");
    defer again.release();
    try testing.expectEqual(protocol.ValueType.number, protocol.typeOf(page.realm, again.borrow()));
}

test "Get and HasProperty of a handle whose object was collected fail without reading it" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://borrowed-operand-collected.test");
    defer page.end();

    const object = try makeObject(page.realm);
    defer object.release();
    const operand = object.borrow();
    try testing.expect(try protocol.hasProperty(page.realm, operand, "a"));

    // The Global is all that holds the object: weak, it no longer does, and
    // a full collection takes the object and empties the handle.
    ffi.v8_Global_SetWeak(@ptrCast(globalOf(operand)), null, noopCollected);
    for (0..3) |_| protocol.requestGarbageCollection(page.agent);
    if (!ffi.v8_Global_IsEmpty(globalOf(operand))) {
        std.debug.print("the weak handle's object survived three full collections: the emptied operand was not reached\n", .{});
        return error.ObjectNotCollected;
    }

    // What the clone answered for an empty handle, and no read of it.
    try testing.expectError(error.OperationFailed, protocol.getProperty(page.realm, operand, "a"));
    try testing.expectError(error.OperationFailed, protocol.hasProperty(page.realm, operand, "a"));
}
