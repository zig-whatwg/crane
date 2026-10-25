//! Implementation for HTMLImageElement interface
//!
//! Production-quality image loading per HTML Standard §4.8.3 "The img element"
//!
//! ## Event Timing Per Spec
//!
//! When `src` is set, the spec requires:
//! 1. **Queue a microtask** to start the "update the image data" algorithm
//!    - This allows `img.onload = fn` to be set after `img.src = url`
//! 2. **Fire events via task queue** (macrotask, not synchronously)
//!    - Events must not fire during script execution that set src
//!
//! ## Cancellation
//!
//! Each `set_src` call increments a generation counter. If src is changed
//! again before the load completes, the old load is cancelled and its
//! events are not fired.
//!
//! ## Image requests and decoding
//!
//! The element has a current request and a pending request (HTML 4.8.4.3),
//! each with a state, a current URL and image data. A response's body is
//! typed by MIME Sniffing's rules for images and decoded through the
//! platform (`platform.decodeImage`, behind the `image_decoding`
//! capability); the decoded RGBA8 is the request's image data, which
//! naturalWidth, naturalHeight, complete, decode() and the 2D context's
//! drawImage read (the last through dom.image_sources).
//!
//! An image whose dimensions the platform obtained is an image, even when
//! the rest of its data ended early or was corrupt: the platform returns it
//! partial (platform.ImageDecodeStatus), and - as in every browser - the
//! request becomes completely available, load fires, and its decoded part
//! is drawn. Only an image whose dimensions cannot be obtained is broken
//! (HTML "update the image data": "corrupted in some fatal way such that the
//! image dimensions cannot be obtained").
//!
//! Spec: https://html.spec.whatwg.org/multipage/images.html#update-the-image-data

const std = @import("std");
const log = std.log.scoped(.img);
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const fetch = @import("fetch");
const HTMLImageElement = interfaces.HTMLImageElement;
const Element = interfaces.Element;
const EventTarget = interfaces.EventTarget;
const Event = interfaces.Event;
const same_object = @import("same_object.zig");
const platform = @import("platform");
const dom = @import("dom");
const reflection = @import("dom").reflection;
const available_images = dom.style.engine.available_images;

// Event loop for microtask/task queuing
const event_loop_mod = @import("streams_event_loop");

pub const State = HTMLImageElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// HTML 4.8.4.3: an image request's state.
pub const RequestState = enum { unavailable, partially_available, completely_available, broken };

/// An image request's image data, decoded: RGBA8, straight alpha, rows top
/// down, OWNED by the element's allocator.
const DecodedImage = *available_images.Image;

/// HTML 4.8.4.3 "image request": its state, current URL and image data.
const ImageRequest = struct {
    state: RequestState = .unavailable,
    /// The current URL, OWNED; empty is the empty string.
    url: []u8 = &.{},
    image: ?DecodedImage = null,
    /// The update of the image data this request belongs to
    /// (InternalState.load_generation when it was made).
    generation: u64 = 0,
    /// HTML 4.8.4.3: the selected source's current pixel density.
    pixel_density: f64 = 1,
    /// The CORS setting and origin at source selection, retained until the
    /// request ends. Attribute changes cannot retag a completed image.
    cors: available_images.CorsSetting = .none,
    origin: ?*dom.origin_record.OriginRecord = null,

    fn available(self: *const ImageRequest) bool {
        return self.state == .partially_available or self.state == .completely_available;
    }

    /// "Forget image request's image data": the image goes, the state and
    /// URL stay.
    fn forgetImage(self: *ImageRequest, allocator: std.mem.Allocator) void {
        _ = allocator;
        if (self.image) |image| image.release();
        self.image = null;
    }

    fn setUrl(self: *ImageRequest, allocator: std.mem.Allocator, url: []const u8) void {
        const copy = allocator.dupe(u8, url) catch return;
        allocator.free(self.url);
        self.url = copy;
    }

    fn deinit(self: *ImageRequest, allocator: std.mem.Allocator) void {
        self.forgetImage(allocator);
        allocator.free(self.url);
        if (self.origin) |origin| origin.release();
        self.* = .{};
    }
};

/// A decode() promise waiting for its element's current request.
const PendingDecode = struct {
    capability: engine.PromiseCapability,
    /// The current request it waits on (ImageRequest.generation).
    generation: u64,
};

/// Internal state for HTMLImageElement implementation
///
/// Contains private data for async image loading:
/// - load_generation: Counter for cancellation (newer loads cancel older ones)
/// - current / pending: the image requests (HTML 4.8.4.3)
/// - complete: Whether the update in flight has settled
pub const InternalState = struct {
    /// Generation counter for load cancellation
    /// Each set_src call increments this; older loads check and abort if superseded
    load_generation: u64 = 0,

    /// Whether the update of the image data in flight has settled - its
    /// fetch done and its event fired or dropped. (The `complete` IDL
    /// attribute reads the requests, not this.)
    complete: bool = true,

    /// HTML 4.8.4.3: the current request, and the pending request.
    current: ImageRequest = .{},
    pending: ?ImageRequest = null,
    /// decode() promises waiting for the current request to settle.
    decodes: std.ArrayList(PendingDecode) = .empty,

    /// The allocator used for this internal state
    allocator: std.mem.Allocator = undefined,
    document: ?same_object.Link = null,
    document_abort_pending: ?u64 = null,
    active_fetch: ?*ImageFetch = null,
    event_pending: bool = false,
    /// The element's one pending-activity keep for "update the image data"
    /// is held: a restarted update keeps no second one (the keep is
    /// counted), and only the first release of it ends it.
    kept_alive: bool = false,
    /// The document whose load event the element's update of the image data
    /// delays, with its slab generation (HTML "update the image data" step
    /// 26: an eager img's fetch "must delay the load event of element's node
    /// document until the task that is queued by the networking task source
    /// once the resource has been fetched has been run"). One per element:
    /// an update that supersedes another keeps it. Ended with the update's
    /// keep (`releaseLoad`: its event's task ran or was dropped, a document
    /// abort, its realm's end, a document that will never be fully active)
    /// and by `deinit`.
    load_delay: ?same_object.Link = null,

    fn keepLoad(self: *InternalState, instance: *runtime.Instance) void {
        if (self.kept_alive) return;
        self.kept_alive = true;
        engine.keepPlatformObjectAlive(instance);
    }

    fn releaseLoad(self: *InternalState, instance: *runtime.Instance) void {
        // The update has ended: so has its delay of the load event.
        self.endLoadDelay();
        if (!self.kept_alive) return;
        self.kept_alive = false;
        engine.releasePlatformObject(instance);
    }

    /// Delay `document`'s load event for this element's update ("delay the
    /// load event", Blink's IncrementLoadEventDelayCount in ImageLoader). A
    /// delay held on another document - the element was adopted - ends.
    fn delayLoad(self: *InternalState, document: *runtime.Instance) void {
        if (self.load_delay) |held| {
            if (held.instance == document and held.isLive()) return;
            self.endLoadDelay();
        }
        self.load_delay = same_object.Link.to(document);
        dom.document_lifecycle.delayLoadEvent(document);
    }

    /// The end of the element's delay, if it holds one; a document that has
    /// gone is not undelayed. Undelaying only queues the load event's task
    /// (Document's loadDelayMayHaveEnded), so it is safe from any caller.
    fn endLoadDelay(self: *InternalState) void {
        const held = self.load_delay orelse return;
        self.load_delay = null;
        if (held.isLive()) dom.document_lifecycle.undelayLoadEvent(held.instance);
    }

    fn cancelFetch(self: *InternalState) void {
        self.document_abort_pending = null;
        if (self.active_fetch) |active| {
            self.active_fetch = null;
            if (active.fetch) |transport| transport.terminate();
            active.allocator.destroy(active);
        }
    }

    /// "Abort the image request" for the pending request and set it to
    /// null.
    fn abortPending(self: *InternalState) void {
        if (self.pending) |*pending| pending.deinit(self.allocator);
        self.pending = null;
    }

    /// The element's requests and decode() promises go with it (or with its
    /// realm): nothing is settled, the capabilities are released.
    fn forgetRequests(self: *InternalState) void {
        self.abortPending();
        self.current.deinit(self.allocator);
        for (self.decodes.items) |*decode| engine.releasePromiseCapability(&decode.capability);
        self.decodes.deinit(self.allocator);
        self.decodes = .empty;
    }

    pub fn deinit(self: *InternalState) void {
        self.endLoadDelay();
        self.cancelFetch();
        self.forgetRequests();
    }
};

/// What "update the image data" found before its microtask: a URL to fetch,
/// no selected source (step 11), or a selected source that does not parse
/// (step 13).
const Selection = enum { fetch, no_source, bad_url, select_source };

/// Context for microtask callback that initiates image loading
/// This is allocated on the heap and freed after the microtask executes
const LoadMicrotaskContext = struct {
    instance: *runtime.Instance,
    instance_generation: u64,
    generation: u64,
    selection: Selection,
    /// The URL to fetch; for `bad_url`, the selected source; empty for
    /// `no_source`.
    url: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *LoadMicrotaskContext) void {
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }
};

/// Event type enum for image loading
const ImageEventType = enum { load, @"error" };

