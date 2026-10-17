//! What a Cache keeps of a request and a response (Service Workers 5.1, a
//! request response list's tuples), as bytes in a Browser's store: the
//! fields its Request and Response objects show again, and what Query Cache
//! compares. Engine-free and Fetch-free: the realm side (api.zig) converts
//! between these and Fetch's internal request and response; Fetch's enums
//! travel as their integer values.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#dfn-request-response-list

const std = @import("std");
const Allocator = std.mem.Allocator;

/// A header: a name and a value. OWNED strings.
pub const Header = struct {
    name: []u8,
    value: []u8,
};

/// A cached request. OWNED strings.
pub const StoredRequest = struct {
    /// Its URL, serialized.
    url: []u8,
    method: []u8,
    headers: []Header = &.{},
    mode: u8 = 0,
    credentials: u8 = 0,
    cache: u8 = 0,
    redirect: u8 = 0,
    integrity: []u8 = &.{},
    /// "client", "no-referrer", or a URL.
    referrer: []u8 = &.{},
    referrer_policy: u8 = 0,
    destination: u8 = 0,
    keepalive: bool = false,
    reload_navigation: bool = false,
    history_navigation: bool = false,

    pub fn deinit(self: *StoredRequest, allocator: Allocator) void {
        allocator.free(self.url);
        allocator.free(self.method);
        freeHeaders(allocator, self.headers);
        allocator.free(self.integrity);
        allocator.free(self.referrer);
    }

    pub fn clone(self: *const StoredRequest, allocator: Allocator) Allocator.Error!StoredRequest {
        var copy = self.*;
        copy.url = try allocator.dupe(u8, self.url);
        errdefer allocator.free(copy.url);
        copy.method = try allocator.dupe(u8, self.method);
        errdefer allocator.free(copy.method);
        copy.headers = try cloneHeaders(allocator, self.headers);
        errdefer freeHeaders(allocator, copy.headers);
        copy.integrity = try allocator.dupe(u8, self.integrity);
        errdefer allocator.free(copy.integrity);
        copy.referrer = try allocator.dupe(u8, self.referrer);
        return copy;
    }
};

/// A cached response. OWNED strings.
pub const StoredResponse = struct {
    response_type: u8 = 0,
    url_list: [][]u8 = &.{},
    status: u16 = 200,
    status_message: []u8 = &.{},
    headers: []Header = &.{},
    cors_exposed: [][]u8 = &.{},
    /// Its body's bytes, or null for a null body.
    body: ?[]u8 = null,
    range_requested: bool = false,
    request_includes_credentials: bool = true,

    /// Fetch's ResponseType values of the opaque and opaque-redirect
    /// filtered responses (api.zig checks them at compile time).
    pub const opaque_types = [_]u8{ 4, 5 };

    /// Whether this is an opaque or opaque-redirect filtered response's
    /// record - its internal response's fields, kept for the user agent:
    /// the filtered response script sees has an empty header list.
    pub fn hidesHeaders(self: *const StoredResponse) bool {
        return std.mem.indexOfScalar(u8, &opaque_types, self.response_type) != null;
    }

    pub fn deinit(self: *StoredResponse, allocator: Allocator) void {
        freeStrings(allocator, self.url_list);
        allocator.free(self.status_message);
        freeHeaders(allocator, self.headers);
        freeStrings(allocator, self.cors_exposed);
        if (self.body) |b| allocator.free(b);
    }

    pub fn clone(self: *const StoredResponse, allocator: Allocator) Allocator.Error!StoredResponse {
        var copy = self.*;
        copy.url_list = try cloneStrings(allocator, self.url_list);
        errdefer freeStrings(allocator, copy.url_list);
        copy.status_message = try allocator.dupe(u8, self.status_message);
        errdefer allocator.free(copy.status_message);
        copy.headers = try cloneHeaders(allocator, self.headers);
        errdefer freeHeaders(allocator, copy.headers);
        copy.cors_exposed = try cloneStrings(allocator, self.cors_exposed);
        errdefer freeStrings(allocator, copy.cors_exposed);
        copy.body = if (self.body) |b| try allocator.dupe(u8, b) else null;
        return copy;
    }

    /// The combined value of its `name` headers, as Vary is read. OWNED, or
    /// null when it has none.
    pub fn header(self: *const StoredResponse, allocator: Allocator, name: []const u8) Allocator.Error!?[]u8 {
        return combinedValue(allocator, self.headers, name);
    }
};

