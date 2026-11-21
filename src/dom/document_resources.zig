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
    /// HTML 13.2.8: the document's list of speculative fetch URLs, OWNED -
    /// each URL is fetched speculatively once.
    speculative_urls: std.ArrayListUnmanaged([]u8) = .empty,

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
        for (self.speculative_urls.items) |url| self.allocator.free(url);
        self.speculative_urls.clearRetainingCapacity();
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
        self.speculative_urls.deinit(self.allocator);
    }

    /// The document has finished parsing: a speculative fetch's entry no
    /// element consumed leaves the preload map ("the parser should have
    /// picked up all preloads by now": Blink Document::FinishedParsing ->
    /// ResourceFetcher::ClearPreloads(kClearSpeculativeMarkupPreloads), which
    /// keeps link preloads). A fetch still filling one keeps it.
    pub fn dropSpeculative(self: *DocumentResources) void {
        var i: usize = 0;
        while (i < self.preloads.items.len) {
            if (!self.preloads.items[i].entry.speculative) {
                i += 1;
                continue;
            }
            var item = self.preloads.orderedRemove(i);
            item.deinit(self.allocator);
        }
    }

    /// HTML 13.2.8 "speculative fetch": whether `request`, the speculative
    /// HTML parser's for `url`, is to be fetched - "if url is already in
    /// document's list of speculative fetch URLs, then do nothing", else it
    /// joins the list - and the document has nothing of its key yet: a
    /// preload, or a resource it loaded or is loading, would answer the
    /// element's fetch already (Blink: a speculative preload of a resource the
    /// document has is a memory-cache hit, ResourceFetcher kUse).
    ///
    /// A render-blocking speculative request that meets the document's
    /// preload of its key still in flight makes that preload's Resource
    /// Timing entry "blocking" (Chrome, the only engine that reports
    /// renderBlockingStatus: ResourceFetcher::MatchPreload returns a preload
    /// to a speculative request without consuming it, and RequestResource
    /// then runs MakePreloadedResourceBlockIfNeeded -
    /// render-blocking-status-link.html's
    /// "link-script-preload-used-immediately": the scanner's parser-blocking
    /// script meets the link preload its own scan just started).
    pub fn beginSpeculativeFetch(self: *DocumentResources, url: []const u8, request: *const InternalRequest) bool {
        if (find(self.preloads.items, request)) |index| {
            const entry = self.preloads.items[index].entry;
            if (request.render_blocking and entry.state == .pending) entry.upgrade_render_blocking = true;
        }
        for (self.speculative_urls.items) |seen| if (std.mem.eql(u8, seen, url)) return false;
        const copy = self.allocator.dupe(u8, url) catch return false;
        self.speculative_urls.append(self.allocator, copy) catch {
            self.allocator.free(copy);
            return false;
        };
        return find(self.preloads.items, request) == null and find(self.loaded.items, request) == null;
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
            // A link preload element whose request matches a speculative
            // fetch's entry - the speculative parser fetched this very preload
            // ahead of the element - takes it over as its own preload: it stays
            // in the map, no longer speculative, for its consumer (Blink: the
            // scanner's request for a rel=preload link is the link preload,
            // SetLinkPreload(true), which the element's own request reuses).
            if (item.entry.speculative and request.link_preload and
                (request.integrity_metadata.len == 0 or std.mem.eql(u8, request.integrity_metadata, item.integrity)))
            {
                item.entry.speculative = false;
                return item.entry.retain();
            }
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
        if (request.link_preload or request.speculative_preload) {
            const entry = Entry.create(self.allocator, true) catch return null;
            entry.speculative = request.speculative_preload;
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
        if (!kept(request) or load_complete) return null;
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

/// Whether the document keeps `request`'s response for a later fetch of the
/// same key while it loads - golden rule 2, the types all three browsers
/// reuse within a loading document, each checked:
///
/// - style sheets (a link's, an @import's): Chrome (resource_fetcher.cc:
///   DetermineRevalidationPolicyInternal, kUse for the document's
///   cached_resources_map_ while !IsLoadComplete), Firefox
///   (layout/style/Loader.cpp: MaybeCoalesceLoadAndNotifyOpen) and Safari
///   (CachedResourceLoader's memory cache) - kept here;
/// - fonts: Chrome's memory cache, Firefox's gfxUserFontSet::UserFontCache::
///   GetFont, Safari's CachedFont - Crane's font loads already share one
///   load per key (dom.style.font_loading's ResourceCache);
/// - images: all three - Crane's list of available images
///   (dom.style.available_images, the img element's);
/// - scripts: Chrome and Safari only. Firefox's release fetches a script
///   again (dom/script/SharedScriptCache.cpp serves a document only behind
///   dom.script_loader.experimental.navigation_cache, @IS_NIGHTLY_BUILD@ in
///   modules/libpref/init/StaticPrefList.yaml), so a script is not kept
///   unless a preload brought it (`consume` keeps a consumed preload's
///   response whatever its type).
fn kept(request: *const InternalRequest) bool {
    return request.destination == .style;
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

/// `document`'s resources, or null when it has kept none (they are rare
/// data: dom.document_rare_data).
pub fn of(document: *runtime.Instance) ?*DocumentResources {
    const state = @import("document_state.zig").Registry.get(document) orelse return null;
    const rare = state.rareData() orelse return null;
    return rare.resources;
}

/// `document`'s resources, made on first use.
pub fn ensure(document: *runtime.Instance) ?*DocumentResources {
    const state = @import("document_state.zig").Registry.get(document) orelse return null;
    const rare = state.ensureRareData(document) catch return null;
    if (rare.resources) |resources| return resources;
    const resources = state.allocator.create(DocumentResources) catch return null;
    resources.* = .init(state.allocator);
    rare.resources = resources;
    return resources;
}

fn consumeThrough(context: *anyopaque, request: *const InternalRequest) ?*Entry {
    const document: *runtime.Instance = @ptrCast(@alignCast(context));
    const self = of(document) orelse return null;
    return self.consume(request, @import("document_lifecycle.zig").isCompletelyLoaded(document));
}

fn registerThrough(context: *anyopaque, request: *const InternalRequest) ?*Entry {
    const document: *runtime.Instance = @ptrCast(@alignCast(context));
    const load_complete = @import("document_lifecycle.zig").isCompletelyLoaded(document);
    // Nothing to keep: no map is made for it.
    if (!request.link_preload and !request.speculative_preload and (!kept(request) or load_complete)) return null;
    const self = ensure(document) orelse return null;
    return self.register(request, load_complete);
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

test "a speculative fetch's entry is consumed by the element's fetch like a preload, and the end of parsing drops one no element consumed" {
    var resources = DocumentResources.init(testing.allocator);
    defer resources.deinit();
    const speculative = try testRequest("https://a.test/i.png", .image);
    defer speculative.deinit();
    speculative.speculative_preload = true;
    const filled = resources.register(speculative, false).?;
    defer filled.release();
    try testing.expect(filled.speculative);
    try testing.expectEqual(@as(usize, 1), resources.preloads.items.len);

    // The img's own fetch consumes it, and the loaded map keeps it.
    const img = try testRequest("https://a.test/i.png", .image);
    defer img.deinit();
    const served = resources.consume(img, false).?;
    defer served.release();
    try testing.expect(served == filled);
    try testing.expectEqual(@as(usize, 0), resources.preloads.items.len);

    // Another, never consumed, goes when the document finishes parsing; a link
    // preload's stays.
    const unused = try testRequest("https://a.test/u.js", .script);
    defer unused.deinit();
    unused.speculative_preload = true;
    resources.register(unused, false).?.release();
    const preload = try testRequest("https://a.test/p.css", .style);
    defer preload.deinit();
    preload.link_preload = true;
    resources.register(preload, false).?.release();
    resources.dropSpeculative();
    try testing.expectEqual(@as(usize, 1), resources.preloads.items.len);
    try testing.expect(!resources.preloads.items[0].entry.speculative);
}

test "a link preload element whose request matches a speculative fetch's entry takes it over as its own preload" {
    var resources = DocumentResources.init(testing.allocator);
    defer resources.deinit();
    const speculative = try testRequest("https://a.test/s.css", .style);
    defer speculative.deinit();
    speculative.speculative_preload = true;
    const filled = resources.register(speculative, false).?;
    defer filled.release();
    const element = try testRequest("https://a.test/s.css", .style);
    defer element.deinit();
    element.link_preload = true;
    const taken = resources.consume(element, false).?;
    defer taken.release();
    try testing.expect(taken == filled);
    // Still in the map, for the preload's consumer; no longer speculative, so
    // the end of parsing keeps it.
    try testing.expect(!filled.speculative);
    resources.dropSpeculative();
    try testing.expectEqual(@as(usize, 1), resources.preloads.items.len);
    const sheet = try testRequest("https://a.test/s.css", .style);
    defer sheet.deinit();
    const consumed = resources.consume(sheet, false).?;
    defer consumed.release();
    try testing.expect(consumed == filled);
    try testing.expectEqual(@as(usize, 0), resources.preloads.items.len);
}

test "the list of speculative fetch URLs lets a URL be fetched speculatively once, and never a key the document already has" {
    var resources = DocumentResources.init(testing.allocator);
    defer resources.deinit();
    const first = try testRequest("https://a.test/a.js", .script);
    defer first.deinit();
    try testing.expect(resources.beginSpeculativeFetch("https://a.test/a.js", first));
    try testing.expect(!resources.beginSpeculativeFetch("https://a.test/a.js", first));
    // A style sheet the document is loading answers the element already.
    const sheet = try testRequest("https://a.test/x.css", .style);
    defer sheet.deinit();
    resources.register(sheet, false).?.release();
    try testing.expect(!resources.beginSpeculativeFetch("https://a.test/x.css", sheet));
    // A render-blocking speculative request meeting a preload of its key in
    // flight makes it blocking, and fetches nothing itself.
    const preload = try testRequest("https://a.test/p.js", .script);
    defer preload.deinit();
    preload.speculative_preload = true;
    const entry = resources.register(preload, false).?;
    defer entry.release();
    try testing.expect(!resources.beginSpeculativeFetch("https://a.test/p.js", preload));
    try testing.expect(!entry.upgrade_render_blocking);
    const blocking = try testRequest("https://a.test/p.js", .script);
    defer blocking.deinit();
    blocking.render_blocking = true;
    try testing.expect(!resources.beginSpeculativeFetch("https://a.test/p.js", blocking));
    try testing.expect(entry.upgrade_render_blocking);
}
