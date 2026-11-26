//! WebIDL maplike declarations (2.5.11, bound by 3.7.11).
//!
//! A maplike declaration's members - size, entries, forEach, get, has,
//! keys, values, %Symbol.iterator%, and for a read-write maplike set,
//! delete and clear - are not operations: 3.7.11 says the interface
//! prototype object "has" them, each a built-in function over the object's
//! map entries. As for a setlike declaration (setlike.zig), codegen emits
//! no member for it: it writes the declaration into Meta (`Meta.maplike`)
//! for the binding, which defines the members, and a `maplikeEntries`
//! delegate through which the binding reaches the impl's map entries
//! (`webidl.maplike.MapEntries`, `webidl.maplike.PlatformObjects`, or
//! `webidl.maplike.View`). A set, delete or clear the interface declares
//! itself stays an ordinary operation and overrides the binding's
//! (3.7.11.8-10: "If A does not declare a member with identifier ...").

const std = @import("std");
const types = @import("types.zig");
const ir_mod = @import("ir.zig");
const setlike = @import("setlike.zig");

/// Return a maplike declaration with its key and value types resolved through
/// `ir`'s typedefs (e.g. `UUID` -> `DOMString`).
pub fn resolve(ir: ?*const ir_mod.IR, map: types.Maplike) types.Maplike {
    return .{
        .key_type = setlike.resolveType(ir, map.key_type),
        .value_type = setlike.resolveType(ir, map.value_type),
        .readonly = map.readonly,
    };
}

fn isBufferSource(name: []const u8) bool {
    const names = [_][]const u8{
        "DataView",
        "ArrayBuffer",
        "SharedArrayBuffer",
        "Int8Array",
        "Int16Array",
        "Int32Array",
        "Uint8Array",
        "Uint16Array",
        "Uint32Array",
        "Uint8ClampedArray",
        "BigInt64Array",
        "BigUint64Array",
        "Float16Array",
        "Float32Array",
        "Float64Array",
    };
    for (names) |n| {
        if (std.mem.eql(u8, name, n)) return true;
    }
    return false;
}

/// Zig key type for a maplike key IDL type: strings -> `[]const u8`,
/// primitives -> their Zig scalar type.
pub fn keyZigType(key: types.IDLType) error{UnsupportedMaplikeType}![]const u8 {
    if (key.nullable or key.unionTypes != null or key.sequence != null or key.generic != null) {
        return error.UnsupportedMaplikeType;
    }
    if (setlike.isStringType(key.type)) return "[]const u8";
    if (setlike.primitiveZigType(key.type)) |prim| return prim;
    return error.UnsupportedMaplikeType;
}

fn sequenceElementType(value: types.IDLType) ?[]const u8 {
    if (std.mem.eql(u8, value.type, "sequence")) {
        if (value.generic) |g| return g;
        if (value.sequence) |s| return s.type;
    }
    return null;
}

fn writeIDLTypeName(writer: anytype, idl_type: types.IDLType) !void {
    if (sequenceElementType(idl_type)) |elem| {
        try writer.print("sequence<{s}>", .{elem});
    } else {
        try writer.writeAll(idl_type.type);
    }
}

/// Write the Zig type of the map entries of a maplike declaration:
/// - string/primitive value -> `webidl.maplike.MapEntries(<K>, <V>)`
/// - `sequence<T>` value -> `webidl.maplike.View(<K>, []const <Elem>)`
/// - `object` / `any` / buffer source value -> `webidl.maplike.View(<K>, *anyopaque)`
/// - interface value with string key -> `webidl.maplike.PlatformObjects`
/// - interface value with non-string key -> `webidl.maplike.View(<K>, *anyopaque)`
pub fn writeEntriesType(writer: anytype, map: types.Maplike) !void {
    const key_zig = try keyZigType(map.key_type);
    const key_is_string = setlike.isStringType(map.key_type.type);
    const value = map.value_type;
    if (value.nullable or value.unionTypes != null) return error.UnsupportedMaplikeType;

    // 1. sequence<T>
    if (sequenceElementType(value)) |elem_idl| {
        const elem_zig = if (setlike.isStringType(elem_idl))
            "[]const u8"
        else if (setlike.primitiveZigType(elem_idl)) |p|
            p
        else
            return error.UnsupportedMaplikeType;
        try writer.print("webidl.maplike.View({s}, []const {s})", .{ key_zig, elem_zig });
        return;
    }

    if (value.generic != null or value.sequence != null) return error.UnsupportedMaplikeType;

    // 2. String value
    if (setlike.isStringType(value.type)) {
        try writer.print("webidl.maplike.MapEntries({s}, []const u8)", .{key_zig});
        return;
    }

    // 3. Primitive value
    if (setlike.primitiveZigType(value.type)) |prim| {
        try writer.print("webidl.maplike.MapEntries({s}, {s})", .{ key_zig, prim });
        return;
    }

    // 4. object / any / buffer source (traced JS handle kept by impl)
    if (std.mem.eql(u8, value.type, "object") or std.mem.eql(u8, value.type, "any") or isBufferSource(value.type)) {
        try writer.print("webidl.maplike.View({s}, *anyopaque)", .{key_zig});
        return;
    }

    // 5. Interface value (platform object traced by impl)
    if (value.type.len != 0 and std.ascii.isUpper(value.type[0])) {
        if (key_is_string) {
            try writer.writeAll("webidl.maplike.PlatformObjects");
        } else {
            try writer.print("webidl.maplike.View({s}, *anyopaque)", .{key_zig});
        }
        return;
    }

    return error.UnsupportedMaplikeType;
}

/// `Meta.maplike`, inside the interface's Meta: the declaration's resolved key
/// and value types (their IDL names) and whether it is readonly.
///
///     pub const maplike = .{ .key_type = "DOMString", .value_type = "Highlight", .readonly = false };
pub fn writeMeta(writer: anytype, map: types.Maplike) !void {
    try writer.writeAll("        \n");
    try writer.writeAll("        /// Maplike declaration (WebIDL 2.5.11): the binding defines its members\n");
    try writer.writeAll("        /// (3.7.11) over the impl's map entries (`maplikeEntries`).\n");
    try writer.writeAll("        pub const maplike = .{ .key_type = \"");
    try writeIDLTypeName(writer, map.key_type);
    try writer.writeAll("\", .value_type = \"");
    try writeIDLTypeName(writer, map.value_type);
    try writer.print("\", .readonly = {} }};\n", .{map.readonly});
}

/// The delegate the binding reads the impl's map entries through, in the
/// generated interface: the impl's `maplikeEntries(instance)`, null when the
/// instance has none (its impl state is gone).
pub fn writeEntriesDelegate(writer: anytype, impl_name: []const u8, map: types.Maplike) !void {
    try writer.writeAll("    /// The map entries of this maplike object (WebIDL 2.5.11), for the\n");
    try writer.writeAll("    /// binding's maplike members.\n");
    try writer.writeAll("    pub fn maplikeEntries(instance: *runtime.Instance) ?*");
    try writeEntriesType(writer, map);
    try writer.writeAll(" {\n");
    try writer.print("        return {s}.maplikeEntries(instance);\n", .{impl_name});
    try writer.writeAll("    }\n\n");
}
