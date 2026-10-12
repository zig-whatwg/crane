//! The default `User-Agent` value.
//!
//! Fetch's HTTP-network-or-cache fetch sends the environment default
//! `User-Agent` value (step 8.15) when a request has no `User-Agent` of its
//! own, and HTML's navigator.userAgent - in a Window and in a worker -
//! returns it, so the two always agree. A Browser's is its network
//! context's (BrowserConfig.user_agent, fetch.network.NetworkContext); this
//! is the one a Browser that sets none gets.
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

/// HTML navigator.appVersion's getter steps for user agent string
/// `user_agent`, in the Chrome/WebKit navigator compatibility mode: "2. If
/// userAgent does not start with `Mozilla/5.0 (`, then return the empty
/// string. 3. Let trail be the substring of userAgent ... that follows the
/// "Mozilla/" prefix. 4. ... Return trail."
pub fn appVersionOf(user_agent: []const u8) []const u8 {
    if (!std.mem.startsWith(u8, user_agent, "Mozilla/5.0 (")) return "";
    return user_agent["Mozilla/".len..];
}

test "appVersion of a user agent string: the trail after Mozilla/, or empty" {
    try std.testing.expectEqualStrings(app_version, appVersionOf(default_user_agent));
    try std.testing.expectEqualStrings("5.0 (X; Y) Z/1", appVersionOf("Mozilla/5.0 (X; Y) Z/1"));
    try std.testing.expectEqualStrings("", appVersionOf("CraneBot/1.0"));
    try std.testing.expectEqualStrings("", appVersionOf("Mozilla/4.0 (X)"));
}

test "appVersion is the user agent after Mozilla/" {
    try std.testing.expect(std.mem.startsWith(u8, default_user_agent, "Mozilla/"));
    try std.testing.expect(std.mem.endsWith(u8, default_user_agent, app_version));
    try std.testing.expect(std.mem.startsWith(u8, app_version, "5.0 "));
}
