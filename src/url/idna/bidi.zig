//! RFC 5893 section 2: validate every nonempty label of a Bidi domain.
const std = @import("std");
const data = @import("unicode_data.zig");
pub const BidiError = error{InvalidBidi};

/// A Bidi domain contains R, AL or AN in any decoded label (RFC 5893 section 1.4).
pub fn isBidi(label: []const u8) bool {
    var it = (std.unicode.Utf8View.init(label) catch return false).iterator();
    while (it.nextCodepoint()) |cp| switch (data.lookupBidiClass(cp)) {
        .R, .AL, .AN => return true,
        else => {},
    };
    return false;
}

/// Apply all six Bidi conditions. Call only when some label makes the domain Bidi.
pub fn validateBidi(label: []const u8) BidiError!void {
    if (label.len == 0) return;
    var it = (std.unicode.Utf8View.init(label) catch return error.InvalidBidi).iterator();
    // 1. The first character establishes direction; digits and neutrals cannot start.
    const first = data.lookupBidiClass(it.nextCodepoint().?);
    const rtl = switch (first) {
        .R, .AL => true,
        .L => false,
        else => return error.InvalidBidi,
    };
    var last = first;
    var en = false;
    var an = false;
    while (it.nextCodepoint()) |cp| {
        const class = data.lookupBidiClass(cp);
        // 2 and 5. Direction-specific allowed classes.
        const allowed = if (rtl) switch (class) {
            .R, .AL, .AN, .EN, .ES, .CS, .ET, .ON, .BN, .NSM => true,
            else => false,
        } else switch (class) {
            .L, .EN, .ES, .CS, .ET, .ON, .BN, .NSM => true,
            else => false,
        };
        if (!allowed) return error.InvalidBidi;
        en = en or class == .EN;
        an = an or class == .AN;
        if (class != .NSM) last = class;
    }
    // 3 and 6. Ignore trailing NSM when checking the final character.
    const valid_end = if (rtl) switch (last) {
        .R, .AL, .EN, .AN => true,
        else => false,
    } else last == .L or last == .EN;
    if (!valid_end) return error.InvalidBidi;
    // 4. European and Arabic numbers must not be mixed in an RTL label.
    if (rtl and en and an) return error.InvalidBidi;
}
