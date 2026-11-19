//! CSSOM 6.6.2: the CSS property attributes of CSSStyleProperties - for each
//! supported CSS property, its camel-cased attribute, its webkit-cased
//! attribute (a -webkit- property's), and its dashed attribute (a property
//! with a "-" in its name) - as one comptime table: each attribute's name and
//! the CSS property its getter and setter pass to getPropertyValue() and
//! setProperty(). The binding defines one accessor per entry on
//! CSSStyleProperties.prototype (Gecko generates CSS2Properties.webidl from
//! its property list; WebKit generates CSSStyleProperties+PropertyNames.idl),
//! reaching an entry by its index.
//!
//! The supported CSS properties are the style declaration's
//! (CSSStyleDeclaration's supported property names): the longhands, the
//! shorthands and the legacy aliases.
//!
//! Spec: https://drafts.csswg.org/cssom-1/#the-cssstyleproperties-interface

const std = @import("std");
const css = @import("css");
const properties = css.properties;

pub const Attribute = struct {
    /// The IDL attribute's name (the property key on the prototype).
    name: [:0]const u8,
    /// The CSS property it stands for.
    property: []const u8,
};

/// CSSOM "CSS property to IDL attribute", optionally with the lowercase
/// first flag: each "-" makes the next character uppercase and is dropped.
fn idlAttribute(comptime property: []const u8, comptime lowercase_first: bool) [:0]const u8 {
    comptime {
        const source = if (lowercase_first) property[1..] else property;
        var out: [source.len:0]u8 = undefined;
        var n: usize = 0;
        var upper = false;
        for (source) |c| {
            if (c == '-') {
                upper = true;
                continue;
            }
            out[n] = if (upper) std.ascii.toUpper(c) else c;
            n += 1;
            upper = false;
        }
        out[n] = 0;
        const final = out;
        return final[0..n :0];
    }
}

fn supportedProperties() []const []const u8 {
    comptime {
        @setEvalBranchQuota(10_000_000);
        var names: []const []const u8 = &.{};
        for (properties.lexicographic) |l| names = names ++ .{l.name()};
        for (@typeInfo(properties.Shorthand).@"enum".field_values) |value| {
            names = names ++ .{@as(properties.Shorthand, @fromBackingInt(@intCast(value))).name()};
        }
        for (properties.legacy_alias_names) |name| names = names ++ .{name};
        return names;
    }
}

/// Every CSS property attribute, in the order of the supported properties:
/// each property's camel-cased, webkit-cased and dashed attribute. The three
/// forms never collide (a camel-cased name has no "-", a dashed one does, and
/// only a -webkit- property's lowercase-first name starts "webkit"), and each
/// supported property is listed once, so no name repeats (the test checks).
pub const attributes: []const Attribute = blk: {
    @setEvalBranchQuota(10_000_000);
    var list: []const Attribute = &.{};
    for (supportedProperties()) |property| {
        list = list ++ .{Attribute{ .name = idlAttribute(property, false), .property = property }};
        if (std.mem.startsWith(u8, property, "-webkit-")) {
            list = list ++ .{Attribute{ .name = idlAttribute(property, true), .property = property }};
        }
        if (std.mem.indexOfScalar(u8, property, '-') != null) {
            list = list ++ .{Attribute{ .name = (property ++ "\x00")[0..property.len :0], .property = property }};
        }
    }
    break :blk list;
};

test "camel-cased, webkit-cased and dashed attributes" {
    try std.testing.expectEqualStrings("fontSize", idlAttribute("font-size", false));
    try std.testing.expectEqualStrings("WebkitTransform", idlAttribute("-webkit-transform", false));
    try std.testing.expectEqualStrings("webkitTransform", idlAttribute("-webkit-transform", true));
    try std.testing.expectEqualStrings("color", idlAttribute("color", false));
    var font_size = false;
    var dashed = false;
    var color = 0;
    var webkit = false;
    for (attributes) |a| {
        if (std.mem.eql(u8, a.name, "fontSize")) font_size = std.mem.eql(u8, a.property, "font-size");
        if (std.mem.eql(u8, a.name, "font-size")) dashed = std.mem.eql(u8, a.property, "font-size");
        if (std.mem.eql(u8, a.name, "color")) color += 1;
        if (std.mem.eql(u8, a.name, "webkitTransform")) webkit = std.mem.eql(u8, a.property, "-webkit-transform");
    }
    try std.testing.expect(font_size);
    try std.testing.expect(dashed);
    try std.testing.expectEqual(1, color);
    try std.testing.expect(webkit);
    // No property without a dash has a dashed attribute of its own name twice.
    for (attributes, 0..) |a, i| for (attributes[i + 1 ..]) |b| try std.testing.expect(!std.mem.eql(u8, a.name, b.name));
}
