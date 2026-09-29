//! The default `User-Agent` value.
//!
//! Fetch's HTTP-network-or-cache fetch sends it (step 8.15) when a request
//! has no `User-Agent` of its own, and HTML's navigator.userAgent - in a
//! Window and in a worker - returns it ("default `User-Agent` value"), so
//! the two always agree. This is the one place it is written.
//!
//! Spec: https://fetch.spec.whatwg.org/#default-user-agent-value

const std = @import("std");
const builtin = @import("builtin");

/// The default `User-Agent` value: implementation-defined, per platform.
pub const default_user_agent = switch (builtin.os.tag) {
    .macos => "Mozilla/5.0 (Macintosh; Intel Mac OS X) WhatWG-Zig/1.0",
    .linux => "Mozilla/5.0 (X11; Linux x86_64) WhatWG-Zig/1.0",
    .windows => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) WhatWG-Zig/1.0",
    else => "Mozilla/5.0 WhatWG-Zig/1.0",
};

/// HTML's navigator.appVersion in the Chrome/WebKit compatibility mode (the
/// mode productSub "20030107" names): the user agent string without its
/// leading "Mozilla/".
pub const app_version = default_user_agent["Mozilla/".len..];

test "appVersion is the user agent after Mozilla/" {
    try std.testing.expect(std.mem.startsWith(u8, default_user_agent, "Mozilla/"));
    try std.testing.expect(std.mem.endsWith(u8, default_user_agent, app_version));
    try std.testing.expect(std.mem.startsWith(u8, app_version, "5.0 "));
}