/// A request/response tuple. OWNED.
pub const Entry = struct {
    request: StoredRequest,
    response: StoredResponse,

    pub fn deinit(self: *Entry, allocator: Allocator) void {
        self.request.deinit(allocator);
        self.response.deinit(allocator);
    }
};

pub fn freeEntries(allocator: Allocator, entries: []Entry) void {
    for (entries) |*entry| entry.deinit(allocator);
    allocator.free(entries);
}

/// Fetch's "combined value" of `name` in `headers`: the values of every
/// header so named (case-insensitively), separated by ", ". OWNED, or null
/// when there is none.
pub fn combinedValue(allocator: Allocator, headers: []const Header, name: []const u8) Allocator.Error!?[]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    var found = false;
    for (headers) |h| {
        if (!std.ascii.eqlIgnoreCase(h.name, name)) continue;
        if (found) try out.appendSlice(allocator, ", ");
        try out.appendSlice(allocator, h.value);
        found = true;
    }
    if (!found) {
        out.deinit(allocator);
        return null;
    }
    return try out.toOwnedSlice(allocator);
}

pub fn freeHeaders(allocator: Allocator, headers: []Header) void {
    for (headers) |h| {
        allocator.free(h.name);
        allocator.free(h.value);
    }
    allocator.free(headers);
}

pub fn cloneHeaders(allocator: Allocator, headers: []const Header) Allocator.Error![]Header {
    const out = try allocator.alloc(Header, headers.len);
    var made: usize = 0;
    errdefer {
        for (out[0..made]) |h| {
            allocator.free(h.name);
            allocator.free(h.value);
        }
        allocator.free(out);
    }
    for (headers) |h| {
        const name = try allocator.dupe(u8, h.name);
        errdefer allocator.free(name);
        out[made] = .{ .name = name, .value = try allocator.dupe(u8, h.value) };
        made += 1;
    }
    return out;
}

fn freeStrings(allocator: Allocator, strings: [][]u8) void {
    for (strings) |s| allocator.free(s);
    allocator.free(strings);
}

fn cloneStrings(allocator: Allocator, strings: []const []u8) Allocator.Error![][]u8 {
    const out = try allocator.alloc([]u8, strings.len);
    var made: usize = 0;
    errdefer {
        for (out[0..made]) |s| allocator.free(s);
        allocator.free(out);
    }
    for (strings) |s| {
        out[made] = try allocator.dupe(u8, s);
        made += 1;
    }
    return out;
}

// ============================================================================
// Bytes
// ============================================================================

const format_version: u8 = 1;

pub const DecodeError = error{ OutOfMemory, Corrupt };

/// `entry` as bytes. OWNED.
pub fn encode(allocator: Allocator, entry: *const Entry) Allocator.Error![]u8 {
    var w: Writer = .{ .allocator = allocator };
    errdefer w.out.deinit(allocator);
    try w.byte(format_version);
    const r = &entry.request;
    try w.string(r.url);
    try w.string(r.method);
    try w.headers(r.headers);
    try w.byte(r.mode);
    try w.byte(r.credentials);
    try w.byte(r.cache);
    try w.byte(r.redirect);
    try w.string(r.integrity);
    try w.string(r.referrer);
    try w.byte(r.referrer_policy);
    try w.byte(r.destination);
    try w.byte(@intFromBool(r.keepalive));
    try w.byte(@intFromBool(r.reload_navigation));
    try w.byte(@intFromBool(r.history_navigation));
    const s = &entry.response;
    try w.byte(s.response_type);
    try w.strings(s.url_list);
    try w.int(u16, s.status);
    try w.string(s.status_message);
    try w.headers(s.headers);
    try w.strings(s.cors_exposed);
    try w.byte(@intFromBool(s.body != null));
    try w.string(s.body orelse "");
    try w.byte(@intFromBool(s.range_requested));
    try w.byte(@intFromBool(s.request_includes_credentials));
    return w.out.toOwnedSlice(allocator);
}

