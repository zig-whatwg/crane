//! Implementation for WindowOrWorkerGlobalScope interface

const std = @import("std");
const runtime = @import("runtime");
const html_core = @import("html_core");
const global_settings = @import("dom").global_settings;
const streams_js = @import("streams_js.zig");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const WindowOrWorkerGlobalScope = interfaces.WindowOrWorkerGlobalScope;

pub const State = WindowOrWorkerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for origin
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    // "return this's relevant settings object's origin, serialized."
    const settings = global_settings.of(instance) orelse return error.InvalidStateError;
    return settings.origin(instance);
}

/// Getter for isSecureContext
pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
    // "return true if this's relevant settings object is a secure context"
    const settings = global_settings.of(instance) orelse return false;
    return settings.is_secure_context(instance);
}

/// Getter for crossOriginIsolated
pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
    // "return this's relevant settings object's cross-origin isolated
    // capability."
    const settings = global_settings.of(instance) orelse return false;
    return settings.cross_origin_isolated(instance);
}

/// Getter for indexedDB
pub fn get_indexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const settings = global_settings.of(instance) orelse return error.InvalidStateError;
    const indexed_db = settings.indexed_db orelse return error.NotImplemented;
    return indexed_db(instance);
}

/// Getter for trustedTypes
pub fn get_trustedTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for performance
pub fn get_performance(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const settings = global_settings.of(instance) orelse return error.InvalidStateError;
    const performance = settings.performance orelse return error.NotImplemented;
    return performance(instance);
}

