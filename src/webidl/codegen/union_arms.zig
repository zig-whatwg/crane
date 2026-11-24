//! The `arms` table codegen writes beside every generated union (lane bind1
//! batch B, B3): one `webidl.UnionArm` per field, naming the field and the
//! kind of its member type, so that the binding's union conversion (WebIDL
//! 3.2.25) asks its questions - "an interface type V implements", "a sequence
//! type", "a string type" - of the IDL types, never of Zig type shapes or arm
//! names. What each kind means: src/webidl/types/union_arms.zig.

const std = @import("std");
const types = @import("types.zig");
const ir_mod = @import("ir.zig");

/// A member type codegen cannot describe. Each names a shape the binding's
/// union conversion has no step for, or one IDL does not allow in a union.
pub const Error = error{
    /// A union written inline among another union's members, `(A or (B or
    /// C))`: its Zig field is not a generated union with a table of its own.
    InlineNestedUnion,
    /// `any` or a promise type: neither may be a union member (WebIDL
    /// 2.13.32).
    NotAUnionMemberType,
    /// A name that is no type the model defines.
    UnknownUnionMemberType,
};

/// A member type's kind, as the `.kind = ...` text of its arm.
const Kind = union(enum) {
    /// A tag of `webidl.union_arms.Kind` with no payload: `string` writes
    /// `.string`.
    tag: []const u8,
    /// An interface type, by name.
    interface: []const u8,
    /// A typed array type, by its [[TypedArrayName]].
    typed_array: []const u8,
};

const string_types = [_][]const u8{ "DOMString", "USVString", "ByteString" };

const numeric_types = [_][]const u8{
    "byte",  "octet",              "short",     "unsigned short",
    "long",  "unsigned long",      "long long", "unsigned long long",
    "float", "unrestricted float", "double",    "unrestricted double",
};

const typed_array_types = [_][]const u8{
    "Int8Array",      "Uint8Array",   "Uint8ClampedArray", "Int16Array",
    "Uint16Array",    "Int32Array",   "Uint32Array",       "BigInt64Array",
    "BigUint64Array", "Float16Array", "Float32Array",      "Float64Array",
};

/// The buffer source typedefs, generated as webidl.buffer_sources' own
/// unions (generator.special_typedef_files), each converted by its own rules.
const buffer_source_typedefs = [_]struct { []const u8, []const u8 }{
    .{ "BufferSource", "buffer_source" },
    .{ "AllowSharedBufferSource", "allow_shared_buffer_source" },
    .{ "ArrayBufferView", "array_buffer_view" },
};

fn isOneOf(name: []const u8, comptime list: []const []const u8) bool {
    for (list) |item| {
        if (std.mem.eql(u8, name, item)) return true;
    }
    return false;
}

/// The kind of union member type `idl_type` in `model`.
fn kindOf(idl_type: types.IDLType, model: *const ir_mod.IR, depth: u8) Error!Kind {
    if (idl_type.unionTypes != null) return error.InlineNestedUnion;
    if (idl_type.sequence != null) return .{ .tag = "sequence" };
    if (idl_type.record != null) return .{ .tag = "record" };
    var name = idl_type.type;
    if (std.mem.indexOf(u8, name, "::")) |colon| name = name[colon + 2 ..];
    if (idl_type.generic != null) {
        if (std.mem.eql(u8, name, "sequence")) return .{ .tag = "sequence" };
        if (std.mem.eql(u8, name, "record")) return .{ .tag = "record" };
        if (std.mem.eql(u8, name, "FrozenArray") or std.mem.eql(u8, name, "ObservableArray")) return .{ .tag = "frozen_array" };
        if (std.mem.eql(u8, name, "async_sequence")) return .{ .tag = "async_sequence" };
        if (std.mem.eql(u8, name, "Promise")) return error.NotAUnionMemberType;
        return error.UnknownUnionMemberType;
    }
    if (isOneOf(name, &string_types)) return .{ .tag = "string" };
    if (isOneOf(name, &numeric_types)) return .{ .tag = "numeric" };
    if (std.mem.eql(u8, name, "boolean")) return .{ .tag = "boolean" };
    if (std.mem.eql(u8, name, "bigint")) return .{ .tag = "bigint" };
    if (std.mem.eql(u8, name, "undefined") or std.mem.eql(u8, name, "void")) return .{ .tag = "undefined" };
    if (std.mem.eql(u8, name, "object")) return .{ .tag = "object" };
    if (std.mem.eql(u8, name, "any")) return error.NotAUnionMemberType;
    if (std.mem.eql(u8, name, "ArrayBuffer")) return .{ .tag = "array_buffer" };
    if (std.mem.eql(u8, name, "SharedArrayBuffer")) return .{ .tag = "shared_array_buffer" };
    if (std.mem.eql(u8, name, "DataView")) return .{ .tag = "data_view" };
    for (typed_array_types) |typed_array| {
        if (std.mem.eql(u8, name, typed_array)) return .{ .typed_array = typed_array };
    }
    for (buffer_source_typedefs) |entry| {
        if (std.mem.eql(u8, name, entry[0])) return .{ .tag = entry[1] };
    }
    // A typedef: a union is a nested union (its own generated union and
    // table); anything else is the kind of the type it names.
    if (model.typedefs.get(name)) |typedef| {
        if (typedef.idlType.unionTypes != null) return .{ .tag = "@\"union\"" };
        if (depth >= 8) return error.UnknownUnionMemberType;
        return kindOf(typedef.idlType, model, depth + 1);
    }
    const kind = model.type_registry.lookup(name) orelse return error.UnknownUnionMemberType;
    return switch (kind) {
        .interface => .{ .interface = name },
        .callback_interface => .{ .tag = "callback_interface" },
        .dictionary => .{ .tag = "dictionary" },
        .enum_type => .{ .tag = "enumeration" },
        .callback => .{ .tag = "callback_function" },
        else => error.UnknownUnionMemberType,
    };
}

/// Write union `union_types`' arms table, its fields named `field_names`
/// (the union's fields, in member order).
pub fn writeArms(
    w: anytype,
    union_name: []const u8,
    union_types: []const types.IDLType,
    field_names: []const []const u8,
    model: *const ir_mod.IR,
) !void {
    std.debug.assert(union_types.len == field_names.len);
    try w.writeAll("\n    /// What each field's member type is, for the binding's union conversion\n");
    try w.writeAll("    /// (WebIDL 3.2.25; webidl.union_arms).\n");
    try w.writeAll("    pub const arms = [_]webidl.UnionArm{\n");
    for (union_types, field_names) |member, field| {
        const kind = kindOf(member, model, 0) catch |err| {
            std.debug.print("  error: union {s}: member `{s}` ({s}): {s}\n", .{ union_name, member.type, field, @errorName(err) });
            return err;
        };
        try w.print("        .{{ .field = \"{s}\", .kind = ", .{field});
        switch (kind) {
            .tag => |tag| try w.print(".{s}", .{tag}),
            .interface => |interface| try w.print(".{{ .interface = \"{s}\" }}", .{interface}),
            .typed_array => |typed_array| try w.print(".{{ .typed_array = \"{s}\" }}", .{typed_array}),
        }
        try w.writeAll(" },\n");
    }
    try w.writeAll("    };\n");
}
