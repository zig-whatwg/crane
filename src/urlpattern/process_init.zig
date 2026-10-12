//! URLPattern §3.2: process a URLPatternInit for construction or matching.
const std = @import("std");
const url = @import("url");
const canonicalize = @import("canonicalize.zig");
const pattern_string = @import("pattern_string.zig");
const URLPatternInit = @import("constructor_string_parser.zig").URLPatternInit;
const Allocator = std.mem.Allocator;
pub const Kind = enum { pattern, url };
pub const names = .{ "protocol", "username", "password", "hostname", "port", "pathname", "search", "hash" };

/// Scratch storage for one construction/match. No value outlives this result.
pub const Result = struct {
    init: URLPatternInit,
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *Result) void {
        self.arena.deinit();
    }
};

fn baseString(allocator: Allocator, value: []const u8, kind: Kind) ![]const u8 {
    // Process a base URL string, steps 2-3: only pattern mode needs escaping.
    return if (kind == .pattern) pattern_string.escape(allocator, value) else value;
}

pub fn isAbsolutePathname(value: []const u8, kind: Kind) bool {
    // Is an absolute pathname, steps 1-7.
    if (value.len == 0) return false;
    if (value[0] == '/') return true;
    return kind == .pattern and value.len >= 2 and (value[0] == '\\' or value[0] == '{') and value[1] == '/';
}

pub fn process(allocator: Allocator, input: URLPatternInit, kind: Kind) !Result {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const temporary = arena.allocator();
    // Steps 1-9: constructor callers supply null defaults; matching supplies
    // empty strings. Distinguish an absent component from an explicit empty one.
    var result: URLPatternInit = .{};
    if (kind == .url) inline for (names) |name| {
        @field(result, name) = "";
    };

    // Steps 10-11: inherit only when no earlier component was provided.
    const base: ?url.internal.url_record.URLRecord = if (input.base_url) |value|
        url.parser.basic_url_parser.parse(temporary, value, null) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidBaseURL
    else
        null;
    if (base) |record| {
        if (input.protocol == null) result.protocol = try baseString(temporary, record.scheme(), kind);
        const no_host = input.protocol == null and input.hostname == null;
        const no_port = no_host and input.port == null;
        if (kind == .url and no_port and input.username == null) {
            result.username = record.username();
            if (input.password == null) result.password = record.password();
        }
        if (no_host) result.hostname = try baseString(temporary, if (record.host) |host|
            try url.host_serializer.serializeHost(temporary, host)
        else
            "", kind);
        if (no_port) result.port = if (record.port) |port| try std.fmt.allocPrint(temporary, "{d}", .{port}) else "";
        if (no_port and input.pathname == null) {
            result.pathname = try baseString(temporary, try canonicalize.serializePath(temporary, &record), kind);
            if (input.search == null) {
                result.search = try baseString(temporary, record.query() orelse "", kind);
                if (input.hash == null) result.hash = try baseString(temporary, record.fragment() orelse "", kind);
            }
        }
    }

    // Steps 12-17 and process-*-for-init: remove exactly one syntax delimiter
    // before canonicalization; pattern fragments are canonicalized on parsing.
    if (input.protocol) |value| {
        const stripped = if (std.mem.endsWith(u8, value, ":")) value[0 .. value.len - 1] else value;
        result.protocol = if (kind == .url) try canonicalize.canonicalizeProtocol(temporary, stripped) else stripped;
    }
    if (input.username) |value| result.username = if (kind == .url) try canonicalize.canonicalizeUsername(temporary, value) else value;
    if (input.password) |value| result.password = if (kind == .url) try canonicalize.canonicalizePassword(temporary, value) else value;
    if (input.hostname) |value| result.hostname = if (kind == .url) try canonicalize.canonicalizeHostname(temporary, value) else value;
    const protocol = result.protocol orelse "";
    if (input.port) |value| result.port = if (kind == .url) try canonicalize.canonicalizePort(temporary, value, protocol) else value;

    // Step 18: relative paths use the base directory before canonicalization.
    if (input.pathname) |input_path| {
        var value = input_path;
        if (base) |record| {
            if (!record.hasOpaquePath() and !isAbsolutePathname(value, kind)) {
                const base_path = try baseString(temporary, try canonicalize.serializePath(temporary, &record), kind);
                if (std.mem.lastIndexOfScalar(u8, base_path, '/')) |slash| {
                    value = try std.mem.concat(temporary, u8, &.{ base_path[0 .. slash + 1], value });
                }
            }
        }
        result.pathname = if (kind == .pattern) value else if (protocol.len == 0 or url.special_schemes.isSpecialScheme(protocol))
            try canonicalize.canonicalizePathname(temporary, value)
        else
            try canonicalize.canonicalizeOpaquePathname(temporary, value);
    }
    // Steps 19-20.
    if (input.search) |value| {
        const stripped = if (std.mem.startsWith(u8, value, "?")) value[1..] else value;
        result.search = if (kind == .url) try canonicalize.canonicalizeSearch(temporary, stripped) else stripped;
    }
    if (input.hash) |value| {
        const stripped = if (std.mem.startsWith(u8, value, "#")) value[1..] else value;
        result.hash = if (kind == .url) try canonicalize.canonicalizeHash(temporary, stripped) else stripped;
    }
    return .{ .init = result, .arena = arena };
}
