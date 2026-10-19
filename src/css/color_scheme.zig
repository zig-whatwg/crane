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

test "a support records the first supported scheme and every scheme it lists" {
    var support: Support = .{};
    try std.testing.expect(support.eql(Support.none));
    support.add(.dark);
    support.add(.light);
    try std.testing.expectEqual(Support.First.dark, support.first);
    try std.testing.expect(support.light and support.dark and !support.only);
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(Support));
}
