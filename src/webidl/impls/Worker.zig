//! Implementation for Worker interface
//!
//! Spec: HTML Standard § 10.2.3 Dedicated workers and the Worker interface
//! https://html.spec.whatwg.org/#dedicated-workers-and-the-worker-interface
//!
//! This implementation bridges the WebIDL Worker interface to the underlying
//! DedicatedWorker implementation in src/html/workers/.
//!
//! ## Message Passing Architecture
//!
//! When `worker.postMessage(data)` is called from JS:
//! 1. call_postMessage serializes `data` using structured clone
//! 2. Message is queued to DedicatedWorker's outside_port
//! 3. outside_port delivers to entangled inside_port (worker side)
//! 4. Worker's V8 context receives MessageEvent
//!
//! When worker calls `self.postMessage(data)`:
//! 1. Worker serializes `data` using structured clone
//! 2. Message is queued to inside_port
//! 3. inside_port delivers to entangled outside_port (main thread)
//! 4. handleMessageFromWorker creates MessageEvent
//! 5. onmessage handler is invoked with MessageEvent

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const Worker = interfaces.Worker;
const MessageEvent = interfaces.MessageEvent;
const EventTarget = interfaces.EventTarget;

// Import parent class implementation for proper initialization chain
const EventTargetImpl = @import("EventTarget.zig");

// Import workers infrastructure
const html_core = @import("html_core");
const workers = html_core.workers;
const DedicatedWorker = workers.DedicatedWorker;
const WorkerOptions = workers.WorkerOptions;
const WorkerType = workers.WorkerType;
const RequestCredentials = workers.RequestCredentials;
const QueuedMessage = workers.message_channel.QueuedMessage;
const JSValue = workers.message_channel.JSValue;
const WorkerContext = workers.WorkerContext;
const worker_error = workers.worker_error;

// Import html module for WorkerV8Context (has interface access, unlike html_core)
const html_full = @import("html");
const WorkerV8Context = html_full.WorkerV8Context;

// Import structured clone for message passing
const structured_clone = html_core.structured_clone;

// Import MessagePort for communication
const message_port_internal = @import("streams_internal");
const InternalMessagePort = message_port_internal.MessagePort;

// Import platform for TimerBackend (used to create DedicatedWorker)
const platform = @import("platform");

// Import Window implementation to access document for origin resolution
const WindowImpl = @import("Window.zig");

// Import DedicatedWorkerGlobalScope for setting up message handler in worker thread
const DedicatedWorkerGlobalScopeImpl = @import("DedicatedWorkerGlobalScope.zig");
const DedicatedWorkerGlobalScope = interfaces.DedicatedWorkerGlobalScope;

// Import V8 engine for callback invocation
const v8_engine = @import("v8");
const template_registry = v8_engine.template_registry;

// Import threading infrastructure for worker execution
const WorkerThreadRunner = workers.WorkerThreadRunner;
const ThreadedWorkerManager = workers.ThreadedWorkerManager;
const WorkerV8Integration = workers.WorkerV8Integration;
const WorkerThreadState = workers.WorkerThreadState;

pub const State = Worker.State;

// Debug logging for worker lifecycle - uses stderr for visibility
const wdebug = struct {
    pub inline fn print(comptime fmt: []const u8, args: anytype) void {
        const stderr = std.fs.File.stderr();
        var buf: [1024]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "[WORKER_IMPL] " ++ fmt, args) catch "[WORKER_IMPL] (format error)\n";
        stderr.writeAll(msg) catch {};
    }
};

pub const ImplError = error{
    NotImplemented,
    WorkerCreationFailed,
    InvalidURL,
    OutOfMemory,
    PostMessageFailed,
};

/// Internal state for Worker implementation
///
/// Contains the backing DedicatedWorker from src/html/workers/
/// and the entangled MessagePort pair for communication.
///
/// Note: The DedicatedWorker requires a TimerBackend which comes from
/// the platform layer. The WebIDL impl stores worker configuration,
/// and actual worker lifecycle is managed when platform is available.
pub const InternalState = struct {
    /// The underlying dedicated worker implementation (optional - created when platform is set)
    dedicated_worker: ?*DedicatedWorker = null,

    /// V8 context for worker execution (created when DedicatedWorker starts)
    v8_context: ?*WorkerV8Context = null,

    /// Outside MessagePort (exposed to the caller)
    outside_port: ?*runtime.Instance = null,

    /// Worker configuration
    script_url: []const u8,
    name: []const u8,
    worker_type: WorkerType,
    credentials: RequestCredentials,

    /// Whether the worker has been terminated
    terminated: bool = false,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    /// Reference to the Worker instance (for message handling)
    worker_instance: ?*runtime.Instance = null,

    /// Runtime context for creating MessageEvent
    ctx: ?runtime.Context = null,

    /// Raw V8 context pointer for message dispatch
    /// Stored directly to avoid GlobalHandle issues. The context is kept alive
    /// by the Browser's context management, so we just need the pointer.
    v8_context_ptr: ?*v8_engine.ffi.Context = null,

    /// V8 isolate for callback invocation
    isolate: ?*v8_engine.ffi.Isolate = null,

    /// Event handler GlobalHandles (stored as V8 Global handles for proper lifecycle)
    /// These are extracted from tagged pointers when set via the WebIDL setters.
    onmessage_handle: v8_engine.OptionalGlobalHandle = null,
    onerror_handle: v8_engine.OptionalGlobalHandle = null,
    onmessageerror_handle: v8_engine.OptionalGlobalHandle = null,

    /// Pending script source to execute (deferred from constructor)
    /// This is set during constructor and executed via timer callback
    pending_script: ?[]const u8 = null,

    /// Pending script URL for deferred V8 context creation
    pending_script_url: ?[]const u8 = null,

    /// Document origin for worker script URL resolution (stored for deferred creation)
    document_origin: ?[]const u8 = null,

    /// Thread runner for threaded worker execution (used instead of same-thread V8 context)
    thread_runner: ?*WorkerThreadRunner = null,

    /// Whether to use threaded execution (true = spawn OS thread, false = same-thread)
    use_threading: bool = true,

    /// Parent Window instance for error propagation
    /// Per HTML § 10.2.5: If error not handled at Worker, propagate to parent context
    parent_window: ?*runtime.Instance = null,

    /// Self-reference GlobalHandle to prevent GC from collecting this Worker
    /// while the DedicatedWorker thread is still alive and may post messages back.
    /// This is disposed when the worker is terminated or errors out.
    self_handle: v8_engine.OptionalGlobalHandle = null,

    pub fn deinit(self: *InternalState) void {
        // Dispose V8 Global handles to prevent memory leaks
        v8_engine.disposeOptionalGlobalHandle(&self.onmessage_handle);
        v8_engine.disposeOptionalGlobalHandle(&self.onerror_handle);
        v8_engine.disposeOptionalGlobalHandle(&self.onmessageerror_handle);

        // v8_context_ptr is a raw pointer, no disposal needed
        // (the context is managed by the Browser)

        // Dispose the self-reference handle that was keeping this Worker alive
        v8_engine.disposeOptionalGlobalHandle(&self.self_handle);

        // Clean up thread runner first (it owns the worker thread)
        if (self.thread_runner) |runner| {
            runner.deinit();
        }

        // Clean up V8 context (for same-thread mode)
        if (self.v8_context) |v8_ctx| {
            v8_ctx.deinit();
        }
        if (self.dedicated_worker) |worker| {
            // Unregister from the global registry before cleanup
            workers.message_channel.WorkerPortRegistry.unregister(worker.port_pair.outside_port);
            worker.deinit();
        }
        self.allocator.free(self.script_url);
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }
        // Free pending script if not yet executed
        if (self.pending_script) |script| {
            self.allocator.free(script);
        }
        // Free pending script URL if not yet used
        if (self.pending_script_url) |url| {
            self.allocator.free(url);
        }
        // Free document origin if stored
        if (self.document_origin) |origin| {
            self.allocator.free(origin);
        }
    }
};

/// Cleanup function for InternalState, called by DedicatedWorker.deinit().
/// This is used as a callback to avoid circular module dependencies between
/// Worker.zig and dedicated_worker.zig.
fn internalStateCleanup(user_data_ptr: *anyopaque) void {
    const internal: *InternalState = @ptrCast(@alignCast(user_data_ptr));
    wdebug.print("[internalStateCleanup] Cleaning up InternalState: {*}\n", .{internal});
    internal.deinit();
    internal.allocator.destroy(internal);
}

/// Initialize instance (creates the instance)
/// IMPORTANT: Worker extends EventTarget, so we must chain to EventTarget.init()
/// to properly set up the event listener infrastructure needed for addEventListener.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (EventTarget) to set up event listener state
    const instance = try EventTargetImpl.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
/// IMPORTANT: Must chain to EventTarget.deinit() through interface (not impl directly)
/// to clean up event listener state.
///
/// NOTE: We do NOT free InternalState here if DedicatedWorker is still alive.
/// The InternalState is stored in dedicated_worker.user_data and will be accessed
/// when the worker posts messages back. Freeing it here would cause use-after-free.
/// The InternalState will be freed when the DedicatedWorker is terminated.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // Only free InternalState if the DedicatedWorker is already gone
        // (i.e., the worker was terminated before the V8 object was GC'd)
        if (internal.dedicated_worker == null) {
            wdebug.print("[Worker.deinit] dedicated_worker is null, freeing InternalState\n", .{});
            internal.deinit();
            internal.allocator.destroy(internal);
        } else {
            // DedicatedWorker is still alive - don't free InternalState yet
            // It will be freed when DedicatedWorker is terminated
            wdebug.print("[Worker.deinit] dedicated_worker still alive, NOT freeing InternalState\n", .{});
            // Clear the reference from state so we don't double-free
            state.own._internal = null;
        }
    }
    // Chain to parent class through interface for proper deinit
    EventTarget.deinit(instance);
}

