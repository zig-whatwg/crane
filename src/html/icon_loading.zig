//! HTML §4.6.8.9 link type `"icon"` selection and default `/favicon.ico` fetching.
//!
//! Spec: https://html.spec.whatwg.org/multipage/links.html#rel-icon
//! Spec: https://html.spec.whatwg.org/multipage/semantics.html#fetching-and-processing-a-resource-from-a-link-element
//!
//! Browser consensus (Golden Rule 2; 3-browser probe on chat.local 2026-11-25
//! against Chrome 157.0.8103.78, Firefox 159.0.1, Safari 27.2):
//! - Top-level documents only: iframes, `<iframe srcdoc>`, `about:blank`,
//!   `data:`, `blob:`, and `file:` never fetch icons (Blink
//!   `LocalFrame::UpdateFaviconURL`, WebKit `DocumentLoader::startIconLoading`,
//!   Gecko `LinkHandlerChild`).
//! - Timing: icon selection and fetching run after the document's `load` event
//!   and `pageshow` (`Document` `completeLoading`), never delaying `load` and
//!   never firing `load`/`error` events on `<link>`.
//! - Selection (HTML §4.6.8.9): `<link rel="icon">` candidates in document tree
//!   order are filtered by `media` and supported `type` (`image/*` when present),
//!   ranked by `sizes` (scalable `"any"` / `image/svg+xml` > closest bitmap size
//!   > unspecified), with equal candidates broken by last in tree order. When a
//!   candidate fails (network error or non-ok HTTP status), the next candidate is
//!   tried.
//! - Dynamic updates after load (Chrome + Firefox 2/3 majority): inserting,
//!   modifying, or removing a `<link rel="icon">` after `completely_loaded`
//!   coalesces a task to re-select and fetch if the winning candidate changed.
//!   Removing a `<link rel="icon">` never re-triggers default `/favicon.ico`.
//! - Default `/favicon.ico`: when a top-level HTTP(S) document finishes loading
//!   with no `<link rel="icon">` defining a link, resolve `"/favicon.ico"`
//!   against the document's URL (not its base URL) and fetch with
//!   `destination = "image"`, `mode = "no-cors"`, `credentials_mode = "include"`,
//!   `use_url_credentials = true`, `initiator_type = null` (HTML §4.6.8.9 +
//!   Fetch §2.2.5: no `PerformanceResourceTiming` entry), and silent CSP
//!   pre-check without violation reporting (Blink `Document::DefaultFaviconAllowedByCSP`,
//!   crbug.com/820846).
//! - CDP Network visibility (Chrome 157): both `<link rel="icon">` and default
//!   `/favicon.ico` carry `is_favicon = true` so `fetch_observer` emits
//!   `type: "Other"` and `initiator.type: "other"` after `Page.loadEventFired`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const engine = @import("engine");
const fetch = @import("fetch");
const css = @import("css");
const dom = @import("dom");

const link_types = @import("link_types.zig");
const style_sheet_loading = @import("style_sheet_loading.zig");
const AsyncFetch = fetch.algorithms.AsyncFetch;
const CorsSetting = style_sheet_loading.CorsSetting;
const ReferrerPolicy = fetch.internal.ReferrerPolicy;

const log = std.log.scoped(.icon_loading);

const max_parsed_sizes = 16;

/// One parsed bitmap size from a `<link rel="icon" sizes="...">` attribute.
pub const IconSize = struct {
    width: u32,
    height: u32,
};

/// Result of parsing HTML §4.6.8.9 `sizes` attribute keywords.
pub const ParsedSizes = struct {
    any: bool = false,
    sizes: [max_parsed_sizes]IconSize = undefined,
    len: usize = 0,

    pub fn slice(self: *const ParsedSizes) []const IconSize {
        return self.sizes[0..self.len];
    }
};

