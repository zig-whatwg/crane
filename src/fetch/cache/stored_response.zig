//! A stored response: what the HTTP cache keeps of a response it stored
//! (RFC 9111 3), immutable once published and reference-counted, so a
//! lookup takes a reference under the cache's lock and reads it outside it,
//! on whichever thread of the Browser asked. A 304 makes a new one
//! (`freshened`) that shares the body. The last reference frees it, with
//! the allocator it was made with - the cache's, which every thread of the
//! Browser may use.
//!
//! Chromium keeps the same pieces: HttpResponseInfo (status, headers, the
//! request/response times, HttpVaryData) beside the body stream of a cache
//! entry.

const std = @import("std");
const Allocator = std.mem.Allocator;
const header_list = @import("../internal/header_list.zig");
pub const Header = header_list.Header;
const freshness = @import("freshness.zig");
pub const Facts = freshness.Facts;
const HeaderView = @import("header_view.zig").HeaderView;

/// The body bytes, shared by a response and the responses a 304 freshened
/// from it.
pub const SharedBody = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    bytes: []u8,

    /// Takes `bytes`, which `allocator` made.
    pub fn adopt(allocator: Allocator, bytes: []u8) Allocator.Error!*SharedBody {
        const body = try allocator.create(SharedBody);
        body.* = .{ .allocator = allocator, .bytes = bytes };
        return body;
    }

    pub fn retain(self: *SharedBody) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    pub fn release(self: *SharedBody) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        self.allocator.free(self.bytes);
        self.allocator.destroy(self);
    }
};

/// One request field a stored response's Vary names, as the storing request
/// had it (combined, HeaderView.combined); null for absent.
pub const VaryField = struct {
    name: []u8,
    value: ?[]u8,
};

/// What Fetch's report timing steps read of a stored response: "The
/// associated body info is stored in the cache alongside the response"
/// (HTTP-network-or-cache fetch 11.5.2).
pub const BodyInfo = struct {
    encoded_size: u64 = 0,
    decoded_size: u64 = 0,
    /// One of HTTP-network fetch's filtered codings - a static string.
    content_encoding: []const u8 = "",
};