/// Constructor implementation
///
/// Spec: HTML Standard § 10.2.3.1 The Worker() constructor
/// https://html.spec.whatwg.org/#dom-worker
///
/// This is called when the interface is constructed from JavaScript:
/// new Worker(scriptURL, options)
pub fn call_constructor(ctx: runtime.Context, scriptURL: runtime.DOMString, options: webidl.Opt(dictionaries.WorkerOptions)) !*runtime.Instance {
    wdebug.print("call_constructor() ENTRY - scriptURL={s}\n", .{scriptURL.asSlice()});

    // NOTE: We rely on the persistent HandleScope from BrowserContext.
    // Creating a local HandleScope here and disposing it at the end of the constructor
    // would leave V8 without a HandleScope for subsequent JavaScript execution.
    // The persistent HandleScope in BrowserContext stays active for the entire test.

    // Create instance through init()
    const instance = try init(ctx.allocator, State, &Worker.vtable, ctx);
    errdefer deinit(instance);

    // Parse options from WorkerOptions dictionary
    var worker_type = WorkerType.classic;
    var credentials = RequestCredentials.same_origin;
    var name: []const u8 = "";

    if (options.wasPassed()) {
        const opts = options.getValue();

        // Parse type: "classic" | "module"
        // Per HTML § 10.2.3.1: If type is "module", the script is treated as a module script
        if (opts.type) |wt| {
            worker_type = switch (wt) {
                ._classic_ => WorkerType.classic,
                ._module_ => WorkerType.module,
            };
        }

        // Parse credentials: "omit" | "same-origin" | "include"
        if (opts.credentials) |creds| {
            credentials = switch (creds) {
                ._omit_ => RequestCredentials.omit,
                ._same_origin_ => RequestCredentials.same_origin,
                ._include_ => RequestCredentials.include,
            };
        }

        // Parse name if present (this is a DOMString, not an enum)
        if (opts.name) |n| {
            name = n.asSlice();
        }
    }

    // Copy the script URL
    const url_copy = try ctx.allocator.dupe(u8, scriptURL.asSlice());
    errdefer ctx.allocator.free(url_copy);

    // Copy the name if present
    const name_copy = if (name.len > 0)
        try ctx.allocator.dupe(u8, name)
    else
        "";
    errdefer if (name_copy.len > 0) ctx.allocator.free(name_copy);

    // Create internal state
    const internal_state = try ctx.allocator.create(InternalState);
    errdefer ctx.allocator.destroy(internal_state);

    // Get the current isolate - don't cast ctx.engine_ctx as it stores the V8 Context, not Isolate
    const current_isolate = v8_engine.ffi.v8_Isolate_GetCurrent();

    internal_state.* = .{
        .dedicated_worker = null,
        .script_url = url_copy,
        .name = name_copy,
        .worker_type = worker_type,
        .credentials = credentials,
        .allocator = ctx.allocator,
        .worker_instance = instance,
        .ctx = ctx,
        .isolate = current_isolate,
    };

    wdebug.print("[WORKER_IMPL] InternalState created:\n", .{});
    wdebug.print("  internal_state ptr: {*}\n", .{internal_state});
    wdebug.print("  worker_instance: {*}\n", .{instance});
    wdebug.print("  ctx: {*}\n", .{ctx});
    wdebug.print("  isolate (from v8_Isolate_GetCurrent): {?}\n", .{@as(?*anyopaque, @ptrCast(current_isolate))});
    wdebug.print("  ctx.engine_ctx: {?}\n", .{ctx.engine_ctx});

    // Store internal state in instance
    var state = instance.getState(State);
    state.own._internal = internal_state;
    wdebug.print("  stored _internal in instance state\n", .{});

    // Try to create the DedicatedWorker using the global timer backend
    // The timer backend is portable (uses std.time) and works on all platforms
    wdebug.print("\n=== Worker.call_constructor() START ===\n", .{});
    wdebug.print("  instance ptr: {*}\n", .{instance});
    wdebug.print("  main isolate: {?*}\n", .{current_isolate});
    wdebug.print("  script URL: {s}\n", .{url_copy});
    wdebug.print("  worker name: {s}\n", .{if (name_copy.len > 0) name_copy else "(unnamed)"});
    wdebug.print("call_constructor() getting timer backend...\n", .{});
    if (platform.getDefaultTimerBackend(ctx.allocator)) |timer_backend| {
        wdebug.print("call_constructor() creating DedicatedWorker...\n", .{});
        const dedicated_worker = DedicatedWorker.init(
            ctx.allocator,
            timer_backend,
            url_copy,
            .{
                .name = name_copy,
                .worker_type = worker_type,
                .credentials = credentials,
            },
        ) catch |err| {
            // Log error but don't fail - worker will be in "not started" state
            wdebug.print("call_constructor() FAILED to create DedicatedWorker: {s}\n", .{@errorName(err)});
            std.log.warn("Failed to create DedicatedWorker: {}", .{err});
            return instance;
        };
        wdebug.print("call_constructor() DedicatedWorker created\n", .{});
        wdebug.print("  DedicatedWorker ptr: {*}\n", .{dedicated_worker});
        wdebug.print("  outside_port ptr: {*}\n", .{dedicated_worker.port_pair.outside_port});
        wdebug.print("  inside_port ptr: {*}\n", .{dedicated_worker.port_pair.inside_port});
        internal_state.dedicated_worker = dedicated_worker;

        // Store the InternalState pointer in dedicated_worker's outside_user_data.
        // This is for the OUTSIDE (main thread) message handler - when the worker sends
        // messages back to the main thread.
        //
        // This is critical because:
        // 1. InternalState is allocated on the Zig heap and won't be GC'd by V8
        // 2. The V8 Worker object (instance) can be GC'd while the worker thread runs
        // 3. When messages arrive, we need access to isolate, ctx, onmessage_handle - all in InternalState
        //
        // We use outside_user_data (not user_data) because user_data is used by the worker
        // thread's DedicatedWorkerGlobalScope for handling messages INSIDE the worker.
        // We also set a cleanup function so DedicatedWorker can properly destroy InternalState
        // when it's destroyed (avoiding circular module dependencies).
        dedicated_worker.outside_user_data = internal_state;
        dedicated_worker.outside_user_data_cleanup_fn = &internalStateCleanup;
        wdebug.print("  Stored InternalState ptr in dedicated_worker outside_user_data: {*}\n", .{internal_state});

        // CRITICAL: Create a GlobalHandle to prevent V8 GC from collecting this Worker
        // while the DedicatedWorker thread is alive. Without this, V8 can GC the Worker
        // JS object while the worker thread is running, causing use-after-free when
        // the worker posts messages back to the main thread.
        //
        // We get the V8 object via ctx.engine_ctx which points to the V8 context,
        // then use the instance's state which is stored in the object's internal field.
        if (v8_engine.ffi.v8_Isolate_GetCurrent()) |isolate| {
            // Store the isolate in internal state for later message dispatch
            internal_state.isolate = isolate;
            wdebug.print("  Stored isolate reference for message dispatch\n", .{});

            // CRITICAL: Store the V8 context pointer for message dispatch
            // This is used instead of ctx.getEngineContextAs() which can crash
            // if the ContextData has been freed or corrupted.
            if (ctx.engine_ctx) |engine_ctx| {
                internal_state.v8_context_ptr = @ptrCast(@alignCast(engine_ctx));
                wdebug.print("  Stored V8 context pointer for message dispatch: {*}\n", .{internal_state.v8_context_ptr});
            } else {
                wdebug.print("  WARNING: ctx.engine_ctx is null, cannot store V8 context\n", .{});
            }
        }

        // Set up message handler on outside port to receive messages from worker
        // When the worker calls postMessage(), the message arrives at outside_port
        // and we dispatch to the onmessage handler.
        dedicated_worker.setOnMessage(handleMessageFromWorkerCallback);

        // Set up error handler to receive errors from worker thread
        // When the worker script fails or throws, we dispatch an ErrorEvent
        // Per HTML Standard § 10.2.5 "Runtime script errors in workers"
        dedicated_worker.setErrorHandler(.{
            .on_error = handleErrorFromWorkerCallback,
            .on_rejection = null, // TODO: handle promise rejections
            .context = @ptrCast(internal_state),
        });

        // Enable message dispatch on outside port
        // Messages are queued until start() is called
        dedicated_worker.startMessageQueue();

        // Register the outside_port with the global registry so the event loop
        // can poll for pending messages from the worker thread
        workers.message_channel.WorkerPortRegistry.register(dedicated_worker.port_pair.outside_port);

        // Get the document origin for resolving relative worker script URLs
        // The origin is needed to resolve URLs like "/path/to/worker.js"
        // Also store the parent Window for error propagation per HTML § 10.2.5
        const document_origin: ?[]const u8 = blk: {
            // Get the Window instance from the V8 context via context_manager
            const v8_ctx = @as(*v8_engine.ffi.Context, @ptrCast(ctx.engine_ctx));
            if (v8_engine.context_manager.getWindowForContext(v8_ctx)) |window_instance| {
                // Store parent Window for error propagation (per HTML § 10.2.5)
                internal_state.parent_window = window_instance;

                // Get the document from the Window
                if (WindowImpl.get_document(window_instance)) |doc_instance| {
                    if (interfaces.Document.get_URL(doc_instance)) |doc_url| {
                        break :blk doc_url;
                    } else |err| {
                        std.log.warn("[Worker] Failed to get document URL: {}", .{err});
                    }
                } else |err| {
                    std.log.warn("[Worker] Failed to get document from Window: {}", .{err});
                }
            } else {
                std.log.warn("[Worker] Failed to get Window from context", .{});
            }
            break :blk null;
        };

        // Fetch the worker script FIRST to get the resolved URL
        // Per HTML Standard § 10.2.5 "Run a worker": resolve URL before creating context
        // For WPT tests, scripts are fetched from the WPT server or resolved as data: URLs
        wdebug.print("call_constructor() fetching worker script from {s}...\n", .{url_copy});
        const fetched_script = workers.fetchWorkerScript(ctx.allocator, url_copy, .{
            .worker_type = worker_type,
            .origin = document_origin,
        }) catch |err| {
            // Log error but don't fail construction - worker enters error state
            // Per spec, errors during script fetch should fire an error event
            wdebug.print("call_constructor() FAILED to fetch script: {s}\n", .{@errorName(err)});
            std.log.warn("Failed to fetch worker script: {}", .{err});
            // Free the document_origin before returning (it was allocated by Document.get_URL)
            if (document_origin) |origin| {
                ctx.allocator.free(origin);
            }
            return instance;
        };
        wdebug.print("call_constructor() script fetched, len={d}\n", .{fetched_script.source.len});

        // Free the document_origin now that fetching is complete (it was allocated by Document.get_URL)
        if (document_origin) |origin| {
            ctx.allocator.free(origin);
        }
        // CRITICAL: DO NOT create V8 isolate/context during constructor!
        // WorkerV8Context.init() enters the worker's isolate, which corrupts
        // the main isolate's HandleScope state during constructor execution.
        //
        // Instead, store the fetched script info and defer ALL V8 operations
        // to the setTimeout callback.

        // Store the fetched script source and URL in internal state for deferred execution
        const script_source_copy = ctx.allocator.dupe(u8, fetched_script.source) catch |err| {
            std.log.warn("Failed to copy worker script source: {}", .{err});
            @constCast(&fetched_script).deinit();
            return instance;
        };
        internal_state.pending_script = script_source_copy;

        // Store the final URL for V8 context creation (resolved relative paths)
        const final_url_copy = ctx.allocator.dupe(u8, fetched_script.final_url) catch |err| {
            std.log.warn("Failed to copy worker script URL: {}", .{err});
            ctx.allocator.free(script_source_copy);
            internal_state.pending_script = null;
            @constCast(&fetched_script).deinit();
            return instance;
        };
        internal_state.pending_script_url = final_url_copy;

        // Clean up fetched script metadata (source and URL are copied)
        @constCast(&fetched_script).deinit();

        // Start the worker's message queue so messages can be dispatched
        // This is pure Zig, no V8 isolate switching
        dedicated_worker.startMessageQueue();

        // CRITICAL: DO NOT execute worker script inside the constructor!
        // Entering/exiting the worker isolate during constructor execution
        // corrupts the main isolate's HandleScope state, causing V8 crashes.
        //
        // Instead, schedule worker script execution via setTimeout(0).
        // This runs after:
        // 1. The constructor returns and V8 wraps the instance
        // 2. JavaScript continues (e.g., fetch_tests_from_worker sets up handlers)
        // 3. The current script finishes
        // 4. The event loop runs the scheduled task
        if (ctx.timer) |timer| {
            wdebug.print("call_constructor() scheduling executeWorkerScriptCallback via setTimeout(0)\n", .{});
            _ = timer.setTimeout(0, executeWorkerScriptCallback, instance);
            wdebug.print("call_constructor() setTimeout scheduled\n", .{});
        } else {
            // No timer available - fall back to synchronous execution
            // WARNING: This may cause crashes due to HandleScope issues
            std.log.warn("Worker: no timer available, executing script synchronously (may crash)", .{});
            _ = executeWorkerScriptSync(internal_state);
        }
    } else |err| {
        // Timer backend initialization failed - worker remains in "not started" state
        wdebug.print("call_constructor() FAILED: no timer backend: {s}\n", .{@errorName(err)});
        std.log.warn("TimerBackend not available, worker will not start", .{});
    }

    wdebug.print("=== Worker.call_constructor() END ===\n", .{});
    wdebug.print("  returning instance: {*}\n\n", .{instance});
    return instance;
}

