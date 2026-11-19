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
//! (`webidl.maplike.PlatformObjects`). A set, delete or clear the interface
//! declares itself stays an ordinary operation and overrides the binding's
//! (3.7.11.8-10: "If A does not declare a member with identifier ...").
//!
//! Staged by owner: an interface is listed in `implemented` in the commit
//! that gives its impl the map entries. The others keep the placeholder
//! their declaration has always generated, byte for byte, until then.

const std = @import("std");
const types = @import("types.zig");

/// The maplike interfaces whose impls keep their map entries for the binding.
pub const implemented = [_][]const u8{"HighlightRegistry"};

pub fn isImplemented(interface_name: []const u8) bool {
    for (implemented) |name| {
        if (std.mem.eql(u8, name, interface_name)) return true;
    }
    return false;
}

/// The Zig type of the map entries of a maplike declaration: a string key
/// type with an interface value type is `webidl.maplike.PlatformObjects` -
/// a view of the entries its impl keeps, and traces (HighlightRegistry's
/// <DOMString, Highlight>). Any other key or value type is an error, so an
/// interface listed in `implemented` with one fails the regeneration.
pub fn entriesType(map: types.Maplike) error{UnsupportedMaplikeType}![]const u8 {
    const key = map.key_type;
    if (key.nullable or key.unionTypes != null or key.sequence != null) return error.UnsupportedMaplikeType;
    const string_key = for ([_][]const u8{ "DOMString", "USVString", "ByteString", "CSSOMString" }) |string| {
        if (std.mem.eql(u8, key.type, string)) break true;
    } else false;
    if (!string_key) return error.UnsupportedMaplikeType;
    const value = map.value_type;
    if (value.nullable or value.unionTypes != null or value.sequence != null) return error.UnsupportedMaplikeType;
    // An interface name: an identifier starting with an uppercase letter
    // (WebIDL's primitive and built-in types are lowercase keywords).
    if (value.type.len != 0 and std.ascii.isUpper(value.type[0])) return "webidl.maplike.PlatformObjects";
    return error.UnsupportedMaplikeType;
}

/// `Meta.maplike`, inside the interface's Meta: the declaration's key and
/// value types (their IDL names) and whether it is readonly.
///
///     pub const maplike = .{ .key_type = "DOMString", .value_type = "Highlight", .readonly = false };
pub fn writeMeta(writer: anytype, map: types.Maplike) !void {
    try writer.writeAll("        \n");
    try writer.writeAll("        /// Maplike declaration (WebIDL 2.5.11): the binding defines its members\n");
    try writer.writeAll("        /// (3.7.11) over the impl's map entries (`maplikeEntries`).\n");
    try writer.print("        pub const maplike = .{{ .key_type = \"{s}\", .value_type = \"{s}\", .readonly = {} }};\n", .{ map.key_type.type, map.value_type.type, map.readonly });
}

/// The delegate the binding reads the impl's map entries through, in the
/// generated interface: the impl's `maplikeEntries(instance)`, null when the
/// instance has none (its impl state is gone).
pub fn writeEntriesDelegate(writer: anytype, impl_name: []const u8, map: types.Maplike) !void {
    const entries = try entriesType(map);
    try writer.writeAll("    /// The map entries of this maplike object (WebIDL 2.5.11), for the\n");
    try writer.writeAll("    /// binding's maplike members.\n");
    try writer.print("    pub fn maplikeEntries(instance: *runtime.Instance) ?*{s} {{\n", .{entries});
    try writer.print("        return {s}.maplikeEntries(instance);\n", .{impl_name});
    try writer.writeAll("    }\n\n");
}

test "entriesType: string keys with interface values" {
    const string: types.IDLType = .{ .type = "DOMString" };
    const highlight: types.IDLType = .{ .type = "Highlight" };
    try std.testing.expectEqualStrings("webidl.maplike.PlatformObjects", try entriesType(.{ .key_type = string, .value_type = highlight }));
    try std.testing.expectError(error.UnsupportedMaplikeType, entriesType(.{ .key_type = .{ .type = "unsigned short" }, .value_type = highlight }));
    try std.testing.expectError(error.UnsupportedMaplikeType, entriesType(.{ .key_type = string, .value_type = .{ .type = "unsigned long long" } }));
}

test "writeMeta and writeEntriesDelegate" {
    var buffer: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer buffer.deinit();
    const map: types.Maplike = .{ .key_type = .{ .type = "DOMString" }, .value_type = .{ .type = "Highlight" } };
    try writeMeta(&buffer.writer, map);
    try writeEntriesDelegate(&buffer.writer, "HighlightRegistryImpl", map);
    const text = buffer.written();
    try std.testing.expect(std.mem.indexOf(u8, text, "pub const maplike = .{ .key_type = \"DOMString\", .value_type = \"Highlight\", .readonly = false };") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "pub fn maplikeEntries(instance: *runtime.Instance) ?*webidl.maplike.PlatformObjects {") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "return HighlightRegistryImpl.maplikeEntries(instance);") != null);
}
