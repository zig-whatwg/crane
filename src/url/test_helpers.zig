//! WebIDL Test Helpers
//!
//! Utilities for constructing WebIDL types in tests.

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");
const URL = @import("url").URL;
const URLSearchParams = @import("url_search_params").URLSearchParams;

/// Convert UTF-8 string literal to webidl.USVString (UTF-16)
/// Caller owns the returned memory.
pub fn usv(allocator: std.mem.Allocator, utf8_string: []const u8) !webidl.USVString {
    return infra.string.utf8ToUtf16(allocator, utf8_string);
}

/// Convert optional UTF-8 string literal to ?webidl.USVString (UTF-16)
/// Caller owns the returned memory.
pub fn usvOpt(allocator: std.mem.Allocator, utf8_string: ?[]const u8) !?webidl.USVString {
    if (utf8_string) |s| {
        return try infra.string.utf8ToUtf16(allocator, s);
    }
    return null;
}

/// Convert webidl.USVString (UTF-16) to UTF-8 string for comparison
/// Caller owns the returned memory.
pub fn toUtf8(allocator: std.mem.Allocator, usv_string: webidl.USVString) ![]const u8 {
    return infra.string.utf16ToUtf8(allocator, usv_string);
}

/// Compare webidl.USVString with UTF-8 string literal
pub fn expectEqualStrings(allocator: std.mem.Allocator, expected_utf8: []const u8, actual_usv: webidl.USVString) !void {
    const actual_utf8 = try toUtf8(allocator, actual_usv);
    defer allocator.free(actual_utf8);
    try std.testing.expectEqualStrings(expected_utf8, actual_utf8);
}

/// Test helper: Create URL from UTF-8 strings
/// WebIDL now expects UTF-8 strings directly, so this is just a passthrough.
pub fn initURL(allocator: std.mem.Allocator, url_utf8: []const u8, base_utf8: ?[]const u8) !URL {
    return URL.init(allocator, url_utf8, base_utf8);
}

/// Test helper: Create URLSearchParams from UTF-8 string
pub fn initURLSearchParams(allocator: std.mem.Allocator, init_utf8: []const u8) !URLSearchParams {
    return URLSearchParams.initWithString(allocator, init_utf8);
}

/// Test helper: Create URLSearchParams from UTF-8 sequence
pub fn initURLSearchParamsFromSequence(allocator: std.mem.Allocator, seq_utf8: []const [2][]const u8) !URLSearchParams {
    return URLSearchParams.initWithSequence(allocator, seq_utf8);
}

// ============================================================================
// URL Setter Wrappers (UTF-8 → UTF-16 conversion)
// ============================================================================

/// Set protocol from UTF-8 string
pub fn setProtocol(url: *URL, allocator: std.mem.Allocator, protocol_utf8: []const u8) !void {
    const protocol_usv = try usv(allocator, protocol_utf8);
    defer allocator.free(protocol_usv);
    return url.setProtocol(protocol_usv);
}

/// Set username from UTF-8 string
pub fn setUsername(url: *URL, allocator: std.mem.Allocator, username_utf8: []const u8) !void {
    const username_usv = try usv(allocator, username_utf8);
    defer allocator.free(username_usv);
    return url.setUsername(username_usv);
}

/// Set password from UTF-8 string
pub fn setPassword(url: *URL, allocator: std.mem.Allocator, password_utf8: []const u8) !void {
    const password_usv = try usv(allocator, password_utf8);
    defer allocator.free(password_usv);
    return url.setPassword(password_usv);
}

/// Set host from UTF-8 string
pub fn setHost(url: *URL, allocator: std.mem.Allocator, host_utf8: []const u8) !void {
    const host_usv = try usv(allocator, host_utf8);
    defer allocator.free(host_usv);
    return url.setHost(host_usv);
}

/// Set hostname from UTF-8 string
pub fn setHostname(url: *URL, allocator: std.mem.Allocator, hostname_utf8: []const u8) !void {
    const hostname_usv = try usv(allocator, hostname_utf8);
    defer allocator.free(hostname_usv);
    return url.setHostname(hostname_usv);
}