/// Getter for onerror
///
/// Spec: HTML Standard § 10.2.3
/// Event handler for error events on the worker.
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onerror;
}

/// Getter for onmessage
///
/// Spec: HTML Standard § 10.2.3
/// Event handler for message events from the worker.
pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onmessage;
}

/// Getter for onmessageerror
///
/// Spec: HTML Standard § 10.2.3
/// Event handler for messageerror events.
pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onmessageerror;
}

/// Extract GlobalHandle from a tagged callback pointer (from V8 conversion).
/// The V8 conversions layer creates Global handles and tags the pointers.
fn extractEventHandler(handler: ?*const anyopaque) v8_engine.OptionalGlobalHandle {
    if (handler) |ptr| {
        const untagged = v8_engine.pointer_tag.untagPointer(ptr);
        if (untagged.tag == .global_handle or untagged.tag == .untagged) {
            return v8_engine.GlobalHandle{ .ptr = @ptrCast(@alignCast(untagged.ptr)) };
        }
    }
    return null;
}

/// Get internal state from instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return if (state.own._internal) |internal| @constCast(internal) else null;
}

/// Setter for onerror
/// Extracts GlobalHandle from the tagged pointer passed from V8.
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onerror = value;

    // Also store as GlobalHandle in internal state for proper V8 invocation
    if (getInternal(instance)) |internal| {
        v8_engine.disposeOptionalGlobalHandle(&internal.onerror_handle);
        internal.onerror_handle = extractEventHandler(@ptrCast(value));
    }
}

/// Setter for onmessage
/// Extracts GlobalHandle from the tagged pointer passed from V8.
///
/// When onmessage is set, we also process any queued messages. This handles the
/// common pattern where:
/// 1. Worker constructor executes the worker script (which posts messages)
/// 2. JavaScript continues and sets worker.onmessage
/// 3. Messages should now be delivered
///
/// Per HTML spec, messages should be delivered asynchronously via the event loop.
/// However, for practical purposes (especially WPT tests), processing messages
/// when the handler is set achieves the correct observable behavior - messages
/// are delivered after the handler is ready.
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onmessage = value;

    // Also store as GlobalHandle in internal state for proper V8 invocation
    if (getInternal(instance)) |internal| {
        v8_engine.disposeOptionalGlobalHandle(&internal.onmessage_handle);
        internal.onmessage_handle = extractEventHandler(@ptrCast(value));

        // Process any messages that were queued before the handler was set
        // This ensures messages posted by the worker during script execution
        // are delivered now that there's a handler to receive them.
        if (internal.dedicated_worker) |dedicated_worker| {
            dedicated_worker.processQueuedMessages();
        }
    }
}

/// Setter for onmessageerror
/// Extracts GlobalHandle from the tagged pointer passed from V8.
pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onmessageerror = value;

    // Also store as GlobalHandle in internal state for proper V8 invocation
    if (getInternal(instance)) |internal| {
        v8_engine.disposeOptionalGlobalHandle(&internal.onmessageerror_handle);
        internal.onmessageerror_handle = extractEventHandler(@ptrCast(value));
    }
}

/// Timer callback for executing the worker script (deferred from constructor)
///
/// CRITICAL: Worker script execution MUST happen on a SEPARATE THREAD to avoid
/// HandleScope corruption. V8 isolates cannot be safely switched on the same thread
/// during active JavaScript execution.
///
/// This callback spawns a worker thread using WorkerThreadRunner, which:
/// 1. Creates V8 isolate ON THE WORKER THREAD (not main thread)
/// 2. Executes the worker script on the worker thread
/// 3. Uses thread-safe message queues for postMessage
fn executeWorkerScriptCallback(user_data: ?*anyopaque) void {
    wdebug.print("\n=== executeWorkerScriptCallback() START ===\n", .{});
    const instance: *runtime.Instance = @ptrCast(@alignCast(user_data orelse return));
    wdebug.print("  instance ptr: {*}\n", .{instance});
    const internal = getInternal(instance) orelse return;
    wdebug.print("  internal ptr: {*}\n", .{internal});
    wdebug.print("  dedicated_worker ptr: {?*}\n", .{internal.dedicated_worker});
    wdebug.print("  use_threading: {}\n", .{internal.use_threading});

    // Check if we should use threading (default: true)
    if (internal.use_threading) {
        wdebug.print("  -> Using threading path (spawnWorkerThread)\n", .{});
        // Use the threading infrastructure - creates V8 isolate on worker thread
        spawnWorkerThread(internal) catch |err| {
            std.log.warn("Worker: Failed to spawn worker thread: {}, falling back to sync", .{err});
            wdebug.print("  -> spawnWorkerThread FAILED: {s}, falling back to sync\n", .{@errorName(err)});
            // Fall back to synchronous execution if threading fails
            executeSyncFallback(internal, instance);
        };
    } else {
        wdebug.print("  -> Using sync fallback path\n", .{});
        // Synchronous fallback (still has HandleScope issues, but useful for testing)
        executeSyncFallback(internal, instance);
    }
    wdebug.print("=== executeWorkerScriptCallback() END ===\n\n", .{});
}

/// Spawn worker on a separate thread using WorkerThreadRunner
///
/// This is the correct approach - V8 isolate creation happens ON THE WORKER THREAD,
/// completely avoiding HandleScope corruption on the main thread.
fn spawnWorkerThread(internal: *InternalState) !void {
    wdebug.print("spawnWorkerThread() called\n", .{});

    const script_url = internal.pending_script_url orelse internal.script_url;
    const script = internal.pending_script orelse return error.NoScript;
    wdebug.print("spawnWorkerThread() script_url={s}\n", .{script_url});

    // Create thread state with worker configuration
    wdebug.print("spawnWorkerThread() creating WorkerThreadState...\n", .{});
    const thread_state = try WorkerThreadState.init(
        internal.allocator,
        script_url,
        .{
            .worker_type = internal.worker_type,
            .name = internal.name,
        },
    );
    wdebug.print("spawnWorkerThread() WorkerThreadState created at {*}, inbox at {*}\n", .{ thread_state, &thread_state.inbox });

    // Set document origin for resolving relative imports in data:/blob: workers
    // This is the creating document's URL, which data:/blob: workers need as a base
    if (internal.document_origin) |origin| {
        try thread_state.setDocumentOrigin(origin);
    }

    // Initialize global wakeup for efficient main thread notification
    // All workers share this wakeup - when any worker posts a message,
    // the main thread is woken up immediately instead of polling
    const wakeup: ?*workers.ThreadedWorkerRegistry.EventWakeup = workers.ThreadedWorkerRegistry.getOrCreateGlobalWakeup(internal.allocator) catch |err| blk: {
        std.log.warn("Worker: Failed to create global wakeup: {}, message delivery may be delayed", .{err});
        // Continue without wakeup - will fall back to polling
        break :blk null;
    };
    if (wakeup) |w| {
        thread_state.wakeup = w;
        thread_state.outbox.setWakeup(w);
    }

    // Link the DedicatedWorker and thread_state bidirectionally:
    // - thread_state.worker_ptr allows callbacks to access the DedicatedWorker
    // - dedicated_worker.thread_state allows postMessageFromWorker to use thread-safe outbox
    if (internal.dedicated_worker) |dw| {
        dw.setThreadState(thread_state);
    }

    // Create the thread runner
    wdebug.print("spawnWorkerThread() creating WorkerThreadRunner...\n", .{});
    var runner = try WorkerThreadRunner.init(internal.allocator, thread_state);

    // Set up V8 callbacks - these run ON THE WORKER THREAD
    // Use WorkerV8Context-based callbacks which have proper WebIDL interface
    // registration (XMLHttpRequest, etc.) instead of raw V8 FFI
    wdebug.print("spawnWorkerThread() setting callbacks...\n", .{});
    runner.setCallbacks(
        createIsolateCallback(),
        disposeIsolateCallback(),
        executeScriptCallback(),
        dispatchMessageCallback(),
        microtaskCheckpointCallback(),
        null, // No callback context needed
    );

    // Store the runner for later cleanup and message passing
    internal.thread_runner = runner;

    // Spawn the worker thread - V8 isolate is created ON THE WORKER THREAD
    wdebug.print("spawnWorkerThread() calling runner.spawn()...\n", .{});
    try runner.spawn();
    wdebug.print("spawnWorkerThread() runner.spawn() returned successfully\n", .{});

    // Send the script to the worker thread for execution
    // The worker thread will execute it after creating its V8 context
    //
    // CRITICAL: Use page_allocator for cross-thread messaging.
    // The message will be freed by the worker thread via msg.deinit().
    // Using the main thread's allocator (internal.allocator) from the worker thread
    // would corrupt the allocator's internal state and cause Bus errors.
    // page_allocator is thread-safe (it just maps/unmaps memory pages).
    wdebug.print("spawnWorkerThread() serializing script for worker...\n", .{});
    const cross_thread_allocator = std.heap.page_allocator;

    const js_value = structured_clone.JSValue{ .string = script };
    const serialized = try structured_clone.structuredSerialize(
        cross_thread_allocator,
        &js_value,
    );

    // Create a SerializedMessage on the heap for cross-thread transfer
    const msg = cross_thread_allocator.create(workers.ThreadSafeMessageQueue.SerializedMessage) catch {
        // Clean up the serialized value struct (but not its contents, as we haven't copied yet)
        cross_thread_allocator.destroy(serialized);
        return;
    };
    msg.* = .{
        .data = serialized.*,
        .transfers = null,
        .allocator = cross_thread_allocator,
    };

    // Free the SerializedValue struct (its contents are now owned by msg.data)
    cross_thread_allocator.destroy(serialized);

    thread_state.inbox.enqueue(msg) catch {
        wdebug.print("spawnWorkerThread() FAILED to enqueue script message\n", .{});
        msg.deinit();
        return;
    };
    wdebug.print("spawnWorkerThread() script message enqueued to worker inbox\n", .{});

    // Free the pending script now that we've sent it
    if (internal.pending_script) |s| {
        internal.allocator.free(s);
        internal.pending_script = null;
    }
    if (internal.pending_script_url) |url| {
        internal.allocator.free(url);
        internal.pending_script_url = null;
    }
}

