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

// Event loop for microtask/task queuing
const event_loop_mod = @import("streams_event_loop");

pub const State = HTMLImageElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for HTMLImageElement implementation
///
/// Contains private data for async image loading:
/// - load_generation: Counter for cancellation (newer loads cancel older ones)
/// - current_src: The URL currently being loaded
/// - complete: Whether loading has completed
pub const InternalState = struct {
    /// Generation counter for load cancellation
    /// Each set_src call increments this; older loads check and abort if superseded
    load_generation: u64 = 0,

    /// Whether the image has finished loading (success or error)
    complete: bool = true,

    /// Natural dimensions (0 if not yet loaded or error)
    natural_width: u32 = 0,
    natural_height: u32 = 0,

    /// The allocator used for this internal state
    allocator: std.mem.Allocator = undefined,
    document: ?same_object.Link = null,
    document_abort_pending: ?u64 = null,
    active_fetch: ?*ImageFetch = null,
    event_pending: bool = false,

    fn cancelFetch(self: *InternalState) void {
        self.document_abort_pending = null;
        if (self.active_fetch) |active| {
            self.active_fetch = null;
            if (active.fetch) |transport| transport.terminate();
            active.allocator.destroy(active);
        }
    }

    pub fn deinit(self: *InternalState) void {
        self.cancelFetch();
    }
};

/// Context for microtask callback that initiates image loading
/// This is allocated on the heap and freed after the microtask executes
const LoadMicrotaskContext = struct {
    instance: *runtime.Instance,
    instance_generation: u64,
    generation: u64,
    url: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *LoadMicrotaskContext) void {
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }
};

/// Event type enum for image loading
const ImageEventType = enum { load, @"error" };

/// Context for task callback that fires load/error event
/// This is allocated on the heap and freed after the task executes
const FireEventTaskContext = struct {
    instance: *runtime.Instance,
    instance_generation: u64,
    generation: u64,
    event_type: ImageEventType,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *FireEventTaskContext) void {
        self.allocator.destroy(self);
    }
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

