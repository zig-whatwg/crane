//! validateUrl and isAllowedUrl - chrome-devtools-mcp's src/utils/url.ts
//! (chrome-devtools-mcp-v1.13.0, Copyright 2025 Google LLC, Apache-2.0;
//! THIRD_PARTY_NOTICES.md), translated: what new_page and navigate_page
//! refuse before any navigation. The URL is parsed by the URL Standard's
//! basic URL parser (`new URL(url)`); `view-source:` wrapping is unwrapped
//! (up to five levels) so the checks see the URL that loads; devtools:,
//! chrome: (but its new-tab and inspect pages), chrome-untrusted: and,
//! without the extensions category, chrome-extension: are refused; with
//! JavaScript evaluation off, javascript:, data: and vbscript: too; with file
//! navigations off, file:.

const std = @import("std");
const Allocator = std.mem.Allocator;
const url = @import("url");
const URLRecord = url.internal.url_record.URLRecord;

pub const Options = struct {
    /// --javascriptEvaluation (default true).
    javascript_evaluation: bool = true,
    /// --categoryExtensions (default false).
    category_extensions: bool = false,
    /// --fileNavigations (default true).
    file_navigations: bool = true,
};

/// The error message validateUrl throws for `input`, or null when it is
/// allowed.
pub fn validate(arena: Allocator, input: []const u8, options: Options) !?[]const u8 {
    var parsed = url.parser.basic_url_parser.parse(arena, input, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return try std.fmt.allocPrint(arena, "Invalid URL: \"{s}\". URLs must be valid according to the URL standard.", .{input}),
    };
    // unwrapViewSource.
    var level: u32 = 0;
    while (level < 5 and std.mem.eql(u8, parsed.scheme(), "view-source")) : (level += 1) {
        const inner = try pathname(arena, &parsed);
        parsed = url.parser.basic_url_parser.parse(arena, inner, null) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return try viewSourceInvalid(arena, input),
        };
    }
    if (std.mem.eql(u8, parsed.scheme(), "view-source")) return try viewSourceInvalid(arena, input);
    const scheme = parsed.scheme();
    if (!options.javascript_evaluation) {
        for ([_][]const u8{ "javascript", "data", "vbscript" }) |refused| if (std.mem.eql(u8, scheme, refused)) {
            return try std.fmt.allocPrint(arena, "Navigating to {s}: URLs is not allowed when JavaScript evaluation is disabled.", .{scheme});
        };
    }
    if (!options.file_navigations and std.mem.eql(u8, scheme, "file")) {
        return "Navigating to file: URLs is not allowed when --file-navigations is disabled.";
    }
    if (std.mem.eql(u8, scheme, "devtools")) return "Navigating to devtools: URLs is not allowed.";
    if (!try isAllowed(arena, &parsed, options)) {
        if (std.mem.eql(u8, scheme, "chrome-extension")) return "Navigating to chrome-extension: URLs is not allowed without --categoryExtensions.";
        return try std.fmt.allocPrint(arena, "Navigating to {s}: URLs is not allowed.", .{scheme});
    }
    return null;
}

fn viewSourceInvalid(arena: Allocator, input: []const u8) ![]const u8 {
    return std.fmt.allocPrint(arena, "Invalid URL: \"{s}\". The view-source: wrapped content is not a valid URL.", .{input});
}

/// isAllowedUrl.
fn isAllowed(arena: Allocator, record: *const URLRecord, options: Options) !bool {
    const scheme = record.scheme();
    if (std.mem.eql(u8, scheme, "chrome")) {
        const host = try std.ascii.allocLowerString(arena, try hostname(arena, record));
        const path = try std.ascii.allocLowerString(arena, try pathname(arena, record));
        for ([_][]const u8{ "newtab", "new-tab-page", "inspect" }) |allowed| if (std.mem.eql(u8, host, allowed)) return true;
        if (host.len == 0 and (std.mem.eql(u8, path, "newtab") or std.mem.eql(u8, path, "new-tab-page") or std.mem.startsWith(u8, path, "inspect"))) return true;
        return false;
    }
    if (std.mem.eql(u8, scheme, "chrome-untrusted")) return false;
    if (!options.category_extensions and std.mem.eql(u8, scheme, "chrome-extension")) return false;
    return true;
}

/// The URL's `hostname` getter.
fn hostname(arena: Allocator, record: *const URLRecord) ![]const u8 {
    const host = record.host orelse return "";
    return url.host_serializer.serializeHost(arena, host);
}

/// The URL's `pathname` getter: an opaque path as it is, else "/" and the
/// segments joined by "/".
fn pathname(arena: Allocator, record: *const URLRecord) ![]const u8 {
    switch (record.path) {
        .opaque_path => |p| return p,
        .segments => |*segments| {
            var out: std.ArrayList(u8) = .empty;
            for (segments.toSlice()) |segment| {
                try out.append(arena, '/');
                try out.appendSlice(arena, segment);
            }
            return out.items;
        },
    }
}

test "validateUrl: invalid URLs, view-source unwrapping and the refused schemes, as chrome-devtools-mcp's" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    try std.testing.expect(try validate(arena, "https://example.com/", .{}) == null);
    try std.testing.expect(try validate(arena, "data:text/html,hi", .{}) == null);
    try std.testing.expect(try validate(arena, "chrome://newtab/", .{}) == null);
    try std.testing.expectEqualStrings("Invalid URL: \"nope\". URLs must be valid according to the URL standard.", (try validate(arena, "nope", .{})).?);
    try std.testing.expectEqualStrings("Navigating to devtools: URLs is not allowed.", (try validate(arena, "view-source:devtools://devtools/x", .{})).?);
    try std.testing.expectEqualStrings("Navigating to chrome: URLs is not allowed.", (try validate(arena, "chrome://settings", .{})).?);
    try std.testing.expectEqualStrings("Navigating to file: URLs is not allowed when --file-navigations is disabled.", (try validate(arena, "view-source:FILE:///etc/passwd", .{ .file_navigations = false })).?);
    try std.testing.expectEqualStrings("Navigating to data: URLs is not allowed when JavaScript evaluation is disabled.", (try validate(arena, "data:,x", .{ .javascript_evaluation = false })).?);
    try std.testing.expectEqualStrings("Navigating to chrome-extension: URLs is not allowed without --categoryExtensions.", (try validate(arena, "chrome-extension://abc/x.html", .{})).?);
}