/// Getter for caches
pub fn get_caches(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const settings = global_settings.of(instance) orelse return error.InvalidStateError;
    const caches = settings.caches orelse return error.NotImplemented;
    return caches(instance);
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

/// Operation: reportError
pub fn call_reportError(instance: *runtime.Instance, e: runtime.JSValue) anyerror!void {
    _ = instance;
    _ = e;
    return error.NotImplemented;
}

/// Operation: setInterval
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-setinterval
///
/// TODO: When implementing, the handler MUST be stored as a V8 Global handle
/// if handler.function is a JavaScript callback. See:
/// - tmp/analysis/CALLBACK_STORAGE.md for the pattern
/// - src/webidl/impls/WebSocket.zig for example usage of OptionalGlobalHandle
///
/// Implementation requirements:
/// 1. For handler.function variant, create Global handle
/// 2. Store in interval registry with Global handle
/// 3. Dispose Global handle when interval is cleared via clearInterval
/// 4. Handle repeating invocation pattern
pub fn call_setInterval(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    _ = instance;
    _ = handler;
    _ = timeout;
    _ = arguments;
    return error.NotImplemented;
}

/// Operation: atob
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#dom-atob
pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.ByteString {
    // Freed by the binding.
    return html_core.base64_utility.atob(instance.ctx.allocator, data.asSlice());
}

/// Operation: btoa
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#dom-btoa
pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.DOMString {
    // Freed by the binding.
    return runtime.DOMString.initOwned(try html_core.base64_utility.btoa(instance.ctx.allocator, data.asSlice()));
}

/// Operation: createImageBitmap
pub fn call_createImageBitmap(instance: *runtime.Instance, image: typedefs.ImageBitmapSource, options: webidl.Opt(dictionaries.ImageBitmapOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = image;
    _ = options;
    return error.NotImplemented;
}

/// Operation: clearInterval
pub fn call_clearInterval(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    _ = instance;
    _ = id;
    return error.NotImplemented;
}

/// Operation: queueMicrotask
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-queuemicrotask
///
/// Queues a microtask to invoke the callback. The callback is a V8 GlobalHandle
/// (tagged pointer) that will be invoked when the microtask queue is processed.
pub fn call_queueMicrotask(instance: *runtime.Instance, callback: callbacks.VoidFunction) anyerror!void {
    const v8_engine = @import("v8");
    const v8_ffi = v8_engine.ffi;
    const pointer_tag = v8_engine.pointer_tag;

    // Get the V8 context from the instance (engine_ctx is a V8 Context pointer)
    const v8_context: *v8_ffi.Context = @ptrCast(@alignCast(instance.ctx.engine_ctx orelse {
        return error.NotImplemented;
    }));

    // Get the current V8 isolate
    const isolate = v8_ffi.v8_Isolate_GetCurrent() orelse {
        return error.NotImplemented;
    };

    // The callback parameter is a tagged pointer to a V8 GlobalHandle (the JS function)
    // We need to untag it to get the actual pointer
    const callback_ptr: *const anyopaque = @ptrCast(callback);
    const untagged = pointer_tag.untagPointer(callback_ptr);

    // Verify it's a global handle (callback functions are always passed as global handles)
    if (untagged.tag != .global_handle and untagged.tag != .untagged) {
        return error.NotImplemented;
    }

    // The untagged pointer is the V8 Global<Function>* (the JS function)
    const js_function: *v8_ffi.Function = @ptrCast(@alignCast(untagged.ptr));

    // Allocate context for the microtask callback
    // This will be freed after the microtask executes
    const ctx = instance.ctx.allocator.create(MicrotaskContext) catch return error.OutOfMemory;
    ctx.* = .{
        .js_function = js_function,
        .v8_context = v8_context,
        .context_addr = @intFromPtr(v8_ffi.v8_Context_GetRawAddress(v8_context) orelse {
            instance.ctx.allocator.destroy(ctx);
            return error.NotImplemented;
        }),
        .isolate = isolate,
        .allocator = instance.ctx.allocator,
    };

    // Queue the microtask with V8
    const callback_fn: ?*const anyopaque = @ptrCast(&microtaskCallback);
    v8_ffi.v8_Isolate_EnqueueMicrotask(isolate, callback_fn, ctx);
}

/// Context passed to the microtask callback
const MicrotaskContext = struct {
    js_function: *@import("v8").ffi.Function,
    v8_context: *@import("v8").ffi.Context,
    /// Raw address of the context, captured while it was alive.
    ///
    /// A queued microtask can outlive its context - the page tears down with
    /// microtasks still on V8's queue - and using `v8_context` then dereferences a
    /// freed Global<Context> inside v8_Function_CallWithReceiver_Safe
    /// (v8_wrapper.cpp:1321). The address is captured up front so liveness can be
    /// checked WITHOUT touching the handle.
    context_addr: usize,
    isolate: *@import("v8").ffi.Isolate,
    allocator: std.mem.Allocator,
};

/// Microtask callback that invokes the JS function
fn microtaskCallback(data: ?*anyopaque) callconv(.c) void {
    const v8_ffi = @import("v8").ffi;

    const ctx: *MicrotaskContext = @ptrCast(@alignCast(data orelse return));
    defer ctx.allocator.destroy(ctx);

    // The context may have been torn down since this microtask was queued - a page
    // can unload with microtasks still on V8's queue. Checking by ADDRESS rather
    // than by handle is deliberate: any query that takes the Global<Context>* has
    // to dereference it, which is the use-after-free being guarded against.
    const context_manager = @import("v8").context_manager;
    if (!context_manager.isContextAddressAlive(ctx.context_addr)) {
        // Still dispose the function handle we own, then drop the task.
        v8_ffi.v8_Function_Dispose(ctx.js_function);
        return;
    }

    // Phase 5 instrumentation: microtasks run from V8's own drain, so this should
    // always be owned - a report here would be a strong signal.
    @import("v8").isolate_ownership.assertOwned(ctx.isolate, "WindowOrWorkerGlobalScope.microtaskCallback");

    // Create a HandleScope for V8 operations
    const handle_scope = v8_ffi.v8_HandleScope_New(ctx.isolate);
    defer v8_ffi.v8_HandleScope_Dispose(handle_scope);

    // Call the function with no arguments and undefined as 'this'
    // v8_Function_CallWithReceiver_Safe signature: (context, function, receiver, argc, argv)
    const undefined_val = v8_ffi.v8_Undefined(ctx.isolate);
    _ = v8_ffi.v8_Function_CallWithReceiver_Safe(
        ctx.v8_context,
        ctx.js_function,
        undefined_val,
        0,
        null, // No arguments
    );

    // Dispose the global handle after execution
    v8_ffi.v8_Function_Dispose(ctx.js_function);
}

/// Operation: structuredClone
/// Spec: https://html.spec.whatwg.org/multipage/structured-data.html#dom-structuredclone
///
/// Creates a deep clone of a value using the structured clone algorithm.
/// Handles circular references, Date, RegExp, Map, Set, ArrayBuffer, etc.
/// Throws DataCloneError for non-cloneable values like functions and symbols.
pub fn call_structuredClone(instance: *runtime.Instance, value: runtime.JSValue, options: webidl.Opt(dictionaries.StructuredSerializeOptions)) anyerror!runtime.JSValue {
    const v8_ffi = @import("v8").ffi;

    // For primitives (undefined, null, boolean, number), return them directly
    // For value types that are passed as handles (strings, objects), use V8's clone
    switch (value) {
        .undefined => return runtime.JSValue.jsUndefined,
        .null => return runtime.JSValue.jsNull,
        .boolean => |b| return runtime.JSValue.fromBoolean(b),
        .number => |n| return runtime.JSValue.fromNumber(n),
        .string => |s| {
            // Clone the string data since input argument data may be freed after return.
            // The returned string is owned and will be freed after conversion to V8.
            const cloned_data = instance.ctx.allocator.dupe(u8, s.data) catch return error.OutOfMemory;
            return runtime.JSValue{ .string = .{
                .data = cloned_data,
                .owned = true,
            } };
        },
        .handle => |h| {
            // For objects/functions/etc, use V8's structured clone
            const v8_value: *v8_ffi.Value = @ptrCast(@alignCast(h.ptr));

            // Check if we have a transfer list in options
            if (options.was_passed and options.value.transfer != null) {
                const transfer_list = options.value.transfer.?;
                if (transfer_list.len > 0) {
                    // Build transfer list for V8
                    var v8_transfers: [64]*v8_ffi.Value = undefined; // Max 64 transfers
                    const count = @min(transfer_list.len, 64);

                    for (0..count) |i| {
                        switch (transfer_list[i]) {
                            .handle => |th| {
                                v8_transfers[i] = @ptrCast(@alignCast(th.ptr));
                            },
                            else => {
                                // Non-object in transfer list is a DataCloneError
                                return error.DataCloneError;
                            },
                        }
                    }

                    var error_code: c_int = 0;
                    const cloned = v8_ffi.v8_Value_StructuredCloneWithTransfer(
                        v8_value,
                        &v8_transfers,
                        count,
                        &error_code,
                    );

                    if (cloned == null or error_code != 0) {
                        return error.DataCloneError;
                    }

                    return runtime.JSValue{
                        .handle = .{
                            .ptr = @ptrCast(cloned.?),
                            .needs_disposal = true,
                            .handle_scope = .global,
                        },
                    };
                }
            }

            // No transfer list, use simple clone
            const cloned = v8_ffi.v8_Value_StructuredClone(v8_value);
            if (cloned == null) {
                // Clone failed - value contains non-cloneable types (functions, symbols, etc.)
                return error.DataCloneError;
            }

            return runtime.JSValue{
                .handle = .{
                    .ptr = @ptrCast(cloned.?),
                    .needs_disposal = true,
                    .handle_scope = .global,
                },
            };
        },
        .instance => {
            // Zig instances cannot be cloned
            return error.DataCloneError;
        },
    }
}

/// Operation: setTimeout
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-settimeout
///
/// TODO: When implementing, the handler MUST be stored as a V8 Global handle
/// if handler.function is a JavaScript callback. See:
/// - tmp/analysis/CALLBACK_STORAGE.md for the pattern
/// - src/webidl/impls/WebSocket.zig for example usage of OptionalGlobalHandle
///
/// Implementation requirements:
/// 1. For handler.function variant, create Global handle
/// 2. Store in timer registry with Global handle
/// 3. Dispose Global handle when timer fires or is cleared via clearTimeout
/// 4. Handle one-shot invocation (unlike setInterval)
pub fn call_setTimeout(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    _ = instance;
    _ = handler;
    _ = timeout;
    _ = arguments;
    return error.NotImplemented;
}

/// Operation: clearTimeout
pub fn call_clearTimeout(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    _ = instance;
    _ = id;
    return error.NotImplemented;
}

/// Operation: fetch
///
/// The fetch runs on the event loop (`fetch.algorithms.AsyncFetch`): this
/// returns p at once, and the fetch task that settles it runs on a later turn.
/// It used to run the whole fetch inside this call, blocked in
/// `curl_easy_perform`, and everything on the thread waited with it.
pub fn call_fetch(instance: *runtime.Instance, input: typedefs.RequestInfo, init_data: webidl.Opt(dictionaries.RequestInit)) anyerror!runtime.JSValue {
    const fetch = @import("fetch");
    const fetch_objects = @import("dom").fetch_objects;
    const abort_algorithms = @import("dom").abort_algorithms;
    const v8 = @import("v8");
    const allocator = instance.ctx.allocator;

    // One call's promise, from the moment the fetch starts until a fetch
    // task settles it: the fetch's client, the task, and the abort steps on
    // requestObject's signal.
    //
    // Who releases it: while the fetch is in flight, the fetch's `gone`, or
    // the abort steps (which end the fetch); once `done` has queued the
    // task, the task (or its `drop`).
    const Call = struct {
        allocator: std.mem.Allocator,
        /// The relevant realm's runtime context. A page that ends RETIRES its
        /// context rather than freeing it, and empties it - `engine_ctx`
        /// becomes null - which is how `alive` tells that the realm is gone.
        ctx: runtime.Context,
        isolate: *v8.ffi.Isolate,
        /// p's resolver, a Global this call owns until p is settled or its
        /// realm is gone. Keeping it keeps p, and so the realm, alive while
        /// the fetch is in flight.
        resolver: *v8.ffi.PromiseResolver,
        outcome: ?(fetch.algorithms.FetchError!fetch.algorithms.FetchResult) = null,
        /// The fetch, from start until it ends (`done` or `gone`) or is
        /// aborted.
        in_flight: ?*fetch.algorithms.AsyncFetch = null,
        /// requestObject's signal while this call's abort steps are on it -
        /// held as (address, slab generation), since nothing here keeps the
        /// signal alive and a collected signal's slot can be reissued.
        signal: ?*runtime.Instance = null,
        signal_generation: u64 = 0,
        /// Step 9's locallyAborted.
        locally_aborted: bool = false,

        const Self = @This();

        fn client(self: *Self) fetch.algorithms.AsyncFetch.Client {
            return .{ .context = self, .done = done, .alive = alive, .gone = gone };
        }

        fn alive(context: *anyopaque) bool {
            const self: *Self = @ptrCast(@alignCast(context));
            return self.ctx.engine_ctx != null;
        }

        /// The realm went away with the fetch in flight; the fetch has been
        /// terminated. Nothing is left to settle.
        fn gone(context: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(context));
            self.in_flight = null;
            self.release();
        }

        /// Fetch has its response: queue the fetch task that runs
        /// processResponse (step 12) - a global task on the networking task
        /// source, given relevantRealm's global object. A window's realm has
        /// an event loop. A worker's has none of its own and runs its tasks
        /// as timers on the page's, so its task is one; a realm with neither
        /// is in the event loop's network step already, a task boundary, and
        /// settles now.
        fn done(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
            const self: *Self = @ptrCast(@alignCast(context));
            self.in_flight = null;
            self.outcome = outcome;
            if (self.ctx.getOptionalEventLoop()) |loop| {
                loop.queueTask(.{ .callback = settle, .context = self, .drop = drop });
                return;
            }
            if (self.ctx.getOptionalTimer()) |timer| {
                if (timer.setTimeout(0, settle, self) != 0) return;
            }
            settle(self);
        }

        /// The fetch task. It runs from the event loop, not from script, so
        /// it enters the realm itself.
        fn settle(context: ?*anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(context.?));
            // The realm can end while the task waits in the queue. And
            // processResponse step 1: if locallyAborted is true, abort these
            // steps - the abort steps settled p already.
            if (!alive(self) or self.locally_aborted) return self.release();

            // Read once: `release` frees this call, and the isolate is
            // exited after it - the defers run in reverse.
            const isolate = self.isolate;
            const entered = v8.ffi.v8_Isolate_GetCurrent() != isolate;
            if (entered) v8.ffi.v8_Isolate_Enter(isolate);
            defer if (entered) v8.ffi.v8_Isolate_Exit(isolate);
            defer self.release();
            {
                const scope = v8.JsScope.init(self.ctx) orelse return;
                defer scope.deinit();
                self.processResponse();
            }
            // In a worker, the task's end is the worker's to run.
            @import("html").worker_v8_context.finishTaskIn(isolate);
        }

        /// processResponse, given fetch's outcome.
        fn processResponse(self: *Self) void {
            const realm = streams_js.Realm.ofContext(self.ctx) catch return;
            const outcome = self.outcome orelse return;
            self.outcome = null;
            var result = outcome catch return self.rejectTypeError(realm, "Failed to fetch");
            result.timing_info.deinit();
            const response = result.response;

            // Step 3: a network error rejects p with a TypeError.
            if (response.response_type == .@"error") {
                response.deinit();
                return self.rejectTypeError(realm, "Failed to fetch");
            }

            // Step 4: responseObject is the result of creating a Response
            // object given response, "immutable" and relevantRealm.
            const response_object = interfaces.Response.call_constructor(self.ctx, webidl.Opt(?typedefs.BodyInit).notPassed(), webidl.Opt(dictionaries.ResponseInit).notPassed()) catch {
                response.deinit();
                return self.rejectTypeError(realm, "Failed to fetch");
            };
            if (!fetch_objects.adoptResponse(response_object, @ptrCast(response), .immutable)) {
                response.deinit();
                return self.rejectTypeError(realm, "Failed to fetch");
            }

            // Step 5: resolve p with responseObject.
            const wrapper = realm.wrap(response_object) catch return;
            _ = v8.ffi.v8_PromiseResolver_Resolve(self.resolver, realm.context, wrapper);
        }

        fn rejectTypeError(self: *Self, realm: streams_js.Realm, message: []const u8) void {
            const reason = realm.typeError(message) catch return;
            defer streams_js.dispose(reason);
            _ = v8.ffi.v8_PromiseResolver_Reject(self.resolver, realm.context, reason);
        }

        /// Step 11's abort steps, run when requestObject's signal is
        /// aborted - from script (`controller.abort()`), or from a task
        /// (`AbortSignal.timeout()`), either way inside the realm.
        fn aborted(context: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(context));
            const signal = self.liveSignal();
            // The signal empties its abort algorithms as it runs them, so
            // there is nothing to remove from it any more.
            self.signal = null;

            // Step 11.1: Set locallyAborted to true.
            self.locally_aborted = true;

            // Step 11.3: Abort controller - the fetch ends here, its transfer
            // cancelled, and its client hears nothing more.
            const was_in_flight = self.in_flight != null;
            if (self.in_flight) |f| {
                self.in_flight = null;
                f.terminate(.{ .kind = .aborted });
            }

            // Step 11.4: Abort the fetch() call with p, request,
            // responseObject and the signal's abort reason. responseObject is
            // made by the task, which has not run, so it is null: reject p.
            // Deviation: request's body is bytes, not a stream, so there is
            // nothing to cancel; and once responseObject exists this call is
            // released and its abort steps removed, so a later abort does not
            // error the response's body - that needs a streamed body.
            if (signal) |s| self.rejectWithAbortReason(s);

            // In flight, the fetch was this call's owner; now nothing is. A
            // task already queued owns it, and releases it when it runs.
            if (was_in_flight) self.release();
        }

        fn rejectWithAbortReason(self: *Self, signal: *runtime.Instance) void {
            const realm = streams_js.Realm.ofContext(self.ctx) catch return;
            const reason_value = interfaces.AbortSignal.get_reason(signal) catch return;
            const reason = realm.fromRuntime(reason_value) catch return;
            defer streams_js.dispose(reason);
            _ = v8.ffi.v8_PromiseResolver_Reject(self.resolver, realm.context, reason);
        }

        fn liveSignal(self: *const Self) ?*runtime.Instance {
            const signal = self.signal orelse return null;
            if (runtime.SlabAllocator.generationOf(signal) != self.signal_generation) return null;
            return signal;
        }

        /// A task that will never run: its loop is going.
        fn drop(context: ?*anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(context.?));
            self.release();
        }

        fn release(self: *Self) void {
            if (self.liveSignal()) |signal| abort_algorithms.remove(signal, self);
            if (self.outcome) |outcome| {
                var result = outcome catch null;
                if (result) |*r| r.deinit();
            }
            v8.ffi.v8_PromiseResolver_Dispose(self.resolver);
            self.allocator.destroy(self);
        }
    };

    // Step 8: relevantRealm, this's relevant realm.
    const realm = try streams_js.Realm.of(instance);

    // Step 1: Let p be a new promise.
    const p = try streams_js.Deferred.init(realm);
    // The promise is made for this call and kept nowhere, so it is handed to
    // the binding with the result (returnOwned) - kept, it pinned the page.
    // The resolver is released here unless the fetch takes it.
    var resolver_taken = false;
    defer if (!resolver_taken) v8.ffi.v8_PromiseResolver_Dispose(p.resolver);

    // Step 2: Let requestObject be the result of invoking the initial value
    // of Request as constructor with input and init. If this throws, reject
    // p with it and return p.
    //
    // The binding converted `init` before this call, so a throwing getter in
    // it has already propagated from fetch(), before p existed. Deviation: it
    // should reject p.
    const request_object = interfaces.Request.call_constructor(instance.ctx, input, init_data) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => {
            rejectWithTypeError(realm, p, "Failed to execute 'fetch': the Request could not be constructed.");
            return p.returnOwned();
        },
    };
    // Nothing script can see holds requestObject, unless its signal's
    // listeners wrapped it; it goes when the call does.
    const request_generation = runtime.SlabAllocator.generationOf(request_object);
    defer request_object.releaseIfUnwrapped(request_generation);

    // Step 3: Let request be requestObject's request.
    const request: *fetch.internal.InternalRequest = @ptrCast(@alignCast(fetch_objects.requestOf(request_object) orelse return error.InvalidStateError));

    // Step 4: If requestObject's signal is aborted, abort the fetch() call
    // with p, request, null, and the signal's abort reason, and return p.
    const signal = try interfaces.Request.get_signal(request_object);
    if (try interfaces.AbortSignal.get_aborted(signal)) {
        const reason = try realm.fromRuntime(try interfaces.AbortSignal.get_reason(signal));
        defer streams_js.dispose(reason);
        p.reject(realm, reason);
        return p.returnOwned();
    }

    // Steps 5-6: no ServiceWorkerGlobalScope exists here.
    // Steps 9-11 are added to requestObject's signal below, once the fetch -
    // step 12's controller - exists for them to abort. Nothing can run in
    // between.

    // Step 12: fetch request. The fetch outlives this call, and requestObject
    // may not, so it fetches a clone: nothing script can observe tells the
    // two apart, since the fetch changes only request's current URL.
    const fetched_request = try request.clone();
    const call = allocator.create(Call) catch {
        fetched_request.deinit();
        return error.OutOfMemory;
    };
    call.* = .{ .allocator = allocator, .ctx = instance.ctx, .isolate = realm.isolate, .resolver = p.resolver };
    call.in_flight = fetch.algorithms.AsyncFetch.startWith(allocator, fetched_request, .{}, .{ .collect = true }, fetch.network.scheduler.threadScheduler(), call.client()) catch {
        // The fetch owned the request, and freed it.
        allocator.destroy(call);
        rejectWithTypeError(realm, p, "Failed to fetch");
        return p.returnOwned();
    };
    resolver_taken = true;

    // Step 11: Add the abort steps to requestObject's signal. Without them
    // the call still settles; it just cannot be aborted.
    if (abort_algorithms.add(signal, .{ .ctx = call, .run = Call.aborted })) {
        call.signal = signal;
        call.signal_generation = runtime.SlabAllocator.generationOf(signal);
    } else |err| {
        std.log.scoped(.fetch).warn("fetch(): abort steps not added: {s}", .{@errorName(err)});
    }

    // Step 13.
    return p.returnOwned();
}

fn rejectWithTypeError(realm: streams_js.Realm, p: streams_js.Deferred, message: []const u8) void {
    const reason = realm.typeError(message) catch return;
    defer streams_js.dispose(reason);
    p.reject(realm, reason);
}
