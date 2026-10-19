//! Platform calendar conversion follows the host's local time, including
//! historical offsets and daylight saving time. No global TZ mutation.
const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform");
const c = @cImport({
    @cInclude("time.h");
});

test "dp1 localDateTime is available and agrees with localtime_r" {
    if (comptime !@hasDecl(platform, "localDateTime")) {
        try std.testing.expect(false);
        return;
    } else {
        if (!hasIdentifiableZone()) {
            std.debug.print("SKIP: queued PLATFORM item: defaultTimeZone mis-identifies a regular-file /etc/localtime as UTC\n", .{});
            return error.SkipZigTest;
        }
        c.tzset();
        // 1969, the epoch, and winter/summer 2026. Include the extremes of
        // WallTime and the nanosecond immediately before the epoch.
        const times = [_]i64{
            -86_400 * std.time.ns_per_s,
            -1,
            0,
            1_767_225_600 * std.time.ns_per_s,
            1_782_864_000 * std.time.ns_per_s,
            std.math.minInt(i64),
            std.math.maxInt(i64),
        };
        for (times) |nanoseconds| {
            const seconds: c.time_t = @intCast(@divFloor(nanoseconds, std.time.ns_per_s));
            var expected: c.struct_tm = undefined;
            try std.testing.expect(c.localtime_r(&seconds, &expected) != null);
            const actual = platform.localDateTime(.{ .ns_since_epoch = nanoseconds });
            try std.testing.expectEqual(expected.tm_year + 1900, actual.year);
            try std.testing.expectEqual(expected.tm_mon + 1, actual.month);
            try std.testing.expectEqual(expected.tm_mday, actual.day);
            try std.testing.expectEqual(expected.tm_hour, actual.hour);
            try std.testing.expectEqual(expected.tm_min, actual.minute);
            try std.testing.expectEqual(expected.tm_sec, actual.second);
        }
    }
}

fn hasIdentifiableZone() bool {
    if (builtin.os.tag == .macos) return true;
    if (std.c.getenv("TZ")) |tz| if (tz[0] != 0) return true;
    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const length = std.c.readlink("/etc/localtime", &buffer, buffer.len);
    return length > 0 and std.mem.indexOf(u8, buffer[0..@intCast(length)], "zoneinfo/") != null;
}