/// Synchronous fallback - still has HandleScope issues but useful for testing
fn executeSyncFallback(internal: *InternalState, instance: *runtime.Instance) void {
    const dedicated_worker = internal.dedicated_worker orelse return;

    // Start the worker context if not yet started
    if (!dedicated_worker.hasContext()) {
        dedicated_worker.startWithContext() catch |err| {
            std.log.warn("Worker: Failed to start worker context: {}", .{err});
            return;
        };
    }

    // Create V8 context if not yet created
    // WARNING: This corrupts HandleScope state on the main thread!
    if (internal.v8_context == null) {
        const script_url = internal.pending_script_url orelse internal.script_url;

        const v8_context = WorkerV8Context.init(
            internal.allocator,
            script_url,
            internal.worker_type,
            internal.document_origin, // Pass document origin as base URL for data:/blob: workers
        ) catch |err| {
            std.log.warn("Worker: Failed to create V8 context: {}", .{err});
            return;
        };
        internal.v8_context = v8_context;

        // Wire up the V8 context to the WorkerContext
        if (dedicated_worker.agent.worker_context) |wctx| {
            wctx.setEngineContext(v8_context.getEngineContext(), v8_context.getCallbacks());
        }

        // Set up DedicatedWorkerGlobalScope
        v8_context.setupWorkerGlobalScope(dedicated_worker) catch |err| {
            std.log.warn("Worker: Failed to set up worker global scope: {}", .{err});
            return;
        };

        // Free the pending script URL
        if (internal.pending_script_url) |url| {
            internal.allocator.free(url);
            internal.pending_script_url = null;
        }
    }

    // Execute worker script
    const has_messages = executeWorkerScriptSync(internal);

    // Schedule message dispatch if needed
    if (has_messages) {
        if (internal.ctx) |ctx| {
            if (ctx.timer) |timer| {
                _ = timer.setTimeout(0, dispatchWorkerMessagesCallback, instance);
            }
        }
    }
}

/// Callback to dispatch worker messages in a clean V8 state.
///
/// This runs in a separate timer callback (not immediately after worker script
/// execution) to ensure V8's HandleScope state is properly restored.
///
/// The event loop's timer handling runs after V8 microtask checkpoints,
/// so we're guaranteed to have a valid HandleScope context here.
fn dispatchWorkerMessagesCallback(user_data: ?*anyopaque) void {
    const instance: *runtime.Instance = @ptrCast(@alignCast(user_data orelse return));
    const internal = getInternal(instance) orelse return;
    const dedicated_worker = internal.dedicated_worker orelse return;

    // Now dispatch messages - we're in a clean V8 state with proper HandleScope
    dedicated_worker.processQueuedMessages();
}

/// Execute worker script synchronously (internal helper)
/// Called from either executeWorkerScriptCallback or synchronous fallback
///
/// CRITICAL DESIGN NOTE:
/// V8's HandleScope state is per-isolate and becomes corrupted when we switch
/// between isolates on the same thread. The worker's executeScript() enters the
/// worker isolate, which invalidates any HandleScope state in the main isolate.
///
/// Therefore, we MUST NOT do any V8 operations (like message dispatch) immediately
/// after worker script execution. Instead, we queue a task to dispatch messages
/// in the next event loop iteration, where the HandleScope state is clean.
///
/// Returns: true if messages were queued for dispatch, false otherwise
fn executeWorkerScriptSync(internal: *InternalState) bool {
    const dedicated_worker = internal.dedicated_worker orelse return false;
    const script = internal.pending_script orelse return false;

    // Verify worker context is ready
    if (!dedicated_worker.hasContext()) {
        std.log.warn("Worker: No context available for script execution", .{});
        return false;
    }

    // Execute the script in worker context
    // The worker's executeScript() enters/exits its own isolate and creates its own HandleScope.
    // After this returns, V8's HandleScope state for the main isolate is corrupted.
    dedicated_worker.executeScript(script) catch |err| {
        std.log.warn("Failed to execute worker script: {}", .{err});
    };

    // Flush pending messages to port queues
    // This is a pure Zig operation - NO V8 operations!
    DedicatedWorker.flushPendingMessages();

    // Free the script source
    internal.allocator.free(script);
    internal.pending_script = null;

    // Check if there are messages to dispatch
    const queue_len = dedicated_worker.port_pair.outside_port.message_queue.items.len;

    // DO NOT dispatch messages here!
    // The V8 HandleScope state is corrupted after worker isolate enter/exit.
    // Messages will be dispatched by the event loop in the next iteration,
    // where the HandleScope is properly managed.
    //
    // The event loop will call processQueuedMessages() in its runOnce() or via
    // a queued task, both of which have clean HandleScope state.

    return queue_len > 0;
}

/// Callback for messages received from the worker via the outside port
///
/// Spec: HTML Standard § 10.2.3
/// "When a message is received on the outside port..."
/// 1. Deserialize the message data
/// 2. Create a MessageEvent with the data
/// 3. Dispatch the event (invoke onmessage handler)
///
/// This is called by DedicatedWorker when a message arrives from the worker
/// on the outside_port (worker → main thread direction).
fn handleMessageFromWorkerCallback(dedicated_worker: *DedicatedWorker, msg: *QueuedMessage) void {
    wdebug.print("[WORKER_IMPL] handleMessageFromWorkerCallback() called\n", .{});

    // Get the InternalState from outside_user_data (set in call_constructor)
    // We use outside_user_data (not user_data) because user_data is used by the worker
    // thread's DedicatedWorkerGlobalScope for handling messages INSIDE the worker.
    // We store InternalState* (not instance*) because InternalState lives on Zig heap
    // and won't be corrupted when V8 GC's the Worker object.
    const user_data = dedicated_worker.outside_user_data orelse {
        wdebug.print("[WORKER_IMPL] handleMessageFromWorkerCallback() outside_user_data is null\n", .{});
        return;
    };
    const internal: *InternalState = @ptrCast(@alignCast(user_data));
    wdebug.print("[WORKER_IMPL] handleMessageFromWorkerCallback() internal from outside_user_data: {*}\n", .{internal});

    wdebug.print("[WORKER_IMPL] handleMessageFromWorkerCallback() dispatching to onmessage\n", .{});
    dispatchMessageEventDirect(internal, msg);
    wdebug.print("handleMessageFromWorkerCallback() dispatch complete\n", .{});
}

/// Handle errors from the worker thread
///
/// Spec: HTML Standard § 10.2.5 "Runtime script errors in workers"
/// https://html.spec.whatwg.org/#runtime-script-errors-2
///
/// When a worker script throws an error that is not caught:
/// 1. Create an ErrorEvent with error details (message, filename, lineno, colno)
/// 2. Dispatch the event at the Worker object on the main thread
/// 3. If not prevented, propagate to the Window's error handler
///
/// This is called by DedicatedWorker when an error occurs in the worker thread.
/// The InternalState is passed via error_event.context, which was set by
/// WorkerErrorHandler.fireError() from the handler's context field.
fn handleErrorFromWorkerCallback(error_event: *worker_error.WorkerErrorEvent) void {
    wdebug.print("[WORKER_IMPL] handleErrorFromWorkerCallback() called\n", .{});
    wdebug.print("[WORKER_IMPL]   message: {s}\n", .{error_event.message});
    wdebug.print("[WORKER_IMPL]   filename: {s}\n", .{error_event.filename});
    wdebug.print("[WORKER_IMPL]   lineno: {d}, colno: {d}\n", .{ error_event.lineno, error_event.colno });

    // Get the InternalState from context (set by WorkerErrorHandler.fireError)
    const context = error_event.context orelse {
        wdebug.print("[WORKER_IMPL] handleErrorFromWorkerCallback() context is null\n", .{});
        return;
    };
    const internal: *InternalState = @ptrCast(@alignCast(context));

    // Get isolate for V8 operations
    const isolate = internal.isolate orelse {
        wdebug.print("[WORKER_IMPL] handleErrorFromWorkerCallback() isolate is null\n", .{});
        return;
    };

    // Verify ctx is available (required by dispatchErrorEvent internally)
    if (internal.ctx == null) {
        wdebug.print("[WORKER_IMPL] handleErrorFromWorkerCallback() ctx is null\n", .{});
        return;
    }

    const instance = internal.worker_instance orelse {
        wdebug.print("[WORKER_IMPL] handleErrorFromWorkerCallback() worker_instance is null\n", .{});
        return;
    };

    // Enter isolate if needed
    const current_isolate = v8_engine.ffi.v8_Isolate_GetCurrent();
    const need_enter_isolate = (current_isolate == null) or (current_isolate != isolate);
    if (need_enter_isolate) {
        v8_engine.ffi.v8_Isolate_Enter(isolate);
    }
    defer if (need_enter_isolate) {
        v8_engine.ffi.v8_Isolate_Exit(isolate);
    };

    // Create HandleScope
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(isolate) orelse {
        wdebug.print("[WORKER_IMPL] handleErrorFromWorkerCallback() failed to create HandleScope\n", .{});
        return;
    };
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Dispatch ErrorEvent on the Worker object
    // Note: dispatchErrorEvent gets context internally via getInternal(instance)
    dispatchErrorEvent(
        instance,
        error_event.message,
        error_event.filename,
        error_event.lineno,
        error_event.colno,
        error_event.error_value,
    );

    wdebug.print("[WORKER_IMPL] handleErrorFromWorkerCallback() complete\n", .{});
}

/// Dispatch a MessageEvent to the Worker's message handlers using EventTarget.dispatchEvent
///
/// This creates a MessageEvent with the deserialized data and dispatches it through
/// the DOM EventTarget system:
/// 1. Create MessageEvent with proper data attribute
/// 2. Set isTrusted to true (event is fired by the browser)
/// 3. Dispatch via EventTarget.dispatchEvent (invokes addEventListener + onmessage)
///
/// ## V8 Callback Invocation
///
/// Event listeners are stored as CallbackWrapper instances that hold Global handles
/// to JavaScript functions. The event dispatch algorithm invokes them via the
/// EventTarget infrastructure.
///
/// The legacy EventHandler (onmessage) is invoked after all event listeners.
///
/// ## JSON Message Handling
///
/// Worker messages are now serialized as JSON strings for cross-isolate safety.
/// This function:
/// 1. Extracts the JSON string from the SerializedValue
/// 2. Parses it using V8's JSON.parse in the main context
/// 3. Creates MessageEvent with the parsed value as data
///
/// ## Spec Reference
/// HTML § 10.2.3: "Fire an event named message at the Worker object, using
/// MessageEvent, with the data attribute initialized to the message."
/// Dispatch message event using InternalState directly (bypasses instance lookup).
/// This is used when user_data contains InternalState* instead of instance*.
fn dispatchMessageEventDirect(internal: *InternalState, msg: *QueuedMessage) void {
    wdebug.print("[dispatchMessageEventDirect] ENTRY, internal={*}\n", .{internal});

    // Debug: Print internal state fields to detect corruption
    wdebug.print("[dispatchMessageEventDirect] internal.isolate={?}\n", .{@as(?*anyopaque, @ptrCast(internal.isolate))});
    wdebug.print("[dispatchMessageEventDirect] internal.ctx={?}\n", .{@as(?*anyopaque, @ptrCast(internal.ctx))});
    wdebug.print("[dispatchMessageEventDirect] internal.v8_context_ptr={?}\n", .{@as(?*anyopaque, @ptrCast(internal.v8_context_ptr))});

    // Get isolate and runtime context (for allocator)
    const isolate = internal.isolate orelse {
        wdebug.print("[dispatchMessageEventDirect] isolate is null!\n", .{});
        return;
    };
    wdebug.print("[dispatchMessageEventDirect] isolate={*}\n", .{isolate});

    const ctx = internal.ctx orelse {
        wdebug.print("[dispatchMessageEventDirect] ctx is null!\n", .{});
        return;
    };

    dispatchMessageEventWithContext(internal, isolate, ctx, msg);
}