/// Set port from UTF-8 string
pub fn setPort(url: *URL, allocator: std.mem.Allocator, port_utf8: []const u8) !void {
    const port_usv = try usv(allocator, port_utf8);
    defer allocator.free(port_usv);
    return url.setPort(port_usv);
}

/// Set pathname from UTF-8 string
pub fn setPathname(url: *URL, allocator: std.mem.Allocator, pathname_utf8: []const u8) !void {
    const pathname_usv = try usv(allocator, pathname_utf8);
    defer allocator.free(pathname_usv);
    return url.setPathname(pathname_usv);
}

/// Set search from UTF-8 string
pub fn setSearch(url: *URL, allocator: std.mem.Allocator, search_utf8: []const u8) !void {
    const search_usv = try usv(allocator, search_utf8);
    defer allocator.free(search_usv);
    return url.setSearch(search_usv);
}

/// Set hash from UTF-8 string
pub fn setHash(url: *URL, allocator: std.mem.Allocator, hash_utf8: []const u8) !void {
    const hash_usv = try usv(allocator, hash_utf8);
    defer allocator.free(hash_usv);
    return url.setHash(hash_usv);
}

/// Set href from UTF-8 string
pub fn setHref(url: *URL, allocator: std.mem.Allocator, href_utf8: []const u8) !void {
    const href_usv = try usv(allocator, href_utf8);
    defer allocator.free(href_usv);
    return url.set_href(href_usv);
}

// ============================================================================
// URL Getter Wrappers (UTF-16 → UTF-8 conversion)
// ============================================================================

/// Get href as UTF-8 string
pub fn getHref(url: *const URL, allocator: std.mem.Allocator) ![]const u8 {
    const href_usv = try url.href();
    defer allocator.free(href_usv);
    return toUtf8(allocator, href_usv);
}

/// Get protocol as UTF-8 string
pub fn getProtocol(url: *const URL, allocator: std.mem.Allocator) ![]const u8 {
    const protocol_usv = try url.protocol();
    defer allocator.free(protocol_usv);
    return toUtf8(allocator, protocol_usv);
}

/// Get username as UTF-8 string
pub fn getUsername(url: *const URL, allocator: std.mem.Allocator) ![]const u8 {
    const username_usv = url.username();
    return toUtf8(allocator, username_usv);
}

/// Get password as UTF-8 string
pub fn getPassword(url: *const URL, allocator: std.mem.Allocator) ![]const u8 {
    const password_usv = url.password();
    return toUtf8(allocator, password_usv);
}

/// Get host as UTF-8 string
pub fn getHost(url: *const URL, allocator: std.mem.Allocator) ![]const u8 {
    const host_usv = try url.host();
    defer allocator.free(host_usv);
    return toUtf8(allocator, host_usv);
}

/// Get hostname as UTF-8 string
pub fn getHostname(url: *const URL, allocator: std.mem.Allocator) ![]const u8 {
    const hostname_usv = try url.hostname();
    defer allocator.free(hostname_usv);
    return toUtf8(allocator, hostname_usv);
}

/// Get port as UTF-8 string
pub fn getPort(url: *const URL, allocator: std.mem.Allocator) ![]const u8 {
    const port_usv = try url.port();
    defer allocator.free(port_usv);
    return toUtf8(allocator, port_usv);
}

/// Get pathname as UTF-8 string
pub fn getPathname(url: *const URL, allocator: std.mem.Allocator) ![]const u8 {
    const pathname_usv = try url.pathname();
    defer allocator.free(pathname_usv);
    return toUtf8(allocator, pathname_usv);
}

/// Get search as UTF-8 string
pub fn getSearch(url: *const URL, allocator: std.mem.Allocator) ![]const u8 {
    const search_usv = try url.search();
    defer allocator.free(search_usv);
    return toUtf8(allocator, search_usv);
}

