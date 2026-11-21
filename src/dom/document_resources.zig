//! A Document's map of preloaded resources (HTML 4.6.8.20) and the
//! resources it loaded while loading - the document's half of
//! fetch.internal.document_resources, whose module comment says what each
//! is and which browsers do the second. Fetch step 11 reaches it through the
//! route a Window client's requests carry (`routeFor`, set by
//! dom.global_settings.requestClient), at the fetch's start.
//!
//! Spec: https://html.spec.whatwg.org/multipage/links.html#map-of-preloaded-resources
//! Spec: https://html.spec.whatwg.org/multipage/links.html#consume-a-preloaded-resource

const std = @import("std");
const runtime = @import("runtime");
const fetch = @import("fetch");
const fetch_resources = fetch.internal.document_resources;
const Entry = fetch_resources.Entry;
const InternalRequest = fetch.internal.InternalRequest;

/// One document's resources. Its entries are shared with the fetches that
/// fill them or wait on them; the document holds one reference to each.
pub const DocumentResources = struct {
    allocator: std.mem.Allocator,
    /// HTML's map of preloaded resources: preload key -> preload entry, an
    /// ordered map.
    preloads: std.ArrayListUnmanaged(Item) = .empty,
    /// The subresources the document loaded (or is loading) while it loads,
    /// for a later fetch of the same key to reuse - a consumed preload's
    /// among them, as Chrome keeps the preload's resource in the document's
    /// cached_resources_map_.
    loaded: std.ArrayListUnmanaged(Item) = .empty,

    pub fn init(allocator: std.mem.Allocator) DocumentResources {
        return .{ .allocator = allocator };
    }

    /// The document is destroyed (or freed): its maps go. A fetch still
    /// filling or waiting on an entry keeps it.
    pub fn clear(self: *DocumentResources) void {
        for (self.preloads.items) |*item| item.deinit(self.allocator);
        self.preloads.clearRetainingCapacity();
        for (self.loaded.items) |*item| item.deinit(self.allocator);
        self.loaded.clearRetainingCapacity();
    }

    /// The document has completely loaded: a loaded resource that is in
    /// serves no later fetch (`consume`), so it goes now; one still being
    /// fetched may still serve one (Chrome's IsLoading()). The preload map
    /// is HTML's, kept until a preload is consumed or the document goes.
    pub fn pruneLoaded(self: *DocumentResources) void {
        var i: usize = 0;
        while (i < self.loaded.items.len) {
            if (self.loaded.items[i].entry.state == .pending) {
                i += 1;
                continue;
            }
            var item = self.loaded.orderedRemove(i);
            item.deinit(self.allocator);
        }
    }

    pub fn deinit(self: *DocumentResources) void {
        self.clear();
        self.preloads.deinit(self.allocator);
        self.loaded.deinit(self.allocator);
    }

    /// HTML "consume a preloaded resource" for `request` - Fetch step 11 -
    /// then the document's reuse of what it loaded; `load_complete`: the
    /// document has completely loaded, after which a fetch reuses only a
    /// resource still being fetched (Chrome's DetermineRevalidationPolicy-
    /// Internal: !IsLoadComplete(), or IsLoading()). Retained for the caller.
    pub fn consume(self: *DocumentResources, request: *const InternalRequest, load_complete: bool) ?*Entry {
        // 1-4. The preload with request's preload key.
        if (find(self.preloads.items, request)) |index| {
            const item = self.preloads.items[index];
            // 5-7. Its integrity metadata: the consumer's must be none, or
            // the same ("This comparison would ignore unknown integrity
            // options", issue #116: a string comparison here); otherwise the
            // preload is not consumed and the request is fetched.
            if (request.integrity_metadata.len == 0 or std.mem.eql(u8, request.integrity_metadata, item.integrity)) {
                // 8. Remove preloads[key].
                _ = self.preloads.orderedRemove(index);
                const entry = item.entry;
                // Chrome (the only engine that reports renderBlockingStatus):
                // a render-blocking consumer of a preload still in flight
                // makes its entry "blocking".
                if (request.render_blocking and entry.state == .pending) entry.upgrade_render_blocking = true;
                // The consumed preload's resource is the document's now: a
                // later same request reuses it while the document loads.
                self.keepLoaded(item) catch {
                    // Kept by this caller alone.
                    const taken = entry.retain();
                    var gone = item;
                    gone.deinit(self.allocator);
                    return taken;
                };
                // 9-10. Its response now, or once it arrives.
                return entry.retain();
            }
        }
        // The document's reuse of a subresource it loaded.
        if (!reusable(request)) return null;
        const index = find(self.loaded.items, request) orelse return null;
        const item = self.loaded.items[index];
        if (!item.entry.reusable()) return null;
        // While the document loads - or the resource is still on its way.
        if (load_complete and item.entry.state != .pending) {
            self.pruneLoaded();
            return null;
        }
        if (request.integrity_metadata.len != 0 and !std.mem.eql(u8, request.integrity_metadata, item.integrity)) return null;
        return item.entry.retain();
    }

    /// A new entry the document keeps for `request`'s response: HTML
    /// "preload" steps 6-7 and 12's commit, "set document's map of preloaded
    /// resources[key] to entry", for a preload; while the document loads, a
    /// loaded resource's for its other subresources. Retained for the
    /// caller, who fulfils it.
    pub fn register(self: *DocumentResources, request: *const InternalRequest, load_complete: bool) ?*Entry {
        if (request.link_preload) {
            const entry = Entry.create(self.allocator, true) catch return null;
            const item = Item.make(self.allocator, request, entry) catch {
                entry.release();
                return null;
            };
            self.preloads.append(self.allocator, item) catch {
                var gone = item;
                gone.deinit(self.allocator);
                return null;
            };
            return entry.retain();
        }
        if (!reusable(request) or load_complete) return null;
        // One entry per key: a later fetch reused the first one's.
        if (find(self.loaded.items, request) != null) return null;
        const entry = Entry.create(self.allocator, false) catch return null;
        const item = Item.make(self.allocator, request, entry) catch {
            entry.release();
            return null;
        };
        self.keepLoaded(item) catch {
            var gone = item;
            gone.deinit(self.allocator);
            return null;
        };
        return entry.retain();
    }

    /// Keep `item` (taken) in the loaded map, replacing an older item of its
    /// key.
    fn keepLoaded(self: *DocumentResources, item: Item) !void {
        if (find(self.loaded.items, &item.keyRequest())) |index| {
            var old = self.loaded.items[index];
            self.loaded.items[index] = item;
            old.deinit(self.allocator);
            return;
        }
        try self.loaded.append(self.allocator, item);
    }
};

