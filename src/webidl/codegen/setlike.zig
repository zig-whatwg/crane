//! WebIDL setlike declarations (2.5.12, bound by 3.7.12).
//!
//! A setlike declaration's members - size, has, forEach, entries, keys,
//! values, %Symbol.iterator%, and for a read-write setlike add, delete and
//! clear - are not operations: 3.7.12 says the interface prototype object
//! "has" them, each a built-in function over the object's set entries. So
//! codegen emits no member for the declaration (an operation it invented
//! would be a `call_*` map entry some impl has to fill in, and a stub fills
//! it with nothing - docs/lessons/codegen-an-iterable-declaration-s-members-
//! are-not-operations.md). It writes the declaration into Meta
//! (`Meta.setlike`) for the binding, which defines the members, and a
//! `setlikeEntries` delegate through which the binding reaches the impl's
//! set entries (`webidl.setlike.SetEntries`). An add, delete or clear the
//! interface declares itself stays an ordinary operation and overrides the
//! binding's (3.7.12.8-10: "If A does not declare a member with identifier
//! ...").
//!
//! Staged by owner: an interface is listed in `implemented` in the commit
//! that gives its impl the set entries. The others keep the placeholder
//! their declaration has always generated, byte for byte, until then.

const std = @import("std");
const types = @import("types.zig");

/// The setlike interfaces whose impls keep their set entries in a
/// `webidl.setlike.SetEntries`.
pub const implemented = [_][]const u8{"CustomStateSet"};

pub fn isImplemented(interface_name: []const u8) bool {
    for (implemented) |name| {
        if (std.mem.eql(u8, name, interface_name)) return true;
    }
    return false;
}

/// The Zig type of the set entries of a setlike declaration whose value type
/// is `value_type`: a string type's set keeps its own copies
/// (`webidl.setlike.Strings`). Values the binding converts to an interface
/// (FontFaceSet's FontFace, Highlight's AbstractRange) need a traced edge per
/// entry, which the set entries do not draw yet: an error, so an interface
/// listed in `implemented` with one fails the regeneration.
pub fn entriesType(value_type: types.IDLType) error{UnsupportedSetlikeValueType}![]const u8 {
    if (value_type.nullable or value_type.unionTypes != null or value_type.sequence != null) return error.UnsupportedSetlikeValueType;
    const name = value_type.type;
    for ([_][]const u8{ "DOMString", "USVString", "ByteString", "CSSOMString" }) |string| {
        if (std.mem.eql(u8, name, string)) return "webidl.setlike.Strings";
    }
    return error.UnsupportedSetlikeValueType;
}

/// `Meta.setlike`, inside the interface's Meta: the declaration's value type
/// (its IDL name) and whether it is readonly.
///
///     pub const setlike = .{ .value_type = "DOMString", .readonly = false };
pub fn writeMeta(writer: anytype, set: types.Setlike) !void {
    try writer.writeAll("        \n");
    try writer.writeAll("        /// Setlike declaration (WebIDL 2.5.12): the binding defines its members\n");
    try writer.writeAll("        /// (3.7.12) over the impl's set entries (`setlikeEntries`).\n");
    try writer.print("        pub const setlike = .{{ .value_type = \"{s}\", .readonly = {} }};\n", .{ set.value_type.type, set.readonly });
}

/// The delegate the binding reads the impl's set entries through, in the
/// generated interface: the impl's `setlikeEntries(instance)`, null when the
/// instance has none (its impl state is gone).
pub fn writeEntriesDelegate(writer: anytype, impl_name: []const u8, set: types.Setlike) !void {
    const entries = try entriesType(set.value_type);
    try writer.writeAll("    /// The set entries of this setlike object (WebIDL 2.5.12), for the\n");
    try writer.writeAll("    /// binding's setlike members.\n");
    try writer.print("    pub fn setlikeEntries(instance: *runtime.Instance) ?*{s} {{\n", .{entries});
    try writer.print("        return {s}.setlikeEntries(instance);\n", .{impl_name});
    try writer.writeAll("    }\n\n");
}