/// Get hash as UTF-8 string
pub fn getHash(url: *const URL, allocator: std.mem.Allocator) ![]const u8 {
    const hash_usv = try url.hash();
    defer allocator.free(hash_usv);
    return toUtf8(allocator, hash_usv);
}

// ============================================================================
// URLSearchParams Helper Wrappers (UTF-8 → UTF-16 conversion)
// ============================================================================

/// Append a key-value pair from UTF-8 strings
pub fn searchParamsAppend(params: *URLSearchParams, allocator: std.mem.Allocator, name_utf8: []const u8, value_utf8: []const u8) !void {
    const name_usv = try usv(allocator, name_utf8);
    defer allocator.free(name_usv);
    const value_usv = try usv(allocator, value_utf8);
    defer allocator.free(value_usv);
    return params.call_append(name_usv, value_usv);
}

/// Delete entries by name from UTF-8 string
pub fn searchParamsDelete(params: *URLSearchParams, allocator: std.mem.Allocator, name_utf8: []const u8, value_utf8: ?[]const u8) !void {
    const name_usv = try usv(allocator, name_utf8);
    defer allocator.free(name_usv);

    var value_usv: ?webidl.USVString = null;
    defer if (value_usv) |v| allocator.free(v);

    if (value_utf8) |v| {
        value_usv = try usv(allocator, v);
    }

    return params.call_delete(name_usv, value_usv);
}

/// Check if entry exists from UTF-8 string
pub fn searchParamsHas(params: *const URLSearchParams, allocator: std.mem.Allocator, name_utf8: []const u8, value_utf8: ?[]const u8) !bool {
    const name_usv = try usv(allocator, name_utf8);
    defer allocator.free(name_usv);

    var value_usv: ?webidl.USVString = null;
    defer if (value_usv) |v| allocator.free(v);

    if (value_utf8) |v| {
        value_usv = try usv(allocator, v);
    }

    return params.call_has(name_usv, value_usv);
}

/// Get value by name from UTF-8 string, returns UTF-8 string or null
pub fn searchParamsGet(params: *const URLSearchParams, allocator: std.mem.Allocator, name_utf8: []const u8) !?[]const u8 {
    const name_usv = try usv(allocator, name_utf8);
    defer allocator.free(name_usv);

    const result_usv = try params.call_get(name_usv);
    if (result_usv) |r| {
        defer allocator.free(r);
        return try toUtf8(allocator, r);
    }

    return null;
}

/// Set value by name from UTF-8 string
pub fn searchParamsSet(params: *URLSearchParams, allocator: std.mem.Allocator, name_utf8: []const u8, value_utf8: []const u8) !void {
    const name_usv = try usv(allocator, name_utf8);
    defer allocator.free(name_usv);
    const value_usv = try usv(allocator, value_utf8);
    defer allocator.free(value_usv);
    return params.call_set(name_usv, value_usv);
}

/// Get all values by name from UTF-8 string, returns array of UTF-8 strings
pub fn searchParamsGetAll(params: *const URLSearchParams, allocator: std.mem.Allocator, name_utf8: []const u8) ![][]const u8 {
    const name_usv = try usv(allocator, name_utf8);
    defer allocator.free(name_usv);

    var result_sequence = try params.call_getAll(name_usv);
    defer result_sequence.deinit();

    const result_usv_items = result_sequence.items();

    var result_utf8 = try allocator.alloc([]const u8, result_usv_items.len);
    errdefer {
        for (result_utf8[0..result_usv_items.len]) |s| allocator.free(s);
        allocator.free(result_utf8);
    }

    for (result_usv_items, 0..) |usv_str, i| {
        result_utf8[i] = try toUtf8(allocator, usv_str);
    }

    return result_utf8;
}

/// Convert URLSearchParams to string (UTF-8)
pub fn searchParamsToString(params: *const URLSearchParams, allocator: std.mem.Allocator) ![]const u8 {
    const result_usv = try params.call_toString();
    defer allocator.free(result_usv);
    return toUtf8(allocator, result_usv);
}
