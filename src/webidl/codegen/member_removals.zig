//! Which members codegen leaves out of an interface.
//!
//! specs/idl is a pinned webref snapshot, updated only as a whole
//! (specs/idl/WEBREF.md). When a spec REMOVES a member after the pinned
//! snapshot and the browsers do not ship it, the member would otherwise stay
//! exposed until the next snapshot update. Each entry names the interface,
//! the member (an attribute, or a named operation: every overload goes), and
//! why, citing the spec change. Codegen fails on an entry that matches no
//! member, so the snapshot update that drops the member also drops its entry
//! here (ir.zig, "Removed members").
//!
//! Nothing here is a general override: add an entry only for a member the
//! spec has removed since the pinned snapshot.

const std = @import("std");

pub const Removal = struct {
    interface: []const u8,
    member: []const u8,
    reason: []const u8,
};

const message_port_close = "whatwg/html#13016 (merged 2026-10, commit 5facb53) removed MessagePort's close event and its " ++
    "onclose event handler IDL attribute - \"no browser ships the close events\" - and WPT #63174 replaced the tests " ++
    "with webmessaging/message-channels/historical.any.js, which Chrome, Firefox and Safari pass; the pinned webref " ++
    "snapshot (curated bfbec43f, 2026-09-17) predates it. Delete this entry at the next webref snapshot update";

pub const table = [_]Removal{
    .{ .interface = "MessagePort", .member = "onclose", .reason = message_port_close },
};

/// Whether `interface`'s `member` is removed, in `entries`.
pub fn find(entries: []const Removal, interface: []const u8, member: []const u8) ?Removal {
    for (entries) |entry| {
        if (std.mem.eql(u8, entry.interface, interface) and std.mem.eql(u8, entry.member, member)) return entry;
    }
    return null;
}

test "the table names each removed member once, with a reason" {
    for (table, 0..) |entry, i| {
        try std.testing.expect(entry.reason.len > 0);
        for (table[i + 1 ..]) |other| {
            try std.testing.expect(!(std.mem.eql(u8, entry.interface, other.interface) and std.mem.eql(u8, entry.member, other.member)));
        }
    }
    try std.testing.expect(find(&table, "MessagePort", "onclose") != null);
    try std.testing.expect(find(&table, "MessagePort", "onmessage") == null);
}