/// What the task that ends an update applies to the element's requests
/// before its event.
const Outcome = union(enum) {
    /// The request of this update decoded: it becomes the current request,
    /// completely available, with this image (OWNED until applied).
    loaded: DecodedImage,
    /// The request of this update is broken: "the image data is not in a
    /// supported file format" (or no response arrived).
    broken,
    /// Steps 11 and 13: no request was made; the current URL becomes `url`
    /// (OWNED) and error fires only when the element has a src attribute
    /// (`only_with_src`) - step 11 - or always - step 13.
    no_request: struct { url: []u8, only_with_src: bool },
    /// Step 7: the image data is already current; only the current URL and
    /// load event wait for this task. Owns the URL until applied/dropped.
    cached: []const u8,

    fn deinit(self: *Outcome, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .loaded => |image| image.release(),
            .no_request => |n| allocator.free(n.url),
            .cached => |url| allocator.free(url),
            .broken => {},
        }
        self.* = .broken;
    }

    fn eventType(self: Outcome) ImageEventType {
        return if (self == .loaded or self == .cached) .load else .@"error";
    }
};

/// Context for task callback that fires load/error event
/// This is allocated on the heap and freed after the task executes
const FireEventTaskContext = struct {
    instance: *runtime.Instance,
    instance_generation: u64,
    generation: u64,
    outcome: Outcome,
    /// Whether the event fires, and which (set when the outcome is applied).
    fire: bool = true,
    event_type: ImageEventType = .load,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *FireEventTaskContext) void {
        self.outcome.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = runtime.InstanceRegistry(.html_image_element, InternalState);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

fn getOrCreateInternal(instance: *runtime.Instance) !*InternalState {
    if (Registry.get(instance)) |internal| {
        return internal;
    }

    // Create new internal state using the runtime's arena allocator
    // This ensures proper cleanup during context shutdown
    // The registry owns this block, so `Registry.remove` returns it to
    // the arena. With `set` it was dropped from the map and held to
    // process exit - measured at 904 bytes per discarded element.
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = .{
        .allocator = instance.ctx.allocator,
    };
    return internal;
}

fn removeInternal(instance: *runtime.Instance) void {
    // Note: The internal state is allocated in the arena allocator,
    // so we don't need to explicitly free it. Just remove from registry.
    Registry.remove(instance);
}

/// HTMLImageElement's own construction steps: the generated chain runs HTMLElement's first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    _ = args;
    // Initialize internal state for image loading - registered, never looked
    // up: an entry already at this address is a dead img's, and a new img
    // that took it for its own inherited the dead one's request state (or,
    // from an earlier runtime, a block that is gone). createIn frees and
    // reports a dead one's (docs/lessons/architecture-an-address-keyed-entry-a-teardown-misses-is-inherited.md).
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = .{ .allocator = instance.ctx.allocator };
}

/// HTMLImageElement's own teardown: the generated chain runs HTMLElement's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    // Clean up internal state
    if (getInternal(instance)) |internal| internal.deinit();
    removeInternal(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try HTMLImageElement.init(ctx.allocator, ctx);
    errdefer HTMLImageElement.deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for crossOrigin: it reflects the crossorigin content attribute, a
/// nullable enumerated attribute limited to only known values (HTML 2.6.1,
/// 2.5.4): missing is null (No CORS), an invalid value is "anonymous".
pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const value = attributeValue(instance, "crossorigin") orelse return null;
    if (std.ascii.eqlIgnoreCase(value, "use-credentials")) return runtime.DOMString.initInterned("use-credentials");
    return runtime.DOMString.initInterned("anonymous");
}

/// Setter for crossOrigin: null removes the content attribute, any other
/// value sets it.
pub fn set_crossOrigin(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    if (value) |v| {
        try Element.call_setAttribute(instance, runtime.DOMString.initInterned("crossorigin"), .{ .domstring = v });
    } else {
        try Element.call_removeAttribute(instance, runtime.DOMString.initInterned("crossorigin"));
    }
}

/// The current request's image, when the request is available (partially
/// or completely: HTML's "if the image is available").
fn availableImage(instance: *runtime.Instance) ?DecodedImage {
    const internal = getInternal(instance) orelse return null;
    if (!internal.current.available()) return null;
    return internal.current.image;
}

/// HTML "determine the dimensions" of an img (2.4, the dimension
/// attributes) with its density-corrected natural width and height when it
/// is available.
fn dimensions(instance: *runtime.Instance) struct { u32, u32 } {
    // 1. Being rendered: the content box's size - the layout capability's
    //    box (with none, nothing is rendered).
    if (renderedSize(instance)) |size| return size;
    // Steps 2-3. A raster image at density 1 with no EXIF resolution: its
    // natural size.
    var width: u32 = 0;
    var height: u32 = 0;
    if (availableImage(instance)) |image| {
        width = densityCorrected(instance, image.width);
        height = densityCorrected(instance, image.height);
    }
    // Steps 4-5: the attributes, parsed as non-negative integers; an error
    // leaves the natural size.
    if (dimensionAttribute(instance, "width")) |value| width = value;
    if (dimensionAttribute(instance, "height")) |value| height = value;
    return .{ width, height };
}

/// Getter for width: "the width of this's dimensions".
pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
    return dimensions(instance)[0];
}

/// Getter for height: "the height of this's dimensions".
pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
    return dimensions(instance)[1];
}

/// Getter for naturalWidth: 0 unless the image is available, else its
/// density-corrected natural width.
/// Spec: https://html.spec.whatwg.org/multipage/embedded-content.html#dom-img-naturalwidth
pub fn get_naturalWidth(instance: *runtime.Instance) anyerror!u32 {
    const image = availableImage(instance) orelse return 0;
    return densityCorrected(instance, image.width);
}

/// Getter for naturalHeight
/// Spec: https://html.spec.whatwg.org/multipage/embedded-content.html#dom-img-naturalheight
pub fn get_naturalHeight(instance: *runtime.Instance) anyerror!u32 {
    const image = availableImage(instance) orelse return 0;
    return densityCorrected(instance, image.height);
}

fn densityCorrected(instance: *runtime.Instance, dimension: u32) u32 {
    const internal = getInternal(instance) orelse return 0;
    if (internal.current.pixel_density == 1) return dimension;
    const value = @as(f64, @floatFromInt(dimension)) / internal.current.pixel_density;
    // HTML permits 0x (infinite natural dimensions) and a zero source size
    // (infinite density). Bound the former before converting to WebIDL.
    if (std.math.isNan(value) or value <= 0) return 0;
    return @intFromFloat(@min(value, @as(f64, @floatFromInt(std.math.maxInt(u32)))));
}

/// Getter for complete
/// Spec: https://html.spec.whatwg.org/multipage/embedded-content.html#dom-img-complete
pub fn get_complete(instance: *runtime.Instance) anyerror!bool {
    // 1. True if both src and srcset are omitted; if srcset is omitted and
    //    src is the empty string - the content attributes (the `src` IDL
    //    attribute resolves src="" to the document URL) ...
    const src = attributeValue(instance, "src");
    const srcset = attributeValue(instance, "srcset");
    if (srcset == null and (src == null or src.?.len == 0)) return true;
    const internal = getInternal(instance) orelse return true;
    // ... or if the current request is completely available or broken and
    // there is no pending request.
    if (internal.pending != null) return false;
    return internal.current.state == .completely_available or internal.current.state == .broken;
}

/// Getter for currentSrc: the current request's current URL.
pub fn get_currentSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    const url: []const u8 = if (getInternal(instance)) |internal| internal.current.url else "";
    return instance.ctx.allocator.dupe(u8, url);
}

/// Getter for referrerPolicy
pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflection.getEnumerated(runtime.DOMString, instance, .{
        .name = "referrerpolicy",
        .keywords = reflection.referrer_policy_keywords,
    });
}

/// Getter for decoding
pub fn get_decoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflection.getEnumerated(runtime.DOMString, instance, .{
        .name = "decoding",
        .keywords = &.{ "sync", "async", "auto" },
        .missing = "auto",
        .invalid = "auto",
    });
}

/// Getter for loading
pub fn get_loading(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflection.getEnumerated(runtime.DOMString, instance, .{
        .name = "loading",
        .keywords = &.{ "eager", "lazy" },
        .missing = "eager",
        .invalid = "eager",
    });
}

/// Getter for fetchPriority
pub fn get_fetchPriority(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflection.getEnumerated(runtime.DOMString, instance, .{
        .name = "fetchpriority",
        .keywords = &.{ "high", "low", "auto" },
        .missing = "auto",
        .invalid = "auto",
    });
}

