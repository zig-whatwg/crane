//! A page session's kept request and response bodies, for Network
//! .getResponseBody and Network.getRequestPostData (CDP part 1 gap 2;
//! tmp/plans/cdp-part1-design.md 3.9).
//!
//! Blink's NetworkResourcesData is the model (third_party/blink/renderer/
//! core/inspector/network_resources_data.cc and inspector_network_agent.cc,
//! BSD-3 - reproduced, not copied): one per Network agent - here, per page
//! session with Network enabled - a record per request, its body kept as it
//! arrives within two limits Network.enable sets: `maxTotalBufferSize` for
//! all bodies (200 MB by default, kDefaultTotalBufferSize off Android) and
//! `maxResourceBufferSize` for one (20 MB, kDefaultResourceBufferSize). A
//! body that grows past the second is evicted (its content dropped, the
//! record kept: "evicted"); room for a new chunk is made by evicting the
//! OLDEST records' content first (EnsureFreeSpace walks request_ids_deque_
//! from its front). A main-frame commit clears every record but the
//! committing navigation's (InspectorNetworkAgent::DidCommitLoad ->
//! NetworkResourcesData::Clear(loader id)).
//!
//! Browser thread only; the session's allocator.

const std = @import("std");
const Allocator = std.mem.Allocator;
const TombstoneGuard = @import("infra").tombstones.TombstoneGuard;

/// kDefaultTotalBufferSize, kDefaultResourceBufferSize (not Android).
pub const default_total_buffer_size: u64 = 200 * 1000 * 1000;
pub const default_resource_buffer_size: u64 = 20 * 1000 * 1000;

pub const Resource = struct {
    /// The document's loader (a navigation id) - what a commit preserves.
    loader: u64,
    /// The request's body as sent, OWNED, when it had bytes.
    post_data: ?[]u8 = null,
    /// The response's MIME type essence and charset parameter, OWNED.
    mime_type: []u8 = &.{},
    charset: []u8 = &.{},
    /// The body received so far, while it is kept.
    content: std.ArrayListUnmanaged(u8) = .empty,
    /// Dropped for the limits (Blink's IsContentEvicted).
    evicted: bool = false,
    /// A response was received (the body belongs to it).
    has_response: bool = false,
    finished: bool = false,

    fn deinit(self: *Resource, allocator: Allocator) void {
        if (self.post_data) |d| allocator.free(d);
        allocator.free(self.mime_type);
        allocator.free(self.charset);
        self.content.deinit(allocator);
    }
};

/// What getResponseBody finds for an id.
pub const Body = union(enum) {
    /// No record: "No resource with given identifier found".
    unknown,
    /// "Request content was evicted from inspector cache".
    evicted,
    /// No content (none arrived, or it is still arriving with nothing kept):
    /// "No data found for resource with given identifier".
    none,
    /// The bytes (BORROWED until the next change) and how to report them.
    content: struct { bytes: []const u8, resource: *const Resource },
};

