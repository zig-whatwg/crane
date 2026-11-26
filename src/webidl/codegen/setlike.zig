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
//! set entries (`webidl.setlike.SetEntries` or `webidl.setlike.PlatformObjects`).
//! An add, delete or clear the interface declares itself stays an ordinary
//! operation and overrides the binding's (3.7.12.8-10: "If A does not declare
//! a member with identifier ...").

const std = @import("std");
const types = @import("types.zig");
const ir_mod = @import("ir.zig");

/// Resolve typedefs (e.g. `UUID` -> `DOMString`) so Meta and entries delegates
/// see the canonical IDL type.
pub fn resolveType(ir: ?*const ir_mod.IR, idl_type: types.IDLType) types.IDLType {
    const model = ir orelse return idl_type;
    var current = idl_type;
    var depth: usize = 0;
    while (depth < 8) : (depth += 1) {
        if (current.unionTypes != null or current.sequence != null or current.generic != null) break;
        const td = model.typedefs.get(current.type) orelse break;
        var next = td.idlType;
        if (current.nullable) next.nullable = true;
        current = next;
    }
    return current;
}

/// Return a setlike declaration with its value type resolved through `ir`'s typedefs.
pub fn resolve(ir: ?*const ir_mod.IR, set: types.Setlike) types.Setlike {
    return .{
        .value_type = resolveType(ir, set.value_type),
        .readonly = set.readonly,
    };
}

pub fn isStringType(name: []const u8) bool {
    for ([_][]const u8{ "DOMString", "USVString", "ByteString", "CSSOMString" }) |s| {
        if (std.mem.eql(u8, name, s)) return true;
    }
    return false;
}

/// Zig scalar type for a WebIDL primitive, or null for non-primitives.
pub fn primitiveZigType(name: []const u8) ?[]const u8 {
    const map = .{
        .{ "boolean", "bool" },
        .{ "byte", "i8" },
        .{ "octet", "u8" },
        .{ "short", "i16" },
        .{ "unsigned short", "u16" },
        .{ "long", "i32" },
        .{ "unsigned long", "u32" },
        .{ "long long", "i64" },
        .{ "unsigned long long", "u64" },
        .{ "float", "f32" },
        .{ "unrestricted float", "f32" },
        .{ "double", "f64" },
        .{ "unrestricted double", "f64" },
    };
    inline for (map) |entry| {
        if (std.mem.eql(u8, name, entry[0])) return entry[1];
    }
    return null;
}

/// The Zig type of the set entries of a setlike declaration whose value type
/// is `value_type`:
/// - string types -> `webidl.setlike.Strings`
/// - primitive types -> `webidl.setlike.SetEntries(<zig_prim>)`
/// - interface types -> `webidl.setlike.PlatformObjects`
pub fn entriesType(value_type: types.IDLType) error{UnsupportedSetlikeValueType}![]const u8 {
    if (value_type.nullable or value_type.unionTypes != null or value_type.sequence != null or value_type.generic != null) {
        return error.UnsupportedSetlikeValueType;
    }
    const name = value_type.type;
    if (isStringType(name)) return "webidl.setlike.Strings";
    const prim_entries = .{
        .{ "boolean", "webidl.setlike.SetEntries(bool)" },
        .{ "byte", "webidl.setlike.SetEntries(i8)" },
        .{ "octet", "webidl.setlike.SetEntries(u8)" },
        .{ "short", "webidl.setlike.SetEntries(i16)" },
        .{ "unsigned short", "webidl.setlike.SetEntries(u16)" },
        .{ "long", "webidl.setlike.SetEntries(i32)" },
        .{ "unsigned long", "webidl.setlike.SetEntries(u32)" },
        .{ "long long", "webidl.setlike.SetEntries(i64)" },
        .{ "unsigned long long", "webidl.setlike.SetEntries(u64)" },
        .{ "float", "webidl.setlike.SetEntries(f32)" },
        .{ "unrestricted float", "webidl.setlike.SetEntries(f32)" },
        .{ "double", "webidl.setlike.SetEntries(f64)" },
        .{ "unrestricted double", "webidl.setlike.SetEntries(f64)" },
    };
    inline for (prim_entries) |entry| {
        if (std.mem.eql(u8, name, entry[0])) return entry[1];
    }
    // An interface name: an identifier starting with an uppercase letter
    // (WebIDL's primitive and built-in types are lowercase keywords).
    if (name.len != 0 and std.ascii.isUpper(name[0])) return "webidl.setlike.PlatformObjects";
    return error.UnsupportedSetlikeValueType;
}

/// `Meta.setlike`, inside the interface's Meta: the declaration's value type
/// (its resolved IDL name) and whether it is readonly.
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