/// Getter for x
pub fn get_x(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for y
pub fn get_y(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // HTML 4.8.4.3.2's relevant mutations of an img element's attributes run
    // "update the image data" - however the attribute is set: the IDL
    // setters reflect into the content attributes, and setAttribute.
    @import("dom").attribute_change_steps.install("img", &attributeChangeSteps);
    @import("dom").adopting_steps.install(&adoptingSteps);
    @import("dom").document_fetches.install(.{ .discard = discardRealm, .prepare_abort = prepareDocumentAbort, .abort = abortDocument });
    // HTML 4.12.5.1.9: an img is an image source for a 2D context.
    dom.image_sources.installImageElement(imageUsability, replacedFacts);
    dom.teardown_sweeps.install(.element_types, &sweepRemaining);
}

/// `dom.teardown_sweeps`: free what the state of every img no exit reached
/// still owns - its requests' URLs and image data, its fetch, its decode()
/// promises - at its Browser's end. A teardown that freed an img's slot
/// without its deinit leaves such a state behind
/// (tests/html/image_fetch_detach_test.zig drops one by hand).
fn sweepRemaining(scope: *runtime.BrowserScope) void {
    Registry.deinitAllAndClear(scope);
}

/// The img's facts for the platform's layout STOPGAP (decision 19b): null
/// for an element that is no img.
fn replacedFacts(instance: *runtime.Instance) ?platform.ReplacedElementFacts {
    _ = getInternal(instance) orelse return null;
    var facts: platform.ReplacedElementFacts = .{
        .connected = interfaces.Node.get_isConnected(instance) catch false,
        .has_natural_size = false,
        .natural_width = 0,
        .natural_height = 0,
        .has_width_attribute = false,
        .width_attribute = 0,
        .has_height_attribute = false,
        .height_attribute = 0,
    };
    if (availableImage(instance)) |image| {
        facts.has_natural_size = true;
        facts.natural_width = densityCorrected(instance, image.width);
        facts.natural_height = densityCorrected(instance, image.height);
    }
    if (dimensionAttribute(instance, "width")) |width| {
        facts.has_width_attribute = true;
        facts.width_attribute = width;
    }
    if (dimensionAttribute(instance, "height")) |height| {
        facts.has_height_attribute = true;
        facts.height_attribute = height;
    }
    return facts;
}

/// A dimension attribute's value, parsed as a non-negative integer; null
/// when absent or an error.
fn dimensionAttribute(instance: *runtime.Instance, name: []const u8) ?u32 {
    const value = attributeValue(instance, name) orelse return null;
    const parsed = reflection.parseNonNegativeInteger(value) orelse return null;
    return @intCast(@min(parsed, std.math.maxInt(u32)));
}

/// The img's content box, when it is being rendered: the layout
/// capability's box (decision 19b's STOPGAP). Null when not rendered - or
/// with no layout at all.
fn renderedSize(instance: *runtime.Instance) ?struct { u32, u32 } {
    if (platform.capabilities.layout == .unsupported) {
        return null;
    } else {
        const browser = @import("html").platform_state.of(instance.ctx) orelse return null;
        const facts = replacedFacts(instance) orelse return null;
        const document = interfaces.Node.get_ownerDocument(instance) catch null;
        const box = platform.replacedElementBox(browser, dom.image_sources.layoutNode(document), dom.image_sources.layoutNode(instance), &facts) orelse return null;
        return .{ roundedCss(box.client.width), roundedCss(box.client.height) };
    }
}

fn roundedCss(value: f64) u32 {
    if (!(value > 0)) return 0;
    return @intFromFloat(@min(@round(value), @as(f64, std.math.maxInt(u32))));
}

/// HTML "check the usability of the image argument" for an img, and its
/// image when good.
fn imageUsability(instance: *runtime.Instance) dom.image_sources.Usability {
    const internal = getInternal(instance) orelse return .bad;
    // A broken current request is an InvalidStateError.
    if (internal.current.state == .broken) return .invalid_state;
    // Not fully decodable - its current request not completely available -
    // or a zero natural size: bad.
    //
    // Deviation from the spec text, as the browsers do (golden rule 2): a
    // partial image - completely available, but whose data ended early or
    // was corrupt after its dimensions, so not "fully decodable" (it does
    // not decode "without errors") - is drawn as far as it decoded, not
    // refused. Blink's ImageElementBase::GetSourceImageForCanvas refuses only
    // an image whose resource ErrorOccurred(), which a decode failure after
    // the size never sets, and draws the partially decoded frame; Gecko
    // finishes a frame the data left mid-way (Decoder::CompleteDecode);
    // ImageIO returns the rows it reached (lane imgpart, 2026-10-12).
    if (internal.current.state != .completely_available) return .bad;
    const image = internal.current.image orelse return .bad;
    if (image.width == 0 or image.height == 0) return .bad;
    return .{
        .good = .{
            .width = image.width,
            .height = image.height,
            .pixels = image.pixels,
            .alpha = .straight,
            // "Not origin-clean if image's current request's image data is
            // CORS-cross-origin."
            .origin_clean = image.cors_same_origin,
        },
    };
}
fn prepareDocumentAbort(document: *runtime.Instance) bool {
    var iter = Registry.iterator(runtime.BrowserScope.ofInstance(document)) orelse return false;
    var canceled = false;
    while (iter.next()) |entry| {
        const internal = entry.internal;
        const link = internal.document orelse continue;
        if (link.instance != document or !link.isLive() or (internal.complete and !internal.event_pending)) continue;
        internal.document_abort_pending = internal.load_generation;
        canceled = true;
    }
    return canceled;
}
fn abortDocument(document: *runtime.Instance) void {
    var iter = Registry.iterator(runtime.BrowserScope.ofInstance(document)) orelse return;
    while (iter.next()) |entry| {
        const internal = entry.internal;
        const generation = internal.document_abort_pending orelse continue;
        const link = internal.document orelse continue;
        if (link.instance != document or !link.isLive()) continue;
        internal.document_abort_pending = null;
        if (generation != internal.load_generation) continue;
        internal.cancelFetch();
        internal.load_generation +%= 1;
        internal.complete = true;
        internal.event_pending = false;
        const instance: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
        internal.releaseLoad(instance);
    }
}
fn discardRealm(realm: runtime.Context) void {
    var iter = Registry.iterator(realm.browserScope() orelse return) orelse return;
    while (iter.next()) |entry| {
        const instance: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
        if (instance.ctx != realm) continue;
        entry.internal.cancelFetch();
        entry.internal.forgetRequests();
        entry.internal.load_generation +%= 1;
        entry.internal.complete = true;
        entry.internal.event_pending = false;
        entry.internal.releaseLoad(instance);
    }
}

/// The img element's attribute change steps: its relevant mutations - the
/// src, srcset, width or sizes attributes set, changed or removed (src set
/// to its own value included: that restarts animations, which nothing here
/// keeps), the crossorigin or referrerpolicy attribute's state changed.
///
/// Not modelled, stated: the other relevant mutations - the img or a source
/// sibling inserted, removed or moved, a picture parent's source changing,
/// auto-sizes. The adopting steps are `adoptingSteps`.
fn attributeChangeSteps(element: *runtime.Instance, local_name: []const u8, old_value: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    if (namespace != null) return;
    const always = [_][]const u8{ "src", "srcset", "width", "sizes" };
    const on_state_change = [_][]const u8{ "crossorigin", "referrerpolicy" };
    for (always) |name| {
        if (std.mem.eql(u8, local_name, name)) return updateTheImageData(element);
    }
    for (on_state_change) |name| {
        if (!std.mem.eql(u8, local_name, name)) continue;
        // An enumerated attribute's state: the same value is the same state.
        const same = if (old_value) |o| (if (value) |v| std.ascii.eqlIgnoreCase(o, v) else false) else value == null;
        if (!same) updateTheImageData(element);
        return;
    }
}

/// HTML "update the image data", as far as this engine models it. After a microtask
/// (step 8, the spec's "allowing the task that invoked this algorithm to
/// continue"), a selected source is fetched and its response decoded, or -
/// with none, or one that does not parse - the current request is broken;
/// a task then updates the requests and fires load or error. A newer update
/// cancels an older one (step 9: the generation counter).
///
/// Not modelled, stated: picture source selection and step 14's
/// "same URL as the pending request"
/// shortcut (the update restarts); the partially available state (the image
/// is decoded once its whole body has arrived - and then, when its data
/// ended early or was corrupt after its dimensions, it is a partial image,
/// completely available). Source selection and URL resolution occur after
/// the microtask, against the then-current attributes and document base URL.
fn updateTheImageData(instance: *runtime.Instance) void {
    // Step 1: "If element's node document is not fully active", the rest
    // waits until it is - for a document with no browsing context (a
    // template's contents, the inert document of a sanitizing fragment
    // parse, DOMParser's and createHTMLDocument's documents), forever: no
    // request, no fetch, no event. Adopting the img into a document with
    // one is a relevant mutation (`adoptingSteps`), which starts a new
    // update there. Blink, Gecko and WebKit load nothing in such a
    // document either (no frame; Gecko's data documents).
    //
    // Not modelled, stated: a document that has a browsing context but is
    // not fully active (an inactive history entry's, a removed iframe's)
    // still loads, as before - nothing here resumes an update when its
    // document becomes fully active again.
    if (!hasBrowsingContext(instance)) return waitForFullyActive(instance);

    // Steps 3–7: only a plain src can reuse the document's list before
    // the microtask. A responsive source is still selected after step 8.
    if (reuseAvailableImage(instance)) return;

    // Steps 8–12: even a plain src is selected and URL-resolved after the
    // caller's task. A base element inserted in that task affects the URL
    // (WPT image-base-url.html); a later unrelated insertion does not.
    startLoad(instance, .select_source, "") catch |err| log.debug("img: the update did not start: {s}", .{@errorName(err)});
}

/// HTML update-image-data step 7. The cache holds only complete images;
/// pending fetches remain independent. No fetch or timing entry is made.
fn reuseAvailableImage(instance: *runtime.Instance) bool {
    if (attributeValue(instance, "srcset") != null) return false;
    if (interfaces.Node.get_parentNode(instance) catch null) |parent| {
        if (dom.element_data.of(parent)) |data| {
            if (std.mem.eql(u8, data.local_name.asSlice(), "picture") and
                std.mem.eql(u8, data.namespaceSlice() orelse "", "http://www.w3.org/1999/xhtml")) return false;
        }
    }
    const document = (interfaces.Node.get_ownerDocument(instance) catch null) orelse return false;
    const style_engine = dom.style.hooks.engineOf(document) orelse return false;
    const cache = style_engine.availableImages() orelse return false;
    const src = attributeValue(instance, "src") orelse return false;
    if (src.len == 0) return false;
    const allocator = instance.ctx.allocator;
    // Step 7.1: this lookup borrows the resolved URL only for this call.
    // Keep ordinary parsing temporary storage on the stack; long URLs use
    // the context allocator and are freed through the same temporary allocator.
    var parse_memory = std.heap.stackFallback(4096, allocator);
    const temporary = parse_memory.get();
    const url = (dom.encoding_parse.encodingParseAndSerializeWithAllocator(temporary, instance, src) catch return false) orelse return false;
    defer temporary.free(url);
    const cors = available_images.CorsSetting.fromAttribute(attributeValue(instance, "crossorigin"));
    const origin = if (cors != .none) (dom.document_origin.shareable(document) catch return false) orelse return false else null;
    const image = cache.get(.{ .url = url, .cors = cors, .origin = origin }) orelse return false;
    // Step 7.4.7 retains the URL until its element task. Allocate that owned
    // copy before changing either request; no pointer into parse_memory escapes.
    const task_url = allocator.dupe(u8, url) catch return false;
    var owned_url = true;
    defer if (owned_url) allocator.free(task_url);
    const internal = getOrCreateInternal(instance) catch return false;
    // Retain first: aborting the current request may drop another reference
    // to the very same payload.
    const kept = image.retain();
    internal.cancelFetch();
    internal.endLoadDelay();
    internal.abortPending();
    internal.current.deinit(allocator);
    internal.load_generation += 1;
    internal.complete = true;
    internal.event_pending = false;
    internal.document = same_object.Link.to(document);
    internal.current = .{
        .state = .completely_available,
        .image = kept,
        .generation = internal.load_generation,
        .cors = cors,
        .origin = if (origin) |o| o.retain() else null,
    };
    settleDecodes(instance, internal, .reject_all);
    internal.keepLoad(instance);
    // Step 7.4.7: currentSrc and load are both deferred. queueImageTask
    // owns task_url from here, including failure and cancellation paths.
    owned_url = false;
    queueImageTask(instance, internal.load_generation, .{ .cached = task_url }, allocator);
    return true;
}

/// Whether `element`'s node document has a browsing context: a window, as
/// `defaultView` answers. One without never becomes fully active.
fn hasBrowsingContext(element: *runtime.Instance) bool {
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return false;
    return (interfaces.Document.get_defaultView(document) catch null) != null;
}

/// Step 1.1-1.3 for a node document that will never be fully active: this
/// update supersedes every older one ("if another instance of this algorithm
/// for this img element was started after this instance ... return"), so an
/// update in flight is cancelled - its fetch, its event and its keep - and
/// this one goes no further. The requests are left as they are.
fn waitForFullyActive(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.cancelFetch();
    internal.load_generation += 1;
    internal.event_pending = false;
    internal.complete = true;
    internal.releaseLoad(instance);
}

/// The img's adopting steps (HTML 4.8.4.3.2: "The element's adopting steps
/// are run" is a relevant mutation): update the image data in its new
/// document. An img parsed into an inert document loads once it is adopted
/// into one that has a browsing context.
fn adoptingSteps(node: *runtime.Instance, _: ?*runtime.Instance) void {
    if (node.stateAs(State) == null) return;
    updateTheImageData(node);
}

/// `url` parsed against `element`'s base URL (its node document's), and
/// serialized; owned by the element's context allocator, null when it does
/// not parse.
fn resolveAgainstBaseUrl(element: *runtime.Instance, url: []const u8) ?[]const u8 {
    // The shared HTML algorithm supplies both the current base URL and
    // document character encoding; its result belongs to ctx.allocator.
    return @import("html").encoding_parse.encodingParseAndSerialize(element, url) catch null;
}

/// HTML 4.8.4.3.10, "parse a srcset attribute". The iterator borrows its
/// input and does not allocate: each candidate is used during this update,
/// before a URL is copied into the existing image request.
const Srcset = struct {
    input: []const u8,
    position: usize = 0,

    const Candidate = struct {
        url: []const u8,
        width: ?f64 = null,
        density: ?f64 = null,
        height: ?f64 = null,
        invalid: bool = false,

        fn descriptor(self: *Candidate, text: []const u8) void {
            if (text.len < 2) {
                self.invalid = true;
                return;
            }
            const number = text[0 .. text.len - 1];
            switch (text[text.len - 1]) {
                'w', 'h' => |unit| {
                    var value: f64 = 0;
                    for (number) |c| {
                        if (!std.ascii.isDigit(c)) {
                            self.invalid = true;
                            return;
                        }
                        value = @min(value * 10 + @as(f64, @floatFromInt(c - '0')), std.math.floatMax(f64));
                    }
                    if (value == 0 or self.density != null or (if (unit == 'w') self.width != null else self.height != null)) {
                        self.invalid = true;
                        return;
                    }
                    if (unit == 'w') self.width = value else self.height = value;
                },
                'x' => {
                    if (self.width != null or self.height != null or self.density != null or !validFloat(number)) {
                        self.invalid = true;
                        return;
                    }
                    const value = std.fmt.parseFloat(f64, number) catch {
                        self.invalid = true;
                        return;
                    };
                    if (value < 0 or !std.math.isFinite(value)) self.invalid = true else self.density = if (value == 0) 0 else value;
                },
                else => self.invalid = true,
            }
        }
    };

    fn whitespace(c: u8) bool {
        return c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == '\x0c';
    }

    /// HTML "valid floating-point number", not the permissive prefix
    /// parser: no leading plus, no trailing dot, and a nonempty exponent.
    fn validFloat(text: []const u8) bool {
        var p: usize = 0;
        if (p < text.len and text[p] == '-') p += 1;
        const integer_start = p;
        while (p < text.len and std.ascii.isDigit(text[p])) : (p += 1) {}
        const integer_digits = p - integer_start;
        if (p < text.len and text[p] == '.') {
            p += 1;
            const fraction_start = p;
            while (p < text.len and std.ascii.isDigit(text[p])) : (p += 1) {}
            if (p == fraction_start) return false;
        } else if (integer_digits == 0) return false;
        if (p < text.len and (text[p] == 'e' or text[p] == 'E')) {
            p += 1;
            if (p < text.len and (text[p] == '+' or text[p] == '-')) p += 1;
            const exponent_start = p;
            while (p < text.len and std.ascii.isDigit(text[p])) : (p += 1) {}
            if (p == exponent_start) return false;
        }
        return p == text.len;
    }

    fn next(self: *Srcset) ?Candidate {
        while (true) {
            // Steps 4–6: commas delimit candidates only after the URL.
            while (self.position < self.input.len and (whitespace(self.input[self.position]) or self.input[self.position] == ',')) : (self.position += 1) {}
            if (self.position == self.input.len) return null;
            const start = self.position;
            while (self.position < self.input.len and !whitespace(self.input[self.position])) : (self.position += 1) {}
            var candidate: Candidate = .{ .url = self.input[start..self.position] };
            if (candidate.url[candidate.url.len - 1] == ',') {
                candidate.url = std.mem.trimEnd(u8, candidate.url, ",");
            } else {
                // Step 8: descriptor, after-descriptor and in-parens
                // states; a comma inside parentheses is not a separator.
                while (self.position < self.input.len) {
                    while (self.position < self.input.len and whitespace(self.input[self.position])) : (self.position += 1) {}
                    const descriptor_start = self.position;
                    var in_parens = false;
                    while (self.position < self.input.len) : (self.position += 1) {
                        const c = self.input[self.position];
                        if (in_parens) {
                            if (c == ')') in_parens = false;
                        } else {
                            if (whitespace(c) or c == ',') break;
                            if (c == '(') in_parens = true;
                        }
                    }
                    if (self.position > descriptor_start) candidate.descriptor(self.input[descriptor_start..self.position]);
                    if (self.position < self.input.len and self.input[self.position] == ',') {
                        self.position += 1;
                        break;
                    }
                }
            }
            // Steps 14–15: a future-compatible h descriptor requires w.
            if (!candidate.invalid and (candidate.height == null or candidate.width != null)) return candidate;
        }
    }
};

const ImageSource = struct { url: []const u8, density: f64 };

/// HTML 4.8.4.3.8/12 followed by 4.8.4.3.7. Choose the smallest density
/// at least the environment's resolution, otherwise the largest density.
/// Equal densities keep the first URL (selection step 1). This streaming
/// choice is equivalent to deduplicating and sorting the entire set.
fn selectImageSource(instance: *runtime.Instance) ?ImageSource {
    const document = (interfaces.Node.get_ownerDocument(instance) catch null) orelse return null;
    const environment = dom.style.hooks.mediaValues(document);
    var candidates: Srcset = .{ .input = attributeValue(instance, "srcset") orelse "" };
    var chosen: ?ImageSource = null;
    var width_seen = false;
    var density_one_seen = false;
    var size: ?f64 = null;
    while (candidates.next()) |candidate| {
        width_seen = width_seen or candidate.width != null;
        density_one_seen = density_one_seen or candidate.density == 1;
        const density = candidate.density orelse if (candidate.width) |width| blk: {
            if (size == null) size = sourceSize(instance, environment);
            break :blk width / size.?;
        } else 1;
        considerSource(&chosen, .{ .url = candidate.url, .density = density }, environment.resolution);
    }
    if (!width_seen and !density_one_seen) {
        if (attributeValue(instance, "src")) |src| if (src.len > 0) {
            considerSource(&chosen, .{ .url = src, .density = 1 }, environment.resolution);
        };
    }
    return chosen;
}

fn considerSource(chosen: *?ImageSource, candidate: ImageSource, resolution: f64) void {
    const current = chosen.* orelse {
        chosen.* = candidate;
        return;
    };
    if (current.density < resolution) {
        if (candidate.density > current.density) chosen.* = candidate;
    } else if (candidate.density >= resolution and candidate.density < current.density) chosen.* = candidate;
}

/// HTML 4.8.4.3.11. Component values, rather than splitting on commas or
/// spaces, preserve functions, media conditions, comments and escapes.
/// Numeric expressions remain subject to Crane's CSS capability (the CSS
/// value grammar currently has no math functions; see row 91's Q4).
fn sourceSize(instance: *runtime.Instance, environment: dom.style.css.media_queries.MediaValues) f64 {
    const css = dom.style.css;
    const text = attributeValue(instance, "sizes") orelse return environment.width;
    var tokenizer = css.tokenizer.Tokenizer.init(text);
    var item_start: usize = 0;
    var last_start: usize = 0;
    var last_end: usize = 0;
    while (true) {
        const token = tokenizer.next();
        if (token.token_type == .whitespace) continue;
        if (token.token_type == .comma or token.token_type == .eof) {
            if (last_end > item_start) {
                if (sourceSizeValue(instance, text[last_start..last_end], environment)) |size| {
                    const condition = std.mem.trim(u8, text[item_start..last_start], " \t\n\r\x0c");
                    if (condition.len == 0) return size;
                    var condition_tokens = css.tokenizer.Tokenizer.init(condition);
                    condition_tokens.skipWhitespace();
                    const first = condition_tokens.next();
                    if (first.token_type == .eof) return size; // comments only
                    var query = css.media_queries.MediaQueryList.parse(instance.ctx.allocator, condition) catch return environment.width;
                    defer query.deinit();
                    // sizes accepts a media CONDITION, not a media type.
                    if (query.queries.len == 1 and query.queries[0].media_type == null and query.matches(&environment)) return size;
                }
            }
            if (token.token_type == .eof) return environment.width;
            item_start = tokenizer.pos;
            last_end = item_start;
            continue;
        }
        last_start = @intFromPtr(token.value.ptr) - @intFromPtr(text.ptr);
        // The tokenizer exposes function and '(' separately. Consume the
        // complete CSS block as one component, including its EOF closure.
        if (token.token_type == .function) _ = tokenizer.next();
        if (token.token_type == .function or token.token_type == .left_paren or token.token_type == .left_bracket or token.token_type == .left_brace) {
            var depth: usize = 1;
            while (depth > 0) {
                const nested = tokenizer.next();
                switch (nested.token_type) {
                    .left_paren, .left_bracket, .left_brace => depth += 1,
                    .right_paren, .right_bracket, .right_brace => depth -= 1,
                    .eof => break,
                    else => {},
                }
            }
        }
        last_end = tokenizer.pos;
    }
}

fn sourceSizeValue(instance: *runtime.Instance, text: []const u8, environment: dom.style.css.media_queries.MediaValues) ?f64 {
    const css = dom.style.css;
    var tokenizer = css.tokenizer.Tokenizer.init(text);
    const token = tokenizer.next();
    if (token.isIdent("auto")) {
        // Step 3.3: no concrete rendered object size in the headless media
        // environment. Ignore auto and try the following size (Q4).
        return null;
    }
    const value = token.numeric_value orelse return null;
    if (value < 0 or !std.math.isFinite(value)) return null;
    if (token.token_type == .number) return if (value == 0) 0 else null;
    if (token.token_type != .dimension) return null;
    const unit_text = token.unit orelse return null;
    const unit_decoded = css.tokenizer.decode(instance.ctx.allocator, unit_text) catch return null;
    defer instance.ctx.allocator.free(unit_decoded);
    // As in the media-query evaluator, there are no dynamic toolbars:
    // small, large and dynamic viewport lengths share this viewport.
    const viewport_variant = unit_decoded.len > 2 and
        (std.ascii.toLower(unit_decoded[0]) == 's' or std.ascii.toLower(unit_decoded[0]) == 'l' or std.ascii.toLower(unit_decoded[0]) == 'd') and
        std.ascii.toLower(unit_decoded[1]) == 'v';
    const unit = css.LengthUnit.fromString(if (viewport_variant) unit_decoded[1..] else unit_decoded) orelse return null;
    // Relative units use the media environment's initial font metrics and
    // viewport, as sizes and media queries require, never element styles.
    const factor: f64 = switch (unit) {
        .px => 1,
        .cm => 96.0 / 2.54,
        .mm => 96.0 / 25.4,
        .in => 96,
        .pt => 96.0 / 72.0,
        .pc => 16,
        .Q => 96.0 / 101.6,
        .em, .rem => environment.font_size,
        .ex, .ch => environment.font_size / 2,
        .lh, .rlh => return null, // the media environment has no line-height metric
        .vw, .vi => environment.width / 100,
        .vh, .vb => environment.height / 100,
        .vmin => @min(environment.width, environment.height) / 100,
        .vmax => @max(environment.width, environment.height) / 100,
        .percent => return null,
    };
    return value * factor;
}

const SelectedLoad = struct {
    selection: Selection,
    url: []const u8,
    density: f64 = 1,
    owned_url: bool = false,
};

fn selectedLoad(instance: *runtime.Instance, selection: Selection, url: []const u8) SelectedLoad {
    if (selection != .select_source) return .{ .selection = selection, .url = url };
    // The ordinary src path needs neither candidate parsing nor the media
    // environment. Its result is still resolved after the microtask.
    const source: ImageSource = if (attributeValue(instance, "srcset") != null)
        selectImageSource(instance) orelse return .{ .selection = .no_source, .url = "" }
    else blk: {
        const src = attributeValue(instance, "src") orelse return .{ .selection = .no_source, .url = "" };
        if (src.len == 0) return .{ .selection = .no_source, .url = "" };
        break :blk .{ .url = src, .density = 1 };
    };
    const resolved = resolveAgainstBaseUrl(instance, source.url) orelse return .{ .selection = .bad_url, .url = source.url };
    return .{ .selection = .fetch, .url = resolved, .density = source.density, .owned_url = true };
}

/// Setter for src: it reflects the src content attribute
/// (https://html.spec.whatwg.org/multipage/embedded-content.html#dom-img-src),
/// whose change is a relevant mutation: the attribute change steps run
/// "update the image data".
pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const dom_value = runtime.DOMString.initInterned(value);
    try Element.call_setAttribute(instance, runtime.DOMString.initInterned("src"), .{ .domstring = dom_value });
}