/// Whether `request` may reuse a resource of its document: one of an
/// element's or a style sheet's - not a fetch() or an XMLHttpRequest, whose
/// requests are always made (Chrome exempts its "raw" resources) - and not a
/// navigation's.
fn reusable(request: *const InternalRequest) bool {
    return switch (request.destination) {
        .empty, .document, .iframe, .frame, .embed, .object, .report, .worker, .sharedworker, .serviceworker => false,
        else => true,
    };
}

/// A key and its entry. The key's strings are OWNED.
const Item = struct {
    url: []u8,
    destination: fetch.internal.Destination,
    mode: fetch.internal.request.RequestMode,
    credentials_mode: fetch.internal.CredentialsMode,
    /// The integrity metadata the resource was fetched with (a preload
    /// entry's "integrity metadata").
    integrity: []u8,
    entry: *Entry,

    /// HTML "create a preload key" for `request`, with `entry` (taken).
    fn make(allocator: std.mem.Allocator, request: *const InternalRequest, entry: *Entry) !Item {
        const url = try allocator.dupe(u8, request.currentUrl());
        errdefer allocator.free(url);
        const integrity = try allocator.dupe(u8, request.integrity_metadata);
        return .{ .url = url, .destination = request.destination, .mode = request.mode, .credentials_mode = request.credentials_mode, .integrity = integrity, .entry = entry };
    }

    fn deinit(self: *Item, allocator: std.mem.Allocator) void {
        allocator.free(self.url);
        allocator.free(self.integrity);
        self.entry.release();
    }

    /// A preload key's itemwise equality with `request`'s.
    fn matches(self: *const Item, url: []const u8, destination: fetch.internal.Destination, mode: fetch.internal.request.RequestMode, credentials_mode: fetch.internal.CredentialsMode) bool {
        return self.destination == destination and self.mode == mode and self.credentials_mode == credentials_mode and std.mem.eql(u8, self.url, url);
    }

    fn keyRequest(self: *const Item) KeyOf {
        return .{ .url = self.url, .destination = self.destination, .mode = self.mode, .credentials_mode = self.credentials_mode };
    }
};

/// A key on its own, for a lookup by an item's key.
const KeyOf = struct {
    url: []const u8,
    destination: fetch.internal.Destination,
    mode: fetch.internal.request.RequestMode,
    credentials_mode: fetch.internal.CredentialsMode,
};

fn find(items: []const Item, key: anytype) ?usize {
    const K = @TypeOf(key);
    const url: []const u8 = if (K == *const KeyOf) key.url else key.currentUrl();
    for (items, 0..) |*item, i| {
        if (item.matches(url, key.destination, key.mode, key.credentials_mode)) return i;
    }
    return null;
}

/// The route a Window client's requests carry to `document`, its
/// associated Document: asked only at a fetch's start, while the document
/// is the window's (fetch.internal.document_resources.Route).
pub fn routeFor(document: *runtime.Instance) fetch.internal.request.DocumentResourcesRoute {
    return .{ .context = document, .consume = consumeThrough, .register = registerThrough };
}

fn resourcesOf(document: *runtime.Instance) ?*DocumentResources {
    const state = @import("document_state.zig").Registry.get(document) orelse return null;
    return &state.resources;
}

