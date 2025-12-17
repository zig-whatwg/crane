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
const runtime = @import("runtime");
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

// Event loop for microtask/task queuing
const event_loop_mod = @import("event_loop");

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
};

/// Context for microtask callback that initiates image loading
/// This is allocated on the heap and freed after the microtask executes
const LoadMicrotaskContext = struct {
    instance: *runtime.Instance,
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
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = .{
        .allocator = instance.ctx.allocator,
    };
    try Registry.set(instance, internal);
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

    // Initialize internal state for image loading
    _ = try getOrCreateInternal(instance);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up internal state
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

/// Getter for alt
pub fn get_alt(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for src - reflects the "src" content attribute
/// Spec: https://html.spec.whatwg.org/multipage/embedded-content.html#dom-img-src
pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString {
    // Get the src attribute value, returning empty string if not set
    const attr_value = try Element.call_getAttribute(instance, runtime.DOMString.initInterned("src"));
    if (attr_value) |val| {
        // USVString is []const u8, DOMString has asSlice() method
        return val.asSlice();
    }
    return "";
}

/// Getter for srcset
pub fn get_srcset(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sizes
pub fn get_sizes(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crossOrigin
pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for useMap
pub fn get_useMap(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for isMap
pub fn get_isMap(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
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
    const src = try get_src(instance);
    if (src.len == 0) {
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

/// Getter for name
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lowsrc
pub fn get_lowsrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for align
pub fn get_align(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for hspace
pub fn get_hspace(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for vspace
pub fn get_vspace(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for longDesc
pub fn get_longDesc(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for border
pub fn get_border(instance: *runtime.Instance) anyerror!runtime.DOMString {
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

/// Setter for alt
pub fn set_alt(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for src - sets the "src" content attribute and initiates async image loading
/// Spec: https://html.spec.whatwg.org/multipage/embedded-content.html#dom-img-src
///
/// Per HTML spec §4.8.3, when src is set:
/// 1. Set the src content attribute on the element
/// 2. Queue a microtask to run the "update the image data" algorithm
///    - This allows `img.onload = fn` to be set AFTER `img.src = url`
/// 3. The microtask fetches the image and queues a task to fire events
///    - Events fire asynchronously via task queue (macrotask), not synchronously
/// 4. Generation counter enables cancellation if src changes before load completes
pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const allocator = instance.ctx.allocator;

    // Step 1: Set the src attribute using Element.setAttribute
    const dom_value = runtime.DOMString.initInterned(value);
    try Element.call_setAttribute(instance, runtime.DOMString.initInterned("src"), dom_value);

    // Step 2: Get the URL string from the value (USVString is already []const u8)
    const url_str = value;

    // Skip empty URLs
    if (url_str.len == 0) {
        return;
    }

    // Step 3: Increment generation counter to cancel any pending loads
    const internal = try getOrCreateInternal(instance);
    internal.load_generation += 1;
    internal.complete = false; // Mark as loading
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
    const generation = ctx.generation;
    const url_str = ctx.url;
    const allocator = ctx.allocator;

    // Check if this load was superseded by a newer set_src call
    const internal = getInternal(instance) orelse return;
    if (internal.load_generation != generation) {
        return; // Cancelled
    }

    // Perform the fetch
    var fetch_result = fetch.webidl.globalFetch(allocator, .{ .url = url_str }, .{});
    defer fetch_result.deinit();

    // Check generation again after fetch
    if (internal.load_generation != generation) {
        return; // Cancelled during fetch
    }

    // Mark as complete
    internal.complete = true;

    // Determine event type based on fetch result
    const event_type: ImageEventType = switch (fetch_result) {
        .response => |response| if (response.ok()) .load else .@"error",
        .err => .@"error",
    };

    // Queue a task to fire the event (per spec, events fire via task queue)
    // Use setTimeout(0) for task queue semantics
    const timer = instance.ctx.getOptionalTimer() orelse {
        // No timer support - fire event synchronously as fallback
        const event_name = switch (event_type) {
            .load => "load",
            .@"error" => "error",
        };
        fireEventOnElement(instance, event_name) catch {};
        return;
    };

    // Allocate task context
    const task_ctx = allocator.create(FireEventTaskContext) catch {
        // OOM - fire synchronously as fallback
        const event_name = switch (event_type) {
            .load => "load",
            .@"error" => "error",
        };
        fireEventOnElement(instance, event_name) catch {};
        return;
    };
    task_ctx.* = .{
        .instance = instance,
        .generation = generation,
        .event_type = event_type,
        .allocator = allocator,
    };

    // Schedule task via setTimeout(0)
    _ = timer.setTimeout(0, &fireEventTaskCallback, task_ctx);
}

/// Task callback - fires load/error event on the element
/// This runs as a macrotask, after microtasks complete
fn fireEventTaskCallback(data: ?*anyopaque) void {
    const ctx: *FireEventTaskContext = @ptrCast(@alignCast(data.?));
    defer ctx.deinit();

    const instance = ctx.instance;
    const generation = ctx.generation;

    // Final generation check - don't fire if superseded
    const internal = getInternal(instance) orelse return;
    if (internal.load_generation != generation) {
        return; // Cancelled
    }

    // Fire the event
    const event_name = switch (ctx.event_type) {
        .load => "load",
        .@"error" => "error",
    };
    fireEventOnElement(instance, event_name) catch {};
}

/// Helper function to create and dispatch an event on an element
fn fireEventOnElement(instance: *runtime.Instance, event_type: []const u8) !void {
    const allocator = instance.ctx.allocator;
    const ctx = instance.ctx;

    // Create the event using the interface's init function (2 args, not 4)
    const event = try Event.init(allocator, ctx);
    errdefer Event.deinit(event);

    // Initialize the event with the given type
    // Per spec: bubbles = true for load/error events on elements, cancelable = false
    const event_type_str = runtime.DOMString.initInterned(event_type);
    const bubbles = webidl.Opt(bool).passed(true);
    const cancelable = webidl.Opt(bool).passed(false);
    try Event.call_initEvent(event, event_type_str, bubbles, cancelable);

    // Dispatch the event on the element
    // HTMLImageElement inherits from Element which inherits from EventTarget
    _ = try EventTarget.call_dispatchEvent(instance, event);
}

/// Setter for srcset
pub fn set_srcset(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for sizes
pub fn set_sizes(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for crossOrigin
pub fn set_crossOrigin(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for useMap
pub fn set_useMap(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for isMap
pub fn set_isMap(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for width
pub fn set_width(instance: *runtime.Instance, value: u32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for height
pub fn set_height(instance: *runtime.Instance, value: u32) anyerror!void {
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

/// Setter for name
pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for lowsrc
pub fn set_lowsrc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for align
pub fn set_align(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for hspace
pub fn set_hspace(instance: *runtime.Instance, value: u32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for vspace
pub fn set_vspace(instance: *runtime.Instance, value: u32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for longDesc
pub fn set_longDesc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for border
pub fn set_border(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
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

/// Operation: setAttribute override
/// Intercepts src attribute changes to trigger image loading per HTML spec.
/// For all other attributes, delegates to Element.call_setAttribute.
/// Spec: https://html.spec.whatwg.org/multipage/images.html#update-the-image-data
pub fn call_setAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString, value: runtime.DOMString) anyerror!void {
    // Check if this is the "src" attribute
    const attr_name = qualifiedName.asSlice();
    if (std.mem.eql(u8, attr_name, "src")) {
        // Delegate to set_src which handles the full async loading flow
        // set_src will call Element.call_setAttribute internally
        try set_src(instance, value.asSlice());
    } else {
        // For all other attributes, just delegate to Element
        try Element.call_setAttribute(instance, qualifiedName, value);
    }
}
