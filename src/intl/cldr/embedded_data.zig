//! CLDR Embedded Locale Data
//!
//! STUB FILE - Will be replaced by generated data from tools/cldr/extract.zig
//!
//! To generate real data:
//!   1. Run: zig build cldr-download
//!   2. Run: zig build cldr-extract
//!
//! This stub provides empty data so the code compiles without CLDR data.

const std = @import("std");
const types = @import("types.zig");
const LocaleData = types.LocaleData;

/// No embedded locales in stub
pub const embedded_locales = [_]LocaleData{
    // Default English locale for fallback
    LocaleData.DEFAULT,
};

/// Embedded locale tags
pub const locale_tags = [_][]const u8{
    "en",
};

/// Get embedded locale data by tag
pub fn getLocale(tag: []const u8) ?*const LocaleData {
    if (std.mem.eql(u8, tag, "en")) {
        return &embedded_locales[0];
    }
    return null;
}