pub const NetworkResources = struct {
    allocator: Allocator,
    max_total: u64 = default_total_buffer_size,
    max_resource: u64 = default_resource_buffer_size,
    by_id: std.AutoHashMapUnmanaged(u64, Resource) = .empty,
    /// Request ids, oldest first (Blink's request_ids_deque_).
    order: std.ArrayListUnmanaged(u64) = .empty,
    /// Bytes of content kept (Blink's content_size_).
    content_size: u64 = 0,
    by_id_guard: TombstoneGuard = .{},

    pub fn init(allocator: Allocator) NetworkResources {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *NetworkResources) void {
        const allocator = self.allocator;
        var it = self.by_id.valueIterator();
        while (it.next()) |r| r.deinit(allocator);
        self.by_id.deinit(allocator);
        self.order.deinit(allocator);
        self.* = .{ .allocator = allocator };
    }

    /// Network.enable's limits (Blink: SetResourcesDataSizeLimits): the
    /// kept content is trimmed to them.
    pub fn setLimits(self: *NetworkResources, total: u64, resource: u64) void {
        self.max_total = total;
        self.max_resource = resource;
        var it = self.by_id.valueIterator();
        while (it.next()) |r| if (r.content.items.len > self.max_resource) self.evict(r);
        _ = self.ensureFreeSpace(0);
    }

    /// A request starts, or starts again for a redirect (the same id: what
    /// the redirect's response sent is no longer the body).
    pub fn requestWillBeSent(self: *NetworkResources, id: u64, loader: u64, post_data: ?[]const u8) Allocator.Error!void {
        const allocator = self.allocator;
        const copy: ?[]u8 = if (post_data) |d| try allocator.dupe(u8, d) else null;
        errdefer if (copy) |c| allocator.free(c);
        if (self.by_id.getPtr(id)) |existing| {
            self.content_size -|= existing.content.items.len;
            existing.deinit(allocator);
            existing.* = .{ .loader = loader, .post_data = copy };
            return;
        }
        try self.order.append(allocator, id);
        errdefer _ = self.order.pop();
        self.by_id_guard.beforeInsert(&self.by_id);
        try self.by_id.put(allocator, id, .{ .loader = loader, .post_data = copy });
    }

    pub fn responseReceived(self: *NetworkResources, id: u64, mime_type: []const u8, charset: []const u8) Allocator.Error!void {
        const allocator = self.allocator;
        const r = self.by_id.getPtr(id) orelse return;
        const mime = try allocator.dupe(u8, mime_type);
        errdefer allocator.free(mime);
        const cs = try allocator.dupe(u8, charset);
        allocator.free(r.mime_type);
        allocator.free(r.charset);
        r.mime_type = mime;
        r.charset = cs;
        r.has_response = true;
    }

    /// More of the body (Blink's MaybeAddResourceData): a resource that
    /// would grow past the per-resource limit is evicted; room is made by
    /// evicting the oldest content; an evicted resource keeps nothing more.
    pub fn addData(self: *NetworkResources, id: u64, bytes: []const u8) void {
        const r = self.by_id.getPtr(id) orelse return;
        if (r.evicted) return;
        if (r.content.items.len + bytes.len > self.max_resource) {
            self.evict(r);
            return;
        }
        if (!self.ensureFreeSpace(bytes.len) or r.evicted) return;
        r.content.appendSlice(self.allocator, bytes) catch {
            self.evict(r);
            return;
        };
        self.content_size += bytes.len;
    }

    pub fn finished(self: *NetworkResources, id: u64) void {
        if (self.by_id.getPtr(id)) |r| r.finished = true;
    }

    pub fn body(self: *const NetworkResources, id: u64) Body {
        const r = self.by_id.getPtr(id) orelse return .unknown;
        if (r.evicted) return .evicted;
        if (!r.has_response or (r.content.items.len == 0 and !r.finished)) return .none;
        return .{ .content = .{ .bytes = r.content.items, .resource = r } };
    }

    /// The request's body as sent; null for an unknown id (`known` false)
    /// or a request with none.
    pub fn postData(self: *const NetworkResources, id: u64, known: *bool) ?[]const u8 {
        const r = self.by_id.getPtr(id) orelse {
            known.* = false;
            return null;
        };
        known.* = true;
        return r.post_data;
    }

    /// A main-frame commit: every record goes but the committing
    /// navigation's (Blink's Clear(preserved loader id)).
    pub fn clearExcept(self: *NetworkResources, loader: u64) void {
        const allocator = self.allocator;
        var kept: usize = 0;
        for (self.order.items) |id| {
            const r = self.by_id.getPtr(id) orelse continue;
            if (r.loader == loader) {
                self.order.items[kept] = id;
                kept += 1;
                continue;
            }
            self.content_size -|= r.content.items.len;
            r.deinit(allocator);
            if (self.by_id.remove(id)) self.by_id_guard.noteRemoval(&self.by_id);
        }
        self.order.shrinkRetainingCapacity(kept);
    }

    fn evict(self: *NetworkResources, r: *Resource) void {
        self.content_size -|= r.content.items.len;
        r.content.clearAndFree(self.allocator);
        r.evicted = true;
    }

    /// Room for `size` more bytes: false when it can never fit; else the
    /// oldest records' content is evicted until it does.
    fn ensureFreeSpace(self: *NetworkResources, size: u64) bool {
        if (size > self.max_total) return false;
        var i: usize = 0;
        while (size > self.max_total -| self.content_size and i < self.order.items.len) : (i += 1) {
            const r = self.by_id.getPtr(self.order.items[i]) orelse continue;
            if (r.content.items.len > 0) self.evict(r);
        }
        return size <= self.max_total -| self.content_size;
    }
};

/// The body as getResponseBody reports it (Blink: InspectorPageAgent::
/// SharedBufferContent with CreateResourceTextDecoder): text for a textual
/// MIME type - decoded as UTF-8 when it is, else byte by byte as Latin-1
/// (the decoder's fallback) - base64 for any other (an image, a font, an
/// octet stream). OWNED by `allocator`.
pub fn reportedBody(allocator: Allocator, bytes: []const u8, mime_type: []const u8, charset: []const u8) Allocator.Error!struct { text: []u8, base64: bool } {
    if (isTextual(mime_type) or charset.len > 0) {
        if (std.unicode.utf8ValidateSlice(bytes)) return .{ .text = try allocator.dupe(u8, bytes), .base64 = false };
        return .{ .text = try latin1ToUtf8(allocator, bytes), .base64 = false };
    }
    return .{ .text = try base64(allocator, bytes), .base64 = true };
}

/// Post data as getRequestPostData reports it: UTF-8 text when it is, else
/// base64 (Blink's post body parser: "tries UTF-8 decoding first").
pub fn reportedPostData(allocator: Allocator, bytes: []const u8) Allocator.Error!struct { text: []u8, base64: bool } {
    if (std.unicode.utf8ValidateSlice(bytes)) return .{ .text = try allocator.dupe(u8, bytes), .base64 = false };
    return .{ .text = try base64(allocator, bytes), .base64 = true };
}

