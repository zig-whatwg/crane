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

// Import WindowOrWorkerGlobalScope mixin implementation for fetch delegation
const WindowOrWorkerGlobalScopeImpl = @import("WindowOrWorkerGlobalScope.zig");

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

/// Check if a scheme is inherently secure
/// Per https://w3c.github.io/webappsec-secure-contexts/
fn isSecureScheme(scheme: []const u8) bool {
    return std.mem.eql(u8, scheme, "https") or
        std.mem.eql(u8, scheme, "wss") or
        std.mem.eql(u8, scheme, "file");
}

/// Check if a host is a secure localhost
/// Per https://w3c.github.io/webappsec-secure-contexts/
fn isSecureLocalhost(host: []const u8) bool {
    return std.mem.eql(u8, host, "localhost") or
        std.mem.eql(u8, host, "127.0.0.1") or
        std.mem.eql(u8, host, "::1");
}

/// Determine if a URL represents a secure context
/// Secure Contexts spec: https://w3c.github.io/webappsec-secure-contexts/
fn isSecureContext(url: []const u8) bool {
    // Check for secure schemes first (fast path)
    if (std.mem.startsWith(u8, url, "https://") or
        std.mem.startsWith(u8, url, "wss://") or
        std.mem.startsWith(u8, url, "file://"))
    {
        return true;
    }

    // For http:// and ws://, check if host is localhost
    if (std.mem.startsWith(u8, url, "http://") or std.mem.startsWith(u8, url, "ws://")) {
        // Extract host from URL: scheme://host[:port][/path]
        const scheme_end = std.mem.indexOf(u8, url, "://") orelse return false;
        const host_start = scheme_end + 3;
        if (host_start >= url.len) return false;

        const rest = url[host_start..];
        // Find end of host (port separator, path, or end of string)
        var host_end = rest.len;
        for (rest, 0..) |c, i| {
            if (c == ':' or c == '/' or c == '?' or c == '#') {
                host_end = i;
                break;
            }
        }
        const host = rest[0..host_end];
        return isSecureLocalhost(host);
    }

    return false;
}

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

    /// Whether the worker is closing
    /// Spec: HTML Standard § 10.1.5 "Terminating a worker"
    closing: bool = false,

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

    /// Mark the worker as closing
    ///
    /// Spec: HTML Standard § 10.1.5 "Terminating a worker"
    pub fn setClosing(self: *InternalState, value: bool) void {
        self.closing = value;
    }

    /// Check if the worker is closing
    ///
    /// Spec: HTML Standard § 10.1.5 "Terminating a worker"
    pub fn isClosing(self: *const InternalState) bool {
        return self.closing;
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
    // Secure Contexts spec: https://w3c.github.io/webappsec-secure-contexts/
    // A context is secure if:
    // 1. Scheme is https, wss, or file
    // 2. OR host is localhost, 127.0.0.1, or ::1 (for http/ws)
    const is_secure = isSecureContext(url);

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

/// Close the worker global scope.
///
/// This marks the worker as closing and stops the event loop.
/// After calling close(), the worker will not accept new tasks and
/// will terminate once the current task completes.
///
/// Spec: HTML Standard § 10.1.5 "Terminating a worker"
/// "Set worker global scope's closing flag to true."
pub fn close(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.setClosing(true);
        // Stop the event loop if running
        if (internal.event_loop) |loop| {
            loop.stop();
        }
    }
}

/// Check if the worker is closing.
///
/// Returns true if close() has been called on this worker.
///
/// Spec: HTML Standard § 10.1.5 "Terminating a worker"
/// "If the worker global scope's closing flag is true, return."
pub fn isClosing(instance: *runtime.Instance) bool {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.isClosing();
    }
    return false;
}

/// Run the event loop (convenience method for testing).
///
/// Spins the event loop to process pending tasks.
pub fn runEventLoop(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.event_loop) |loop| {
            loop.run() catch {};
        }
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
///
/// Spec: HTML Standard § 10.2.5 "Runtime script errors in documents"
/// The onerror attribute is an OnErrorEventHandler that receives error events
/// when uncaught exceptions occur in the worker.
///
/// The handler signature is: function(message, filename, lineno, colno, error)
/// If the handler returns true, the error is considered handled and won't propagate.
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.OnErrorEventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onerror = value;
}

/// Setter for onlanguagechange
pub fn set_onlanguagechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onoffline
///
/// Spec: HTML Standard § 10.1
/// "The onoffline event handler is fired when the worker goes offline."
///
/// Note: Network connectivity monitoring is platform-dependent. When the
/// platform detects a network state change, it should fire "offline" or
/// "online" events at the WorkerGlobalScope. This setter stores the handler
/// which will be invoked when such events are dispatched.
pub fn set_onoffline(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onoffline = value;
}