pub const StoredResponse = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    /// The cache key: the network partition key and the URL, fragment
    /// removed (`keyUrl`).
    partition: []u8,
    url: []u8,
    status: u16,
    status_message: []u8,
    /// RFC 9111 3.1: every field received, but Connection and the fields it
    /// names, the hop-by-hop and proxy-specific ones, and Set-Cookie.
    headers: []Header,
    body: *SharedBody,
    body_info: BodyInfo,
    vary: []VaryField,
    /// The response's Vary contains "*": it never matches (4.1).
    vary_star: bool,
    /// RFC 9111 4.2.3's request_time and response_time, seconds.
    request_time: i64,
    response_time: i64,
    facts: Facts,
    /// What the cache counts against its caps.
    size: usize,

    pub const Init = struct {
        partition: []const u8,
        url: []const u8,
        status: u16,
        status_message: []const u8 = "",
        headers: []const Header,
        /// Copied. A writer still collecting gives none and `setBody`s later.
        body: []const u8 = "",
        body_info: ?BodyInfo = null,
        /// The storing request's fields, for the Vary data.
        request: HeaderView = .{},
        request_time: i64,
        response_time: i64,
    };

    pub fn create(allocator: Allocator, init: Init) Allocator.Error!*StoredResponse {
        const self = try allocator.create(StoredResponse);
        errdefer allocator.destroy(self);
        const partition = try allocator.dupe(u8, init.partition);
        errdefer allocator.free(partition);
        const url = try allocator.dupe(u8, init.url);
        errdefer allocator.free(url);
        const status_message = try allocator.dupe(u8, init.status_message);
        errdefer allocator.free(status_message);
        const headers = try storableHeaders(allocator, init.headers);
        errdefer freeHeaders(allocator, headers);
        const bytes = try allocator.dupe(u8, init.body);
        const body = SharedBody.adopt(allocator, bytes) catch |err| {
            allocator.free(bytes);
            return err;
        };
        errdefer body.release();
        var vary_star = false;
        const vary = try varyData(allocator, headers, init.request, &vary_star);
        self.* = .{
            .allocator = allocator,
            .partition = partition,
            .url = url,
            .status = init.status,
            .status_message = status_message,
            .headers = headers,
            .body = body,
            .body_info = init.body_info orelse .{ .encoded_size = init.body.len, .decoded_size = init.body.len },
            .vary = vary,
            .vary_star = vary_star,
            .request_time = init.request_time,
            .response_time = init.response_time,
            .facts = Facts.fromHeaders(init.status, headers),
            .size = 0,
        };
        self.size = self.computeSize();
        return self;
    }

    /// Give a response made without its body (a writer's, before the body
    /// ended) its body - `bytes`, which the response's allocator made, taken.
    /// Only before it is published: a published response never changes.
    pub fn setBody(self: *StoredResponse, bytes: []u8, info: BodyInfo) Allocator.Error!void {
        const body = SharedBody.adopt(self.allocator, bytes) catch |err| {
            self.allocator.free(bytes);
            return err;
        };
        self.body.release();
        self.body = body;
        self.body_info = info;
        self.size = self.computeSize();
    }

    pub fn retain(self: *StoredResponse) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    pub fn release(self: *StoredResponse) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        const allocator = self.allocator;
        allocator.free(self.partition);
        allocator.free(self.url);
        allocator.free(self.status_message);
        freeHeaders(allocator, self.headers);
        self.body.release();
        freeVary(allocator, self.vary);
        allocator.destroy(self);
    }

    /// The first stored line named `name`.
    pub fn header(self: *const StoredResponse, name: []const u8) ?[]const u8 {
        for (self.headers) |h| if (std.ascii.eqlIgnoreCase(h.name, name)) return h.value;
        return null;
    }

    pub fn headerCount(self: *const StoredResponse, name: []const u8) usize {
        var count: usize = 0;
        for (self.headers) |h| {
            if (std.ascii.eqlIgnoreCase(h.name, name)) count += 1;
        }
        return count;
    }

    /// RFC 9111 4.1: whether `request`'s fields match the ones the stored
    /// response's Vary nominated, as the storing request had them.
    pub fn varyMatches(self: *const StoredResponse, request: HeaderView) bool {
        if (self.vary_star) return false;
        for (self.vary) |field| {
            if (!request.matches(field.name, field.value)) return false;
        }
        return true;
    }

    /// Its freshness lifetime (RFC 9111 4.2.1), seconds.
    pub fn lifetime(self: *const StoredResponse) u64 {
        return freshness.lifetime(self.facts, self.response_time);
    }

    /// Its current age at `now` (4.2.3), seconds.
    pub fn currentAge(self: *const StoredResponse, now: i64) u64 {
        return freshness.currentAge(self.facts, self.request_time, self.response_time, now);
    }

    /// RFC 9111 4.3.4 and 3.2: a copy freshened by a 304's `fields`, made at
    /// `request_time` and received at `response_time` - each field the 304
    /// carries replacing the stored lines of its name, but those 3.1 never
    /// stores and those the stored body depends on (`keptOnUpdate`). The body
    /// is shared. Its Vary data is the stored response's: the request the
    /// 304 answered was validated against it.
    pub fn freshened(self: *const StoredResponse, allocator: Allocator, fields: []const Header, request_time: i64, response_time: i64) Allocator.Error!*StoredResponse {
        var merged: std.ArrayListUnmanaged(Header) = .empty;
        defer merged.deinit(allocator);
        const update = try storableHeaders(allocator, fields);
        defer freeHeaders(allocator, update);
        // The stored lines a 304 field does not replace, in their order...
        for (self.headers) |h| {
            if (!keptOnUpdate(h.name) and hasName(update, h.name)) continue;
            try merged.append(allocator, h);
        }
        // ...then the 304's, but those the stored response keeps.
        for (update) |h| {
            if (keptOnUpdate(h.name)) continue;
            try merged.append(allocator, h);
        }
        const copy = try allocator.create(StoredResponse);
        errdefer allocator.destroy(copy);
        const partition = try allocator.dupe(u8, self.partition);
        errdefer allocator.free(partition);
        const url = try allocator.dupe(u8, self.url);
        errdefer allocator.free(url);
        const status_message = try allocator.dupe(u8, self.status_message);
        errdefer allocator.free(status_message);
        const headers = try copyHeaders(allocator, merged.items);
        errdefer freeHeaders(allocator, headers);
        const vary = try copyVary(allocator, self.vary);
        errdefer freeVary(allocator, vary);
        self.body.retain();
        copy.* = .{
            .allocator = allocator,
            .partition = partition,
            .url = url,
            .status = self.status,
            .status_message = status_message,
            .headers = headers,
            .body = self.body,
            .body_info = self.body_info,
            .vary = vary,
            .vary_star = self.vary_star,
            .request_time = request_time,
            .response_time = response_time,
            .facts = Facts.fromHeaders(self.status, headers),
            .size = 0,
        };
        copy.size = copy.computeSize();
        return copy;
    }

    fn computeSize(self: *const StoredResponse) usize {
        var size: usize = @sizeOf(StoredResponse) + self.partition.len + self.url.len + self.status_message.len + self.body.bytes.len;
        for (self.headers) |h| size += h.name.len + h.value.len + @sizeOf(Header);
        for (self.vary) |v| size += v.name.len + (if (v.value) |value| value.len else 0) + @sizeOf(VaryField);
        return size;
    }
};

/// RFC 9111 3.2: fields a 304 does not update - Content-Length (named by
/// 3.2), and those the stored body was decoded or parsed under: the body is
/// kept decoded (Content-Encoding) and was sniffed and parsed as its type
/// (Content-Type) - 3.2's own examples - and Content-Range, which is
/// "automatically processed and removed".
fn keptOnUpdate(name: []const u8) bool {
    for ([_][]const u8{ "Content-Length", "Content-Encoding", "Content-Type", "Content-Range" }) |kept| {
        if (std.ascii.eqlIgnoreCase(name, kept)) return true;
    }
    return false;
}

