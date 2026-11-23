//! The text of the exception a failing binding call throws (lane react1; the
//! integrator's approval, 2026-11-22: a per-thread call-stack extent).
//!
//! WebIDL leaves an exception's message to the implementation; every browser
//! gives one. An impl that fails returns a Zig error, and the engine adapter
//! turns it into the exception (WebIDL "throw": a DOMException whose name is
//! the error's). The text travels beside the error: the impl records it as it
//! returns the error (`fail`), and the adapter's conversion of that error
//! takes it (`take`) when the error's name is the recorded one, then builds
//! the message from the member the binding ran (`message`). An error with no
//! text keeps the name as its message.
//!
//! A text is the failing call's alone: every binding entry clears what an
//! earlier call left (`beginBindingCall`), so a text an impl recorded and a
//! Zig caller then caught and carried on from never names a later call's
//! error of the same name; and a conversion clears the record, taken or not.
//!
//! Texts are static (comptime strings): recording one allocates nothing, and
//! a call that succeeds costs only the entry's clear.

const std = @import("std");

const Pending = struct {
    /// The name of the error the text belongs to (@errorName).
    name: []const u8,
    text: []const u8,
};

// per-thread: a call-stack extent - the text the failing binding call on this thread's stack recorded with its error, set by the impl as it returns the error (fail), read and cleared by the engine adapter's conversion of that error on the same stack, and cleared at every binding entry on this thread.
threadlocal var pending: ?Pending = null;

/// Record `text` for `err`, the error this impl is returning, and return it:
/// `return exception_text.fail(error.NotFoundError, "...")`.
pub inline fn fail(comptime err: anytype, comptime text: []const u8) @TypeOf(err) {
    pending = .{ .name = @errorName(err), .text = text };
    return err;
}

/// A binding call begins: a text an earlier call left is not this call's.
pub inline fn beginBindingCall() void {
    pending = null;
}

/// The text recorded for the error named `error_name`, or null; either way
/// the record is gone.
pub fn take(error_name: []const u8) ?[]const u8 {
    const p = pending orelse return null;
    pending = null;
    if (!std.mem.eql(u8, p.name, error_name)) return null;
    return p.text;
}

/// What the failing member is, for the message's prefix.
pub const Member = struct {
    kind: Kind,
    interface_name: []const u8,
    /// The operation's or attribute's name; unused for a constructor.
    member_name: []const u8,

    pub const Kind = enum { operation, getter, setter, constructor };
};

/// The exception's message: Chrome's shape - "Failed to execute 'op' on
/// 'Interface': <text>", "Failed to read the 'attr' property from
/// 'Interface': <text>", "Failed to set the 'attr' property on 'Interface':
/// <text>", "Failed to construct 'Interface': <text>" - in `buf`; the text
/// alone when `buf` cannot hold it. The three browsers have no majority on
/// the prefix (Firefox writes "Interface.op: <text>", Safari the text alone)
/// and WebIDL leaves the message to the implementation, so it is Chrome's,
/// whose engine Crane's is (the integrator, 2026-11-22). The text itself is
/// recorded only where Chrome's agrees with Firefox's or Safari's.
pub fn message(buf: []u8, member: Member, text: []const u8) []const u8 {
    const written = switch (member.kind) {
        .operation => std.fmt.bufPrint(buf, "Failed to execute '{s}' on '{s}': {s}", .{ member.member_name, member.interface_name, text }),
        .getter => std.fmt.bufPrint(buf, "Failed to read the '{s}' property from '{s}': {s}", .{ member.member_name, member.interface_name, text }),
        .setter => std.fmt.bufPrint(buf, "Failed to set the '{s}' property on '{s}': {s}", .{ member.member_name, member.interface_name, text }),
        .constructor => std.fmt.bufPrint(buf, "Failed to construct '{s}': {s}", .{ member.interface_name, text }),
    };
    return written catch text;
}
