//! WebIDL Test Helpers
//!
//! Utilities for constructing WebIDL types in tests.
//!
//! TODO: This file has circular import issues - it's INSIDE the url module
//! trying to import the public URL API. Needs refactoring.

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

// Stub types to avoid circular imports
const URL = *anyopaque;
const URLSearchParams = *anyopaque;

/// All functions return NotImplemented error due to circular import
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

// All remaining functions stubbed due to circular import
pub fn initURL(_: std.mem.Allocator, _: []const u8, _: ?[]const u8) error{NotImplemented}!URL {
    return error.NotImplemented;
}

pub fn initURLSearchParams(_: std.mem.Allocator, _: []const u8) error{NotImplemented}!URLSearchParams {
    return error.NotImplemented;
}

pub fn initURLSearchParamsFromSequence(_: std.mem.Allocator, _: []const [2][]const u8) error{NotImplemented}!URLSearchParams {
    return error.NotImplemented;
}

pub fn setProtocol(_: *URL, _: std.mem.Allocator, _: []const u8) error{NotImplemented}!void {
    return error.NotImplemented;
}

pub const set_protocol = setProtocol;

pub fn setUsername(_: *URL, _: std.mem.Allocator, _: []const u8) error{NotImplemented}!void {
    return error.NotImplemented;
}

pub const set_username = setUsername;

pub fn setPassword(_: *URL, _: std.mem.Allocator, _: []const u8) error{NotImplemented}!void {
    return error.NotImplemented;
}

pub const set_password = setPassword;

pub fn setHost(_: *URL, _: std.mem.Allocator, _: []const u8) error{NotImplemented}!void {
    return error.NotImplemented;
}

pub const set_host = setHost;

pub fn setHostname(_: *URL, _: std.mem.Allocator, _: []const u8) error{NotImplemented}!void {
    return error.NotImplemented;
}

pub const set_hostname = setHostname;

pub fn setPort(_: *URL, _: std.mem.Allocator, _: []const u8) error{NotImplemented}!void {
    return error.NotImplemented;
}

pub const set_port = setPort;

pub fn setPathname(_: *URL, _: std.mem.Allocator, _: []const u8) error{NotImplemented}!void {
    return error.NotImplemented;
}

pub const set_pathname = setPathname;

pub fn setSearch(_: *URL, _: std.mem.Allocator, _: []const u8) error{NotImplemented}!void {
    return error.NotImplemented;
}

pub const set_search = setSearch;

pub fn setHash(_: *URL, _: std.mem.Allocator, _: []const u8) error{NotImplemented}!void {
    return error.NotImplemented;
}

pub const set_hash = setHash;

pub fn setHref(_: *URL, _: std.mem.Allocator, _: []const u8) error{NotImplemented}!void {
    return error.NotImplemented;
}

pub const set_href = setHref;

pub fn getHref(_: *const URL, _: std.mem.Allocator) error{NotImplemented}![]const u8 {
    return error.NotImplemented;
}

pub fn getProtocol(_: *const URL, _: std.mem.Allocator) error{NotImplemented}![]const u8 {
    return error.NotImplemented;
}

pub fn getUsername(_: *const URL, _: std.mem.Allocator) error{NotImplemented}![]const u8 {
    return error.NotImplemented;
}

pub fn getPassword(_: *const URL, _: std.mem.Allocator) error{NotImplemented}![]const u8 {
    return error.NotImplemented;
}

pub fn getHost(_: *const URL, _: std.mem.Allocator) error{NotImplemented}![]const u8 {
    return error.NotImplemented;
}

pub fn getHostname(_: *const URL, _: std.mem.Allocator) error{NotImplemented}![]const u8 {
    return error.NotImplemented;
}

pub fn getPort(_: *const URL, _: std.mem.Allocator) error{NotImplemented}![]const u8 {
    return error.NotImplemented;
}

pub fn getPathname(_: *const URL, _: std.mem.Allocator) error{NotImplemented}![]const u8 {
    return error.NotImplemented;
}

pub fn getSearch(_: *const URL, _: std.mem.Allocator) error{NotImplemented}![]const u8 {
    return error.NotImplemented;
}

pub fn getHash(_: *const URL, _: std.mem.Allocator) error{NotImplemented}![]const u8 {
    return error.NotImplemented;
}

pub fn searchParamsAppend(_: *URLSearchParams, _: std.mem.Allocator, _: []const u8, _: []const u8) error{NotImplemented}!void {
    return error.NotImplemented;
}

pub fn searchParamsDelete(_: *URLSearchParams, _: std.mem.Allocator, _: []const u8, _: ?[]const u8) error{NotImplemented}!void {
    return error.NotImplemented;
}

pub fn searchParamsHas(_: *const URLSearchParams, _: std.mem.Allocator, _: []const u8, _: ?[]const u8) error{NotImplemented}!bool {
    return error.NotImplemented;
}

pub fn searchParamsGet(_: *const URLSearchParams, _: std.mem.Allocator, _: []const u8) error{NotImplemented}!?[]const u8 {
    return error.NotImplemented;
}

pub fn searchParamsSet(_: *URLSearchParams, _: std.mem.Allocator, _: []const u8, _: []const u8) error{NotImplemented}!void {
    return error.NotImplemented;
}

pub fn searchParamsGetAll(_: *const URLSearchParams, _: std.mem.Allocator, _: []const u8) error{NotImplemented}![][]const u8 {
    return error.NotImplemented;
}

pub fn searchParamsToString(_: *const URLSearchParams, _: std.mem.Allocator) error{NotImplemented}![]const u8 {
    return error.NotImplemented;
}