fn consumeThrough(context: *anyopaque, request: *const InternalRequest) ?*Entry {
    const document: *runtime.Instance = @ptrCast(@alignCast(context));
    const self = resourcesOf(document) orelse return null;
    return self.consume(request, @import("document_lifecycle.zig").isCompletelyLoaded(document));
}

fn registerThrough(context: *anyopaque, request: *const InternalRequest) ?*Entry {
    const document: *runtime.Instance = @ptrCast(@alignCast(context));
    const self = resourcesOf(document) orelse return null;
    return self.register(request, @import("document_lifecycle.zig").isCompletelyLoaded(document));
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn testRequest(url: []const u8, destination: fetch.internal.Destination) !*InternalRequest {
    const request = try InternalRequest.init(testing.allocator, url);
    request.destination = destination;
    request.mode = .no_cors;
    request.credentials_mode = .include;
    return request;
}

test "a preload is consumed once by a request of its key, and its response then serves a reuse while the document loads" {
    var resources = DocumentResources.init(testing.allocator);
    defer resources.deinit();
    const preload = try testRequest("https://a.test/s.css", .style);
    defer preload.deinit();
    preload.link_preload = true;
    const filled = resources.register(preload, false).?;
    defer filled.release();

    const sheet = try testRequest("https://a.test/s.css", .style);
    defer sheet.deinit();
    sheet.render_blocking = true;
    const first = resources.consume(sheet, false).?;
    defer first.release();
    try testing.expect(first == filled);
    // In flight when a render-blocking request consumed it.
    try testing.expect(filled.upgrade_render_blocking);
    try testing.expectEqual(@as(usize, 0), resources.preloads.items.len);

    // A second preload of the key - after the first was consumed - reuses
    // the document's resource.
    const again = try testRequest("https://a.test/s.css", .style);
    defer again.deinit();
    again.link_preload = true;
    const reused = resources.consume(again, false).?;
    defer reused.release();
    try testing.expect(reused == filled);

    // Another destination, mode or URL is another resource.
    const script = try testRequest("https://a.test/s.css", .script);
    defer script.deinit();
    try testing.expect(resources.consume(script, false) == null);

    // Once the document has loaded, a resource that is in is fetched again.
    const response = try fetch.internal.InternalResponse.init(testing.allocator);
    filled.fulfill(response);
    try testing.expect(resources.consume(sheet, true) == null);
}

test "a loading document reuses a subresource of the same key; fetch() and a mismatched integrity never do" {
    var resources = DocumentResources.init(testing.allocator);
    defer resources.deinit();
    const sheet = try testRequest("https://a.test/x.css", .style);
    defer sheet.deinit();
    try testing.expect(resources.consume(sheet, false) == null);
    const entry = resources.register(sheet, false).?;
    defer entry.release();
    // One entry per key.
    try testing.expect(resources.register(sheet, false) == null);
    const again = resources.consume(sheet, false).?;
    defer again.release();
    try testing.expect(again == entry);

    const raw = try testRequest("https://a.test/x.css", .empty);
    defer raw.deinit();
    try testing.expect(resources.consume(raw, false) == null);
    try testing.expect(resources.register(raw, false) == null);

    const checked = try testRequest("https://a.test/x.css", .style);
    defer checked.deinit();
    try checked.setIntegrityMetadata("sha256-abc");
    try testing.expect(resources.consume(checked, false) == null);
}

test "a preload whose integrity metadata differs from the consumer's is not consumed" {
    var resources = DocumentResources.init(testing.allocator);
    defer resources.deinit();
    const preload = try testRequest("https://a.test/p.js", .script);
    defer preload.deinit();
    preload.link_preload = true;
    try preload.setIntegrityMetadata("sha256-one");
    const entry = resources.register(preload, false).?;
    defer entry.release();
    const consumer = try testRequest("https://a.test/p.js", .script);
    defer consumer.deinit();
    try consumer.setIntegrityMetadata("sha256-two");
    try testing.expect(resources.consume(consumer, false) == null);
    try testing.expectEqual(@as(usize, 1), resources.preloads.items.len);
}

test "a completely loaded document lets go of the loaded resources that are in, keeping one still being fetched and its preloads" {
    var resources = DocumentResources.init(testing.allocator);
    defer resources.deinit();
    const done_request = try testRequest("https://a.test/done.css", .style);
    defer done_request.deinit();
    const done = resources.register(done_request, false).?;
    done.fulfill(try fetch.internal.InternalResponse.init(testing.allocator));
    done.release();
    const pending_request = try testRequest("https://a.test/pending.css", .style);
    defer pending_request.deinit();
    const pending = resources.register(pending_request, false).?;
    defer pending.release();
    const preload = try testRequest("https://a.test/later.js", .script);
    defer preload.deinit();
    preload.link_preload = true;
    resources.register(preload, false).?.release();

    resources.pruneLoaded();
    try testing.expectEqual(@as(usize, 1), resources.loaded.items.len);
    try testing.expectEqual(@as(usize, 1), resources.preloads.items.len);
    // The pending one still serves a fetch.
    const reused = resources.consume(pending_request, true).?;
    reused.release();
}
