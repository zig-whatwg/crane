//! The user agent's product token is Crane's: the default `User-Agent`
//! value Fetch sends (HTTP-network-or-cache fetch step 8.15, the environment
//! default) and navigator.userAgent, which returns the same value, both carry
//! "Crane/0.1" on every platform - not the old "WhatWG-Zig/1.0" (the user,
//! 2026-11-20). navigator.vendor is the Chrome navigator compatibility mode's
//! "Google Inc." (the user's ruling, 2026-11-20).
//!
//! tests/html is one executable: the engine may already be started.
const std = @import("std");
const fetch = @import("fetch");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const token = "Crane/0.1";

test "the default User-Agent value ends with Crane's product token" {
    const value = fetch.internal.user_agent.default_user_agent;
    try std.testing.expect(std.mem.startsWith(u8, value, "Mozilla/5.0 "));
    try std.testing.expect(std.mem.endsWith(u8, value, " " ++ token));
    try std.testing.expect(std.mem.indexOf(u8, value, "WhatWG-Zig") == null);
    // The one HTTP-network-or-cache fetch sends when a request has none.
    try std.testing.expectEqualStrings(value, fetch.algorithms.http_fetch.default_user_agent);
}

fn navigatorUserAgent() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try harness.expectEval(page, "navigator.userAgent.endsWith(' Crane/0.1') && !navigator.userAgent.includes('WhatWG-Zig')", "true");
}

test "navigator.userAgent carries Crane's product token" {
    try helpers.onFreshThread(navigatorUserAgent);
}

fn navigatorVendor() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // HTML "vendor" getter steps, the Chrome navigator compatibility mode -
    // the mode productSub "20030107" and appVersion already name (the user's
    // ruling, 2026-11-20).
    try harness.expectEval(page, "navigator.vendor", "Google Inc.");
    try harness.expectEval(page, "navigator.vendorSub", "");
}

test "navigator.vendor is the Chrome compatibility mode's, Google Inc." {
    try helpers.onFreshThread(navigatorVendor);
}