/// Start an update of `instance`'s image data, superseding any in flight.
///
/// 1. Queue a microtask to run the rest - so `img.onload = fn` set after
///    `img.src = url` still hears the event.
/// 2. The microtask updates the requests and fetches the image, or breaks
///    the current request; a task applies the outcome and fires the event.
/// 3. A generation counter cancels an update a newer one superseded.
fn startLoad(instance: *runtime.Instance, selection: Selection, url_str: []const u8) !void {
    const allocator = instance.ctx.allocator;

    // Step 9's "another instance of this algorithm started after this one":
    // a new generation cancels the older update's fetch and task.
    const internal = try getOrCreateInternal(instance);
    internal.cancelFetch();
    internal.document = if (interfaces.Node.get_ownerDocument(instance) catch null) |document| same_object.Link.to(document) else null;
    internal.event_pending = false;
    internal.load_generation += 1;
    internal.complete = false; // Mark as loading
    // HTML keeps the element while update-the-image-data is running, even
    // when disconnected. Cancellation and the event's completed task end it.
    internal.keepLoad(instance);
    errdefer {
        internal.complete = true;
        releaseLoadHold(instance, runtime.SlabAllocator.generationOf(instance), internal.load_generation);
    }
    const current_generation = internal.load_generation;
    // Steps 24 and 26: an update that fetches an eager img's image delays
    // its node document's load event until the task that fires load or
    // error has run (`releaseLoad`). Taken now, when the update is invoked,
    // not when the fetch starts after the microtask: Blink's ImageLoader
    // takes it in UpdateFromElement (delay_until_do_update_from_element_)
    // and holds it through the fetch and the event, so "the end" - which
    // can reach step 8 before the microtask has run - waits for the image.
    const has_src = if (attributeValue(instance, "src")) |src| src.len > 0 else false;
    const may_fetch = selection == .fetch or (selection == .select_source and
        (attributeValue(instance, "srcset") != null or has_src));
    if (may_fetch and !isLazy(instance)) {
        if (internal.document) |document| internal.delayLoad(document.instance);
    }

    // Step 8: Queue a microtask for the rest of the algorithm.
    const event_loop = instance.ctx.getOptionalEventLoop() orelse {
        // No event loop - fall back to synchronous loading (for tests without event loop)
        performSynchronousLoad(instance, selection, url_str, current_generation);
        return;
    };

    // Allocate context for the microtask
    const url_copy = try allocator.dupe(u8, url_str);
    errdefer allocator.free(url_copy);

    const ctx = try allocator.create(LoadMicrotaskContext);
    ctx.* = .{
        .instance = instance,
        .instance_generation = runtime.SlabAllocator.generationOf(instance),
        .generation = current_generation,
        .selection = selection,
        .url = url_copy,
        .allocator = allocator,
    };

    // Queue microtask
    event_loop.queueMicrotask(.{
        .callback = &loadMicrotaskCallback,
        .context = ctx,
    });
}

