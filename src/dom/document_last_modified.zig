//! HTML document.lastModified's numeric local-calendar representation.
//! https://html.spec.whatwg.org/multipage/dom.html#dom-document-lastmodified
const std = @import("std");
const platform = @import("platform");

pub const LocalDateTime = platform.LocalDateTime;
pub const WallTime = platform.WallTime;

/// HTML's month/day/year and hour/minute/second fields, with the year
/// padded to at least four digits. OWNED by the caller's allocator.
pub fn format(allocator: std.mem.Allocator, time: LocalDateTime) std.mem.Allocator.Error![]u8 {
    // WallTime's local years are positive (1677-2262). Format the numeric
    // magnitude: Zig's signed decimal formatter includes a leading plus.
    const year: u32 = @intCast(time.year);
    return std.fmt.allocPrint(allocator, "{d:0>2}/{d:0>2}/{d:0>4} {d:0>2}:{d:0>2}:{d:0>2}", .{
        time.month, time.day, year, time.hour, time.minute, time.second,
    });
}