fn dispatchMessageEvent(instance: *runtime.Instance, msg: *QueuedMessage) void {
    wdebug.print("[dispatchMessageEvent] ENTRY, instance={*}\n", .{instance});

    // Get internal state with GlobalHandle and isolate
    const internal = getInternal(instance) orelse {
        wdebug.print("[dispatchMessageEvent] getInternal returned null!\n", .{});
        return;
    };
    wdebug.print("[dispatchMessageEvent] got internal={*}\n", .{internal});

    // Debug: Print internal state fields to detect corruption
    wdebug.print("[dispatchMessageEvent] internal.isolate={?}\n", .{@as(?*anyopaque, @ptrCast(internal.isolate))});
    wdebug.print("[dispatchMessageEvent] internal.ctx={?}\n", .{@as(?*anyopaque, @ptrCast(internal.ctx))});
    wdebug.print("[dispatchMessageEvent] internal.v8_context_ptr={?}\n", .{@as(?*anyopaque, @ptrCast(internal.v8_context_ptr))});

    // Get isolate and runtime context (for allocator)
    const isolate = internal.isolate orelse {
        wdebug.print("[dispatchMessageEvent] isolate is null!\n", .{});
        return;
    };
    wdebug.print("[dispatchMessageEvent] isolate={*}\n", .{isolate});

    const ctx = internal.ctx orelse {
        wdebug.print("[dispatchMessageEvent] ctx is null!\n", .{});
        return;
    };

    dispatchMessageEventWithContext(internal, isolate, ctx, msg);
}

/// Core message dispatch logic shared by both entry points
fn dispatchMessageEventWithContext(
    internal: *InternalState,
    isolate: *v8_engine.ffi.Isolate,
    ctx: runtime.Context,
    msg: *QueuedMessage,
) void {
    // Get the instance from internal state (needed for dispatchMessageErrorEvent)
    const instance = internal.worker_instance orelse {
        wdebug.print("[dispatchMessageEventWithContext] worker_instance is null!\n", .{});
        return;
    };

    // Use the V8 context pointer stored at constructor time.
    // This is more reliable than ctx.getEngineContextAs() which can crash
    // if the ContextData has been freed or corrupted.
    const v8_context: *v8_engine.ffi.Context = internal.v8_context_ptr orelse blk: {
        // Fallback to old method (may crash, but provides error info)
        break :blk ctx.getEngineContextAs(v8_engine.ffi.Context) orelse {
            std.log.warn("[dispatchMessageEvent] No v8_context_ptr and getEngineContextAs returned null", .{});
            return;
        };
    };

    // Check current isolate state
    const current_isolate = v8_engine.ffi.v8_Isolate_GetCurrent();

    // We need to be in the main isolate to dispatch events.
    // After worker script execution, we may be in a different isolate
    // (e.g., a previous test's isolate). We must enter the correct isolate.
    const need_enter_isolate = (current_isolate == null) or (current_isolate != isolate);
    if (need_enter_isolate) {
        v8_engine.ffi.v8_Isolate_Enter(isolate);
    }
    defer if (need_enter_isolate) {
        v8_engine.ffi.v8_Isolate_Exit(isolate);
    };

    // Create HandleScope for V8 handle allocation
    // This is CRITICAL when called from a timer callback where there's no
    // existing HandleScope (unlike when called from JavaScript execution).
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(isolate) orelse {
        std.log.warn("[dispatchMessageEvent] Failed to create HandleScope - V8 may be in invalid state", .{});
        return;
    };
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Verify we have a valid context, enter if needed
    const current_context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate);
    const need_enter_context = (current_context == null) or (current_context != v8_context);
    if (need_enter_context) {
        v8_engine.ffi.v8_Context_Enter(v8_context);
    }
    defer if (need_enter_context) {
        v8_engine.ffi.v8_Context_Exit(v8_context);
    };

    // Reconstruct transferred ArrayBuffers in the receiving context
    // Per HTML § 2.7.7 StructuredDeserializeWithTransfer:
    // "For each transferDataHolder of serializeWithTransferResult's [[TransferDataHolders]]:
    //  Let value be a new instance of transferDataHolder.[[Type]] with internal state from transferDataHolder."
    var reconstructed_buffers: std.ArrayListUnmanaged(*v8_engine.ffi.ArrayBuffer) = .{};
    defer reconstructed_buffers.deinit(ctx.allocator);

    if (msg.transferred) |transfers| {
        for (transfers) |maybe_transfer| {
            if (maybe_transfer) |transfer_ptr| {
                // Check if this is a TransferredArrayBuffer by trying to interpret it
                // Note: We stored TransferredArrayBuffer pointers in parseTransferList
                const tab: *TransferredArrayBuffer = @ptrCast(@alignCast(transfer_ptr));

                // Create new ArrayBuffer in this context with the transferred data
                const new_buffer = v8_engine.ffi.v8_ArrayBuffer_New(isolate, tab.byte_length);
                if (new_buffer) |buffer| {
                    // Copy the transferred data into the new ArrayBuffer
                    if (tab.data.len > 0) {
                        const dest_ptr = v8_engine.ffi.v8_ArrayBuffer_Data(buffer);
                        if (dest_ptr) |dest| {
                            const dest_slice: [*]u8 = @ptrCast(dest);
                            @memcpy(dest_slice[0..tab.byte_length], tab.data);
                        }
                    }
                    reconstructed_buffers.append(ctx.allocator, buffer) catch {};
                }

                // Clean up the transfer data - we've consumed it
                tab.deinit();
                ctx.allocator.destroy(tab);
            }
        }
        // Free the transfers array itself
        ctx.allocator.free(transfers);
    }

    // Get the message data - check if it's a JSON string from worker
    // The worker sends JSON-serialized messages for cross-isolate safety
    var v8_data: ?*v8_engine.ffi.Value = null;

    // Check the serialized value type
    if (msg.data.type == .primitive) {
        switch (msg.data.data.primitive) {
            .string => |json_str| {
                // JSON string from worker - parse it in main context
                v8_data = v8_engine.ffi.v8_JSON_Parse_FromBuffer(
                    v8_context,
                    json_str.ptr,
                    @intCast(json_str.len),
                );
                if (v8_data == null) {
                    std.log.warn("Worker.dispatchMessageEvent: JSON.parse failed for: {s}", .{json_str});
                }
            },
            else => {},
        }
    } else {}

    // If we couldn't get V8 data (JSON parse failed or not a string message),
    // fire messageerror event per HTML Standard § 9.3.6.2:
    // "If this throws an exception, then fire an event named messageerror"
    //
    // NOTE: The previous deserialization fallback was buggy - it treated
    // *serialize.JSValue (a Zig struct) as if it were a V8 handle, causing
    // "Cannot create a handle without a HandleScope" crashes.
    // Worker messages should always be JSON-serialized strings, so JSON.parse
    // should always succeed. If it doesn't, that's a serialization bug.
    if (v8_data == null) {
        std.log.warn("Worker.dispatchMessageEvent: JSON.parse failed, firing messageerror", .{});
        dispatchMessageErrorEvent(instance, internal, isolate, v8_context, ctx);
        return;
    }

    // We have V8 data from JSON.parse - create MessageEvent with it
    const message_event = MessageEvent.call_constructor(
        ctx,
        runtime.DOMString.initInterned("message"),
        webidl.Opt(dictionaries.MessageEventInit).notPassed(),
    ) catch |err| {
        std.log.warn("Failed to create MessageEvent: {}", .{err});
        if (v8_data) |data| {
            v8_engine.ffi.v8_Value_Dispose(data);
        }
        return;
    };

    // Set the data property on the MessageEvent
    // v8_JSON_Parse_FromBuffer returns a Local handle that's only valid in the current HandleScope.
    // When the callback executes (via v8_Function_Call), it may create its own HandleScope.
    // The callback then accesses message.data, which triggers our getter.
    // At that point, the original Local handle might not be valid.
    //
    // Solution: Convert the Local to a Global handle for safe storage.
    // The Global handle persists across HandleScope boundaries.
    const global_data = v8_engine.ffi.v8_Value_ToGlobal(isolate, @ptrCast(v8_data)) orelse {
        std.log.warn("Failed to convert JSON data to Global handle", .{});
        return;
    };
    // Note: This Global handle persists across HandleScope boundaries.
    // It is disposed at the end of this function after dispatch completes.

    {
        var event_state = message_event.getState(MessageEvent.State);
        event_state.own.data = runtime.JSValue.fromHandle(@ptrCast(global_data));
        std.debug.print("[Worker.dispatchMessageEvent] Set MessageEvent.data to handle ptr={*}\n", .{global_data});
        // Set isTrusted to true since this event is fired by the browser
        event_state.base.own.isTrusted = true;
        event_state.base.own.target = instance;
        event_state.base.own.currentTarget = instance;
    }

    // Wrap the MessageEvent instance as a V8 Object
    const v8_event = template_registry.wrapInstanceAsV8Object(
        message_event,
        "MessageEvent",
        isolate,
        v8_context,
    ) catch |err| {
        std.log.warn("Failed to wrap MessageEvent as V8 object: {s}", .{@errorName(err)});
        return;
    };

    // Dispatch via EventTarget.dispatchEvent - this invokes addEventListener listeners
    // through the DOM event dispatch algorithm
    _ = EventTarget.call_dispatchEvent(instance, message_event) catch |err| {
        std.log.warn("Failed to dispatch MessageEvent: {s}", .{@errorName(err)});
    };

    // After dispatchEvent, also invoke the legacy onmessage handler if set via IDL attribute
    // The EventTarget.dispatchEvent handles listeners registered via addEventListener,
    // but we need to separately handle the legacy onXXX IDL attribute handler that
    // is stored as a GlobalHandle in internal state.
    invokeLegacyOnmessageHandler(instance, isolate, v8_context, v8_event, internal);

    // Note: The Global handle stored in event_state.own.data is NOT disposed here.
    // JavaScript event handlers might schedule async work (setTimeout, Promise.then)
    // that accesses event.data later. Disposing here would cause use-after-free.
    // The Global handle will be disposed when the MessageEvent is garbage collected
    // via the weak callback mechanism and MessageEvent.deinit.
}