/// Step 24: the img's lazy loading attribute is in the Lazy state - its
/// value "lazy", ASCII case-insensitive. Missing or any other value is the
/// Eager state (the attribute's missing and invalid value default).
fn isLazy(instance: *runtime.Instance) bool {
    const value = attributeValue(instance, "loading") orelse return false;
    return std.ascii.eqlIgnoreCase(value, "lazy");
}

/// Steps 11 and 13 after the microtask: the current request is broken and
/// both requests are aborted; the task sets the current URL and fires error.
fn breakCurrentRequest(instance: *runtime.Instance, internal: *InternalState) void {
    internal.abortPending();
    internal.current.forgetImage(internal.allocator);
    internal.current.state = .broken;
    internal.current.generation = internal.load_generation;
    // The current request changed: decode() promises waiting on it reject.
    settleDecodes(instance, internal, .reject_all);
}

/// Steps 16-18: abort the pending request; a new image request for
/// `url`, which is the current request if the current one is unavailable
/// or broken, else the pending request.
fn makeImageRequest(instance: *runtime.Instance, internal: *InternalState, url: []const u8, generation: u64, density: f64) void {
    internal.abortPending();
    var request: ImageRequest = .{ .generation = generation, .pixel_density = density };
    request.setUrl(internal.allocator, url);
    request.cors = available_images.CorsSetting.fromAttribute(attributeValue(instance, "crossorigin"));
    if (request.cors != .none) if (interfaces.Node.get_ownerDocument(instance) catch null) |document| {
        if (dom.document_origin.shareable(document) catch null) |origin| request.origin = origin.retain();
    };
    if (internal.current.state == .unavailable or internal.current.state == .broken) {
        internal.current.deinit(internal.allocator);
        internal.current = request;
        // The current request changed.
        settleDecodes(instance, internal, .reject_all);
    } else {
        internal.pending = request;
    }
}

