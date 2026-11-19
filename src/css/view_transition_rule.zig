//! CSS View Transitions 2 §8.3: the @view-transition rule's descriptors.
//!
//! "@view-transition { <declaration-list> }" accepts two descriptors:
//! navigation (§8.3.2: auto | none) and types (§9.4: none |
//! <view-transition-type>+, a <view-transition-type> being "any
//! <custom-ident> other than none, and not starting with the string
//! "-ua-""). A descriptor whose value does not match its grammar "must be
//! ignored in [its] entirety; [it does] not make the @view-transition rule
//! invalid" (§8.3.2), so a rule keeps only the valid descriptors, the last
//! valid declaration of each winning.
//!
//! Serialization: CSSOM's "serialize a CSS rule" has no @view-transition
//! steps; Chrome, Firefox and Safari serialize the declared descriptors in
//! the order navigation, types, each as "name: value;", in "@view-transition
//! { ... }", and a rule with neither as "@view-transition { }"
//! (css-view-transitions/navigation/with-types/at-rule-with-types-parsing.html:
//! Chrome and Safari 16/16, Firefox Nightly 16/16).
//!
//! Spec: https://drafts.csswg.org/css-view-transitions-2/#view-transition-rule

const std = @import("std");
const Allocator = std.mem.Allocator;
const rules = @import("rules.zig");
const properties = @import("properties.zig");
const tokenizer = @import("tokenizer.zig");
const serialize = @import("serialize.zig");
const values = @import("style_values.zig");

pub const Navigation = enum { auto, none };

pub const Data = struct {
    allocator: Allocator,
    /// The navigation descriptor, null when the rule declares no valid one.
    navigation: ?Navigation = null,
    /// The types descriptor: null when the rule declares no valid one, an
    /// empty list for `none`, else the <view-transition-type>s in order
    /// (decoded; duplicates kept, as the grammar's `+` keeps them).
    types: ?[][]u8 = null,

    pub fn deinit(self: *Data) void {
        self.freeTypes();
        self.* = undefined;
    }

    fn freeTypes(self: *Data) void {
        const list = self.types orelse return;
        for (list) |name| self.allocator.free(name);
        self.allocator.free(list);
        self.types = null;
    }

    /// The types as the CSSOM's `types` getter answers them (§8.3.3): the
    /// descriptor's value, or an empty list when the rule has none.
    pub fn typeList(self: *const Data) []const []const u8 {
        const list = self.types orelse return &.{};
        return list;
    }

    pub fn cssText(self: *const Data, allocator: Allocator) Allocator.Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try out.appendSlice(allocator, "@view-transition { ");
        if (self.navigation) |navigation| {
            try out.appendSlice(allocator, "navigation: ");
            try out.appendSlice(allocator, @tagName(navigation));
            try out.appendSlice(allocator, "; ");
        }
        if (self.types) |list| {
            try out.appendSlice(allocator, "types: ");
            if (list.len == 0) try out.appendSlice(allocator, "none");
            for (list, 0..) |name, i| {
                if (i != 0) try out.append(allocator, ' ');
                try serialize.appendIdentifier(&out, allocator, name);
            }
            try out.appendSlice(allocator, "; ");
        }
        try out.append(allocator, '}');
        return out.toOwnedSlice(allocator);
    }
};

/// The rule's data, or null when `rule` is no valid @view-transition rule:
/// the at-rule needs a block, and its prelude is empty (§8.3.1's syntax).
pub fn fromParsed(allocator: Allocator, rule: *const rules.Rule) Allocator.Error!?Data {
    if (!rule.has_block) return null;
    if (std.mem.trim(u8, rule.prelude, " \t\n\r\x0c").len != 0) return null;
    var result: Data = .{ .allocator = allocator };
    errdefer result.deinit();
    for (rule.declarations) |declaration| {
        // A descriptor takes no !important (CSS Cascade 5 6.4: it is not
        // a property declaration); browsers drop the declaration.
        if (declaration.important) continue;
        if (std.mem.eql(u8, declaration.name, "navigation")) {
            if (parseNavigation(declaration.value)) |navigation| result.navigation = navigation;
        } else if (std.mem.eql(u8, declaration.name, "types")) {
            if (try parseTypes(allocator, declaration.value)) |list| {
                result.freeTypes();
                result.types = list;
            }
        }
    }
    return result;
}