/// Invoke the legacy onmessage IDL attribute handler
///
/// Per HTML spec, the onXXX IDL event handlers are separate from addEventListener.
/// The onmessage property stores a GlobalHandle to a JavaScript function.
/// This function is called after EventTarget.dispatchEvent has handled all
/// addEventListener-registered listeners.
///
/// Note: EventTarget.dispatchEvent already handles listeners registered via
/// addEventListener, so this function only handles the legacy IDL attribute.
fn invokeLegacyOnmessageHandler(
    instance: *runtime.Instance,
    isolate: *v8_engine.ffi.Isolate,
    v8_context: *v8_engine.ffi.Context,
    v8_event: *v8_engine.ffi.Object,
    internal: *InternalState,
) void {
    _ = instance; // For future use with EventTarget internal state

    // Invoke the onmessage handler if set
    if (internal.onmessage_handle) |onmessage_global| {
        // Retrieve Local handle from Global handle
        const local_value = onmessage_global.get(isolate) orelse {
            std.log.warn("Worker.invokeLegacyOnmessageHandler: Failed to get Local from GlobalHandle", .{});
            return;
        };

        // Verify it's a function
        if (!v8_engine.ffi.v8_Value_IsFunction(@ptrCast(local_value))) {
            std.log.warn("Worker.invokeLegacyOnmessageHandler: onmessage is not a function", .{});
            return;
        }
        const function: *v8_engine.ffi.Function = @ptrCast(local_value);

        // Call the V8 function with the MessageEvent as argument
        const undefined_recv = v8_engine.ffi.v8_Undefined(isolate);
        var args = [_]*v8_engine.ffi.Value{@ptrCast(v8_event)};
        _ = v8_engine.ffi.v8_Function_Call(function, v8_context, @ptrCast(undefined_recv), 1, &args);
    }
}

/// Dispatch a messageerror event to the Worker
///
/// Spec: HTML Standard § 9.3.6.2
/// "If this throws an exception, then fire an event named messageerror at the port,
/// using MessageEvent, with the origin attribute initialized to origin..."
///
/// This is called when structured clone deserialization fails on a received message.
fn dispatchMessageErrorEvent(
    instance: *runtime.Instance,
    internal: *const InternalState,
    isolate: *v8_engine.ffi.Isolate,
    v8_context: *v8_engine.ffi.Context,
    ctx: runtime.Context,
) void {
    // Create MessageEventInit dictionary for messageerror
    // Per spec, data is undefined for messageerror events
    const init_dict = dictionaries.MessageEventInit{
        .base = .{
            .bubbles = false,
            .cancelable = false,
            .composed = false,
        },
        .data = null, // data is undefined for messageerror
        .origin = "",
        .lastEventId = null,
        .source = null,
        .ports = null,
    };

    // Create MessageEvent via interface with type "messageerror"
    const message_event = MessageEvent.call_constructor(
        ctx,
        runtime.DOMString.initInterned("messageerror"),
        webidl.Opt(dictionaries.MessageEventInit).passed(init_dict),
    ) catch |err| {
        std.log.warn("Failed to create messageerror event: {s}", .{@errorName(err)});
        return;
    };

    // Set isTrusted and target/currentTarget
    {
        var ev_state = message_event.getState(MessageEvent.State);
        ev_state.base.own.isTrusted = true;
        ev_state.base.own.target = instance;
        ev_state.base.own.currentTarget = instance;
    }

    // Wrap event as V8 object
    const v8_event = template_registry.wrapInstanceAsV8Object(
        message_event,
        "MessageEvent",
        isolate,
        v8_context,
    ) catch |err| {
        std.log.warn("Failed to wrap messageerror event: {s}", .{@errorName(err)});
        return;
    };

    // Dispatch via EventTarget.dispatchEvent
    _ = EventTarget.call_dispatchEvent(instance, message_event) catch |err| {
        std.log.warn("Failed to dispatch messageerror event: {s}", .{@errorName(err)});
        return;
    };

    // Also invoke the legacy onmessageerror handler if set
    if (internal.onmessageerror_handle) |onmessageerror_global| {
        const local_value = onmessageerror_global.get(isolate) orelse {
            return;
        };

        if (!v8_engine.ffi.v8_Value_IsFunction(@ptrCast(local_value))) {
            return;
        }
        const function: *v8_engine.ffi.Function = @ptrCast(local_value);

        const undefined_recv = v8_engine.ffi.v8_Undefined(isolate);
        var args = [_]*v8_engine.ffi.Value{@ptrCast(v8_event)};
        _ = v8_engine.ffi.v8_Function_Call(function, v8_context, @ptrCast(undefined_recv), 1, &args);
    }
}

/// Operation: terminate
///
/// Spec: HTML Standard § 10.2.3.1 terminate()
/// "The terminate() method, when invoked, must cause the terminate a worker
/// algorithm to be run on the worker with which the object is associated."
pub fn call_terminate(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    if (state.own._internal) |internal_ptr| {
        // Mark as terminated
        const internal = @constCast(internal_ptr);
        internal.terminated = true;
        if (internal.dedicated_worker) |worker| {
            worker.terminate();
        }
    }
}

/// Operation: postMessage
///
/// Spec: HTML Standard § 10.2.3.1 postMessage(message, transfer)
/// Posts a message to the worker. Uses structured clone algorithm.
///
/// The message is serialized using the structured clone algorithm and
/// sent to the worker's message queue. If transfer list is provided,
/// transferable objects are moved (not copied) to the worker.
///
/// ## Transferable Objects (HTML § 2.7.3)
/// - ArrayBuffer: Data ownership transferred, original neutered
/// - MessagePort: Port entanglement transferred
/// - ReadableStream, WritableStream, TransformStream
/// - ImageBitmap, OffscreenCanvas
pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.terminated) {
            return; // Worker is terminated, ignore message
        }
        if (internal.dedicated_worker) |worker| {
            // Serialize the V8 value to JSON string, then create JSValue for structured clone
            const v8_ctx: *v8_engine.ffi.Context = @ptrCast(instance.ctx.engine_ctx orelse return error.InvalidContext);
            const v8_value: *v8_engine.ffi.Value = @ptrCast(message.toAnyopaque() orelse return error.TypeError);

            // Parse transfer list if provided
            // NOTE: transfer_pointers contains TransferredArrayBuffer structs that own their data.
            // We pass ownership to postMessageTyped → QueuedMessage → receiving end.
            // DO NOT free transfer_pointers here - the receiving end is responsible for cleanup.
            var transfer_pointers: ?[]?*anyopaque = null;

            if (transfer != .undefined and transfer != .null) {
                transfer_pointers = try parseTransferList(instance.ctx.allocator, transfer);
            }

            // First call to get required buffer size
            var size_buf: [1]u8 = undefined;
            const required_size = v8_engine.ffi.v8_JSON_Stringify_ToBuffer(v8_ctx, v8_value, &size_buf, 0);
            if (required_size < 0) {
                // Serialization failed - post undefined
                const js_value = JSValue{ .undefined = {} };
                try worker.postMessageTyped(&js_value, transfer_pointers);
                return;
            }
            if (required_size == 0) {
                // Empty result - post undefined
                const js_value = JSValue{ .undefined = {} };
                try worker.postMessageTyped(&js_value, transfer_pointers);
                return;
            }

            // Allocate buffer and serialize
            const buf = instance.ctx.allocator.alloc(u8, @intCast(required_size)) catch return error.OutOfMemory;
            defer instance.ctx.allocator.free(buf);

            const written = v8_engine.ffi.v8_JSON_Stringify_ToBuffer(v8_ctx, v8_value, buf.ptr, required_size);
            if (written < 0) {
                return error.SerializationFailed;
            }

            // Create JSValue with the JSON string (will be parsed on receive side)
            const json_slice = buf[0..@intCast(written)];
            const json_copy = instance.ctx.allocator.dupe(u8, json_slice) catch return error.OutOfMemory;
            const js_value = JSValue{ .string = json_copy };

            // Post the serialized message with transfer list
            try worker.postMessageTyped(&js_value, transfer_pointers);
        }
    }
}

/// Transferred ArrayBuffer data - stores the copied data before detachment
pub const TransferredArrayBuffer = struct {
    /// Copied data from the original ArrayBuffer
    data: []u8,
    /// Original byte length
    byte_length: usize,
    /// Allocator used for this struct
    allocator: std.mem.Allocator,

    pub fn deinit(self: *TransferredArrayBuffer) void {
        self.allocator.free(self.data);
    }
};

/// Parse a V8 transfer list (array of transferable objects) into transfer data
///
/// Spec: HTML Standard § 9.3.1 "postMessage(message, transfer)"
/// The transfer list contains objects that should be transferred (not cloned).
///
/// For ArrayBuffers, this function:
/// 1. Identifies each ArrayBuffer in the transfer list
/// 2. Copies the ArrayBuffer data (BEFORE detaching - V8 frees backing store on detach)
/// 3. Detaches (neuters) the ArrayBuffer, making original unusable
/// 4. Returns the copied data for reconstruction on the receiving end
///
/// Per HTML § 2.7.3 Transferable objects:
/// "When an ArrayBuffer is transferred, the original buffer is detached
/// and becomes unusable."
///
/// Returns: Array of TransferredArrayBuffer pointers (or null for non-ArrayBuffer items)
fn parseTransferList(allocator: std.mem.Allocator, transfer: runtime.JSValue) !?[]?*anyopaque {
    // Transfer should be an array
    const transfer_ptr = transfer.toAnyopaque() orelse return null;

    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return null;
    const v8_context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return null;

    const transfer_value: *v8_engine.ffi.Value = @ptrCast(transfer_ptr);

    // Check if it's an array
    if (!v8_engine.ffi.v8_Value_IsArray(transfer_value)) {
        return null; // Not an array, ignore
    }

    const transfer_array: *v8_engine.ffi.Array = @ptrCast(transfer_value);
    const length = v8_engine.ffi.v8_Array_Length(transfer_array);

    if (length == 0) {
        return null;
    }

    // Allocate array for transfer data
    var transfers = try allocator.alloc(?*anyopaque, length);
    errdefer {
        // Clean up any allocated TransferredArrayBuffer on error
        for (transfers) |maybe_transfer| {
            if (maybe_transfer) |transfer_ptr_inner| {
                const tab: *TransferredArrayBuffer = @ptrCast(@alignCast(transfer_ptr_inner));
                tab.deinit();
                allocator.destroy(tab);
            }
        }
        allocator.free(transfers);
    }

    for (0..length) |i| {
        const element = v8_engine.ffi.v8_Array_Get(v8_context, transfer_array, @intCast(i));
        if (element) |elem| {
            // Check if it's an ArrayBuffer - these are transferable
            if (v8_engine.ffi.v8_Value_IsArrayBuffer(elem)) {
                // Cast to ArrayBuffer
                const array_buffer: *v8_engine.ffi.ArrayBuffer = @ptrCast(elem);

                // Check if already detached (per spec: throw DataCloneError)
                if (v8_engine.ffi.v8_ArrayBuffer_IsDetached(array_buffer)) {
                    // DataCloneError: Cannot transfer a detached ArrayBuffer
                    return error.DataCloneError;
                }

                // Step 1: Get the data and length BEFORE detaching
                // (V8 frees the backing store on detach, so we must copy first)
                const byte_length = v8_engine.ffi.v8_ArrayBuffer_ByteLength(array_buffer);
                const data_ptr = v8_engine.ffi.v8_ArrayBuffer_Data(array_buffer);

                // Create transfer data structure
                const transferred = try allocator.create(TransferredArrayBuffer);
                errdefer allocator.destroy(transferred);

                // Copy the data
                if (data_ptr != null and byte_length > 0) {
                    const data_copy = try allocator.alloc(u8, byte_length);
                    errdefer allocator.free(data_copy);

                    const src: [*]const u8 = @ptrCast(data_ptr.?);
                    @memcpy(data_copy, src[0..byte_length]);

                    transferred.* = .{
                        .data = data_copy,
                        .byte_length = byte_length,
                        .allocator = allocator,
                    };
                } else {
                    // Empty ArrayBuffer
                    transferred.* = .{
                        .data = &[_]u8{},
                        .byte_length = 0,
                        .allocator = allocator,
                    };
                }

                // Step 2: Detach the ArrayBuffer - this makes the original unusable
                // Per HTML § 2.7.3: "Detach(value)"
                v8_engine.ffi.v8_ArrayBuffer_Detach(array_buffer);

                // Store the transfer data
                transfers[i] = @ptrCast(transferred);
            } else if (v8_engine.ffi.v8_Value_IsObject(elem)) {
                // Other transferable objects (MessagePort, etc.) - store for now
                // TODO: Implement MessagePort transfer (disentangle + re-entangle)
                transfers[i] = @ptrCast(elem);
            } else {
                transfers[i] = null;
            }
        } else {
            transfers[i] = null;
        }
    }

    return transfers;
}

