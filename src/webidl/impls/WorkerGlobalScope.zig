//! Implementation for WorkerGlobalScope interface
//!
//! Spec: HTML Standard § 10.1 The WorkerGlobalScope common interface
//! https://html.spec.whatwg.org/#workerglobalscope
//!
//! WorkerGlobalScope is the base interface for all worker global scopes
//! (DedicatedWorkerGlobalScope, SharedWorkerGlobalScope, ServiceWorkerGlobalScope).
//! It provides common functionality like location, navigator, importScripts, etc.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const WorkerGlobalScope = interfaces.WorkerGlobalScope;
const WorkerLocation = interfaces.WorkerLocation;
const WorkerNavigator = interfaces.WorkerNavigator;

// Import workers infrastructure
const html_core = @import("html_core");
const workers = html_core.workers;
const InternalWorkerLocation = workers.WorkerLocation;
const InternalWorkerNavigator = workers.WorkerNavigator;
const WorkerType = workers.WorkerType;

// Import structured clone
const structured_clone = html_core.structured_clone;

// Import event loop for timer support
const event_loop_mod = html_core.event_loop;
const EventLoop = event_loop_mod.EventLoop;
const Timer = event_loop_mod.Timer;

// Import script fetching for importScripts
const script_fetch = html_core.workers.script_fetch;
const FetchedScript = script_fetch.FetchedScript;

pub const State = WorkerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
    NetworkError,
    TypeError,
    OutOfMemory,
};

/// Internal state for WorkerGlobalScope implementation
///
/// Contains cached WorkerLocation and WorkerNavigator objects,
/// as well as worker type information and event loop reference.
pub const InternalState = struct {
    /// Internal WorkerLocation (from src/html/workers/)
    internal_location: ?*InternalWorkerLocation = null,

    /// Internal WorkerNavigator (from src/html/workers/)
    internal_navigator: ?*InternalWorkerNavigator = null,

    /// Cached WebIDL WorkerLocation interface instance
    location_instance: ?*runtime.Instance = null,

    /// Cached WebIDL WorkerNavigator interface instance
    navigator_instance: ?*runtime.Instance = null,

    /// Reference to the worker's event loop (for timer APIs)
    /// This is set when the worker is fully initialized with an event loop.
    event_loop: ?*EventLoop = null,

    /// Worker script URL
    url: []const u8 = "",

    /// Worker type (classic or module)
    worker_type: WorkerType = .classic,

    /// Origin
    origin: []const u8 = "",

    /// Is secure context
    is_secure_context: bool = false,

    /// Cross-origin isolated
    cross_origin_isolated: bool = false,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        // Clean up WebIDL interface instances
        if (self.location_instance) |loc_inst| {
            runtime.Instance.deinit(loc_inst);
        }
        if (self.navigator_instance) |nav_inst| {
            runtime.Instance.deinit(nav_inst);
        }
        // Clean up internal implementations
        if (self.internal_location) |loc| {
            loc.deinit();
        }
        if (self.internal_navigator) |nav| {
            nav.deinit();
        }
        // Note: event_loop is not owned, so we don't deinit it
    }

    /// Set the event loop reference (called after worker initialization)
    pub fn setEventLoop(self: *InternalState, loop: *EventLoop) void {
        self.event_loop = loop;
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Initialize with worker URL and type
pub fn initWithUrl(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    url: []const u8,
    worker_type: WorkerType,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state
    const internal_state = try allocator.create(InternalState);
    errdefer allocator.destroy(internal_state);

    // Create WorkerLocation
    const location = try InternalWorkerLocation.init(allocator, url);
    errdefer location.deinit();

    // Create WorkerNavigator
    const navigator = try InternalWorkerNavigator.init(allocator);
    errdefer navigator.deinit();

    // Determine if secure context
    const is_secure = std.mem.startsWith(u8, url, "https://") or
        std.mem.startsWith(u8, url, "wss://") or
        std.mem.startsWith(u8, url, "file://");

    internal_state.* = .{
        .internal_location = location,
        .internal_navigator = navigator,
        .url = url,
        .worker_type = worker_type,
        .origin = location.getOrigin(),
        .is_secure_context = is_secure,
        .allocator = allocator,
    };

    // Store internal state
    var state = instance.getState(State);
    state.own._internal = internal_state;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Set the event loop reference for this WorkerGlobalScope.
///
/// Must be called after initialization to wire up timer APIs (setTimeout, setInterval).
/// The WorkerAgent or WorkerContext should call this after creating the global scope.
///
/// Spec: HTML Standard § 10.1.4 Worker Event Loops
/// "Each worker has an event loop that is responsible for executing tasks"
pub fn setEventLoop(instance: *runtime.Instance, loop: *EventLoop) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.setEventLoop(loop);
    }
}