/// §8.3.2: auto | none, ASCII case-insensitively.
fn parseNavigation(text: []const u8) ?Navigation {
    var stream = properties.Stream.init(text);
    const token = stream.next();
    if (token.token_type != .ident or !stream.atEnd()) return null;
    if (std.ascii.eqlIgnoreCase(token.value, "auto")) return .auto;
    if (std.ascii.eqlIgnoreCase(token.value, "none")) return .none;
    return null;
}

/// §9.4: none | <view-transition-type>+. Owned list, or null when invalid.
fn parseTypes(allocator: Allocator, text: []const u8) Allocator.Error!?[][]u8 {
    var stream = properties.Stream.init(text);
    var list: std.ArrayList([]u8) = .empty;
    defer {
        for (list.items) |name| allocator.free(name);
        list.deinit(allocator);
    }
    var count: usize = 0;
    var saw_none = false;
    while (!stream.atEnd()) : (count += 1) {
        const token = stream.next();
        if (token.token_type != .ident) return null;
        const decoded = try tokenizer.decode(allocator, token.value);
        var owned = true;
        defer if (owned) allocator.free(decoded);
        if (std.ascii.eqlIgnoreCase(decoded, "none")) {
            saw_none = true;
            continue;
        }
        // Values 4 §4.2: a <custom-ident> is never a CSS-wide keyword nor
        // `default`; §9.4 also excludes the "-ua-" prefix, as written
        // (Chrome and Safari keep "-uA-something").
        if (values.CssWide.parse(decoded) != null or std.ascii.eqlIgnoreCase(decoded, "default")) return null;
        if (std.mem.startsWith(u8, decoded, "-ua-")) return null;
        try list.append(allocator, decoded);
        owned = false;
    }
    // `none` stands alone.
    if (saw_none) {
        if (count != 1) return null;
        return try allocator.alloc([]u8, 0);
    }
    if (list.items.len == 0) return null;
    return try list.toOwnedSlice(allocator);
}

const testing = std.testing;

fn expectTypes(input: []const u8, expected: ?[]const []const u8) !void {
    const parsed = try parseTypes(testing.allocator, input);
    defer if (parsed) |list| {
        for (list) |name| testing.allocator.free(name);
        testing.allocator.free(list);
    };
    if (expected) |want| {
        const got = parsed orelse return error.TestExpectedEqual;
        try testing.expectEqual(want.len, got.len);
        for (want, got) |w, g| try testing.expectEqualStrings(w, g);
    } else try testing.expect(parsed == null);
}

test "types: none | <view-transition-type>+" {
    try expectTypes("nOnE", &.{});
    try expectTypes("abc", &.{"abc"});
    try expectTypes("abc xyz", &.{ "abc", "xyz" });
    try expectTypes("abc\\ xyz", &.{"abc xyz"});
    try expectTypes("   abc \txyz ", &.{ "abc", "xyz" });
    try expectTypes("abc -uA-something", &.{ "abc", "-uA-something" });
    try expectTypes("abc -ok-something", &.{ "abc", "-ok-something" });
    try expectTypes("abc abc", &.{ "abc", "abc" });
    try expectTypes("abc ABC", &.{ "abc", "ABC" });
    for ([_][]const u8{ "abc none", "abc, def", "dEfAuLt", "abc -ua-something", "123", "*", "*11 abc", "inherit", "abc initial", "" }) |bad| try expectTypes(bad, null);
}

test "navigation: auto | none" {
    try testing.expectEqual(Navigation.auto, parseNavigation("AUTO").?);
    try testing.expectEqual(Navigation.none, parseNavigation(" none ").?);
    try testing.expect(parseNavigation("auto none") == null);
    try testing.expect(parseNavigation("same-origin") == null);
}
