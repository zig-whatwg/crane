//! The [Reflect*] extended attributes, as codegen reads them.
//!
//! HTML 2.6.2 "Using reflect via IDL extended attributes": [Reflect],
//! [ReflectSetter], [ReflectURL], [ReflectNonNegative], [ReflectPositive] and
//! [ReflectPositiveWithFallback] each make an attribute reflect a content
//! attribute - its name the string the extended attribute takes, or else the
//! IDL attribute's name in ASCII lowercase - and [ReflectRange] and
//! [ReflectDefault] adjust how. HTML 2.6.1 "Reflecting content attributes in
//! IDL attributes" then gives the getter and setter steps for each IDL type.
//!
//! This module turns an attribute's extended attributes into a `Reflection`,
//! and writes it as the comptime spec the runtime half,
//! `src/webidl/impls/reflection.zig`, takes:
//!
//!     .{ .name = "colspan", .default = 1, .range = .{ 1, 1000 } }
//!
//! so the generated getter can end in
//! `return try reflection.get(u32, instance, .{ ... });`.

const std = @import("std");
const types = @import("types.zig");

/// The IDL types HTML 2.6.1 gives getter and setter steps for, as far as
/// codegen reflects them. `T?` and `FrozenArray<T>?` of Element are not here:
/// they carry per-element state (the explicitly set attr-element(s)) that a
/// stateless reflection cannot hold.
pub const Kind = enum {
    /// DOMString, including [LegacyNullToEmptyString] DOMString - the binding
    /// has already turned a null into "" by the time the setter runs.
    string,
    /// DOMString?
    nullable_string,
    /// USVString
    usv_string,
    boolean,
    long,
    unsigned_long,
    double,
    /// DOMTokenList
    token_list,
};

/// Which "limited to only ..." a numeric reflection is.
pub const Limit = enum {
    none,
    /// [ReflectNonNegative]: long, "limited to only non-negative numbers".
    non_negative,
    /// [ReflectPositive]: "limited to only positive numbers".
    positive,
    /// [ReflectPositiveWithFallback]: "limited to only positive numbers with
    /// fallback".
    positive_with_fallback,
};

/// One reflected attribute.
pub const Reflection = struct {
    kind: Kind,
    /// The reflected content attribute name.
    name: []const u8,
    /// [ReflectSetter]: only the setter reflects; the getter is the
    /// attribute's own prose, so it stays the impl's.
    setter_only: bool = false,
    /// [ReflectURL]: "treated as a URL".
    url: bool = false,
    limit: Limit = .none,
    /// [ReflectDefault]'s argument, as written in the IDL (`1`, `1.0`).
    default: ?[]const u8 = null,
    /// [ReflectRange]'s two arguments, as written in the IDL.
    range: ?[2][]const u8 = null,

    pub fn deinit(self: Reflection, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }

    /// Whether the getter reflects (every primary attribute but
    /// [ReflectSetter]).
    pub fn reflectsGetter(self: Reflection) bool {
        return !self.setter_only;
    }
};

/// The primary reflection extended attributes (HTML 2.6.2: "only one of
/// these can be used at a time"), with the limit each implies.
const primaries = [_]struct { name: []const u8, limit: Limit = .none, url: bool = false, setter_only: bool = false }{
    .{ .name = "Reflect" },
    .{ .name = "ReflectSetter", .setter_only = true },
    .{ .name = "ReflectURL", .url = true },
    .{ .name = "ReflectNonNegative", .limit = .non_negative },
    .{ .name = "ReflectPositive", .limit = .positive },
    .{ .name = "ReflectPositiveWithFallback", .limit = .positive_with_fallback },
};

/// The IDL type of `attr` as a reflection `Kind`, or null for a type codegen
/// does not reflect.
pub fn kindOf(attr: types.Attribute) ?Kind {
    const t = attr.idlType;
    if (t.unionTypes != null or t.sequence != null or t.record != null or t.generic != null) return null;
    const name = t.type;
    if (std.mem.eql(u8, name, "DOMString")) return if (t.nullable) .nullable_string else .string;
    if (t.nullable) return null;
    if (std.mem.eql(u8, name, "USVString")) return .usv_string;
    if (std.mem.eql(u8, name, "boolean")) return .boolean;
    if (std.mem.eql(u8, name, "long")) return .long;
    if (std.mem.eql(u8, name, "unsigned long")) return .unsigned_long;
    if (std.mem.eql(u8, name, "double")) return .double;
    if (std.mem.eql(u8, name, "DOMTokenList")) return .token_list;
    return null;
}

/// The reflection `attr` declares, or null when it has no primary reflection
/// extended attribute or its type is not one codegen reflects. The result's
/// `name` is allocated.
pub fn of(allocator: std.mem.Allocator, attr: types.Attribute) !?Reflection {
    if (attr.static) return null;
    const kind = kindOf(attr) orelse return null;
    for (primaries) |primary| {
        const ext = find(attr.extAttrs, primary.name) orelse continue;
        // "its reflected content attribute name is the string value it takes,
        // if one is provided; otherwise it is the IDL attribute name converted
        // to ASCII lowercase."
        const name = if (ext.rhs) |rhs| switch (rhs) {
            .identifier => |id| try allocator.dupe(u8, unquote(id)),
            .string => |s| try allocator.dupe(u8, unquote(s)),
            else => try std.ascii.allocLowerString(allocator, attr.name),
        } else try std.ascii.allocLowerString(allocator, attr.name);
        var result: Reflection = .{
            .kind = kind,
            .name = name,
            .setter_only = primary.setter_only,
            .url = primary.url,
            .limit = primary.limit,
        };
        if (find(attr.extAttrs, "ReflectDefault")) |d| if (d.rhs) |rhs| switch (rhs) {
            .identifier => |id| result.default = id,
            else => {},
        };
        if (find(attr.extAttrs, "ReflectRange")) |r| if (r.rhs) |rhs| switch (rhs) {
            .identifierList => |list| if (list.len == 2) {
                result.range = .{ list[0], list[1] };
            },
            else => {},
        };
        return result;
    }
    return null;
}

fn find(ext_attrs: []const types.ExtendedAttribute, name: []const u8) ?types.ExtendedAttribute {
    for (ext_attrs) |ext| {
        if (std.mem.eql(u8, ext.name, name)) return ext;
    }
    return null;
}

/// A string literal's lexeme carries its quotes: `"accept-charset"`.
fn unquote(text: []const u8) []const u8 {
    if (text.len >= 2 and (text[0] == '"' or text[0] == '\'') and text[text.len - 1] == text[0]) {
        return text[1 .. text.len - 1];
    }
    return text;
}

/// Write `r` as the comptime `reflection.Spec` literal the runtime helper
/// takes: `.{ .name = "colspan", .default = 1, .range = .{ 1, 1000 } }`.
pub fn writeSpec(writer: anytype, r: Reflection) !void {
    try writer.print(".{{ .name = \"{s}\"", .{r.name});
    if (r.url) try writer.writeAll(", .url = true");
    switch (r.limit) {
        .none => {},
        .non_negative => try writer.writeAll(", .limit = .non_negative"),
        .positive => try writer.writeAll(", .limit = .positive"),
        .positive_with_fallback => try writer.writeAll(", .limit = .positive_with_fallback"),
    }
    if (r.default) |d| try writer.print(", .default = {s}", .{d});
    if (r.range) |range| try writer.print(", .range = .{{ {s}, {s} }}", .{ range[0], range[1] });
    try writer.writeAll(" }");
}