/// The task's first half, for update `generation`: apply `outcome` to the
/// requests (step 27's tasks; steps 11 and 13's). Returns whether the
/// event fires.
fn applyOutcome(instance: *runtime.Instance, internal: *InternalState, generation: u64, outcome: *Outcome) bool {
    const is_pending = if (internal.pending) |pending| pending.generation == generation else false;
    switch (outcome.*) {
        .loaded => |image| {
            // "If image request is the pending request, abort the image
            // request for the current request, upgrade the pending request
            // to the current request"; then "set image request to the
            // completely available state".
            if (is_pending) {
                internal.current.deinit(internal.allocator);
                internal.current = internal.pending.?;
                internal.pending = null;
                settleDecodes(instance, internal, .reject_all);
            }
            internal.current.forgetImage(internal.allocator);
            internal.current.image = image;
            internal.current.state = .completely_available;
            // Step 27's final task, before load: add the image under the
            // request's snapshotted key, with ignore-higher-layer-caching.
            if (internal.current.cors == .none or internal.current.origin != null) {
                if (interfaces.Node.get_ownerDocument(instance) catch null) |document| {
                    if (dom.style.hooks.engineOf(document)) |style_engine| {
                        if (style_engine.ensureAvailableImages()) |cache| {
                            cache.put(.{ .url = internal.current.url, .cors = internal.current.cors, .origin = internal.current.origin }, image) catch {};
                        } else |_| {}
                    }
                }
            }
            outcome.* = .broken; // the image is the request's now
            settleDecodes(instance, internal, Settlement.ofAvailable(image));
            return true;
        },
        .broken => {
            // "Set image request's state to broken, abort the image request
            // for the current request and the pending request, upgrade the
            // pending request to the current request if image request is
            // the pending request".
            if (is_pending) {
                internal.current.deinit(internal.allocator);
                internal.current = internal.pending.?;
                internal.pending = null;
            }
            internal.abortPending();
            internal.current.forgetImage(internal.allocator);
            internal.current.state = .broken;
            settleDecodes(instance, internal, .reject_all);
            return true;
        },
        .no_request => |n| {
            // "Change the current request's current URL to" the empty string
            // (step 11) or the selected source (step 13).
            internal.current.setUrl(internal.allocator, n.url);
            // Step 11: a src attribute or responsive source set.
            if (n.only_with_src) return attributeValue(instance, "src") != null or attributeValue(instance, "srcset") != null;
            return true;
        },
        .cached => |url| {
            internal.current.setUrl(internal.allocator, url);
            return true;
        },
    }
}

/// Fallback synchronous load for environments without event loop (tests)
fn performSynchronousLoad(instance: *runtime.Instance, selection: Selection, url_str: []const u8, generation: u64) void {
    const allocator = instance.ctx.allocator;

    // Check if this load was superseded
    const internal = getInternal(instance) orelse return;
    if (internal.load_generation != generation) {
        return; // Cancelled by a newer load
    }
    defer releaseLoadHold(instance, runtime.SlabAllocator.generationOf(instance), generation);

    const selected = selectedLoad(instance, selection, url_str);
    defer if (selected.owned_url) allocator.free(selected.url);
    var outcome: Outcome = switch (selected.selection) {
        .no_source, .bad_url => blk: {
            breakCurrentRequest(instance, internal);
            const url = allocator.dupe(u8, selected.url) catch return;
            break :blk .{ .no_request = .{ .url = url, .only_with_src = selected.selection == .no_source } };
        },
        .fetch => blk: {
            makeImageRequest(instance, internal, selected.url, generation, selected.density);
            var fetch_result = fetch.webidl.globalFetch(allocator, .{ .url = selected.url }, .{});
            defer fetch_result.deinit();
            // Check generation again after fetch (may have been cancelled during fetch)
            if (internal.load_generation != generation) return;
            break :blk switch (fetch_result) {
                .response => |response| decodeResponse(allocator, response.internal),
                .err => .broken,
            };
        },
        .select_source => unreachable,
    };
    defer outcome.deinit(allocator);

    // Mark as complete
    internal.complete = true;

    // Fire event synchronously (fallback behavior)
    const event_type = outcome.eventType();
    if (applyOutcome(instance, internal, generation, &outcome)) {
        fireEventOnElement(instance, @tagName(event_type)) catch {};
    }
}

/// Microtask callback - runs the "update the image data" algorithm
/// This executes after the current script completes but before the next task
fn loadMicrotaskCallback(data: ?*anyopaque) void {
    const ctx: *LoadMicrotaskContext = @ptrCast(@alignCast(data.?));
    defer ctx.deinit();

    const instance = ctx.instance;
    if (runtime.SlabAllocator.generationOf(instance) != ctx.instance_generation) return;
    const generation = ctx.generation;
    const allocator = ctx.allocator;

    // Step 9: superseded by a newer update.
    const internal = getInternal(instance) orelse return;
    if (internal.load_generation != generation) {
        return; // Cancelled
    }

    const selected = selectedLoad(instance, ctx.selection, ctx.url);
    defer if (selected.owned_url) allocator.free(selected.url);
    switch (selected.selection) {
        // Steps 11 and 13.
        .no_source, .bad_url => {
            breakCurrentRequest(instance, internal);
            internal.complete = true;
            const url = allocator.dupe(u8, selected.url) catch {
                queueImageTask(instance, generation, .broken, allocator);
                return;
            };
            queueImageTask(instance, generation, .{ .no_request = .{ .url = url, .only_with_src = selected.selection == .no_source } }, allocator);
        },
        .fetch => {
            // Steps 16-18.
            makeImageRequest(instance, internal, selected.url, generation, selected.density);
            // "In parallel": the image request is fetched without blocking
            // the event loop; its response arrives from the loop's network
            // step (ImageFetch). One that cannot start is an error.
            startImageFetch(instance, selected.url, generation) catch |err| {
                log.debug("img: the fetch did not start: {s}", .{@errorName(err)});
                internal.complete = true;
                queueImageTask(instance, generation, .broken, allocator);
            };
        },
        .select_source => unreachable,
    }
}