/// The entry `bytes` hold. OWNED.
pub fn decode(allocator: Allocator, bytes: []const u8) DecodeError!Entry {
    var r: Reader = .{ .allocator = allocator, .bytes = bytes };
    if (try r.byte() != format_version) return error.Corrupt;
    var request: StoredRequest = .{ .url = &.{}, .method = &.{} };
    errdefer request.deinit(allocator);
    request.url = try r.string();
    request.method = try r.string();
    request.headers = try r.headers();
    request.mode = try r.byte();
    request.credentials = try r.byte();
    request.cache = try r.byte();
    request.redirect = try r.byte();
    request.integrity = try r.string();
    request.referrer = try r.string();
    request.referrer_policy = try r.byte();
    request.destination = try r.byte();
    request.keepalive = try r.byte() != 0;
    request.reload_navigation = try r.byte() != 0;
    request.history_navigation = try r.byte() != 0;
    var response: StoredResponse = .{};
    errdefer response.deinit(allocator);
    response.response_type = try r.byte();
    response.url_list = try r.strings();
    response.status = try r.int(u16);
    response.status_message = try r.string();
    response.headers = try r.headers();
    response.cors_exposed = try r.strings();
    const has_body = try r.byte() != 0;
    const body = try r.string();
    if (has_body) response.body = body else allocator.free(body);
    response.range_requested = try r.byte() != 0;
    response.request_includes_credentials = try r.byte() != 0;
    if (r.at != bytes.len) return error.Corrupt;
    return .{ .request = request, .response = response };
}

const Writer = struct {
    allocator: Allocator,
    out: std.ArrayListUnmanaged(u8) = .empty,

    fn byte(self: *Writer, value: u8) Allocator.Error!void {
        try self.out.append(self.allocator, value);
    }

    fn int(self: *Writer, comptime T: type, value: T) Allocator.Error!void {
        var buf: [@sizeOf(T)]u8 = undefined;
        std.mem.writeInt(T, &buf, value, .big);
        try self.out.appendSlice(self.allocator, &buf);
    }

    fn string(self: *Writer, value: []const u8) Allocator.Error!void {
        try self.int(u32, @intCast(value.len));
        try self.out.appendSlice(self.allocator, value);
    }

    fn strings(self: *Writer, values: []const []u8) Allocator.Error!void {
        try self.int(u32, @intCast(values.len));
        for (values) |v| try self.string(v);
    }

    fn headers(self: *Writer, values: []const Header) Allocator.Error!void {
        try self.int(u32, @intCast(values.len));
        for (values) |h| {
            try self.string(h.name);
            try self.string(h.value);
        }
    }
};

const Reader = struct {
    allocator: Allocator,
    bytes: []const u8,
    at: usize = 0,

    fn take(self: *Reader, n: usize) DecodeError![]const u8 {
        if (self.bytes.len - self.at < n) return error.Corrupt;
        const out = self.bytes[self.at .. self.at + n];
        self.at += n;
        return out;
    }

    fn byte(self: *Reader) DecodeError!u8 {
        return (try self.take(1))[0];
    }

    fn int(self: *Reader, comptime T: type) DecodeError!T {
        return std.mem.readInt(T, (try self.take(@sizeOf(T)))[0..@sizeOf(T)], .big);
    }

    fn string(self: *Reader) DecodeError![]u8 {
        const len = try self.int(u32);
        return self.allocator.dupe(u8, try self.take(len));
    }

    fn strings(self: *Reader) DecodeError![][]u8 {
        const count = try self.int(u32);
        if (count > self.bytes.len) return error.Corrupt;
        const out = try self.allocator.alloc([]u8, count);
        var made: usize = 0;
        errdefer {
            for (out[0..made]) |s| self.allocator.free(s);
            self.allocator.free(out);
        }
        while (made < count) : (made += 1) out[made] = try self.string();
        return out;
    }

    fn headers(self: *Reader) DecodeError![]Header {
        const count = try self.int(u32);
        if (count > self.bytes.len) return error.Corrupt;
        const out = try self.allocator.alloc(Header, count);
        var made: usize = 0;
        errdefer {
            for (out[0..made]) |h| {
                self.allocator.free(h.name);
                self.allocator.free(h.value);
            }
            self.allocator.free(out);
        }
        while (made < count) : (made += 1) {
            const name = try self.string();
            errdefer self.allocator.free(name);
            out[made] = .{ .name = name, .value = try self.string() };
        }
        return out;
    }
};