/// Getter for self
///
/// Spec: HTML Standard § 10.1
/// "The self attribute must return the WorkerGlobalScope object itself."
pub fn get_self(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return instance;
}

/// Getter for location
///
/// Spec: HTML Standard § 10.1.2
/// "The location attribute must return the WorkerLocation object created for
/// the WorkerGlobalScope object when the worker was created."
pub fn get_location(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // Return cached instance if already created
        if (internal.location_instance) |loc_inst| {
            return loc_inst;
        }

        // Create WorkerLocation interface instance
        if (internal.internal_location) |loc| {
            // Create a new runtime.Instance wrapping the internal location
            const loc_instance = WorkerLocation.init(internal.allocator, instance.ctx) catch {
                return error.OutOfMemory;
            };

            // Get the location state and wire it to the internal location
            const loc_state = loc_instance.getState(WorkerLocation.State);

            // Create WorkerLocation's internal state
            const WorkerLocationImpl = @import("WorkerLocation.zig");
            const loc_internal = internal.allocator.create(WorkerLocationImpl.InternalState) catch {
                runtime.Instance.deinit(loc_instance);
                return error.OutOfMemory;
            };
            loc_internal.* = .{
                .internal_location = loc,
                .allocator = internal.allocator,
            };
            loc_state.own._internal = loc_internal;

            // Cache and return
            internal.location_instance = loc_instance;
            return loc_instance;
        }
    }
    return error.NotImplemented;
}

/// Getter for navigator
///
/// Spec: HTML Standard § 10.1.3
/// "The navigator attribute must return the WorkerNavigator object created for
/// the WorkerGlobalScope object when the worker was created."
pub fn get_navigator(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // Return cached instance if already created
        if (internal.navigator_instance) |nav_inst| {
            return nav_inst;
        }

        // Create WorkerNavigator interface instance
        if (internal.internal_navigator) |nav| {
            // Create a new runtime.Instance wrapping the internal navigator
            const nav_instance = WorkerNavigator.init(internal.allocator, instance.ctx) catch {
                return error.OutOfMemory;
            };

            // Get the navigator state and wire it to the internal navigator
            const nav_state = nav_instance.getState(WorkerNavigator.State);

            // Create WorkerNavigator's internal state
            const WorkerNavigatorImpl = @import("WorkerNavigator.zig");
            const nav_internal = internal.allocator.create(WorkerNavigatorImpl.InternalState) catch {
                runtime.Instance.deinit(nav_instance);
                return error.OutOfMemory;
            };
            nav_internal.* = .{
                .internal_navigator = nav,
                .allocator = internal.allocator,
            };
            nav_state.own._internal = nav_internal;

            // Cache and return
            internal.navigator_instance = nav_instance;
            return nav_instance;
        }
    }
    return error.NotImplemented;
}

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.OnErrorEventHandler {
    const state = instance.getState(State);
    return state.own.onerror;
}

/// Getter for onlanguagechange
pub fn get_onlanguagechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onlanguagechange;
}

/// Getter for onoffline
pub fn get_onoffline(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onoffline;
}

/// Getter for ononline
pub fn get_ononline(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.ononline;
}

/// Getter for onrejectionhandled
pub fn get_onrejectionhandled(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onrejectionhandled;
}

/// Getter for onunhandledrejection
pub fn get_onunhandledrejection(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onunhandledrejection;
}

/// Getter for fonts
pub fn get_fonts(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // FontFaceSet is not yet implemented
    _ = instance;
    return error.NotImplemented;
}

/// Getter for origin
///
/// Spec: HTML Standard § 10.1.1
/// "The origin attribute must return this's relevant settings object's origin,
/// serialized."
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.origin;
    }
    return "null";
}

/// Getter for isSecureContext
///
/// Spec: HTML Standard § 10.1.1
/// "The isSecureContext attribute must return true if this's relevant settings
/// object is a secure context, and false otherwise."
pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.is_secure_context;
    }
    return false;
}

