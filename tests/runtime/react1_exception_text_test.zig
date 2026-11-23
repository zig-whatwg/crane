//! runtime.exception_text: the text an impl gives the exception its failing
//! binding call throws (lane react1, the integrator's approval 2026-11-22).
//! The impl records it with the error it returns (`fail`); the engine
//! adapter's conversion of that error takes it (`take`) when the error's name
//! is the recorded one; every binding entry clears what an earlier call left
//! (`beginBindingCall`), so a text an impl recorded and a Zig caller then
//! caught never names a later call's error.

const std = @import("std");
const runtime = @import("runtime");

const testing = std.testing;
const exception_text = runtime.exception_text;

fn removeChildFails() error{NotFoundError}!void {
    return exception_text.fail(error.NotFoundError, "The node to be removed is not a child of this node.");
}

test "fail returns its error and records the text; the conversion of that error takes it once" {
    exception_text.beginBindingCall();
    try testing.expectError(error.NotFoundError, removeChildFails());
    try testing.expectEqualStrings("The node to be removed is not a child of this node.", exception_text.take("NotFoundError").?);
    // Taken: a second conversion finds none.
    try testing.expectEqual(@as(?[]const u8, null), exception_text.take("NotFoundError"));
}

test "an error of another name than the recorded one gets no text, and the record is gone" {
    exception_text.beginBindingCall();
    try testing.expectError(error.NotFoundError, removeChildFails());
    try testing.expectEqual(@as(?[]const u8, null), exception_text.take("HierarchyRequestError"));
    try testing.expectEqual(@as(?[]const u8, null), exception_text.take("NotFoundError"));
}

test "catch and continue: a text a caller caught never names a later binding call's error of the same name" {
    // Binding call 1: an impl records a text, a Zig caller catches the error and carries on, and the call succeeds.
    exception_text.beginBindingCall();
    removeChildFails() catch {};
    // Binding call 2 fails with the same error name, with no text of its own.
    exception_text.beginBindingCall();
    try testing.expectEqual(@as(?[]const u8, null), exception_text.take("NotFoundError"));
}

test "Chrome's message shape, from the member the binding ran" {
    var buf: [256]u8 = undefined;
    try testing.expectEqualStrings(
        "Failed to execute 'removeChild' on 'Node': The node to be removed is not a child of this node.",
        exception_text.message(&buf, .{ .kind = .operation, .interface_name = "Node", .member_name = "removeChild" }, "The node to be removed is not a child of this node."),
    );
    try testing.expectEqualStrings(
        "Failed to set the 'value' property on 'HTMLInputElement': text",
        exception_text.message(&buf, .{ .kind = .setter, .interface_name = "HTMLInputElement", .member_name = "value" }, "text"),
    );
    try testing.expectEqualStrings(
        "Failed to read the 'x' property from 'Y': text",
        exception_text.message(&buf, .{ .kind = .getter, .interface_name = "Y", .member_name = "x" }, "text"),
    );
    try testing.expectEqualStrings(
        "Failed to construct 'Event': text",
        exception_text.message(&buf, .{ .kind = .constructor, .interface_name = "Event", .member_name = "" }, "text"),
    );
    // A message longer than the buffer is the text alone.
    var small: [16]u8 = undefined;
    try testing.expectEqualStrings("text", exception_text.message(&small, .{ .kind = .operation, .interface_name = "Node", .member_name = "removeChild" }, "text"));
}