/// Queue the task that applies `outcome` to `instance`'s requests and fires
/// its event, for the update `generation` names (a newer update cancels it
/// when it runs). The task owns `outcome` from here.
fn queueImageTask(instance: *runtime.Instance, generation: u64, outcome: Outcome, allocator: std.mem.Allocator) void {
    var owned = outcome;
    if (getInternal(instance)) |internal| internal.event_pending = true;
    const loop = instance.ctx.getOptionalEventLoop() orelse {
        // No event loop - apply and fire synchronously as fallback
        defer owned.deinit(allocator);
        defer releaseLoadHold(instance, runtime.SlabAllocator.generationOf(instance), generation);
        const internal = getInternal(instance) orelse return;
        internal.event_pending = false;
        const event_type = owned.eventType();
        if (applyOutcome(instance, internal, generation, &owned)) fireEventOnElement(instance, @tagName(event_type)) catch {};
        return;
    };
    const task_ctx = allocator.create(FireEventTaskContext) catch {
        // OOM: the outcome is lost; the request stays as it was, and no
        // event fires.
        owned.deinit(allocator);
        if (getInternal(instance)) |internal| internal.event_pending = false;
        releaseLoadHold(instance, runtime.SlabAllocator.generationOf(instance), generation);
        return;
    };
    task_ctx.* = .{
        .instance = instance,
        .instance_generation = runtime.SlabAllocator.generationOf(instance),
        .generation = generation,
        .outcome = owned,
        .allocator = allocator,
    };
    var task: runtime.EventLoopTask = .{ .callback = fireEventTaskCallback, .context = task_ctx, .drop = dropImageEvent };
    if (getInternal(instance)) |internal| if (internal.document) |document| {
        task.document = document.instance;
        task.document_generation = document.generation;
    };
    loop.queueTask(task);
}

/// The response's body as the image request's image data: typed by MIME
/// Sniffing's rules for images ("the image sniffing rules ... with the
/// image's associated Content-Type headers giving the official type") and
/// decoded through the platform. The response's status is not consulted:
/// "whether the image is fetched successfully or not ... must be ignored
/// when determining the image's type and whether it is a valid image." A
/// network error, or no body, is no image.
///
/// The response is the unfiltered one (AsyncFetch delivers it with its type
/// set): an opaque response's body is still the image's - CORS-cross-origin
/// image data, which a canvas may draw but not read.
fn decodeResponse(allocator: std.mem.Allocator, response: *const fetch.internal.InternalResponse) Outcome {
    const image = available_images.decodeResponse(allocator, response) orelse return .broken;
    return .{ .loaded = image };
}

/// The image request of one "update the image data", fetched in parallel
/// (fetch.algorithms.AsyncFetch, as a link's style sheet is). The loading
/// element's pending-activity hold lasts through its event; slab generations
/// still fence callbacks after forced document teardown.
///
/// Its response is decoded when the whole body has arrived (decodeResponse),
/// and the outcome applied in a task. The document's load event waits for the update
/// (InternalState.load_delay).
const ImageFetch = struct {
    allocator: std.mem.Allocator,
    element: *runtime.Instance,
    element_generation: u64,
    /// The load this fetch is for (InternalState.load_generation).
    load_generation: u64,
    realm: runtime.Context,
    fetch: ?*fetch.algorithms.AsyncFetch = null,

    fn client(self: *ImageFetch) fetch.algorithms.AsyncFetch.Client {
        return .{ .context = self, .done = done, .alive = alive, .gone = gone };
    }

    fn elementIsLive(self: *const ImageFetch) bool {
        return runtime.SlabAllocator.generationOf(self.element) == self.element_generation;
    }

    fn alive(context: *anyopaque) bool {
        const self: *ImageFetch = @ptrCast(@alignCast(context));
        return self.realm.engine_ctx != null and self.elementIsLive();
    }

    /// The element or its realm went with the fetch in flight; the fetch
    /// has been terminated, and no event fires.
    fn gone(context: *anyopaque) void {
        const self: *ImageFetch = @ptrCast(@alignCast(context));
        self.detach();
        self.allocator.destroy(self);
    }

    /// Take this fetch out of its element's state, by identity (DW-N2). The
    /// state is keyed by the element's address and never dereferences the
    /// element, and a state reissued at that address holds its own fetch -
    /// so no liveness gate: one cleared only while the element was live
    /// left a state whose slot a teardown had freed pointing at this fetch,
    /// which `gone` destroys, for that state's cancelFetch to destroy again.
    fn detach(self: *ImageFetch) void {
        self.fetch = null;
        if (getInternal(self.element)) |internal| {
            if (internal.active_fetch == self) internal.active_fetch = null;
        }
    }

    /// The response, body and all: decoded into the image request's image
    /// data, or broken - applied, with load or error, in a task, unless a
    /// newer update superseded this one.
    fn done(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        const self: *ImageFetch = @ptrCast(@alignCast(context));
        self.detach();
        defer self.allocator.destroy(self);
        if (!self.elementIsLive()) {
            if (outcome) |result| {
                var r = result;
                r.deinit();
            } else |_| {}
            return;
        }
        const internal = getInternal(self.element) orelse return;
        const superseded = internal.load_generation != self.load_generation;
        var decoded: Outcome = blk: {
            var result = outcome catch break :blk .broken;
            defer result.deinit();
            if (superseded) break :blk .broken;
            break :blk decodeResponse(self.element.ctx.allocator, result.response);
        };
        if (superseded) {
            decoded.deinit(self.element.ctx.allocator);
            return;
        }
        internal.complete = true;
        queueImageTask(self.element, self.load_generation, decoded, self.element.ctx.allocator);
    }
};

/// HTML "update the image data" step 23's request: "create a potential-CORS
/// request given urlString, "image", and the current state of the element's
/// crossorigin content attribute"; its client the element's node
/// document's relevant settings object; its initiator type "img"; its
/// referrer policy the element's referrerpolicy attribute's state - then
/// fetched in parallel.
fn startImageFetch(instance: *runtime.Instance, url: []const u8, generation: u64) !void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    internal.document = if (interfaces.Node.get_ownerDocument(instance) catch null) |document| same_object.Link.to(document) else null;
    const allocator = instance.ctx.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, url);
    var request_owned = true;
    defer if (request_owned) request.deinit();
    request.destination = .image;
    request.initiator_type = .img;
    // HTML update-the-image-data step 23: responsive image requests use
    // the imageset initiator (distinct from Resource Timing's "img").
    if (attributeValue(instance, "srcset") != null) request.initiator = .imageset;
    // "Create a potential-CORS request": mode "no-cors" for No CORS,
    // "cors" otherwise; credentials "include", or "same-origin" for
    // Anonymous; the use-URL-credentials flag set.
    const cors = attributeValue(instance, "crossorigin");
    if (cors) |state| {
        request.mode = .cors;
        request.credentials_mode = if (std.ascii.eqlIgnoreCase(state, "use-credentials")) .include else .same_origin;
    } else {
        request.mode = .no_cors;
        request.credentials_mode = .include;
    }
    request.use_url_credentials = true;
    request.referrer_policy = fetch.internal.policy_container.referrerPolicyFromAttribute(attributeValue(instance, "referrerpolicy"));
    // The client: the element's node document's relevant settings object -
    // its realm's global's.
    if (realmGlobal(instance.ctx)) |global| {
        var client = try @import("dom").global_settings.requestClient(global);
        defer client.deinit();
        try fetch.internal.populateRequestFromClient(request, client.request);
    }

    const image_fetch = try allocator.create(ImageFetch);
    errdefer allocator.destroy(image_fetch);
    image_fetch.* = .{
        .allocator = allocator,
        .element = instance,
        .element_generation = runtime.SlabAllocator.generationOf(instance),
        .load_generation = generation,
        .realm = instance.ctx,
    };
    // The fetch owns the request from here, even when it fails to start.
    request_owned = false;
    image_fetch.fetch = try fetch.algorithms.AsyncFetch.start(allocator, request, .{}, @import("dom").agent_fetches.of(instance.ctx), image_fetch.client());
    internal.active_fetch = image_fetch;
}

/// The value of `instance`'s attribute `name`, or null when it has none.
fn attributeValue(instance: *runtime.Instance, name: []const u8) ?[]const u8 {
    const value = (Element.call_getAttribute(instance, runtime.DOMString.initInterned(name)) catch return null) orelse return null;
    return value.asSlice();
}

