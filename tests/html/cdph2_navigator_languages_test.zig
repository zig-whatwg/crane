//! The languages a navigator reports (html_core.window.host_overrides):
//! Blink's ParseAndSanitize of an Accept-Language override
//! (third_party/blink/renderer/core/frame/navigator_language.cc) - split at
//! ',' skipping empty items, white space stripped, "xx_" made "xx-", no
//! q-value dropped and nothing deduplicated, the default language when
//! nothing is left - and, with no override, the platform's list: en-US then
//! en, Chrome's and Firefox's for an en-US user (Safari's is en-US alone).
//! Here, not in host_overrides.zig: html_core's own test blocks do not run
//! (build.zig: a dependency module's tests are not collected).

const std = @import("std");
const html_core = @import("html_core");
const host_overrides = html_core.window.host_overrides;
const Languages = host_overrides.Languages;

/// `languages`' tags joined with '|'.
fn joined(languages: *const Languages, buffer: []u8) []const u8 {
    var at: usize = 0;
    for (languages.tags, 0..) |tag, i| {
        if (i > 0) {
            buffer[at] = '|';
            at += 1;
        }
        @memcpy(buffer[at..][0..tag.len], tag);
        at += tag.len;
    }
    return buffer[0..at];
}

test "ParseAndSanitize: split at ',' skipping empty items, white space stripped, xx_ made xx-, q-values and repeats kept" {
    const allocator = std.testing.allocator;
    var buffer: [128]u8 = undefined;
    var list = try host_overrides.parseLanguages(allocator, " en_US ,,de;q=0.9, en_US,zh_Hant");
    defer list.deinit(allocator);
    try std.testing.expectEqualStrings("en-US|de;q=0.9|en-US|zh-Hant", joined(&list, &buffer));
    // Nothing left: the default language (the platform's first).
    var empty = try host_overrides.parseLanguages(allocator, ",,");
    defer empty.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), empty.tags.len);
    try std.testing.expectEqualStrings("en-US", empty.first());
}

test "with no override the languages are the platform's list: en-US then en (Chrome's and Firefox's default)" {
    const allocator = std.testing.allocator;
    var list = try host_overrides.platformLanguages(allocator);
    defer list.deinit(allocator);
    var buffer: [64]u8 = undefined;
    try std.testing.expectEqualStrings("en-US|en", joined(&list, &buffer));
}

test "a worker's snapshot gives the languages of its Accept-Language copy, as the tab's override does; none without one" {
    const allocator = std.testing.allocator;
    var overrides: host_overrides.HostOverrides = .{};
    defer overrides.deinit(allocator);
    try overrides.setUserAgent(allocator, 1, "", null, "de-DE,de");
    var snapshot = try host_overrides.UserAgentSnapshot.of(allocator, &overrides);
    defer snapshot.deinit(allocator);
    var from_snapshot = (try snapshot.languages(allocator)).?;
    defer from_snapshot.deinit(allocator);
    var from_tab = (try overrides.languages(allocator)).?;
    defer from_tab.deinit(allocator);
    var buffer: [64]u8 = undefined;
    try std.testing.expectEqualStrings("de-DE|de", joined(&from_snapshot, &buffer));
    try std.testing.expectEqualStrings("de-DE", from_tab.first());
    var none = try host_overrides.UserAgentSnapshot.of(allocator, &host_overrides.HostOverrides{});
    defer none.deinit(allocator);
    try std.testing.expect((try none.languages(allocator)) == null);
}
