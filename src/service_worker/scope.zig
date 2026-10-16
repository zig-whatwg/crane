//! The URL steps of Service Workers: what Start Register checks of a script
//! URL and a scope URL, the scope strings the registration map is keyed by,
//! Match Service Worker Registration's prefix match, and the Update
//! algorithm's maximum scope (its fetch hook steps 11-16, with the
//! `Service-Worker-Allowed` header).
//!
//! Every URL here is a string the URL parser accepts; what is kept is the
//! serialization (the registration map's keys are "serialized scope urls").
//! Nothing here touches a thread, a realm or an engine.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#start-register-algorithm

const std = @import("std");
const Allocator = std.mem.Allocator;
const parser = @import("basic_parser");
const serializer = @import("url_serializer");
const URLRecord = @import("url_record").URLRecord;
const origin_mod = @import("origin");

pub const Error = error{ TypeError, OutOfMemory };

/// What Start Register keeps of its URLs: both serialized with the exclude
/// fragment flag (steps 2 and 7 null their fragments). OWNED.
pub const RegisterUrls = struct {
    script_url: []u8,
    scope_url: []u8,

    pub fn deinit(self: *RegisterUrls, allocator: Allocator) void {
        allocator.free(self.script_url);
        allocator.free(self.scope_url);
    }
};

/// Start Register steps 1-9, for `script_url` (the result of parsing
/// register()'s scriptURL with the API base URL, serialized - null when that
/// failed) and `scope_url` (options["scope"] parsed the same way - null when
/// it was not given, `failed_scope` true when it was given and did not
/// parse). TypeError for every step that rejects with one.
pub fn startRegister(allocator: Allocator, script_url: ?[]const u8, scope_url: ?[]const u8, failed_scope: bool) Error!RegisterUrls {
    // 1. If scriptURL is failure, reject promise with a TypeError.
    const script_input = script_url orelse return error.TypeError;
    var script = parseUrl(allocator, script_input, null) catch |err| return mapParse(err);
    defer script.deinit();
    // 2. Set scriptURL's fragment to null (the serialization below excludes
    // it).
    // 3. If scriptURL's scheme is not one of "http" and "https", reject.
    if (!isHttpScheme(script.scheme())) return error.TypeError;
    // 4. If any of the strings in scriptURL's path contains either ASCII
    // case-insensitive "%2f" or ASCII case-insensitive "%5c", reject.
    if (pathHasEscapedSlash(&script)) return error.TypeError;

    // 5. If scopeURL is null, set scopeURL to the result of parsing the
    // string "./" with scriptURL.
    // 6. If scopeURL is failure, reject promise with a TypeError.
    if (failed_scope) return error.TypeError;
    var scope = if (scope_url) |input|
        parseUrl(allocator, input, null) catch |err| return mapParse(err)
    else
        parseUrl(allocator, "./", &script) catch |err| return mapParse(err);
    defer scope.deinit();
    // 7. Set scopeURL's fragment to null.
    // 8. If scopeURL's scheme is not one of "http" and "https", reject.
    if (!isHttpScheme(scope.scheme())) return error.TypeError;
    // 9. If any of the strings in scopeURL's path contains "%2f" or "%5c",
    // reject.
    if (pathHasEscapedSlash(&scope)) return error.TypeError;

    const script_serialized = try serialize(allocator, &script);
    errdefer allocator.free(script_serialized);
    const scope_serialized = try serialize(allocator, &scope);
    return .{ .script_url = script_serialized, .scope_url = scope_serialized };
}

/// `url` serialized with the exclude fragment flag set: how the
/// registration map keys a scope (Set Registration step 2, Get Registration
/// step 3). OWNED.
pub fn serializeExcludingFragment(allocator: Allocator, url: []const u8) Error![]u8 {
    var record = parseUrl(allocator, url, null) catch |err| return mapParse(err);
    defer record.deinit();
    return serialize(allocator, &record);
}

/// `url` with its fragment nulled, serialized - getRegistration()'s step 5
/// for a client URL that already parsed against the API base URL. Null when
/// it does not parse.
pub fn parseAgainst(allocator: Allocator, input: []const u8, base: ?[]const u8) error{OutOfMemory}!?[]u8 {
    var base_record: ?URLRecord = null;
    defer if (base_record) |*b| b.deinit();
    if (base) |b| base_record = parseUrl(allocator, b, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => null,
    };
    var record = parseUrl(allocator, input, if (base_record) |*b| b else null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return null,
    };
    defer record.deinit();
    const serialized = serializer.serialize(allocator, &record, false) catch return error.OutOfMemory;
    return @constCast(serialized);
}

/// Match Service Worker Registration steps 2-6: of `scopes` (the serialized
/// scope urls of the storage key's registrations), the longest one
/// `client_url` (serialized) starts with - "prefix-based rather than
/// path-structural". Its index, or null.
pub fn longestMatchingScope(scopes: []const []const u8, client_url: []const u8) ?usize {
    var best: ?usize = null;
    for (scopes, 0..) |scope, i| {
        if (!std.mem.startsWith(u8, client_url, scope)) continue;
        if (best) |b| {
            if (scopes[b].len >= scope.len) continue;
        }
        best = i;
    }
    return best;
}