/// Getter for crossOriginIsolated
///
/// Spec: HTML Standard § 10.1.1
/// "The crossOriginIsolated attribute must return this's relevant settings object's
/// cross-origin isolated capability."
pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.cross_origin_isolated;
    }
    return false;
}

/// Getter for indexedDB
pub fn get_indexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for trustedTypes
pub fn get_trustedTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for performance
pub fn get_performance(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for caches
pub fn get_caches(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scheduler
pub fn get_scheduler(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crypto
pub fn get_crypto(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.OnErrorEventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onlanguagechange
pub fn set_onlanguagechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onoffline
pub fn set_onoffline(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ononline
pub fn set_ononline(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onrejectionhandled
pub fn set_onrejectionhandled(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onunhandledrejection
pub fn set_onunhandledrejection(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: reportError
pub fn call_reportError(instance: *runtime.Instance, e: *const anyopaque) anyerror!void {
    _ = instance;
    _ = e;
    return error.NotImplemented;
}

/// Operation: atob
///
/// Spec: HTML Standard § 8.3 Base64 utility methods
/// https://html.spec.whatwg.org/#dom-atob
///
/// "The atob(data) method must run the following steps:
/// 1. Let decodedData be the result of running forgiving-base64 decode on data.
/// 2. If decodedData is failure, then throw an "InvalidCharacterError" DOMException.
/// 3. Return decodedData."
pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.ByteString {
    const input = data.asSlice();

    // Handle empty input - ByteString is just []const u8
    if (input.len == 0) {
        return "";
    }

    // Calculate decoded length using standard library function
    const state = instance.getState(State);
    const allocator = if (state.own._internal) |internal| internal.allocator else std.heap.page_allocator;

    // Use calcSizeForSlice to get exact decoded length
    const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(input) catch {
        return error.InvalidCharacter;
    };

    // Allocate buffer for decoded data
    const buffer = allocator.alloc(u8, decoded_len) catch return error.OutOfMemory;
    errdefer allocator.free(buffer);

    // Decode using standard base64 - decode returns void on success
    std.base64.standard.Decoder.decode(buffer, input) catch {
        allocator.free(buffer);
        return error.InvalidCharacter;
    };

    // Return the buffer - ByteString is just []const u8
    // NOTE: The caller is responsible for freeing this buffer
    return buffer;
}

/// Operation: btoa
///
/// Spec: HTML Standard § 8.3 Base64 utility methods
/// https://html.spec.whatwg.org/#dom-btoa
///
/// "The btoa(data) method must run the following steps:
/// 1. If data contains any character whose code point is greater than U+00FF,
///    throw an "InvalidCharacterError" DOMException.
/// 2. Return the forgiving-base64 encode of data."
pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.DOMString {
    const input = data.asSlice();

    // Step 1: Validate all characters are in Latin-1 range (U+0000 to U+00FF)
    // Since we're dealing with bytes (0-255), this is implicitly satisfied

    // Handle empty input
    if (input.len == 0) {
        return runtime.DOMString.initEmpty();
    }

    // Step 2: Encode to base64
    const state = instance.getState(State);
    const allocator = if (state.own._internal) |internal| internal.allocator else std.heap.page_allocator;

    // Calculate encoded length
    const encoded_len = std.base64.standard.Encoder.calcSize(input.len);
    const buffer = allocator.alloc(u8, encoded_len) catch return error.OutOfMemory;
    errdefer allocator.free(buffer);

    // Encode - returns a slice into buffer
    const encoded = std.base64.standard.Encoder.encode(buffer, input);

    // DOMString.initOwned takes just the slice, allocator is tracked elsewhere
    // NOTE: The caller is responsible for freeing via DOMString.deinit(allocator)
    return runtime.DOMString.initOwned(encoded);
}

/// Operation: setInterval
///
/// Spec: HTML Standard § 8.6 Timers
/// https://html.spec.whatwg.org/#dom-setinterval
///
/// Sets a repeating timer that fires at the specified interval.
pub fn call_setInterval(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const *const anyopaque) anyerror!i32 {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.event_loop) |event_loop| {
            // Get delay (default to 0 if not provided)
            const delay_ms: i64 = if (timeout.wasPassed())
                @intCast(timeout.getValue())
            else
                0;

            // TODO: Proper callback conversion
            // The handler needs to be wrapped to call the JavaScript function.
            // For now, we create a no-op callback - real implementation needs V8 integration.
            _ = handler;
            _ = arguments;

            const timer_id = event_loop.setInterval(
                &noopTimerCallback,
                delay_ms,
                null,
            ) catch return error.OutOfMemory;

            return @intCast(timer_id);
        }
    }
    return error.NotImplemented;
}

/// No-op timer callback used as placeholder until proper V8 callback integration
fn noopTimerCallback(_: ?*anyopaque) void {
    // TODO: This should invoke the actual JavaScript callback
    // Real implementation needs:
    // 1. Store timer_id -> handler mapping
    // 2. When callback fires, look up handler
    // 3. Call JavaScript function via V8
}

/// Operation: createImageBitmap
pub fn call_createImageBitmap(instance: *runtime.Instance, image: typedefs.ImageBitmapSource, options: webidl.Opt(dictionaries.ImageBitmapOptions)) anyerror!*const anyopaque {
    _ = instance;
    _ = image;
    _ = options;
    return error.NotImplemented;
}

/// Operation: clearInterval
///
/// Spec: HTML Standard § 8.6 Timers
/// https://html.spec.whatwg.org/#dom-clearinterval
///
/// Cancels a repeating timer.
pub fn call_clearInterval(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    if (!id.wasPassed()) {
        return; // No-op if no ID provided
    }

    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.event_loop) |event_loop| {
            event_loop.clearInterval(@intCast(id.getValue()));
            return;
        }
    }
    return error.NotImplemented;
}

/// Operation: queueMicrotask
pub fn call_queueMicrotask(instance: *runtime.Instance, callback: callbacks.VoidFunction) anyerror!void {
    _ = instance;
    _ = callback;
    return error.NotImplemented;
}

/// Operation: structuredClone
///
/// Spec: HTML Standard § 2.7.9 structuredClone(value, options)
/// https://html.spec.whatwg.org/#dom-structuredclone
///
/// "The structuredClone(value, options) method, when invoked, must run these steps:
/// 1. Let serialized be ? StructuredSerializeWithTransfer(value, options["transfer"]).
/// 2. Let deserializeRecord be ? StructuredDeserializeWithTransfer(serialized, this's relevant Realm).
/// 3. Return deserializeRecord.[[Deserialized]]."
pub fn call_structuredClone(instance: *runtime.Instance, value: *const anyopaque, options: webidl.Opt(dictionaries.StructuredSerializeOptions)) anyerror!*const anyopaque {
    // Get allocator from instance
    const state = instance.getState(State);
    if (state.own._internal == null) {
        return error.NotImplemented;
    }
    const internal = state.own._internal.?;

    // Parse options for transfer list
    const transfer_list: ?[]structured_clone.Transferable = if (options.wasPassed()) blk: {
        // Transfer list parsing would be done here
        _ = options.getValue();
        break :blk null;
    } else null;

    // The value parameter represents the JavaScript value to clone
    // In a full implementation, this would be properly converted to JSValue
    // based on the actual JavaScript type. For now, treat as undefined if null.
    const js_value = if (@intFromPtr(value) != 0)
        // Non-null value - simplified handling
        structured_clone.JSValue{ .object = .{ .properties = &[_]structured_clone.JSValue.ObjectValue.ObjectProperty{} } }
    else
        structured_clone.JSValue.undefined;

    // Perform structured clone
    const cloned = structured_clone.structuredClone(
        internal.allocator,
        &js_value,
        transfer_list,
    ) catch {
        return error.OutOfMemory;
    };

    // Return as opaque pointer
    return @ptrCast(cloned);
}

/// Operation: importScripts
///
/// Spec: HTML Standard § 10.1.5 importScripts(urls...)
/// https://html.spec.whatwg.org/#dom-workerglobalscope-importscripts
///
/// "The importScripts(urls) method, when invoked, must run these steps:
/// 1. If this is a module script, throw a TypeError exception.
/// 2. Let settings object be this's relevant settings object.
/// 3. If urls is empty, return.
/// 4. Parse each value in urls, relative to settings object...
/// 5. For each url in the resulting URL records, fetch the script..."
pub fn call_importScripts(instance: *runtime.Instance, urls: []const runtime.DOMString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.NotImplemented;

    // Step 1: Check if module worker
    // Spec: "throw a TypeError exception" for module workers
    if (internal.worker_type == .module) {
        return error.TypeError;
    }

    // Step 3: If urls is empty, return
    if (urls.len == 0) {
        return;
    }

    // Steps 4-5: Parse and fetch each script in order
    // Per spec, scripts are fetched and executed synchronously in order
    for (urls) |url| {
        const url_str = url.asSlice();
        if (url_str.len == 0) {
            continue;
        }

        // Fetch the script using the script_fetch module
        var fetched = script_fetch.fetchWorkerScript(internal.allocator, url_str, .{
            .worker_type = .classic,
            .origin = internal.origin,
            .credentials = .same_origin,
            .is_import_scripts = true,
        }) catch |err| {
            return switch (err) {
                script_fetch.WorkerScriptError.NetworkError => error.NetworkError,
                script_fetch.WorkerScriptError.InvalidUrl => error.TypeError,
                script_fetch.WorkerScriptError.ModuleNotAllowed => error.TypeError,
                script_fetch.WorkerScriptError.OutOfMemory => error.OutOfMemory,
                else => error.NetworkError,
            };
        };
        defer fetched.deinit();

        // Execute the script
        // NOTE: Script execution requires access to the worker's V8 context.
        // The WorkerAgent.executeScript() should be called here, but we don't
        // have direct access to it from the WebIDL implementation layer.
        // For now, we just verify the script was fetched successfully.
        // Full integration would need:
        // 1. Access to the WorkerAgent through a stored reference
        // 2. Call agent.executeScript(fetched.source)
        //
        // The script source is available in fetched.source for execution.
        _ = fetched.source;
    }
}

/// Operation: clearTimeout
///
/// Spec: HTML Standard § 8.6 Timers
/// https://html.spec.whatwg.org/#dom-cleartimeout
///
/// Cancels a one-shot timer.
pub fn call_clearTimeout(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    if (!id.wasPassed()) {
        return; // No-op if no ID provided
    }

    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.event_loop) |event_loop| {
            event_loop.clearTimeout(@intCast(id.getValue()));
            return;
        }
    }
    return error.NotImplemented;
}

/// Operation: setTimeout
///
/// Spec: HTML Standard § 8.6 Timers
/// https://html.spec.whatwg.org/#dom-settimeout
///
/// Sets a one-shot timer that fires after the specified delay.
pub fn call_setTimeout(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const *const anyopaque) anyerror!i32 {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.event_loop) |event_loop| {
            // Get delay (default to 0 if not provided)
            const delay_ms: i64 = if (timeout.wasPassed())
                @intCast(timeout.getValue())
            else
                0;

            // TODO: Proper callback conversion
            // The handler needs to be wrapped to call the JavaScript function.
            // For now, we create a no-op callback - real implementation needs V8 integration.
            _ = handler;
            _ = arguments;

            const timer_id = event_loop.setTimeout(
                &noopTimerCallback,
                delay_ms,
                null,
            ) catch return error.OutOfMemory;

            return @intCast(timer_id);
        }
    }
    return error.NotImplemented;
}

