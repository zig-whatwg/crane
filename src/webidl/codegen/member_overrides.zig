//! Which members a supplementary IDL file replaces.
//!
//! An interface's partial definitions merge their members into it (ir.zig,
//! "Merging"); an attribute or a named operation a supplementary file
//! declares again for one interface is an error - codegen stops and names
//! both - except where this table says a file replaces it (an operation is
//! then replaced, not given an overload). Each entry names the interface, the member, the file whose
//! declaration wins, and why. The replaced declaration keeps its position
//! among the members; the replacing one's type and extended attributes take
//! its place.
//!
//! Nothing here is a general override: add an entry only for a spec that
//! redefines a member another spec defines, where webref's IDL keeps the
//! older definition.

const std = @import("std");

pub const Override = struct {
    interface: []const u8,
    member: []const u8,
    /// The file (basename) whose declaration wins.
    file: []const u8,
    reason: []const u8,
};

const trusted_types_script = "Trusted Types 4.1.2 (https://w3c.github.io/trusted-types/dist/spec/#enforcement-in-scripts) " ++
    "redefines HTMLScriptElement's text and src with Trusted Types unions (TrustedScript or DOMString), " ++
    "(TrustedScriptURL or USVString); webref's trusted-types.idl omits that partial interface because it " ++
    "conflicts with html.idl's declarations, so specs/supplementary/trusted-types-script.idl restates it";

const editing_exec_command = "The editing spec (https://w3c.github.io/editing/docs/execCommand/#execcommand()) declares " ++
    "execCommand's value as (TrustedHTML or DOMString), so a TrustedHTML reaches Trusted Types' check for the " ++
    "insertHTML command as itself; webref's html.idl keeps optional DOMString, so " ++
    "specs/supplementary/execcommand.idl restates the editing spec's declaration";

pub const table = [_]Override{
    .{ .interface = "HTMLScriptElement", .member = "src", .file = "trusted-types-script.idl", .reason = trusted_types_script },
    .{ .interface = "HTMLScriptElement", .member = "text", .file = "trusted-types-script.idl", .reason = trusted_types_script },
    .{ .interface = "Document", .member = "execCommand", .file = "execcommand.idl", .reason = editing_exec_command },
};

/// The override for `interface`'s `member`, in `entries`.
pub fn find(entries: []const Override, interface: []const u8, member: []const u8) ?Override {
    for (entries) |entry| {
        if (std.mem.eql(u8, entry.interface, interface) and std.mem.eql(u8, entry.member, member)) return entry;
    }
    return null;
}

test "the table names each replaced member once, with its file and reason" {
    for (table, 0..) |entry, i| {
        try std.testing.expect(entry.reason.len > 0);
        try std.testing.expect(std.mem.endsWith(u8, entry.file, ".idl"));
        for (table[i + 1 ..]) |other| {
            try std.testing.expect(!(std.mem.eql(u8, entry.interface, other.interface) and std.mem.eql(u8, entry.member, other.member)));
        }
    }
    try std.testing.expectEqualStrings("trusted-types-script.idl", find(&table, "HTMLScriptElement", "text").?.file);
    try std.testing.expect(find(&table, "HTMLScriptElement", "async") == null);
    try std.testing.expectEqualStrings("execcommand.idl", find(&table, "Document", "execCommand").?.file);
}