/// HTML §4.6.8.9 `sizes` attribute parsing (steps 1-7).
pub fn parseSizes(value: ?[]const u8) ParsedSizes {
    var result: ParsedSizes = .{};
    const raw = value orelse return result;
    // "split the attribute's value on ASCII whitespace"
    var tokens = std.mem.tokenizeAny(u8, raw, " \t\n\x0C\r");
    while (tokens.next()) |token| {
        if (std.ascii.eqlIgnoreCase(token, "any")) {
            result.any = true;
            continue;
        }
        // Step 1: Must contain exactly one U+0078 'x' or U+0058 'X'.
        var x_pos: ?usize = null;
        var multiple_x = false;
        for (token, 0..) |c, idx| {
            if (c == 'x' or c == 'X') {
                if (x_pos != null) {
                    multiple_x = true;
                    break;
                }
                x_pos = idx;
            }
        }
        if (multiple_x) continue;
        const sep = x_pos orelse continue;

        // Steps 2-3: width string and height string.
        const width_str = token[0..sep];
        const height_str = token[sep + 1 ..];

        // Step 4: Neither may be empty, start with '0', or contain non-ASCII-digits.
        if (!validPositiveDigits(width_str) or !validPositiveDigits(height_str)) continue;

        // Steps 5-6: Rules for parsing non-negative integers (clamped to u32).
        const width = parseNonNegativeU32(width_str);
        const height = parseNonNegativeU32(height_str);

        // Step 7: Record (width, height).
        if (result.len < max_parsed_sizes) {
            result.sizes[result.len] = .{ .width = width, .height = height };
            result.len += 1;
        }
    }
    return result;
}

fn validPositiveDigits(s: []const u8) bool {
    if (s.len == 0 or s[0] == '0') return false;
    for (s) |c| {
        if (!std.ascii.isDigit(c)) return false;
    }
    return true;
}

fn parseNonNegativeU32(s: []const u8) u32 {
    var acc: u32 = 0;
    for (s) |c| {
        const digit: u32 = c - '0';
        const mul = @mulWithOverflow(acc, 10);
        if (mul[1] != 0) return std.math.maxInt(u32);
        const add = @addWithOverflow(mul[0], digit);
        if (add[1] != 0) return std.math.maxInt(u32);
        acc = add[0];
    }
    return acc;
}

fn isSvgMimeType(type_attr: ?[]const u8) bool {
    const value = type_attr orelse return false;
    const essence = std.mem.trim(u8, value[0 .. std.mem.indexOfScalar(u8, value, ';') orelse value.len], " \t\n\x0C\r");
    return std.ascii.eqlIgnoreCase(essence, "image/svg+xml");
}

/// Rank a `<link rel="icon">` candidate according to HTML §4.6.8.9 (`type` and
/// `sizes`), given `desired_size` in raw device pixels. Higher score wins;
/// equal scores tie-break by last declared in tree order.
pub fn candidateScore(type_attr: ?[]const u8, sizes_attr: ?[]const u8, desired_size: u32) i64 {
    const parsed = parseSizes(sizes_attr);
    // Scalable icons (`sizes="any"` or `type="image/svg+xml"`) fit any size.
    if (parsed.any or isSvgMimeType(type_attr)) return 1_000_000;

    if (parsed.len > 0) {
        const target: i64 = @max(@as(i64, desired_size), 16);
        var best: i64 = std.math.minInt(i64);
        for (parsed.slice()) |sz| {
            const w: i64 = sz.width;
            const h: i64 = sz.height;
            const min_dim = @min(w, h);
            const max_dim = @max(w, h);
            // Prefer square icons over non-square; prefer >= target (downscaling)
            // over < target (upscaling); prefer closer to target.
            const square_bonus: i64 = if (w == h) 20_000 else 0;
            const fit_score: i64 = if (min_dim >= target)
                700_000 - @min(max_dim - target, 200_000)
            else
                400_000 - @min((target - min_dim) * 4, 200_000);
            const score = fit_score + square_bonus;
            if (score > best) best = score;
        }
        return best;
    }

    // Unspecified sizes (e.g. multi-resolution .ico or unsized png).
    return 50_000;
}