/// Operation: fetch
///
/// Spec: Fetch Standard § 5.4 Fetch method
/// https://fetch.spec.whatwg.org/#fetch-method
///
/// "The fetch(input, init) method, when invoked, must run these steps:
/// 1. Let p be a new promise.
/// 2. Let requestObject be the result of invoking the initial value of
///    Request as constructor with input and init as arguments.
/// 3. Let request be requestObject's request.
/// 4. Fetch request with processResponseConsumeBody set to...
/// 5. Return p."
///
/// Implementation:
/// - Creates a V8 Promise to return to JavaScript
/// - Parses RequestInfo into an InternalRequest
/// - Executes the fetch algorithm
/// - Resolves/rejects the Promise with the Response
pub fn call_fetch(instance: *runtime.Instance, input: typedefs.RequestInfo, init_data: webidl.Opt(dictionaries.RequestInit)) anyerror!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.NotImplemented;
    const allocator = internal.allocator;

    // Step 1: Get the URL from RequestInfo
    // RequestInfo is either a URL string or a Request object
    const url_str: []const u8 = switch (input) {
        .variant_1 => |url| url, // USVString (URL)
        .variant_0 => {
            // Request object - extract URL
            // For now, we don't have access to Request's URL directly from anyopaque
            // This requires the Request interface to expose its URL
            return error.NotImplemented; // TODO: Extract URL from Request object
        },
    };

    // Step 2: Create InternalRequest
    // Import fetch module
    const fetch_mod = @import("fetch");
    const InternalRequest = fetch_mod.internal.request.InternalRequest;
    const Response = fetch_mod.Response;

    var request = InternalRequest.init(allocator, url_str) catch {
        return error.OutOfMemory;
    };
    errdefer request.deinit();

    // Step 3: Apply init options if provided
    if (init_data.wasPassed()) {
        const req_init = init_data.getValue();

        // Apply method
        if (req_init.method) |method_str| {
            request.setMethod(method_str) catch {};
        }

        // Apply mode
        if (req_init.mode) |mode| {
            request.mode = switch (mode) {
                ._cors_ => .cors,
                ._no_cors_ => .no_cors,
                ._same_origin_ => .same_origin,
                ._navigate_ => .navigate,
            };
        }

        // Apply credentials
        if (req_init.credentials) |creds| {
            request.credentials_mode = switch (creds) {
                ._omit_ => .omit,
                ._same_origin_ => .same_origin,
                ._include_ => .include,
            };
        }

        // Apply cache mode
        if (req_init.cache) |cache_mode| {
            request.cache_mode = switch (cache_mode) {
                ._default_ => .default,
                ._no_store_ => .no_store,
                ._reload_ => .reload,
                ._no_cache_ => .no_cache,
                ._force_cache_ => .force_cache,
                ._only_if_cached_ => .only_if_cached,
            };
        }

        // Apply redirect mode
        if (req_init.redirect) |redirect_mode| {
            request.redirect_mode = switch (redirect_mode) {
                ._follow_ => .follow,
                ._error_ => .@"error",
                ._manual_ => .manual,
            };
        }

        // Apply referrer policy
        if (req_init.referrerPolicy) |ref_policy| {
            request.referrer_policy = switch (ref_policy) {
                .__ => .empty,
                ._no_referrer_ => .no_referrer,
                ._no_referrer_when_downgrade_ => .no_referrer_when_downgrade,
                ._same_origin_ => .same_origin,
                ._origin_ => .origin,
                ._strict_origin_ => .strict_origin,
                ._origin_when_cross_origin_ => .origin_when_cross_origin,
                ._strict_origin_when_cross_origin_ => .strict_origin_when_cross_origin,
                ._unsafe_url_ => .unsafe_url,
            };
        }

        // Apply keepalive
        if (req_init.keepalive) |keepalive| {
            request.keepalive = keepalive;
        }

        // Apply integrity
        if (req_init.integrity) |integrity| {
            request.integrity_metadata = integrity.asSlice();
        }
    }

    // Set origin from worker's settings object
    if (internal.origin.len > 0) {
        request.origin = .{ .origin = internal.origin };
    }

    // Step 4: Execute fetch algorithm
    // For now, we execute synchronously. Full async requires V8 Promise integration.
    // The V8 Promise API is available in src/runtime/engines/v8/promise.zig
    // but requires V8 Isolate and Context which aren't directly accessible here.
    var fetch_result = fetch_mod.fetch(allocator, request, .{
        .cross_origin_isolated_capability = internal.cross_origin_isolated,
    }) catch |err| {
        request.deinit();
        return switch (err) {
            fetch_mod.FetchError.OutOfMemory => error.OutOfMemory,
            fetch_mod.FetchError.NetworkError => error.NetworkError,
            fetch_mod.FetchError.AbortError => error.NetworkError,
        };
    };
    defer fetch_result.timing_info.deinit();

    // Request is now consumed
    request.deinit();

    // Step 5: Create Response WebIDL object from InternalResponse
    const response = Response.fromInternal(allocator, fetch_result.response) catch {
        fetch_result.response.deinit();
        return error.OutOfMemory;
    };
    // Note: ownership of fetch_result.response is transferred to Response

    // Return the Response object as opaque pointer
    // In a full Promise-based implementation, we would:
    // 1. Create a V8 Promise (Promise(void).init(isolate, context))
    // 2. Schedule async fetch task on event loop
    // 3. Return promise.getPromise() cast to *const anyopaque
    // 4. When fetch completes, resolve promise with Response
    //
    // For now, we return the Response synchronously
    return @ptrCast(response);
}