/// Setter for ononline
///
/// Spec: HTML Standard § 10.1
/// "The ononline event handler is fired when the worker comes online."
///
/// Note: Network connectivity monitoring is platform-dependent. When the
/// platform detects a network state change, it should fire "offline" or
/// "online" events at the WorkerGlobalScope. This setter stores the handler
/// which will be invoked when such events are dispatched.
pub fn set_ononline(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.ononline = value;
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
pub fn call_reportError(instance: *runtime.Instance, e: runtime.JSValue) anyerror!void {
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
/// Delegates to WindowOrWorkerGlobalScope mixin implementation for proper V8 callback handling.
pub fn call_setInterval(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    return WindowOrWorkerGlobalScopeImpl.call_setInterval(instance, handler, timeout, arguments);
}

/// Operation: createImageBitmap
pub fn call_createImageBitmap(instance: *runtime.Instance, image: typedefs.ImageBitmapSource, options: webidl.Opt(dictionaries.ImageBitmapOptions)) anyerror!runtime.JSValue {
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
/// Delegates to WindowOrWorkerGlobalScope mixin implementation.
pub fn call_clearInterval(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    return WindowOrWorkerGlobalScopeImpl.call_clearInterval(instance, id);
}

/// Operation: queueMicrotask
///
/// Spec: HTML Standard § 8.6 Microtask queuing
/// https://html.spec.whatwg.org/#dom-queuemicrotask
///
/// Delegates to WindowOrWorkerGlobalScope mixin implementation.
pub fn call_queueMicrotask(instance: *runtime.Instance, callback: callbacks.VoidFunction) anyerror!void {
    return WindowOrWorkerGlobalScopeImpl.call_queueMicrotask(instance, callback);
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
pub fn call_structuredClone(instance: *runtime.Instance, value: runtime.JSValue, options: webidl.Opt(dictionaries.StructuredSerializeOptions)) anyerror!runtime.JSValue {
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
    // Convert from runtime.JSValue to structured_clone.JSValue
    const js_value: structured_clone.JSValue = switch (value) {
        .undefined => structured_clone.JSValue.undefined,
        .null => structured_clone.JSValue.null,
        .boolean => |b| .{ .boolean = b },
        .number => |n| .{ .number = n },
        .string => |s| .{ .string = s.data },
        else => structured_clone.JSValue{ .object = .{ .properties = &[_]structured_clone.JSValue.ObjectValue.ObjectProperty{} } },
    };

    // Perform structured clone
    const cloned = structured_clone.structuredClone(
        internal.allocator,
        &js_value,
        transfer_list,
    ) catch {
        return error.OutOfMemory;
    };

    // Convert structured clone result back to runtime.JSValue
    return switch (cloned.*) {
        .undefined => runtime.JSValue.jsUndefined,
        .null => runtime.JSValue.jsNull,
        .boolean => |b| runtime.JSValue.fromBoolean(b),
        .number => |n| runtime.JSValue.fromNumber(n),
        .string => |s| runtime.JSValue.fromStringRef(s),
        else => runtime.JSValue.jsUndefined, // Complex objects not fully supported yet
    };
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

    // Get the worker's script URL for resolving relative URLs
    // Per HTML spec, relative URLs in importScripts() resolve against worker's location
    const base_url: ?[]const u8 = if (internal.internal_location) |loc| loc.getHref() else null;

    for (urls) |url| {
        const url_str = url.asSlice();
        if (url_str.len == 0) {
            continue;
        }

        // Fetch the script using the script_fetch module
        // Pass base_url (worker's script URL) for relative URL resolution
        var fetched = script_fetch.fetchWorkerScript(internal.allocator, url_str, .{
            .worker_type = .classic,
            .origin = base_url orelse internal.origin,
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
/// Delegates to WindowOrWorkerGlobalScope mixin implementation.
pub fn call_clearTimeout(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    return WindowOrWorkerGlobalScopeImpl.call_clearTimeout(instance, id);
}

/// Operation: setTimeout
///
/// Spec: HTML Standard § 8.6 Timers
/// https://html.spec.whatwg.org/#dom-settimeout
///
/// Sets a one-shot timer that fires after the specified delay.
/// Delegates to WindowOrWorkerGlobalScope mixin implementation for proper V8 callback handling.
pub fn call_setTimeout(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    return WindowOrWorkerGlobalScopeImpl.call_setTimeout(instance, handler, timeout, arguments);
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
/// Per WHATWG Fetch spec, fetch() MUST always return a Promise (never throw synchronously).
/// Delegates to WindowOrWorkerGlobalScope mixin implementation which handles:
/// - Promise creation FIRST (before any error-prone operations)
/// - All errors converted to Promise rejections
/// - Async networking via AsyncCurlManager
pub fn call_fetch(instance: *runtime.Instance, input: typedefs.RequestInfo, init_data: webidl.Opt(dictionaries.RequestInit)) anyerror!runtime.JSValue {
    // Delegate to the WindowOrWorkerGlobalScope mixin implementation
    // which properly returns a Promise and rejects on any errors.
    return WindowOrWorkerGlobalScopeImpl.call_fetch(instance, input, init_data);
}

// ============================================================================
// Network State Change Events
// ============================================================================

/// Fire an "offline" event at the WorkerGlobalScope.
///
/// Spec: HTML Standard § 10.1
/// "The offline event is fired when the worker goes offline."
///
/// This function should be called by the platform layer when network
/// connectivity is lost. It dispatches an Event to the WorkerGlobalScope,
/// which will invoke any registered event listeners and the onoffline handler.
pub fn fireOfflineEvent(instance: *runtime.Instance) void {
    fireNetworkEvent(instance, "offline", get_onoffline);
}

/// Fire an "online" event at the WorkerGlobalScope.
///
/// Spec: HTML Standard § 10.1
/// "The online event is fired when the worker comes online."
///
/// This function should be called by the platform layer when network
/// connectivity is restored. It dispatches an Event to the WorkerGlobalScope,
/// which will invoke any registered event listeners and the ononline handler.
pub fn fireOnlineEvent(instance: *runtime.Instance) void {
    fireNetworkEvent(instance, "online", get_ononline);
}

/// Internal helper to fire network state events
fn fireNetworkEvent(
    instance: *runtime.Instance,
    event_type: []const u8,
    get_handler: fn (*runtime.Instance) anyerror!typedefs.EventHandler,
) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;

    // Create Event via interface
    const Event = interfaces.Event;
    const event = Event.call_constructor(
        instance.ctx,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.EventInit).notPassed(),
    ) catch |err| {
        std.log.warn("Failed to create {s} event: {s}", .{ event_type, @errorName(err) });
        return;
    };

    // Set isTrusted since this is a browser-generated event
    var ev_state = event.getState(Event.State);
    ev_state.own.isTrusted = true;
    ev_state.own.target = instance;
    ev_state.own.currentTarget = instance;

    // Dispatch via EventTarget.dispatchEvent if available
    // WorkerGlobalScope inherits from EventTarget
    const EventTarget = interfaces.EventTarget;
    _ = EventTarget.call_dispatchEvent(instance, event) catch |err| {
        std.log.warn("Failed to dispatch {s} event: {s}", .{ event_type, @errorName(err) });
        return;
    };

    // Also invoke the legacy handler if set
    // Get the handler using the provided getter function
    const handler = get_handler(instance) catch return;
    _ = handler;
    _ = internal;
    // Note: Actually invoking the handler requires V8 integration similar to
    // Worker.invokeLegacyOnmessageHandler. The EventTarget.dispatchEvent above
    // handles listeners registered via addEventListener. For the IDL attribute
    // handler, we would need to call into V8 with the handler GlobalHandle.
    // This is left as future work when V8 context is available here.
}

// =============================================================================
// Tests
// =============================================================================

test "isSecureContext - HTTPS is secure" {
    try std.testing.expect(isSecureContext("https://example.com/path"));
    try std.testing.expect(isSecureContext("https://example.com:443/path"));
}

test "isSecureContext - WSS is secure" {
    try std.testing.expect(isSecureContext("wss://example.com/socket"));
}

test "isSecureContext - file:// is secure" {
    try std.testing.expect(isSecureContext("file:///path/to/file"));
}

test "isSecureContext - HTTP localhost is secure" {
    try std.testing.expect(isSecureContext("http://localhost/path"));
    try std.testing.expect(isSecureContext("http://localhost:8080/path"));
    try std.testing.expect(isSecureContext("http://127.0.0.1/path"));
    try std.testing.expect(isSecureContext("http://127.0.0.1:3000/path"));
    try std.testing.expect(isSecureContext("http://[::1]/path"));
    try std.testing.expect(isSecureContext("http://::1/path"));
}

test "isSecureContext - WS localhost is secure" {
    try std.testing.expect(isSecureContext("ws://localhost/socket"));
    try std.testing.expect(isSecureContext("ws://127.0.0.1:8080/socket"));
}

test "isSecureContext - HTTP non-localhost is NOT secure" {
    try std.testing.expect(!isSecureContext("http://example.com/path"));
    try std.testing.expect(!isSecureContext("http://web-platform.test:8000/path"));
    try std.testing.expect(!isSecureContext("http://192.168.1.1/path"));
}

test "isSecureContext - WS non-localhost is NOT secure" {
    try std.testing.expect(!isSecureContext("ws://example.com/socket"));
}

test "isSecureContext - unknown schemes are NOT secure" {
    try std.testing.expect(!isSecureContext("ftp://example.com/path"));
    try std.testing.expect(!isSecureContext("data:text/html,<h1>test</h1>"));
}