const Candidate = struct {
    url: []u8,
    cors: CorsSetting = .no_cors,
    referrer_policy: ReferrerPolicy = .empty,
    nonce: []u8,
    integrity: []u8,
    fetch_priority: fetch.internal.request.Priority = .auto,
    score: i64 = 0,
    tree_index: usize = 0,
    is_default_favicon: bool = false,

    fn deinit(self: *Candidate, allocator: std.mem.Allocator) void {
        allocator.free(self.url);
        allocator.free(self.nonce);
        allocator.free(self.integrity);
    }

    fn lessThan(_: void, a: Candidate, b: Candidate) bool {
        if (a.score != b.score) return a.score > b.score;
        // HTML §4.6.8.9: "If there are multiple equally appropriate icons,
        // user agents must use the last one declared in tree order".
        return a.tree_index > b.tree_index;
    }
};

const IconLoad = struct {
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
    document_generation: u64,
    realm: runtime.Context,
    candidates: std.ArrayListUnmanaged(Candidate) = .empty,
    next_candidate: usize = 0,
    active_fetch: ?*AsyncFetch = null,
    update_queued: bool = false,
    document_abort_pending: bool = false,
    destroying: bool = false,

    fn documentIsLive(self: *const IconLoad) bool {
        return dom.refcount.weakLinkLive(self.document, self.document_generation);
    }

    fn client(self: *IconLoad) AsyncFetch.Client {
        return .{ .context = self, .done = fetchDone, .alive = fetchAlive, .gone = fetchGone };
    }

    fn clearCandidates(self: *IconLoad) void {
        for (self.candidates.items) |*c| c.deinit(self.allocator);
        self.candidates.clearRetainingCapacity();
        self.next_candidate = 0;
    }

    fn terminateActiveFetch(self: *IconLoad) void {
        if (self.active_fetch) |f| {
            self.active_fetch = null;
            f.terminate();
        }
    }

    fn releaseIfIdle(self: *IconLoad) void {
        if (self.active_fetch == null and !self.update_queued) {
            self.destroy();
        }
    }

    fn destroy(self: *IconLoad) void {
        if (self.destroying) return;
        self.destroying = true;
        self.realm.forgetObject(.icon_loads, self);
        self.terminateActiveFetch();
        self.clearCandidates();
        self.candidates.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

fn loadsIn(realm: runtime.Context) []const *IconLoad {
    return @ptrCast(realm.objects(.icon_loads).items);
}

fn findForDocument(document: *runtime.Instance) ?*IconLoad {
    const gen = runtime.SlabAllocator.generationOf(document);
    for (loadsIn(document.ctx)) |load| {
        if (load.document == document and load.document_generation == gen) return load;
    }
    return null;
}

fn getOrCreateLoad(document: *runtime.Instance) ?*IconLoad {
    if (findForDocument(document)) |existing| return existing;
    const allocator = document.ctx.allocator;
    const load = allocator.create(IconLoad) catch return null;
    load.* = .{
        .allocator = allocator,
        .document = document,
        .document_generation = runtime.SlabAllocator.generationOf(document),
        .realm = document.ctx,
    };
    document.ctx.addObject(.icon_loads, load) catch {
        allocator.destroy(load);
        return null;
    };
    return load;
}

/// Install the document-abort and realm-discard hooks once at process start
/// (called from `HTMLLinkElement.installHooks`).
pub fn installDocumentAbort() void {
    dom.document_fetches.install(.{
        .discard = discardRealm,
        .prepare_abort = prepareDocumentAbort,
        .abort = abortDocument,
        .prepare_navigation_document_abort = prepareDocumentAbort,
    });
}

fn prepareDocumentAbort(document: *runtime.Instance) bool {
    const gen = runtime.SlabAllocator.generationOf(document);
    for (loadsIn(document.ctx)) |load| {
        if (load.document != document or load.document_generation != gen) continue;
        load.document_abort_pending = true;
    }
    // Background favicon fetches must not mark a document unsalvageable for
    // BFCache (`Document.abortDocument` checks the return value).
    return false;
}

fn abortDocument(document: *runtime.Instance) void {
    const gen = runtime.SlabAllocator.generationOf(document);
    while (true) {
        const target: *IconLoad = blk: {
            for (loadsIn(document.ctx)) |load| {
                if (load.document_abort_pending and load.document == document and load.document_generation == gen) break :blk load;
            }
            return;
        };
        target.destroy();
    }
}

fn discardRealm(realm: runtime.Context) void {
    while (loadsIn(realm).len > 0) {
        const load = loadsIn(realm)[0];
        load.destroy();
    }
}

/// Whether `document` is shown by a top-level browsing context (not an iframe,
/// frame, srcdoc, or detached document).
fn isTopLevel(document: *runtime.Instance) bool {
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return false;
    if (dom.navigable_container.of(window) != null) return false;
    const parent = (interfaces.Window.get_parent(window) catch null) orelse return false;
    return parent == window;
}

/// Called from `Document` `completeLoading` right after `loadEventFired`,
/// `pageshow`, `completely_loaded = true`, `frameStoppedLoading`, and
/// `queueNavigationTimingEntry`.
pub fn onDocumentLoaded(document: *runtime.Instance) void {
    if (!document.ctx.hasEngine()) return;
    if (!isTopLevel(document)) return;

    const load = getOrCreateLoad(document) orelse return;
    load.terminateActiveFetch();
    load.clearCandidates();

    const has_declared = collectLinkCandidates(document, load);
    if (!has_declared) {
        appendDefaultFaviconCandidate(document, load);
    }
    if (load.candidates.items.len == 0) {
        load.releaseIfIdle();
        return;
    }

    startNextCandidate(load);
}

/// Called from `HTMLLinkElement` on insertion, removal, or icon-relevant
/// attribute change. Pre-load changes are ignored because `onDocumentLoaded`
/// collects the whole document's `<link rel="icon">` elements after `load`.
/// Post-load changes coalesce into a single event-loop task.
pub fn onLinkChanged(document: *runtime.Instance) void {
    if (!document.ctx.hasEngine()) return;
    if (!dom.document_lifecycle.isCompletelyLoaded(document)) return;
    if (!isTopLevel(document)) return;

    const load = getOrCreateLoad(document) orelse return;
    if (load.update_queued) return;

    const loop = document.ctx.getOptionalEventLoop() orelse {
        refreshDynamicIcons(load);
        return;
    };
    const allocator = document.ctx.allocator;
    const task = allocator.create(UpdateTask) catch return;
    const pin = engine.retainValue(document.ctx, .{ .instance = document }) catch {
        allocator.destroy(task);
        return;
    };
    task.* = .{
        .document = document,
        .generation = runtime.SlabAllocator.generationOf(document),
        .realm = document.ctx,
        .allocator = allocator,
        .pin = pin,
    };
    load.update_queued = true;
    loop.queueTask(.{
        .callback = &UpdateTask.run,
        .context = task,
        .drop = &UpdateTask.drop,
        .document = document,
        .document_generation = task.generation,
    });
}

const UpdateTask = struct {
    document: *runtime.Instance,
    generation: u64,
    realm: runtime.Context,
    allocator: std.mem.Allocator,
    pin: engine.Owned,

    fn run(context: ?*anyopaque) void {
        const self: *@This() = @ptrCast(@alignCast(context orelse return));
        const document = self.document;
        const generation = self.generation;
        const realm = self.realm;
        self.destroy();
        if (!realm.hasEngine() or runtime.SlabAllocator.generationOf(document) != generation) return;
        const load = findForDocument(document) orelse return;
        load.update_queued = false;
        refreshDynamicIcons(load);
    }

    fn drop(context: ?*anyopaque) void {
        const self: *@This() = @ptrCast(@alignCast(context orelse return));
        if (runtime.SlabAllocator.generationOf(self.document) == self.generation) {
            if (findForDocument(self.document)) |load| {
                load.update_queued = false;
                load.releaseIfIdle();
            }
        }
        self.destroy();
    }

    fn destroy(self: *@This()) void {
        self.pin.release();
        self.allocator.destroy(self);
    }
};

fn refreshDynamicIcons(load: *IconLoad) void {
    if (!load.documentIsLive() or !load.realm.hasEngine() or !isTopLevel(load.document)) {
        load.releaseIfIdle();
        return;
    }

    load.terminateActiveFetch();
    load.clearCandidates();

    _ = collectLinkCandidates(load.document, load);
    // Dynamic removal of <link rel="icon"> after load does NOT re-trigger
    // default `/favicon.ico`.
    if (load.candidates.items.len == 0) {
        load.releaseIfIdle();
        return;
    }

    startNextCandidate(load);
}

/// Walk `document` in document tree order and append every matching
/// `<link rel="icon">` candidate to `load.candidates`, sorted by
/// `(score DESC, tree_index DESC)`. Returns whether the document contained any
/// `<link>` with the `"icon"` keyword and a valid non-empty `href`.
fn collectLinkCandidates(document: *runtime.Instance, load: *IconLoad) bool {
    const root = dom.instance_bridge.getNodeBase(document) orelse return false;
    const desired_size = desiredIconSize(document);
    var has_declared = false;
    var tree_index: usize = 0;

    var current: ?*dom.NodeBase = root.firstChild();
    while (current) |node| {
        if (node.node_type == dom.NodeBase.ELEMENT_NODE) {
            if (dom.instance_bridge.getInstanceTyped(runtime.Instance, node)) |instance| {
                if (instance.stateAs(interfaces.HTMLLinkElement.State) != null) {
                    if (maybeCollectLink(instance, document, load, desired_size, tree_index)) {
                        has_declared = true;
                    }
                    tree_index += 1;
                }
            }
        }
        // Pre-order tree traversal within the document tree.
        if (node.firstChild()) |child| {
            current = child;
        } else {
            var cursor: ?*dom.NodeBase = node;
            current = null;
            while (cursor) |c| {
                if (c == root) break;
                if (c.next_sibling) |sib| {
                    current = sib;
                    break;
                }
                cursor = c.parent_node;
            }
        }
    }

    if (load.candidates.items.len > 1) {
        std.mem.sort(Candidate, load.candidates.items, {}, Candidate.lessThan);
        dedupCandidates(load);
    }
    return has_declared;
}

fn dedupCandidates(load: *IconLoad) void {
    var write: usize = 0;
    for (load.candidates.items, 0..) |*cand, idx| {
        var dup = false;
        for (load.candidates.items[0..write]) |*kept| {
            if (kept.cors == cand.cors and
                kept.referrer_policy == cand.referrer_policy and
                std.mem.eql(u8, kept.url, cand.url))
            {
                dup = true;
                break;
            }
        }
        if (dup) {
            cand.deinit(load.allocator);
        } else {
            if (write != idx) load.candidates.items[write] = cand.*;
            write += 1;
        }
    }
    load.candidates.items.len = write;
}

fn maybeCollectLink(
    element: *runtime.Instance,
    document: *runtime.Instance,
    load: *IconLoad,
    desired_size: u32,
    tree_index: usize,
) bool {
    const rel = elementAttr(element, "rel") orelse return false;
    if (!link_types.hasToken(rel, "icon")) return false;
    const href = elementAttr(element, "href") orelse return false;
    if (href.len == 0) return false;

    const url = (dom.encoding_parse.encodingParseAndSerializeWithAllocator(load.allocator, document, href) catch return false) orelse return false;
    errdefer load.allocator.free(url);

    // A connected <link rel="icon"> with a valid non-empty href declares an
    // icon (suppressing the default /favicon.ico fallback even if type/media
    // does not match this environment).
    const type_attr = elementAttr(element, "type");
    if (!link_types.typeMatches(type_attr, .image)) {
        load.allocator.free(url);
        return true;
    }
    if (!mediaMatches(element, document)) {
        load.allocator.free(url);
        return true;
    }

    const nonce_raw = dom.attribute_change_steps.readForAttribute(element, "http://www.w3.org/1999/xhtml", "nonce") orelse "";
    const integrity_raw = elementAttr(element, "integrity") orelse "";
    const nonce = load.allocator.dupe(u8, nonce_raw) catch {
        load.allocator.free(url);
        return true;
    };
    errdefer load.allocator.free(nonce);
    const integrity = load.allocator.dupe(u8, integrity_raw) catch {
        load.allocator.free(nonce);
        load.allocator.free(url);
        return true;
    };
    errdefer load.allocator.free(integrity);

    const priority: fetch.internal.request.Priority = blk: {
        const raw = elementAttr(element, "fetchpriority") orelse break :blk .auto;
        if (std.ascii.eqlIgnoreCase(raw, "high")) break :blk .high;
        if (std.ascii.eqlIgnoreCase(raw, "low")) break :blk .low;
        break :blk .auto;
    };

    const score = candidateScore(type_attr, elementAttr(element, "sizes"), desired_size);
    load.candidates.append(load.allocator, .{
        .url = @constCast(url),
        .cors = CorsSetting.fromAttribute(elementAttr(element, "crossorigin")),
        .referrer_policy = referrerPolicyState(elementAttr(element, "referrerpolicy")),
        .nonce = nonce,
        .integrity = integrity,
        .fetch_priority = priority,
        .score = score,
        .tree_index = tree_index,
        .is_default_favicon = false,
    }) catch {
        load.allocator.free(integrity);
        load.allocator.free(nonce);
        load.allocator.free(url);
        return true;
    };
    return true;
}

/// HTML §4.6.8.9 default `/favicon.ico` steps:
/// Only for documents whose URL's scheme is an HTTP(S) scheme, resolve
/// `"/favicon.ico"` against the Document's URL (not its base URL).
fn appendDefaultFaviconCandidate(document: *runtime.Instance, load: *IconLoad) void {
    const doc_url = interfaces.Document.get_URL(document) catch return;
    defer document.ctx.allocator.free(doc_url);
    if (!isHttpScheme(doc_url)) return;

    const parsed = (interfaces.URL.call_static_parse(
        document,
        "/favicon.ico",
        webidl.Opt(runtime.USVString).passed(doc_url),
    ) catch null) orelse return;
    defer runtime.Instance.deinit(parsed);

    const href = interfaces.URL.get_href(parsed) catch return;
    defer document.ctx.allocator.free(href);

    const owned_url = load.allocator.dupe(u8, href) catch return;
    errdefer load.allocator.free(owned_url);
    const nonce = load.allocator.dupe(u8, "") catch return;
    errdefer load.allocator.free(nonce);
    const integrity = load.allocator.dupe(u8, "") catch return;
    errdefer load.allocator.free(integrity);

    load.candidates.append(load.allocator, .{
        .url = owned_url,
        .cors = .no_cors,
        .referrer_policy = .empty,
        .nonce = nonce,
        .integrity = integrity,
        .fetch_priority = .auto,
        .score = 0,
        .tree_index = 0,
        .is_default_favicon = true,
    }) catch {
        load.allocator.free(integrity);
        load.allocator.free(nonce);
        load.allocator.free(owned_url);
    };
}

fn isHttpScheme(url: []const u8) bool {
    return (url.len >= 7 and std.ascii.eqlIgnoreCase(url[0..7], "http://")) or
        (url.len >= 8 and std.ascii.eqlIgnoreCase(url[0..8], "https://"));
}

fn desiredIconSize(document: *runtime.Instance) u32 {
    const values = dom.style.hooks.mediaValues(document);
    const dpr: f64 = if (values.resolution > 0) values.resolution else 1.0;
    const px = @as(u32, @intFromFloat(@round(16.0 * dpr)));
    return @max(px, 16);
}

fn elementAttr(element: *runtime.Instance, comptime name: []const u8) ?[]const u8 {
    const value = (interfaces.Element.call_getAttributeNS(element, null, runtime.DOMString.initInterned(name)) catch null) orelse return null;
    return value.asSlice();
}

fn mediaMatches(element: *runtime.Instance, document: *runtime.Instance) bool {
    const text = elementAttr(element, "media") orelse return true;
    if (text.len == 0) return true;
    const values = dom.style.hooks.mediaValues(document);
    return css.media_queries.MediaQueryList.matchesQuery(element.ctx.allocator, text, &values) catch true;
}

fn referrerPolicyState(value: ?[]const u8) ReferrerPolicy {
    const v = value orelse return .empty;
    inline for (@typeInfo(ReferrerPolicy).@"enum".field_names, @typeInfo(ReferrerPolicy).@"enum".field_values) |field_name, field_value| {
        if (field_value != @backingInt(ReferrerPolicy.empty) and link_types.keywordIs(field_name, v)) {
            return @field(ReferrerPolicy, field_name);
        }
    }
    return .empty;
}

fn globalOf(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    return global;
}

fn startNextCandidate(load: *IconLoad) void {
    while (load.next_candidate < load.candidates.items.len) {
        if (!load.documentIsLive() or !load.realm.hasEngine() or load.destroying) {
            load.clearCandidates();
            load.releaseIfIdle();
            return;
        }
        const cand = &load.candidates.items[load.next_candidate];
        const started = startCandidateFetch(load, cand) catch |err| blk: {
            log.debug("icon fetch of {s} not started: {}", .{ cand.url, err });
            break :blk null;
        };
        if (started) |f| {
            load.active_fetch = f;
            return;
        }
        // Candidate could not start (e.g. default /favicon.ico silently skipped
        // by CSP or allocation error): advance to next candidate if any.
        load.next_candidate += 1;
    }
    load.clearCandidates();
    load.releaseIfIdle();
}

fn startCandidateFetch(load: *IconLoad, cand: *const Candidate) !?*AsyncFetch {
    const allocator = load.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, cand.url);
    var request_owned = true;
    defer if (request_owned) request.deinit();

    // HTML §4.6.8.9:
    // - destination is "image"
    // - credentials mode is "include" (or "same-origin" for crossorigin="anonymous" on <link>)
    // - use-URL-credentials flag is set
    request.destination = .image;
    request.mode = if (cand.cors == .no_cors) .no_cors else .cors;
    request.credentials_mode = if (cand.cors == .anonymous) .same_origin else .include;
    request.use_url_credentials = true;
    request.referrer_policy = cand.referrer_policy;
    request.priority = cand.fetch_priority;
    request.is_favicon = true;
    if (cand.integrity.len != 0) try request.setIntegrityMetadata(cand.integrity);
    if (cand.nonce.len != 0) try request.setCryptographicNonceMetadata(cand.nonce);

    // HTML §4.2.4.3 step 5: `<link rel="icon">` sets initiator_type = "link"
    // (preserving Resource Timing for explicit icon links and crane/cs3-icon-allowed).
    // HTML §4.6.8.9 default `/favicon.ico`: initiator_type remains null per
    // Fetch §2.2.5 (no PerformanceResourceTiming entry).
    request.initiator_type = if (cand.is_default_favicon) null else .link;

    if (globalOf(load.realm)) |global| {
        var client = try dom.global_settings.requestClient(global);
        defer client.deinit();
        try fetch.internal.populateRequestFromClient(request, client.request);
    }

    if (cand.is_default_favicon) {
        // Blink `Document::DefaultFaviconAllowedByCSP` (crbug.com/820846):
        // check CSP silently (no securitypolicyviolation event, no HTTP or CDP
        // request when blocked) so strict `img-src 'none'` pages are not
        // spammed with violations for an implicit default icon lookup.
        request.csp_violation_reporter = null;
        if (fetch.algorithms.csp_check.shouldRequestBeBlocked(request)) {
            return null;
        }
    }

    request_owned = false;
    return try AsyncFetch.start(allocator, request, .{}, dom.agent_fetches.of(load.realm), load.client());
}

fn fetchAlive(context: *anyopaque) bool {
    const load: *IconLoad = @ptrCast(@alignCast(context));
    return !load.destroying and load.realm.engine_ctx != null and load.documentIsLive();
}

fn fetchGone(context: *anyopaque) void {
    const load: *IconLoad = @ptrCast(@alignCast(context));
    load.active_fetch = null;
    if (!load.destroying) load.releaseIfIdle();
}

fn fetchDone(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
    const load: *IconLoad = @ptrCast(@alignCast(context));
    load.active_fetch = null;
    if (load.destroying) {
        var res = outcome catch return;
        res.deinit();
        return;
    }

    const ok = blk: {
        var result = outcome catch break :blk false;
        defer result.deinit();
        const response = result.response;
        if (response.response_type == .@"error") break :blk false;
        break :blk fetch.internal.isOkStatus(response.status);
    };

    if (ok) {
        // HTML §4.2.4.3: icon has no "process the linked resource" algorithm,
        // fires no link events, and we have no UI decoder.
        load.clearCandidates();
        load.releaseIfIdle();
        return;
    }

    // HTML §4.6.8.9: "If the user agent tries to use an icon but that icon is
    // determined ... to in fact be inappropriate ..., then the user agent must
    // try the next-most-appropriate icon as determined by the attributes."
    load.next_candidate += 1;
    startNextCandidate(load);
}

// ============================================================================
// Unit tests (pure HTML §4.6.8.9 sizes parsing & candidate ranking)
// ============================================================================

test "parseSizes follows HTML 4.6.8.9 steps 1-7" {
    const p1 = parseSizes("16x16 32X32 any");
    try std.testing.expect(p1.any);
    try std.testing.expectEqual(@as(usize, 2), p1.len);
    try std.testing.expectEqual(@as(u32, 16), p1.slice()[0].width);
    try std.testing.expectEqual(@as(u32, 16), p1.slice()[0].height);
    try std.testing.expectEqual(@as(u32, 32), p1.slice()[1].width);
    try std.testing.expectEqual(@as(u32, 32), p1.slice()[1].height);

    // Invalid tokens: leading zero, multiple x, missing side, non-digits.
    const p2 = parseSizes("016x16 16x016 16x16x16 x16 16x abc 48x48");
    try std.testing.expect(!p2.any);
    try std.testing.expectEqual(@as(usize, 1), p2.len);
    try std.testing.expectEqual(@as(u32, 48), p2.slice()[0].width);
    try std.testing.expectEqual(@as(u32, 48), p2.slice()[0].height);

    // Case-insensitive ANY.
    const p3 = parseSizes("  AnY\t\n");
    try std.testing.expect(p3.any);
    try std.testing.expectEqual(@as(usize, 0), p3.len);
}

test "candidateScore prefers scalable, then closest >= desired square, then unspecified" {
    const svg_any = candidateScore("image/svg+xml", "any", 16);
    const png_16 = candidateScore("image/png", "16x16", 16);
    const png_32 = candidateScore("image/png", "32x32", 16);
    const png_8 = candidateScore("image/png", "8x8", 16);
    const unsized = candidateScore(null, null, 16);

    try std.testing.expect(svg_any > png_16);
    try std.testing.expect(png_16 > png_32);
    try std.testing.expect(png_32 > png_8);
    try std.testing.expect(png_8 > unsized);
}