pub fn base64(allocator: Allocator, bytes: []const u8) Allocator.Error![]u8 {
    const encoder = std.base64.standard.Encoder;
    const out = try allocator.alloc(u8, encoder.calcSize(bytes.len));
    _ = encoder.encode(out, bytes);
    return out;
}

fn latin1ToUtf8(allocator: Allocator, bytes: []const u8) Allocator.Error![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    for (bytes) |b| {
        var buffer: [2]u8 = undefined;
        const n = std.unicode.utf8Encode(b, &buffer) catch unreachable;
        try out.appendSlice(allocator, buffer[0..n]);
    }
    return out.toOwnedSlice(allocator);
}

/// Blink's CreateResourceTextDecoder's textual types: XML, HTML, the
/// JavaScript MIME types and JSON, and text/* (DOMImplementation::
/// IsTextMIMEType).
pub fn isTextual(mime_type: []const u8) bool {
    var lower_buffer: [128]u8 = undefined;
    if (mime_type.len > lower_buffer.len) return false;
    const mime = std.ascii.lowerString(&lower_buffer, mime_type);
    if (std.mem.startsWith(u8, mime, "text/")) return true;
    if (std.mem.endsWith(u8, mime, "+json") or std.mem.endsWith(u8, mime, "+xml")) return true;
    const exact = [_][]const u8{
        "application/json",         "application/xml",          "application/xhtml+xml",
        "application/javascript",   "application/x-javascript", "application/ecmascript",
        "application/x-ecmascript", "image/svg+xml",            "application/manifest+json",
    };
    for (exact) |t| if (std.mem.eql(u8, mime, t)) return true;
    return false;
}

const testing = std.testing;

fn resourcesFor(allocator: Allocator, total: u64, one: u64) NetworkResources {
    return .{ .allocator = allocator, .max_total = total, .max_resource = one };
}

test "a body is kept as it arrives, and read back once its response came" {
    var res = resourcesFor(testing.allocator, 100, 50);
    defer res.deinit();
    try res.requestWillBeSent(1, 7, null);
    try testing.expect(res.body(1) == .none);
    try res.responseReceived(1, "text/plain", "");
    res.addData(1, "hel");
    res.addData(1, "lo");
    res.finished(1);
    try testing.expectEqualStrings("hello", res.body(1).content.bytes);
    try testing.expect(res.body(2) == .unknown);
}

test "past the per-resource limit a body is evicted; the oldest content makes room for a new one" {
    var res = resourcesFor(testing.allocator, 10, 6);
    defer res.deinit();
    try res.requestWillBeSent(1, 0, null);
    try res.requestWillBeSent(2, 0, null);
    try res.requestWillBeSent(3, 0, null);
    for ([_]u64{ 1, 2, 3 }) |id| try res.responseReceived(id, "text/plain", "");
    res.addData(1, "12345");
    res.addData(1, "67"); // 7 > 6: evicted
    try testing.expect(res.body(1) == .evicted);
    res.addData(2, "abcde");
    res.addData(3, "vwxyz"); // 10 total: fits
    res.finished(2);
    res.finished(3);
    try testing.expectEqualStrings("abcde", res.body(2).content.bytes);
    // One more byte for 3 evicts the oldest content (2's).
    try res.requestWillBeSent(4, 0, null);
    try res.responseReceived(4, "text/plain", "");
    res.addData(4, "!");
    try testing.expect(res.body(2) == .evicted);
    try testing.expectEqualStrings("vwxyz", res.body(3).content.bytes);
}

test "a main-frame commit keeps only the committing navigation's records" {
    var res = resourcesFor(testing.allocator, 100, 100);
    defer res.deinit();
    try res.requestWillBeSent(1, 5, "a=1");
    try res.requestWillBeSent(2, 9, null);
    res.clearExcept(9);
    var known = false;
    try testing.expect(res.postData(1, &known) == null);
    try testing.expect(!known);
    _ = res.postData(2, &known);
    try testing.expect(known);
}

test "reportedBody: text for textual types, base64 for the rest; Latin-1 when not UTF-8" {
    const text = try reportedBody(testing.allocator, "{\"a\":1}", "application/json", "");
    defer testing.allocator.free(text.text);
    try testing.expect(!text.base64);
    const image = try reportedBody(testing.allocator, "\x89PNG", "image/png", "");
    defer testing.allocator.free(image.text);
    try testing.expect(image.base64);
    try testing.expectEqualStrings("iVBORw==", image.text);
    const latin = try reportedBody(testing.allocator, "caf\xe9", "text/plain", "iso-8859-1");
    defer testing.allocator.free(latin.text);
    try testing.expectEqualStrings("caf\u{e9}", latin.text);
    const post = try reportedPostData(testing.allocator, "\xff\x00");
    defer testing.allocator.free(post.text);
    try testing.expect(post.base64);
}