/// RFC 9111 3.1's exceptions to "include all received response header
/// fields": Connection and the fields it lists, the hop-by-hop fields RFC
/// 9110 7.6.1 names, the proxy-specific ones (MUST NOT be stored) - and
/// Set-Cookie: cookies are stored by HTTP-network fetch from the network's
/// response only, and Chromium persists cached headers without them
/// (HttpResponseHeaders::Persist, PERSIST_SANS_COOKIES).
fn storableHeaders(allocator: Allocator, headers: []const Header) Allocator.Error![]Header {
    var kept: std.ArrayListUnmanaged(Header) = .empty;
    defer kept.deinit(allocator);
    for (headers) |h| {
        if (!storable(headers, h.name)) continue;
        try kept.append(allocator, h);
    }
    return copyHeaders(allocator, kept.items);
}

fn storable(headers: []const Header, name: []const u8) bool {
    const never = [_][]const u8{
        "Connection", "Keep-Alive",  "Proxy-Connection",   "TE",                        "Transfer-Encoding",
        "Upgrade",    "Trailer",     "Proxy-Authenticate", "Proxy-Authentication-Info", "Proxy-Authorization",
        "Set-Cookie", "Set-Cookie2",
    };
    for (never) |n| if (std.ascii.eqlIgnoreCase(name, n)) return false;
    // Fields the Connection header names (RFC 9110 7.6.1).
    for (headers) |h| {
        if (!std.ascii.eqlIgnoreCase(h.name, "Connection")) continue;
        var options = std.mem.splitScalar(u8, h.value, ',');
        while (options.next()) |option| {
            if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, option, " \t"), name)) return false;
        }
    }
    return true;
}

fn hasName(headers: []const Header, name: []const u8) bool {
    for (headers) |h| if (std.ascii.eqlIgnoreCase(h.name, name)) return true;
    return false;
}

fn copyHeaders(allocator: Allocator, headers: []const Header) Allocator.Error![]Header {
    const out = try allocator.alloc(Header, headers.len);
    var made: usize = 0;
    errdefer {
        for (out[0..made]) |*h| h.deinit(allocator);
        allocator.free(out);
    }
    for (headers) |h| {
        out[made] = try h.clone(allocator);
        made += 1;
    }
    return out;
}

fn freeHeaders(allocator: Allocator, headers: []Header) void {
    for (headers) |*h| h.deinit(allocator);
    allocator.free(headers);
}

/// The Vary data (Chromium's HttpVaryData): for each field name the stored
/// response's Vary lines list, the storing request's value of it.
fn varyData(allocator: Allocator, headers: []const Header, request: HeaderView, star: *bool) Allocator.Error![]VaryField {
    var fields: std.ArrayListUnmanaged(VaryField) = .empty;
    errdefer {
        freeVaryItems(allocator, fields.items);
        fields.deinit(allocator);
    }
    for (headers) |h| {
        if (!std.ascii.eqlIgnoreCase(h.name, "Vary")) continue;
        var names = std.mem.splitScalar(u8, h.value, ',');
        while (names.next()) |raw| {
            const name = std.mem.trim(u8, raw, " \t");
            if (name.len == 0) continue;
            if (std.mem.eql(u8, name, "*")) {
                star.* = true;
                continue;
            }
            var duplicate = false;
            for (fields.items) |f| {
                if (std.ascii.eqlIgnoreCase(f.name, name)) duplicate = true;
            }
            if (duplicate) continue;
            const owned_name = try allocator.dupe(u8, name);
            errdefer allocator.free(owned_name);
            const value = try request.combined(allocator, name);
            errdefer if (value) |v| allocator.free(v);
            try fields.append(allocator, .{ .name = owned_name, .value = value });
        }
    }
    return fields.toOwnedSlice(allocator);
}

fn copyVary(allocator: Allocator, vary: []const VaryField) Allocator.Error![]VaryField {
    const out = try allocator.alloc(VaryField, vary.len);
    var made: usize = 0;
    errdefer {
        freeVaryItems(allocator, out[0..made]);
        allocator.free(out);
    }
    for (vary) |field| {
        const name = try allocator.dupe(u8, field.name);
        errdefer allocator.free(name);
        out[made] = .{ .name = name, .value = if (field.value) |v| try allocator.dupe(u8, v) else null };
        made += 1;
    }
    return out;
}

fn freeVaryItems(allocator: Allocator, vary: []const VaryField) void {
    for (vary) |field| {
        allocator.free(field.name);
        if (field.value) |v| allocator.free(v);
    }
}

fn freeVary(allocator: Allocator, vary: []VaryField) void {
    freeVaryItems(allocator, vary);
    allocator.free(vary);
}