/// The Update algorithm's fetch hook, steps 11-16: whether a script at
/// `script_url` may control `scope_url`, given the response's
/// `Service-Worker-Allowed` header value (isomorphic-decoded; null when the
/// response has none). Both URLs serialized. `error.NetworkError` for step
/// 14.2 (the header does not parse - "asynchronously complete these steps
/// with a network error"); false for step 16 (a "SecurityError").
pub fn scopeIsAllowed(allocator: Allocator, script_url: []const u8, scope_url: []const u8, service_worker_allowed: ?[]const u8) error{ NetworkError, OutOfMemory }!bool {
    var script = parseUrl(allocator, script_url, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.NetworkError,
    };
    defer script.deinit();
    var scope = parseUrl(allocator, scope_url, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return false,
    };
    defer scope.deinit();

    // 12. Let maxScopeString be null.
    var max_scope_string: ?[]u8 = null;
    defer if (max_scope_string) |s| allocator.free(s);
    if (service_worker_allowed) |allowed| {
        // 14.1. Let maxScope be the result of parsing serviceWorkerAllowed
        // using job's script url as the base URL.
        var max_scope = parseUrl(allocator, allowed, &script) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            // 14.2. If maxScope is failure: a network error.
            else => return error.NetworkError,
        };
        defer max_scope.deinit();
        // 14.3. If maxScope's origin is job's script url's origin, set
        // maxScopeString to "/" followed by maxScope's path segments joined
        // by "/".
        if (try sameOrigin(allocator, &max_scope, &script)) max_scope_string = try pathString(allocator, &max_scope);
    } else {
        // 13.1. Let resolvedScope be the result of parsing "./" using job's
        // script url as the base URL.
        var resolved = parseUrl(allocator, "./", &script) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.NetworkError,
        };
        defer resolved.deinit();
        // 13.2. maxScopeString: "/" followed by its path segments (the last
        // one empty, so the string ends in "/").
        max_scope_string = try pathString(allocator, &resolved);
    }
    // 15. Let scopeString be "/" followed by scopeURL's path segments.
    const scope_string = try pathString(allocator, &scope);
    defer allocator.free(scope_string);
    // 16. If maxScopeString is null or scopeString does not start with it:
    // a SecurityError.
    const max = max_scope_string orelse return false;
    return std.mem.startsWith(u8, scope_string, max);
}

/// The serialized origin of `url`, or "null" for an opaque one. OWNED.
pub fn originOf(allocator: Allocator, url: []const u8) error{OutOfMemory}![]u8 {
    var record = parseUrl(allocator, url, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return allocator.dupe(u8, "null"),
    };
    defer record.deinit();
    const origin = origin_mod.getOrigin(allocator, &record) catch return allocator.dupe(u8, "null");
    defer origin.deinit(allocator);
    return origin.serialize(allocator) catch error.OutOfMemory;
}

/// Whether two serialized URLs have the same origin (tuple origins only: an
/// opaque origin is the same as nothing else).
pub fn sameOriginUrls(allocator: Allocator, a: []const u8, b: []const u8) error{OutOfMemory}!bool {
    const origin_a = try originOf(allocator, a);
    defer allocator.free(origin_a);
    if (std.mem.eql(u8, origin_a, "null")) return false;
    const origin_b = try originOf(allocator, b);
    defer allocator.free(origin_b);
    return std.mem.eql(u8, origin_a, origin_b);
}

// ----------------------------------------------------------------------------

fn parseUrl(allocator: Allocator, input: []const u8, base: ?*const URLRecord) parser.ParseError!URLRecord {
    return parser.parse(allocator, input, base);
}

fn mapParse(err: parser.ParseError) Error {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.TypeError,
    };
}

fn serialize(allocator: Allocator, record: *const URLRecord) error{OutOfMemory}![]u8 {
    const serialized = serializer.serialize(allocator, record, true) catch return error.OutOfMemory;
    return @constCast(serialized);
}

fn isHttpScheme(scheme: []const u8) bool {
    return std.mem.eql(u8, scheme, "http") or std.mem.eql(u8, scheme, "https");
}

fn pathHasEscapedSlash(record: *const URLRecord) bool {
    return switch (record.path) {
        .opaque_path => |path| hasEscapedSlash(path),
        .segments => |segments| for (segments.toSlice()) |segment| {
            if (hasEscapedSlash(segment)) break true;
        } else false,
    };
}

fn hasEscapedSlash(segment: []const u8) bool {
    return std.ascii.indexOfIgnoreCase(segment, "%2f") != null or std.ascii.indexOfIgnoreCase(segment, "%5c") != null;
}

/// "/" followed by the strings in `record`'s path (including empty strings),
/// separated from each other by "/". OWNED.
fn pathString(allocator: Allocator, record: *const URLRecord) error{OutOfMemory}![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.append(allocator, '/');
    switch (record.path) {
        .opaque_path => |path| try out.appendSlice(allocator, path),
        .segments => |segments| for (segments.toSlice(), 0..) |segment, i| {
            if (i > 0) try out.append(allocator, '/');
            try out.appendSlice(allocator, segment);
        },
    }
    return out.toOwnedSlice(allocator);
}

fn sameOrigin(allocator: Allocator, a: *const URLRecord, b: *const URLRecord) error{OutOfMemory}!bool {
    const origin_a = origin_mod.getOrigin(allocator, a) catch return false;
    defer origin_a.deinit(allocator);
    const origin_b = origin_mod.getOrigin(allocator, b) catch return false;
    defer origin_b.deinit(allocator);
    return origin_mod.isSameOrigin(origin_a, origin_b);
}