// ============================================================================
// Error Event Dispatch
// ============================================================================

/// Dispatch an ErrorEvent to the Worker's error handlers
///
/// This creates an ErrorEvent and dispatches it through the DOM EventTarget system.
/// Per HTML spec, if the error is not handled (event not canceled), it propagates
/// to the parent context.
///
/// ## Spec Reference
/// HTML § 10.2.3: "If the script has muted errors, then set message to 'Script error.',
/// and mute error"
/// HTML § 10.2.5: "If the error is not handled, fire an event named error at the
/// Worker object."
pub fn dispatchErrorEvent(
    instance: *runtime.Instance,
    message_text: []const u8,
    filename: []const u8,
    lineno: u32,
    colno: u32,
    error_value: ?*const anyopaque,
) void {
    // Get internal state
    const internal = getInternal(instance) orelse return;
    const ctx = internal.ctx orelse return;

    // Get V8 context
    const isolate = internal.isolate orelse return;
    const v8_context: *v8_engine.ffi.Context = ctx.getEngineContextAs(v8_engine.ffi.Context) orelse return;

    // Ensure we're in the correct isolate
    const current_isolate = v8_engine.ffi.v8_Isolate_GetCurrent();
    const need_enter_isolate = (current_isolate == null) or (current_isolate != isolate);
    if (need_enter_isolate) {
        v8_engine.ffi.v8_Isolate_Enter(isolate);
    }
    defer if (need_enter_isolate) {
        v8_engine.ffi.v8_Isolate_Exit(isolate);
    };

    // Create HandleScope
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(isolate);
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Enter context if needed
    const current_context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate);
    const need_enter_context = (current_context == null) or (current_context != v8_context);
    if (need_enter_context) {
        v8_engine.ffi.v8_Context_Enter(v8_context);
    }
    defer if (need_enter_context) {
        v8_engine.ffi.v8_Context_Exit(v8_context);
    };

    // Import ErrorEvent interface and its impl
    const ErrorEvent = interfaces.ErrorEvent;
    const ErrorEventImpl = @import("ErrorEvent.zig");

    // Create ErrorEvent
    const error_event = ErrorEventImpl.createErrorEvent(
        ctx.allocator,
        ctx,
        message_text,
        filename,
        lineno,
        colno,
        error_value,
        true, // cancelable
    ) catch |err| {
        std.log.warn("Failed to create ErrorEvent: {s}", .{@errorName(err)});
        return;
    };

    // Set isTrusted since this event is fired by the browser
    {
        var ev_state = error_event.getState(ErrorEvent.State);
        ev_state.base.own.isTrusted = true;
        ev_state.base.own.target = instance;
        ev_state.base.own.currentTarget = instance;
    }

    // Dispatch via EventTarget.dispatchEvent
    const not_canceled = EventTarget.call_dispatchEvent(instance, error_event) catch |err| {
        std.log.warn("Failed to dispatch ErrorEvent: {s}", .{@errorName(err)});
        return;
    };

    // Also invoke the legacy onerror handler if set via IDL attribute
    if (internal.onerror_handle) |onerror_global| {
        // Wrap the ErrorEvent as a V8 Object
        const v8_event = template_registry.wrapInstanceAsV8Object(
            error_event,
            "ErrorEvent",
            isolate,
            v8_context,
        ) catch |err| {
            std.log.warn("Failed to wrap ErrorEvent as V8 object: {s}", .{@errorName(err)});
            return;
        };

        // Retrieve Local handle from Global handle
        const local_value = onerror_global.get(isolate) orelse {
            std.log.warn("Worker.dispatchErrorEvent: Failed to get Local from GlobalHandle", .{});
            return;
        };

        // Verify it's a function
        if (!v8_engine.ffi.v8_Value_IsFunction(@ptrCast(local_value))) {
            std.log.warn("Worker.dispatchErrorEvent: onerror is not a function", .{});
            return;
        }
        const function: *v8_engine.ffi.Function = @ptrCast(local_value);

        // Call the V8 function with the ErrorEvent as argument
        const undefined_recv = v8_engine.ffi.v8_Undefined(isolate);
        var args = [_]*v8_engine.ffi.Value{@ptrCast(v8_event)};
        _ = v8_engine.ffi.v8_Function_Call(function, v8_context, @ptrCast(undefined_recv), 1, &args);
    }

    // Per HTML § 10.2.5: If the error event is not canceled, propagate to parent context
    // "If the error is not handled, fire an event named error at the Worker object"
    // "If that's also not canceled, then report the exception to the user"
    if (not_canceled) {
        // Propagate to parent Window
        propagateErrorToParent(internal, message_text, filename, lineno, colno, error_value);
    }
}

/// Propagate an unhandled worker error to the parent Window
///
/// Spec: HTML Standard § 10.2.5 "Run a worker" step 11
/// "If the script has muted errors... Otherwise, fire an event named error at the Worker object"
/// "If that event is not canceled, then report the exception to the user"
///
/// This function implements the "error not handled" algorithm:
/// 1. Fire ErrorEvent at the parent Window
/// 2. If not canceled, report to console
fn propagateErrorToParent(
    internal: *InternalState,
    message_text: []const u8,
    filename: []const u8,
    lineno: u32,
    colno: u32,
    error_value: ?*const anyopaque,
) void {
    // Get parent Window for error propagation
    const parent_window = internal.parent_window orelse {
        // No parent Window - just log to console
        std.log.warn("Unhandled worker error (no parent Window): {s} at {s}:{d}:{d}", .{
            message_text, filename, lineno, colno,
        });
        return;
    };

    // Get the parent Window's context
    const parent_ctx = parent_window.ctx;
    const parent_v8_ctx: *v8_engine.ffi.Context = parent_ctx.getEngineContextAs(v8_engine.ffi.Context) orelse {
        std.log.warn("Unhandled worker error (no parent V8 context): {s} at {s}:{d}:{d}", .{
            message_text, filename, lineno, colno,
        });
        return;
    };

    // Get V8 isolate
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse {
        std.log.warn("Unhandled worker error (no V8 isolate): {s} at {s}:{d}:{d}", .{
            message_text, filename, lineno, colno,
        });
        return;
    };

    // Create HandleScope
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(isolate);
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Ensure we're in the parent context
    const current_context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate);
    const need_enter_context = (current_context == null) or (current_context != parent_v8_ctx);
    if (need_enter_context) {
        v8_engine.ffi.v8_Context_Enter(parent_v8_ctx);
    }
    defer if (need_enter_context) {
        v8_engine.ffi.v8_Context_Exit(parent_v8_ctx);
    };

    // Create ErrorEvent for the parent Window
    const ErrorEventImpl = @import("ErrorEvent.zig");
    const error_event = ErrorEventImpl.createErrorEvent(
        parent_ctx.allocator,
        parent_ctx,
        message_text,
        filename,
        lineno,
        colno,
        error_value,
        true, // cancelable
    ) catch |err| {
        std.log.warn("Failed to create ErrorEvent for parent Window: {s}", .{@errorName(err)});
        std.log.warn("Unhandled worker error: {s} at {s}:{d}:{d}", .{
            message_text, filename, lineno, colno,
        });
        return;
    };

    // Set isTrusted
    {
        var ev_state = error_event.getState(interfaces.ErrorEvent.State);
        ev_state.base.own.isTrusted = true;
        ev_state.base.own.target = parent_window;
        ev_state.base.own.currentTarget = parent_window;
    }

    // Dispatch error event to parent Window via EventTarget.dispatchEvent
    const not_canceled_at_window = EventTarget.call_dispatchEvent(parent_window, error_event) catch |err| {
        std.log.warn("Failed to dispatch ErrorEvent to parent Window: {s}", .{@errorName(err)});
        std.log.warn("Unhandled worker error: {s} at {s}:{d}:{d}", .{
            message_text, filename, lineno, colno,
        });
        return;
    };

    // If still not canceled, report to console (final fallback)
    if (not_canceled_at_window) {
        // Per spec: "Report the exception to the user"
        // In browsers, this shows in the DevTools console
        std.log.warn("Unhandled worker error: {s} at {s}:{d}:{d}", .{
            message_text, filename, lineno, colno,
        });
    }
}

// ============================================================================
// WorkerV8Context-based Callbacks for Worker Threads
// ============================================================================
// These callbacks use WorkerV8Context which has proper WebIDL interface
// registration (XMLHttpRequest, etc.) instead of WorkerIsolateData which
// only has raw V8 FFI without interfaces.

/// Callback to create a V8 isolate with proper WebIDL interface registration
fn createIsolateWithInterfaces(thread_state: *workers.WorkerThreadState, allocator: std.mem.Allocator) anyerror!*anyopaque {
    wdebug.print("\n=== [WORKER THREAD] createIsolateWithInterfaces() START ===\n", .{});
    wdebug.print("  thread_state ptr: {*}\n", .{thread_state});
    wdebug.print("  script_url: {s}\n", .{thread_state.script_url});
    wdebug.print("  worker_ptr: {?*}\n", .{thread_state.worker_ptr});

    const worker_ctx = try WorkerV8Context.init(
        allocator,
        thread_state.script_url,
        thread_state.worker_type,
        thread_state.document_origin, // Pass document origin as base URL for data:/blob: workers
    );
    wdebug.print("  WorkerV8Context created: {*}\n", .{worker_ctx});

    // Set up worker-specific global scope (postMessage, close, importScripts, done)
    // using the DedicatedWorker pointer passed through thread_state
    if (thread_state.worker_ptr) |worker_ptr| {
        const dedicated_worker: *DedicatedWorker = @ptrCast(@alignCast(worker_ptr));
        wdebug.print("  Setting up worker global scope with DedicatedWorker: {*}\n", .{dedicated_worker});
        try worker_ctx.setupWorkerGlobalScope(dedicated_worker);
        wdebug.print("  Worker global scope setup complete (includes message handler)\n", .{});

        // NOTE: Message handler setup is now done INSIDE setupWorkerGlobalScope()
        // where the V8 isolate is still entered. Calling getRuntimeContext() here
        // would crash because the isolate has been exited by the defer block.
    } else {
        wdebug.print("  WARNING: No worker_ptr in thread_state!\n", .{});
    }

    wdebug.print("=== [WORKER THREAD] createIsolateWithInterfaces() END ===\n\n", .{});
    return @ptrCast(worker_ctx);
}