/// The global of `realm`.
fn realmGlobal(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

/// Task callback - fires load/error event on the element
/// This runs as a macrotask, after microtasks complete
fn fireEventTaskCallback(data: ?*anyopaque) void {
    const ctx: *FireEventTaskContext = @ptrCast(@alignCast(data.?));
    defer ctx.deinit();
    defer releaseLoadHold(ctx.instance, ctx.instance_generation, ctx.generation);

    const instance = ctx.instance;
    if (runtime.SlabAllocator.generationOf(instance) != ctx.instance_generation) return;
    const generation = ctx.generation;

    // Final generation check - don't fire if superseded
    const internal = getInternal(instance) orelse return;
    if (internal.load_generation != generation) {
        return; // Cancelled
    }
    internal.event_pending = false;
    // The outcome's steps, then the event.
    ctx.event_type = ctx.outcome.eventType();
    ctx.fire = applyOutcome(instance, internal, generation, &ctx.outcome);
    if (!ctx.fire) return;

    // The task runs from the event loop, not from script: it is run as a task
    // of the element's realm, which enters it. A realm that has gone (the page
    // navigated away) runs nothing, and the task has no one to report to: it
    // is dropped, as a task of a document that is not fully active is.
    engine.runTaskInRealm(instance.ctx, fireEventTaskSteps, ctx) catch {};
}
fn releaseLoadHold(instance: *runtime.Instance, instance_generation: u64, load_generation: u64) void {
    if (runtime.SlabAllocator.generationOf(instance) != instance_generation) return;
    const internal = getInternal(instance) orelse return;
    if (internal.load_generation == load_generation and internal.complete and !internal.event_pending) internal.releaseLoad(instance);
}
fn dropImageEvent(context: ?*anyopaque) void {
    const task: *FireEventTaskContext = @ptrCast(@alignCast(context.?));
    defer task.deinit();
    if (runtime.SlabAllocator.generationOf(task.instance) == task.instance_generation) if (getInternal(task.instance)) |internal| {
        if (internal.load_generation == task.generation) internal.event_pending = false;
    };
    releaseLoadHold(task.instance, task.instance_generation, task.generation);
}

/// The task's steps, inside the element's realm: fire the event.
fn fireEventTaskSteps(data: ?*anyopaque) void {
    const ctx: *FireEventTaskContext = @ptrCast(@alignCast(data.?));
    fireEventOnElement(ctx.instance, @tagName(ctx.event_type)) catch {};
}

/// DOM "fire an event" named `event_type` at the element: an Event created
/// in the element's relevant realm with its type initialized, then
/// dispatched. HTML's image loads fire load and error without bubbles or
/// cancelable ("fire an event named load at the img element").
///
/// The event is made by the constructor, which gives it its internal state
/// and its type: `Event.init` makes a bare instance that `initEvent` then
/// leaves untouched (it returns early on an event without state), so the
/// event this used to build had no type and reached no listener - no img
/// ever fired load or error.
fn fireEventOnElement(instance: *runtime.Instance, event_type: []const u8) !void {
    const event = try Event.call_constructor(
        instance.ctx,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.EventInit).passed(.{ .bubbles = false, .cancelable = false, .composed = false }),
    );
    // Not `defer deinit`: a listener can keep the event, and its wrapper then
    // owns it.
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);

    // Fired by the user agent, so trusted (DOM 2.10). EventTarget is an
    // ancestor, so its impl (existing debt, unchanged).
    _ = try @import("dom").fire_event.dispatchTrusted(instance, event);
}

/// Setter for referrerPolicy
pub fn set_referrerPolicy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try reflection.set(runtime.DOMString, instance, .{ .name = "referrerpolicy" }, value);
}

/// Setter for decoding
pub fn set_decoding(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try reflection.set(runtime.DOMString, instance, .{ .name = "decoding" }, value);
}

/// Setter for loading
pub fn set_loading(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try reflection.set(runtime.DOMString, instance, .{ .name = "loading" }, value);
}

/// Setter for fetchPriority
pub fn set_fetchPriority(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try reflection.set(runtime.DOMString, instance, .{ .name = "fetchpriority" }, value);
}

/// Operation: decode. HTML 4.8.4.1's decode() method steps.
///
/// Not modelled, stated: the node document "stops being fully active"
/// wait (a realm's end drops the waiting promises unsettled).
pub fn call_decode(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // 1. Let promise be a new promise.
    var promise = try engine.createPromise(instance.ctx);
    errdefer engine.releasePromiseCapability(&promise);
    const result = try engine.retainValue(instance.ctx, promise.promise);
    errdefer result.release();
    // 2. Queue a microtask - after update the image data's, which a src
    //    set just before queued.
    const allocator = instance.ctx.allocator;
    const waiting = try allocator.create(DecodeMicrotask);
    errdefer allocator.destroy(waiting);
    waiting.* = .{ .allocator = allocator, .element = same_object.Link.to(instance), .capability = promise };
    try engine.queueRealmMicrotask(instance.ctx, &DecodeMicrotask.steps, waiting);
    // 3. Return promise.
    return result.take();
}

/// decode() step 2's microtask.
const DecodeMicrotask = struct {
    allocator: std.mem.Allocator,
    element: same_object.Link,
    capability: engine.PromiseCapability,

    const steps: engine.PromiseReactionSteps = .{ .fulfilled = run, .dropped = drop };

    fn run(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *DecodeMicrotask = @ptrCast(@alignCast(data.?));
        defer self.allocator.destroy(self);
        const instance = self.element.instance;
        const internal = if (self.element.isLive()) getInternal(instance) else null;
        const state = internal orelse {
            engine.releasePromiseCapability(&self.capability);
            return;
        };
        // 2.2. If the current request is broken, reject promise with an
        //      "EncodingError" DOMException.
        if (state.current.state == .broken) {
            rejectEncodingError(instance.ctx, &self.capability);
            return;
        }
        // 2.3. Otherwise, in parallel, wait for the current request to
        //      change, break or become completely available. Already
        //      completely available: decoded - resolved, or rejected when
        //      its decoding fails - in a task.
        state.decodes.append(state.allocator, .{ .capability = self.capability, .generation = state.current.generation }) catch {
            engine.releasePromiseCapability(&self.capability);
            return;
        };
        if (state.current.state == .completely_available) settleDecodes(instance, state, Settlement.ofAvailable(state.current.image));
    }

    fn drop(data: ?*anyopaque) void {
        const self: *DecodeMicrotask = @ptrCast(@alignCast(data.?));
        engine.releasePromiseCapability(&self.capability);
        self.allocator.destroy(self);
    }
};

/// Reject `capability` with an "EncodingError" DOMException made in `realm`,
/// and release it.
fn rejectEncodingError(realm: runtime.Context, capability: *engine.PromiseCapability) void {
    defer engine.releasePromiseCapability(capability);
    const exception = engine.createDOMException(realm, "EncodingError", "The image cannot be decoded.") catch return;
    defer exception.release();
    engine.rejectPromise(capability, exception.value) catch {};
}

const Settlement = enum {
    /// The current request changed or broke: every waiting promise rejects.
    reject_all,
    /// The current request became completely available and its image
    /// decodes: the promises waiting on it resolve.
    resolve_current,
    /// The current request became completely available but its decoding
    /// fails (DecodedImage.decodingFails): the promises waiting on it
    /// reject.
    reject_current,

    /// The settlement of the promises waiting on a completely available
    /// current request with `image`.
    fn ofAvailable(image: ?DecodedImage) Settlement {
        const decoded = image orelse return .reject_current;
        return if (decoded.decodingFails()) .reject_current else .resolve_current;
    }
};

/// End the decode() promises `settlement` ends: "queue a global task on the
/// DOM manipulation task source" to resolve or reject them.
fn settleDecodes(instance: *runtime.Instance, internal: *InternalState, settlement: Settlement) void {
    if (internal.decodes.items.len == 0) return;
    var taken: std.ArrayList(engine.PromiseCapability) = .empty;
    var i: usize = 0;
    while (i < internal.decodes.items.len) {
        const waiting = internal.decodes.items[i];
        const ends = switch (settlement) {
            .reject_all => true,
            .resolve_current, .reject_current => waiting.generation == internal.current.generation,
        };
        if (!ends) {
            i += 1;
            continue;
        }
        taken.append(internal.allocator, waiting.capability) catch {
            i += 1;
            continue;
        };
        _ = internal.decodes.orderedRemove(i);
    }
    if (taken.items.len == 0) return;
    const task = internal.allocator.create(DecodeTask) catch {
        for (taken.items) |*capability| engine.releasePromiseCapability(capability);
        taken.deinit(internal.allocator);
        return;
    };
    task.* = .{ .allocator = internal.allocator, .realm = instance.ctx, .capabilities = taken, .resolve = settlement == .resolve_current };
    const loop = instance.ctx.getOptionalEventLoop() orelse {
        DecodeTask.run(task);
        return;
    };
    var queued: runtime.EventLoopTask = .{ .callback = DecodeTask.run, .context = task, .drop = DecodeTask.drop };
    if (internal.document) |document| {
        queued.document = document.instance;
        queued.document_generation = document.generation;
    }
    loop.queueTask(queued);
}

/// The global task that settles decode() promises.
const DecodeTask = struct {
    allocator: std.mem.Allocator,
    realm: runtime.Context,
    capabilities: std.ArrayList(engine.PromiseCapability),
    resolve: bool,

    fn run(data: ?*anyopaque) void {
        const self: *DecodeTask = @ptrCast(@alignCast(data.?));
        defer self.deinit();
        engine.runTaskInRealm(self.realm, steps, self) catch {};
    }

    fn steps(data: ?*anyopaque) void {
        const self: *DecodeTask = @ptrCast(@alignCast(data.?));
        for (self.capabilities.items) |*capability| {
            if (self.resolve) {
                engine.resolvePromise(capability, .undefined) catch {};
                engine.releasePromiseCapability(capability);
            } else {
                rejectEncodingError(self.realm, capability);
            }
        }
        self.capabilities.clearRetainingCapacity();
    }

    fn drop(data: ?*anyopaque) void {
        const self: *DecodeTask = @ptrCast(@alignCast(data.?));
        self.deinit();
    }

    fn deinit(self: *DecodeTask) void {
        for (self.capabilities.items) |*capability| engine.releasePromiseCapability(capability);
        self.capabilities.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};