fn getOrCreateInternal(instance: *runtime.Instance) !*InternalState {
    if (Registry.get(instance)) |internal| {
        return internal;
    }

    // Create new internal state using the runtime's arena allocator
    // This ensures proper cleanup during context shutdown
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    // The registry owns this block, so `Registry.remove` returns it to
    // the arena. With `set` it was dropped from the map and held to
    // process exit - measured at 904 bytes per discarded element.
    const internal = try Registry.createIn(instance, ArenaAllocator.get());
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

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (HTMLElement)
    const HTMLElementImpl = @import("HTMLElement.zig");
    const instance = try HTMLElementImpl.init(allocator, StateType, vtable, ctx);
    errdefer HTMLElementImpl.deinit(instance);

    // Initialize internal state for image loading - registered, never looked
    // up: an entry already at this address is a dead img's, and a new img
    // that took it for its own inherited the dead one's request state (or,
    // from an earlier runtime, a block that is gone). createIn frees and
    // reports a dead one's (docs/lessons/architecture-an-address-keyed-entry-a-teardown-misses-is-inherited.md).
    const internal = try Registry.createIn(instance, runtime.ArenaAllocator.get());
    internal.* = .{ .allocator = instance.ctx.allocator };

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up internal state
    if (getInternal(instance)) |internal| internal.cancelFetch();
    removeInternal(instance);

    // Chain to parent class through interface (per Golden Rule #14)
    const HTMLElement = interfaces.HTMLElement;
    HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLImageElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for crossOrigin
pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for width
pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for height
pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for naturalWidth
/// Spec: https://html.spec.whatwg.org/multipage/embedded-content.html#dom-img-naturalwidth
pub fn get_naturalWidth(instance: *runtime.Instance) anyerror!u32 {
    if (getInternal(instance)) |internal| {
        return internal.natural_width;
    }
    return 0;
}

/// Getter for naturalHeight
/// Spec: https://html.spec.whatwg.org/multipage/embedded-content.html#dom-img-naturalheight
pub fn get_naturalHeight(instance: *runtime.Instance) anyerror!u32 {
    if (getInternal(instance)) |internal| {
        return internal.natural_height;
    }
    return 0;
}

/// Getter for complete
/// Spec: https://html.spec.whatwg.org/multipage/embedded-content.html#dom-img-complete
/// Returns true if the image has finished loading (success or error) or has no src
pub fn get_complete(instance: *runtime.Instance) anyerror!bool {
    // Per spec: complete is true if:
    // 1. src attribute is not set (or empty)
    // 2. The image has finished loading (success or error)
    // The content attribute, not the `src` IDL attribute: that one resolves
    // src="" to the document URL, and it is the empty value that counts here.
    const src = try Element.call_getAttributeNS(instance, null, runtime.DOMString.initInterned("src"));
    if (src == null or src.?.isEmpty()) {
        return true; // No src attribute
    }

    if (getInternal(instance)) |internal| {
        return internal.complete;
    }
    return true; // No internal state = complete
}

/// Getter for currentSrc
pub fn get_currentSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for referrerPolicy
pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for decoding
pub fn get_decoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for loading
pub fn get_loading(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fetchPriority
pub fn get_fetchPriority(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
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

/// Getter for attributionSrc
pub fn get_attributionSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sharedStorageWritable
pub fn get_sharedStorageWritable(instance: *runtime.Instance) anyerror!bool {
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
    @import("dom").document_fetches.install(.{ .discard = discardRealm, .prepare_abort = prepareDocumentAbort, .abort = abortDocument });
}
fn prepareDocumentAbort(document: *runtime.Instance) bool {
    var iter = Registry.iterator() orelse return false;
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
    var iter = Registry.iterator() orelse return;
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
        engine.releasePlatformObject(instance);
    }
}
fn discardRealm(realm: runtime.Context) void {
    var iter = Registry.iterator() orelse return;
    while (iter.next()) |entry| {
        const instance: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
        if (instance.ctx != realm) continue;
        entry.internal.cancelFetch();
        entry.internal.load_generation +%= 1;
        entry.internal.complete = true;
        entry.internal.event_pending = false;
        engine.releasePlatformObject(instance);
    }
}

/// The img element's attribute change steps: its relevant mutations - the
/// src, srcset, width or sizes attributes set, changed or removed (src set
/// to its own value included: that restarts animations, which nothing here
/// keeps), the crossorigin or referrerpolicy attribute's state changed.
///
/// Not modelled, stated: the other relevant mutations - the img or a source
/// sibling inserted, removed or moved, a picture parent's source changing,
/// the adopting steps, auto-sizes.
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

/// HTML "update the image data", as far as this engine models it: the
/// selected source is the src attribute (no srcset or picture source
/// selection - stated); a non-empty one is fetched, after a microtask (the
/// spec's "await a stable state"), and load or error fires in a task. A
/// newer update cancels an older one (the generation counter).
fn updateTheImageData(instance: *runtime.Instance) void {
    const src = (Element.call_getAttribute(instance, runtime.DOMString.initInterned("src")) catch return) orelse return;
    if (src.asSlice().len == 0) return;
    // "Parse selected source, relative to the element's node document": the
    // fetch needs an absolute URL. One that does not parse loads nothing.
    const url = resolveAgainstBaseUrl(instance, src.asSlice()) orelse return;
    defer instance.ctx.allocator.free(url);
    startLoad(instance, url) catch |err| log.debug("img: the load did not start: {s}", .{@errorName(err)});
}

/// `url` parsed against `element`'s base URL (its node document's), and
/// serialized; owned by the element's context allocator, null when it does
/// not parse.
fn resolveAgainstBaseUrl(element: *runtime.Instance, url: []const u8) ?[]const u8 {
    const base = interfaces.Node.get_baseURI(element) catch return null;
    defer element.ctx.allocator.free(base);
    const base_arg = if (base.len > 0) webidl.Opt(runtime.USVString).passed(base) else webidl.Opt(runtime.USVString).notPassed();
    const parsed = (interfaces.URL.call_static_parse(element, url, base_arg) catch return null) orelse return null;
    defer runtime.Instance.deinit(parsed);
    return interfaces.URL.get_href(parsed) catch null;
}

/// Setter for src: it reflects the src content attribute
/// (https://html.spec.whatwg.org/multipage/embedded-content.html#dom-img-src),
/// whose change is a relevant mutation: the attribute change steps run
/// "update the image data".
pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const dom_value = runtime.DOMString.initInterned(value);
    try Element.call_setAttribute(instance, runtime.DOMString.initInterned("src"), .{ .domstring = dom_value });
}

/// Start loading `url_str` for `instance`, superseding any load in flight.
///
/// 1. Queue a microtask to run the fetch - so `img.onload = fn` set after
///    `img.src = url` still hears the event.
/// 2. The microtask fetches the image and queues a task to fire the event.
/// 3. A generation counter cancels a load a newer one superseded.
fn startLoad(instance: *runtime.Instance, url_str: []const u8) !void {
    const allocator = instance.ctx.allocator;

    // Skip empty URLs
    if (url_str.len == 0) {
        return;
    }

    // Step 3: Increment generation counter to cancel any pending loads
    const internal = try getOrCreateInternal(instance);
    internal.cancelFetch();
    internal.document = if (interfaces.Node.get_ownerDocument(instance) catch null) |document| same_object.Link.to(document) else null;
    internal.event_pending = false;
    internal.load_generation += 1;
    internal.complete = false; // Mark as loading
    // HTML keeps the element while update-the-image-data is running, even
    // when disconnected. Cancellation and the event's completed task end it.
    engine.keepPlatformObjectAlive(instance);
    errdefer {
        internal.complete = true;
        releaseLoadHold(instance, runtime.SlabAllocator.generationOf(instance), internal.load_generation);
    }
    const current_generation = internal.load_generation;

    // Step 4: Queue a microtask to start the "update the image data" algorithm
    // This allows img.onload to be set after img.src (per spec)
    const event_loop = instance.ctx.getOptionalEventLoop() orelse {
        // No event loop - fall back to synchronous loading (for tests without event loop)
        performSynchronousLoad(instance, url_str, current_generation);
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
        .url = url_copy,
        .allocator = allocator,
    };

    // Queue microtask
    event_loop.queueMicrotask(.{
        .callback = &loadMicrotaskCallback,
        .context = ctx,
    });
}

/// Fallback synchronous load for environments without event loop (tests)
fn performSynchronousLoad(instance: *runtime.Instance, url_str: []const u8, generation: u64) void {
    const allocator = instance.ctx.allocator;

    // Check if this load was superseded
    const internal = getInternal(instance) orelse return;
    if (internal.load_generation != generation) {
        return; // Cancelled by a newer load
    }

    // Perform fetch
    var fetch_result = fetch.webidl.globalFetch(allocator, .{ .url = url_str }, .{});
    defer fetch_result.deinit();
    defer releaseLoadHold(instance, runtime.SlabAllocator.generationOf(instance), generation);

    // Check generation again after fetch (may have been cancelled during fetch)
    if (internal.load_generation != generation) {
        return;
    }

    // Mark as complete
    internal.complete = true;

    // Fire event synchronously (fallback behavior)
    switch (fetch_result) {
        .response => |response| {
            if (response.ok()) {
                fireEventOnElement(instance, "load") catch {};
            } else {
                fireEventOnElement(instance, "error") catch {};
            }
        },
        .err => {
            fireEventOnElement(instance, "error") catch {};
        },
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
    const url_str = ctx.url;
    const allocator = ctx.allocator;

    // Check if this load was superseded by a newer set_src call
    const internal = getInternal(instance) orelse return;
    if (internal.load_generation != generation) {
        return; // Cancelled
    }

    // "In parallel": the image request is fetched without blocking the
    // event loop; its response arrives from the loop's network step
    // (ImageFetch). One that cannot start is an error.
    startImageFetch(instance, url_str, generation) catch |err| {
        log.debug("img: the fetch did not start: {s}", .{@errorName(err)});
        internal.complete = true;
        queueImageEvent(instance, generation, .@"error", allocator);
    };
}

/// Queue the task that fires `event_type` at `instance` for the load
/// `generation` names (a newer load cancels it when it runs).
fn queueImageEvent(instance: *runtime.Instance, generation: u64, event_type: ImageEventType, allocator: std.mem.Allocator) void {
    if (getInternal(instance)) |internal| internal.event_pending = true;
    const event_name = switch (event_type) {
        .load => "load",
        .@"error" => "error",
    };
    const loop = instance.ctx.getOptionalEventLoop() orelse {
        // No event loop - fire event synchronously as fallback
        defer releaseLoadHold(instance, runtime.SlabAllocator.generationOf(instance), generation);
        if (getInternal(instance)) |internal| internal.event_pending = false;
        fireEventOnElement(instance, event_name) catch {};
        return;
    };
    const task_ctx = allocator.create(FireEventTaskContext) catch {
        // OOM - fire synchronously as fallback
        defer releaseLoadHold(instance, runtime.SlabAllocator.generationOf(instance), generation);
        if (getInternal(instance)) |internal| internal.event_pending = false;
        fireEventOnElement(instance, event_name) catch {};
        return;
    };
    task_ctx.* = .{
        .instance = instance,
        .instance_generation = runtime.SlabAllocator.generationOf(instance),
        .generation = generation,
        .event_type = event_type,
        .allocator = allocator,
    };
    var task: runtime.EventLoopTask = .{ .callback = fireEventTaskCallback, .context = task_ctx, .drop = dropImageEvent };
    if (getInternal(instance)) |internal| if (internal.document) |document| {
        task.document = document.instance;
        task.document_generation = document.generation;
    };
    loop.queueTask(task);
}

/// The image request of one "update the image data", fetched in parallel
/// (fetch.algorithms.AsyncFetch, as a link's style sheet is). The loading
/// element's pending-activity hold lasts through its event; slab generations
/// still fence callbacks after forced document teardown.
///
/// Not modelled, stated: the image is not decoded - a response that is not
/// a network error and is ok (or opaque, which cannot be read) is a
/// loaded image; the list of available images; delaying the document's
/// load event.
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

    fn detach(self: *ImageFetch) void {
        self.fetch = null;
        if (self.elementIsLive()) if (getInternal(self.element)) |internal| {
            if (internal.active_fetch == self) internal.active_fetch = null;
        };
    }

    /// The response, body and all: the image is available, or the request
    /// failed - load or error, in a task, unless a newer load superseded
    /// this one.
    fn done(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        const self: *ImageFetch = @ptrCast(@alignCast(context));
        self.detach();
        defer self.allocator.destroy(self);
        const event_type: ImageEventType = blk: {
            var result = outcome catch break :blk .@"error";
            defer result.deinit();
            const response = result.response;
            if (response.response_type == .@"error") break :blk .@"error";
            if (response.response_type == .@"opaque") break :blk .load;
            break :blk if (fetch.internal.isOkStatus(response.status)) .load else .@"error";
        };
        if (!self.elementIsLive()) return;
        const internal = getInternal(self.element) orelse return;
        if (internal.load_generation != self.load_generation) return;
        internal.complete = true;
        queueImageEvent(self.element, self.load_generation, event_type, self.element.ctx.allocator);
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
    image_fetch.fetch = try fetch.algorithms.AsyncFetch.start(allocator, request, .{}, fetch.network.scheduler.threadScheduler(), image_fetch.client());
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

    // The task runs from the event loop, not from script: it is run as a task
    // of the element's realm, which enters it. A realm that has gone (the page
    // navigated away) runs nothing, and the task has no one to report to: it
    // is dropped, as a task of a document that is not fully active is.
    engine.runTaskInRealm(instance.ctx, fireEventTaskSteps, ctx) catch {};
}
fn releaseLoadHold(instance: *runtime.Instance, instance_generation: u64, load_generation: u64) void {
    if (runtime.SlabAllocator.generationOf(instance) != instance_generation) return;
    const internal = getInternal(instance) orelse return;
    if (internal.load_generation == load_generation and internal.complete and !internal.event_pending) engine.releasePlatformObject(instance);
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
    const event_name = switch (ctx.event_type) {
        .load => "load",
        .@"error" => "error",
    };
    fireEventOnElement(ctx.instance, event_name) catch {};
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
    _ = try @import("EventTarget.zig").dispatchTrusted(instance, event);
}

/// Setter for crossOrigin
pub fn set_crossOrigin(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for referrerPolicy
pub fn set_referrerPolicy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for decoding
pub fn set_decoding(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for loading
pub fn set_loading(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for fetchPriority
pub fn set_fetchPriority(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for attributionSrc
pub fn set_attributionSrc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for sharedStorageWritable
pub fn set_sharedStorageWritable(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: decode
pub fn call_decode(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}