/// Callback to dispose a WorkerV8Context
fn disposeIsolateWithInterfaces(isolate_data: *anyopaque) void {
    wdebug.print("\n=== [WORKER THREAD] disposeIsolateWithInterfaces() ===\n", .{});
    wdebug.print("  isolate_data ptr: {*}\n", .{isolate_data});
    const worker_ctx: *WorkerV8Context = @ptrCast(@alignCast(isolate_data));
    worker_ctx.deinit();
    wdebug.print("  WorkerV8Context disposed\n\n", .{});
}

/// Callback to execute a script in the WorkerV8Context
fn executeScriptWithInterfaces(isolate_data: *anyopaque, script: []const u8, source_url: []const u8) anyerror!void {
    wdebug.print("\n=== [WORKER THREAD] executeScriptWithInterfaces() START ===\n", .{});
    wdebug.print("  isolate_data ptr: {*}\n", .{isolate_data});
    wdebug.print("  script length: {d} bytes\n", .{script.len});
    wdebug.print("  source_url: {s}\n", .{source_url});
    if (script.len > 0) {
        const preview_len = @min(script.len, 100);
        wdebug.print("  script preview: {s}...\n", .{script[0..preview_len]});
    }

    const worker_ctx: *WorkerV8Context = @ptrCast(@alignCast(isolate_data));
    // source_url already logged above, WorkerV8Context uses its own script_url

    // Execute the script (WorkerV8Context.executeScript handles enter/exit internally)
    _ = try worker_ctx.executeScript(script);
    wdebug.print("=== [WORKER THREAD] executeScriptWithInterfaces() END ===\n\n", .{});
}

/// Callback to dispatch a message to the WorkerV8Context
///
/// Per HTML spec, the first message to a worker is the script to execute.
/// Subsequent messages are postMessage data that should be dispatched as MessageEvents.
///
/// Spec: HTML Standard § 10.2.5 Processing model
/// https://html.spec.whatwg.org/#run-a-worker
fn dispatchMessageWithInterfaces(isolate_data: *anyopaque, msg: *workers.ThreadSafeMessageQueue.SerializedMessage) anyerror!void {
    wdebug.print("\n=== [WORKER THREAD] dispatchMessageWithInterfaces() START ===\n", .{});
    wdebug.print("  isolate_data ptr: {*}\n", .{isolate_data});
    wdebug.print("  msg ptr: {*}\n", .{msg});
    wdebug.print("  msg.data.type: {s}\n", .{@tagName(msg.data.type)});

    const worker_ctx: *WorkerV8Context = @ptrCast(@alignCast(isolate_data));

    // Check if this is the initial script message or a postMessage
    if (!worker_ctx.script_executed) {
        // First message: execute as script
        wdebug.print("  First message - executing as script\n", .{});

        if (msg.data.type == .string_object) {
            const script = msg.data.data.string_object;
            wdebug.print("  Executing as script (string_object), len: {d}\n", .{script.len});
            _ = try worker_ctx.executeScript(script);
        } else if (msg.data.type == .primitive) {
            if (msg.data.data.primitive == .string) {
                const script = msg.data.data.primitive.string;
                wdebug.print("  Executing as script (primitive.string), len: {d}\n", .{script.len});
                _ = try worker_ctx.executeScript(script);
            } else {
                wdebug.print("  ERROR: First message is non-string primitive: {s}\n", .{@tagName(msg.data.data.primitive)});
            }
        } else {
            wdebug.print("  ERROR: First message has unexpected type\n", .{});
        }

        // Mark script as executed - subsequent messages are postMessage data
        worker_ctx.script_executed = true;
    } else {
        // Subsequent messages: dispatch as MessageEvent
        wdebug.print("  Subsequent message - dispatching as MessageEvent\n", .{});

        // Convert the serialized data to a JavaScript value and dispatch
        // Since worker global scope is set up via JavaScript, we dispatch using JS
        try dispatchMessageEventViaJS(worker_ctx, msg);
    }

    // Clean up the message
    msg.deinit();
    wdebug.print("=== [WORKER THREAD] dispatchMessageWithInterfaces() END ===\n\n", .{});
}

/// Dispatch a message as a MessageEvent via JavaScript
///
/// This creates a MessageEvent with the message data and dispatches it to the
/// worker's global scope, invoking both addEventListener handlers and the
/// legacy onmessage handler.
///
/// Spec: HTML Standard § 9.4.2 Posting messages
/// https://html.spec.whatwg.org/#posting-messages
fn dispatchMessageEventViaJS(worker_ctx: *WorkerV8Context, msg: *workers.ThreadSafeMessageQueue.SerializedMessage) !void {
    // Convert the message data to a JavaScript literal for embedding in script
    var js_data_buf: [8192]u8 = undefined;
    var js_data_len: usize = 0;

    if (msg.data.type == .string_object) {
        // String data - escape for JavaScript string literal
        const str = msg.data.data.string_object;
        js_data_len = try formatJSStringLiteral(str, &js_data_buf);
    } else if (msg.data.type == .primitive) {
        switch (msg.data.data.primitive) {
            .string => |str| {
                js_data_len = try formatJSStringLiteral(str, &js_data_buf);
            },
            .number => |num| {
                js_data_len = (std.fmt.bufPrint(&js_data_buf, "{d}", .{num}) catch return error.BufferTooSmall).len;
            },
            .boolean => |b| {
                const s = if (b) "true" else "false";
                @memcpy(js_data_buf[0..s.len], s);
                js_data_len = s.len;
            },
            .null => {
                const s = "null";
                @memcpy(js_data_buf[0..s.len], s);
                js_data_len = s.len;
            },
            .undefined => {
                const s = "undefined";
                @memcpy(js_data_buf[0..s.len], s);
                js_data_len = s.len;
            },
            else => {
                // For other primitives, use null as fallback
                const s = "null";
                @memcpy(js_data_buf[0..s.len], s);
                js_data_len = s.len;
            },
        }
    } else {
        // For complex types, serialize to null for now
        // TODO: Full structured clone deserialization
        const s = "null";
        @memcpy(js_data_buf[0..s.len], s);
        js_data_len = s.len;
    }

    const js_data = js_data_buf[0..js_data_len];

    // Build JavaScript to create and dispatch MessageEvent
    // Using a script buffer large enough for the template + data
    var script_buf: [16384]u8 = undefined;
    const script = std.fmt.bufPrint(&script_buf,
        \\(function() {{
        \\  var data = {s};
        \\  var event = new MessageEvent('message', {{ data: data }});
        \\  // Dispatch to addEventListener handlers
        \\  self.dispatchEvent(event);
        \\  // Also invoke legacy onmessage handler if set
        \\  if (typeof self.onmessage === 'function') {{
        \\    self.onmessage(event);
        \\  }}
        \\}})();
    , .{js_data}) catch return error.BufferTooSmall;

    wdebug.print("  Dispatching MessageEvent with data type: {s}\n", .{@tagName(msg.data.type)});
    _ = try worker_ctx.executeScript(script);
}

/// Format a string as a JavaScript string literal with proper escaping
fn formatJSStringLiteral(str: []const u8, buf: []u8) !usize {
    var pos: usize = 0;

    // Opening quote
    if (pos >= buf.len) return error.BufferTooSmall;
    buf[pos] = '"';
    pos += 1;

    for (str) |c| {
        const escaped = switch (c) {
            '"' => "\\\"",
            '\\' => "\\\\",
            '\n' => "\\n",
            '\r' => "\\r",
            '\t' => "\\t",
            else => null,
        };

        if (escaped) |esc| {
            if (pos + esc.len > buf.len) return error.BufferTooSmall;
            @memcpy(buf[pos..][0..esc.len], esc);
            pos += esc.len;
        } else if (c < 0x20) {
            // Control characters - use \xNN format
            if (pos + 4 > buf.len) return error.BufferTooSmall;
            _ = std.fmt.bufPrint(buf[pos..][0..4], "\\x{X:0>2}", .{c}) catch return error.BufferTooSmall;
            pos += 4;
        } else {
            if (pos >= buf.len) return error.BufferTooSmall;
            buf[pos] = c;
            pos += 1;
        }
    }

    // Closing quote
    if (pos >= buf.len) return error.BufferTooSmall;
    buf[pos] = '"';
    pos += 1;

    return pos;
}

/// Get the create isolate callback function pointer
pub fn createIsolateCallback() workers.WorkerThreadRunner.CreateIsolateFn {
    return createIsolateWithInterfaces;
}

/// Get the dispose isolate callback function pointer
pub fn disposeIsolateCallback() workers.WorkerThreadRunner.DisposeIsolateFn {
    return disposeIsolateWithInterfaces;
}

/// Get the execute script callback function pointer
pub fn executeScriptCallback() workers.WorkerThreadRunner.ExecuteScriptFn {
    return executeScriptWithInterfaces;
}

/// Get the dispatch message callback function pointer
pub fn dispatchMessageCallback() workers.WorkerThreadRunner.DispatchMessageFn {
    return dispatchMessageWithInterfaces;
}

/// Callback to perform V8 microtask checkpoint
/// This is called from the worker loop to process Promises and async/await continuations
fn microtaskCheckpointWithInterfaces(isolate_data: *anyopaque) void {
    const worker_ctx: *WorkerV8Context = @ptrCast(@alignCast(isolate_data));
    worker_ctx.performMicrotaskCheckpoint();
}

/// Get the microtask checkpoint callback function pointer
pub fn microtaskCheckpointCallback() workers.WorkerThreadRunner.MicrotaskCheckpointFn {
    return microtaskCheckpointWithInterfaces;
}

/// Get the global worker wakeup primitive.
/// Returns null if no workers have been created yet or wakeup initialization failed.
/// Used by Browser.runEventLoop to wait efficiently for worker messages.
pub fn getGlobalWorkerWakeup() ?*workers.ThreadedWorkerRegistry.EventWakeup {
    return workers.ThreadedWorkerRegistry.global_wakeup;
}

/// Flush pending messages from all workers to the main thread.
/// This should be called from the main thread's event loop to deliver
/// messages that workers have posted via postMessage().
pub fn flushPendingWorkerMessages() void {
    wdebug.print("flushPendingWorkerMessages() called\n", .{});

    // First, poll threaded workers' outboxes for cross-thread messages.
    // This is the primary path for workers running on separate OS threads.
    const dispatched_threaded = workers.ThreadedWorkerRegistry.pollAndDispatch();
    if (dispatched_threaded) {
        wdebug.print("flushPendingWorkerMessages() dispatched threaded worker messages\n", .{});
    }

    // Then, flush any messages still in the thread-local pending_messages list.
    // This handles same-thread workers (tests, single-threaded mode).
    DedicatedWorker.flushPendingMessages();

    // Finally, poll all registered worker ports and dispatch queued messages.
    // Messages may have been transferred to port queues by worker thread cleanup.
    const dispatched_ports = workers.message_channel.WorkerPortRegistry.pollAndDispatch();
    if (dispatched_ports) {
        wdebug.print("flushPendingWorkerMessages() dispatched port messages\n", .{});
    }
}
