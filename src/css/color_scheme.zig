//! CSS Color Adjustment 1 section 2: color schemes. The `color-scheme`
//! property's value (2.2) reduced to what Crane's used color scheme reads
//! from it - a "color scheme support" (2.3): the schemes it names that the
//! UA supports, in order, and whether it supports them solely (`only`).
//!
//! Crane supports the light and the dark color scheme. A <custom-ident> in
//! the list is kept for serialization and means nothing (2.2: "User agents
//! must not interpret any <custom-ident> values as having a meaning").
//!
//! Spec: https://drafts.csswg.org/css-color-adjust-1/#color-scheme-prop
//! Spec: https://drafts.csswg.org/css-color-adjust-1/#resolving-color-schemes

const std = @import("std");

/// A color scheme the UA supports.
pub const Scheme = enum(u1) { light, dark };

/// A color scheme support, as far as the used color scheme reads it: the
/// first scheme the UA supports among those listed, whether light and dark
/// are listed, and the sole-support flag. The null support (`normal`, or a
/// page with no valid color-scheme meta) is `Support.none`; so is a list of
/// custom idents only, which section 2.3 step 1 treats alike ("none of the
/// color schemes in support are supported by the UA").
pub const Support = packed struct(u8) {
    first: First = .none,
    light: bool = false,
    dark: bool = false,
    only: bool = false,
    _padding: u3 = 0,

    pub const First = enum(u2) { none, light, dark };

    pub const none: Support = .{};

    /// `scheme` is listed next.
    pub fn add(self: *Support, scheme: Scheme) void {
        switch (scheme) {
            .light => self.light = true,
            .dark => self.dark = true,
        }
        if (self.first == .none) self.first = switch (scheme) {
            .light => .light,
            .dark => .dark,
        };
    }

    pub fn eql(a: Support, b: Support) bool {
        return @as(u8, @bitCast(a)) == @as(u8, @bitCast(b));
    }
};

/// Section 2.3, "determine the used color scheme" given a color scheme
/// support and a color scheme preference. Crane's preference is the host's
/// preferred scheme, light or dark (never "no preference", never an
/// overriding one: Crane does not override color schemes, 2.5), and the UA
/// default is light (the WPT color-scheme files assume it: wpt#31268).
pub fn used(support: Support, preference: Scheme) Scheme {
    // 1. "If support is null, or none of the color schemes in support are
    // supported by the UA, return the UA default color scheme."
    const first: Scheme = switch (support.first) {
        .none => return .light,
        .light => .light,
        .dark => .dark,
    };
    // 2. A preference is always given.
    // 3. "If preference's color scheme is in support and supported by the
    // UA, return that color scheme."
    switch (preference) {
        .light => if (support.light) return .light,
        .dark => if (support.dark) return .dark,
    }
    // 4. "If support is flagged as sole support, return the first supported
    // color scheme in support." 5. No overriding preference. 6. "Otherwise,
    // return the first supported color scheme in support."
    return first;
}

test "a support records the first supported scheme and every scheme it lists" {
    var support: Support = .{};
    try std.testing.expect(support.eql(Support.none));
    support.add(.dark);
    support.add(.light);
    try std.testing.expectEqual(Support.First.dark, support.first);
    try std.testing.expect(support.light and support.dark and !support.only);
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(Support));
}

test "the used color scheme: section 2.3 with a light or dark preference" {
    const Case = struct { text: []const u8, support: Support, light: Scheme, dark: Scheme };
    var light_dark: Support = .{};
    light_dark.add(.light);
    light_dark.add(.dark);
    var dark_light: Support = .{};
    dark_light.add(.dark);
    dark_light.add(.light);
    var dark: Support = .{};
    dark.add(.dark);
    var only_light: Support = .{ .only = true };
    only_light.add(.light);
    const only_custom: Support = .{ .only = true };
    const cases = [_]Case{
        // Step 1: null support, or none the UA supports: the UA default.
        .{ .text = "normal", .support = Support.none, .light = .light, .dark = .light },
        .{ .text = "only purple", .support = only_custom, .light = .light, .dark = .light },
        // Step 3: the preference, when supported.
        .{ .text = "light dark", .support = light_dark, .light = .light, .dark = .dark },
        .{ .text = "dark light", .support = dark_light, .light = .light, .dark = .dark },
        // Steps 4 and 6: the first supported scheme.
        .{ .text = "dark", .support = dark, .light = .dark, .dark = .dark },
        .{ .text = "only light", .support = only_light, .light = .light, .dark = .light },
    };
    for (cases) |case| {
        std.testing.expectEqual(case.light, used(case.support, .light)) catch |err| {
            std.debug.print("{s}, light preference\n", .{case.text});
            return err;
        };
        std.testing.expectEqual(case.dark, used(case.support, .dark)) catch |err| {
            std.debug.print("{s}, dark preference\n", .{case.text});
            return err;
        };
    }
}
