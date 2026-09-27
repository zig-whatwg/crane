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
//! 1. call_postMessage serializes `data` with transfer through the Engine
//!    table (StructuredSerializeWithTransfer)
//! 2. Message is queued to DedicatedWorker's outside_port
//! 3. outside_port delivers to entangled inside_port (worker side)
//! 4. The worker host fires a MessageEvent at the worker's global scope
//!
//! When worker calls `self.postMessage(data)`:
//! 1. The worker host serializes `data` in the worker's realm
//! 2. Message is queued to inside_port
//! 3. inside_port delivers to entangled outside_port (main thread)
//! 4. handleMessageFromWorker deserializes it into this realm
//! 5. `message` is fired at the Worker object (onmessage and listeners)

const std = @import("std");
const log = std.log.scoped(.worker);
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

// The constructor parses the script URL (the URL Standard's API parser), and
// the blob-URL check needs the outside settings' origin.
const api_parser = @import("api_parser");
const url_serializer = @import("url_serializer");
const url_origin = @import("origin");

// Import workers infrastructure
const html_core = @import("html_core");
const workers = html_core.workers;
const DedicatedWorker = workers.DedicatedWorker;
const WorkerOptions = workers.WorkerOptions;
const WorkerType = workers.WorkerType;
const RequestCredentials = workers.RequestCredentials;
const message_channel = workers.message_channel;
const WorkerErrorEvent = workers.worker_error.WorkerErrorEvent;
const QueuedMessage = message_channel.QueuedMessage;
const EngineMessage = message_channel.EngineMessage;
const WorkerContext = workers.WorkerContext;

// The worker host: the HTML half of "run a worker" (has interface access,
// unlike html_core).
const html_full = @import("html");
const WorkerV8Context = html_full.WorkerV8Context;
const worker_host = html_full.worker_v8_context;

// Import platform for TimerBackend (used to create DedicatedWorker)
const platform = @import("platform");

// Import event loop for task scheduling (message dispatch)
const event_loop_mod = @import("streams_event_loop");

pub const State = Worker.State;

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

    /// The worker host running the worker (created when DedicatedWorker starts)
    host: ?*WorkerV8Context = null,

    /// Outside MessagePort (exposed to the caller)
    outside_port: ?*runtime.Instance = null,

    /// Worker configuration
    script_url: []const u8,
    name: []const u8,
    worker_type: WorkerType,
    credentials: RequestCredentials,

    /// Whether the worker has been terminated
    terminated: bool = false,

    /// Whether the worker script has been evaluated
    /// Per Chromium's DedicatedWorkerMessagingProxy::was_script_evaluated_ pattern:
    /// Messages must not be dispatched until the script finishes executing.
    script_evaluated: bool = false,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    /// Reference to the Worker instance (for message handling)
    worker_instance: ?*runtime.Instance = null,

    /// Runtime context for creating MessageEvent
    ctx: ?runtime.Context = null,

    /// Pending script source to execute (deferred from constructor)
    /// This is set during constructor and executed via timer callback
    pending_script: ?[]const u8 = null,

    /// Final URL of the script (after resolution, for V8 context)
    /// Stored during constructor to avoid re-fetching when blob URLs are revoked
    script_final_url: ?[]const u8 = null,

    /// Pending messages to send to worker (before DedicatedWorker is created)
    /// Messages are queued here if postMessage is called before worker initialization completes.
    /// Once the DedicatedWorker is ready, these are flushed to the inside port.
    pending_outgoing_messages: std.ArrayList(EngineMessage),

    pub fn deinit(self: *InternalState) void {
        // Clean up pending outgoing messages
        for (self.pending_outgoing_messages.items) |*msg| msg.deinit();
        self.pending_outgoing_messages.deinit(self.allocator);

        // Clean up V8 context first (it uses the dedicated_worker's WorkerContext).
        //
        // deinit() releases V8 resources and is idempotent; it does NOT free the
        // context. The worker chain below reaches WorkerContext.deinit ->
        // disposeContextCallback -> deinit() a second time, which now early-returns
        // on a flag in LIVE memory. Only after that chain has finished is it safe to
        // release the storage, and this is the single place that does it.
        const host_owned = self.host;
        if (host_owned) |host| {
            host.deinit();
            self.host = null;
        }
        if (self.dedicated_worker) |worker| {
            worker.deinit();
        }
        if (host_owned) |host| {
            host.destroy();
        }
        self.allocator.free(self.script_url);
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }
        // Free pending script if not yet executed
        if (self.pending_script) |script| {
            self.allocator.free(script);
        }
        // Free script_final_url if set
        if (self.script_final_url) |url| {
            self.allocator.free(url);
        }
    }
};

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
pub fn deinit(instance: *runtime.Instance) void {
    // Whatever pending-activity hold is left on it goes with it.
    releasePendingActivity(instance);
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    // Chain to parent class through interface for proper deinit
    EventTarget.deinit(instance);
}

/// `script_url` encoding-parsed relative to `api_base_url` and serialized:
/// the Worker constructor's steps 3-4, given the outside settings' API base
/// URL. OWNED (`allocator`). SyntaxError when it does not parse - a relative
/// URL with no base among them.
pub fn resolveScriptURL(allocator: std.mem.Allocator, script_url: []const u8, api_base_url: ?[]const u8) error{ SyntaxError, OutOfMemory }![]const u8 {
    var base_record: ?@import("url_record").URLRecord = null;
    defer if (base_record) |*b| b.deinit();
    if (api_base_url) |base| base_record = api_parser.parseURL(allocator, base, null) catch null;
    var record = api_parser.parseURL(allocator, script_url, if (base_record) |*b| b else null) catch
        return error.SyntaxError;
    defer record.deinit();
    return url_serializer.serialize(allocator, &record, false) catch error.OutOfMemory;
}

/// The outside settings' origin, serialized: the origin of `api_base_url`,
/// or "null" (an opaque origin) without one. OWNED (`allocator`).
fn serializedOriginOf(allocator: std.mem.Allocator, api_base_url: ?[]const u8) ![]u8 {
    const base = api_base_url orelse return allocator.dupe(u8, "null");
    var record = api_parser.parseURL(allocator, base, null) catch return allocator.dupe(u8, "null");
    defer record.deinit();
    const origin = try url_origin.getOrigin(allocator, &record);
    defer origin.deinit(allocator);
    return origin.serialize(allocator);
}

/// The current settings object's API base URL, for the instance a constructor
/// just made in it: a window's document's base URL, read through the
/// Document's `baseURI`; a worker's is its script URL, which its realm
/// records as its document URL. OWNED by `instance.ctx.allocator`. The same
/// lookup WebSocket's and Request's constructors make.
fn apiBaseURL(instance: *runtime.Instance) ?[]u8 {
    const ctx = instance.ctx;
    if (relevantWindow(instance)) |window| {
        const document = interfaces.Window.get_document(window) catch null;
        if (document) |d| {
            const base = interfaces.Node.get_baseURI(d) catch null;
            if (base) |b| {
                if (b.len > 0) return @constCast(b);
                d.ctx.allocator.free(b);
            }
        }
    }
    if (ctx.documentUrl()) |document_url| {
        if (document_url.len > 0) return ctx.allocator.dupe(u8, document_url) catch null;
    }
    return null;
}

/// `instance`'s relevant global object, when it is a Window.
fn relevantWindow(instance: *runtime.Instance) ?*runtime.Instance {
    const engine = instance.ctx.getEngine() orelse return null;
    const relevant_global = engine.relevantGlobalObject orelse return null;
    const global = relevant_global(instance) orelse return null;
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return global;
}

/// Constructor implementation
///
/// Spec: HTML Standard § 10.2.3.1 The Worker() constructor
/// https://html.spec.whatwg.org/#dom-worker
///
/// This is called when the interface is constructed from JavaScript:
/// new Worker(scriptURL, options)
pub fn call_constructor(ctx: runtime.Context, scriptURL: runtime.DOMString, options: webidl.Opt(dictionaries.WorkerOptions)) !*runtime.Instance {

    // NOTE: We rely on the persistent HandleScope from BrowserContext.
    // Creating a local HandleScope here and disposing it at the end of the constructor
    // would leave V8 without a HandleScope for subsequent JavaScript execution.
    // The persistent HandleScope in BrowserContext stays active for the entire test.

    // Create instance through init()
    const instance = try init(ctx.allocator, State, &Worker.vtable, ctx);
    errdefer deinit(instance);

    // A Worker has pending activity from the moment it is made until its
    // worker has ended (Blink's DedicatedWorker::HasPendingActivity): script
    // may drop it at once - `new Worker(url).onmessage = f`, or a worker's own
    // nested worker held in a local - and the worker still runs, and the
    // tasks queued for it must not find it freed. The binding wraps it after
    // this returns, and the wrapper takes the hold then; the worker host
    // releases it once the worker has ended (`releaseOwnerWhenIdle`).
    keepPendingActivity(instance);

    // Parse options - use defaults for type/credentials since dictionary has opaque enum pointers
    const worker_type = WorkerType.classic;
    const credentials = RequestCredentials.same_origin;
    var name: []const u8 = "";

    if (options.wasPassed()) {
        const opts = options.getValue();
        // Note: opts.type and opts.credentials are ?*const anyopaque (opaque enum pointers)
        // The dictionary codegen doesn't provide typed enum access yet.
        // For now, we use default values (classic, same_origin).
        // TODO: When dictionary codegen supports typed enums, parse these:
        // - type: "classic" | "module" -> WorkerType
        // - credentials: "omit" | "same-origin" | "include" -> RequestCredentials
        _ = opts.type; // Acknowledge but skip (uses default: classic)
        _ = opts.credentials; // Acknowledge but skip (uses default: same_origin)

        // Parse name if present (this is a DOMString, not an enum)
        if (opts.name) |n| {
            name = n.asSlice();
        }
    }

    // Steps 2-4: "Let outsideSettings be the current settings object. Let
    // workerURL be the result of encoding-parsing a URL given scriptURL,
    // relative to outsideSettings. If workerURL is failure, then throw a
    // "SyntaxError" DOMException." Relative to its API base URL - a window's
    // document's URL - which Crane used to replace with the document's
    // origin, so `support/x.js` from /workers/y.html fetched /support/x.js.
    const base_url = apiBaseURL(instance);
    defer if (base_url) |b| ctx.allocator.free(b);
    const url_copy = try resolveScriptURL(ctx.allocator, scriptURL.asSlice(), base_url);
    errdefer ctx.allocator.free(url_copy);
    // Its origin, for the blob-URL store's same-origin check.
    const requesting_origin = try serializedOriginOf(ctx.allocator, base_url);
    defer ctx.allocator.free(requesting_origin);

    // Copy the name if present
    const name_copy = if (name.len > 0)
        try ctx.allocator.dupe(u8, name)
    else
        "";
    errdefer if (name_copy.len > 0) ctx.allocator.free(name_copy);

    // Create internal state
    const internal_state = try ctx.allocator.create(InternalState);
    errdefer ctx.allocator.destroy(internal_state);

    internal_state.* = .{
        .dedicated_worker = null,
        .script_url = url_copy,
        .name = name_copy,
        .worker_type = worker_type,
        .credentials = credentials,
        .allocator = ctx.allocator,
        .worker_instance = instance,
        .ctx = ctx,
        .pending_outgoing_messages = .empty,
    };

    // Store internal state in instance
    var state = instance.getState(State);
    state.own._internal = internal_state;

    // CRITICAL: Fetch the worker script IMMEDIATELY in the constructor!
    //
    // Per Chromium's implementation, the script fetch must start as soon as the
    // Worker is constructed. This is critical for blob URLs because:
    // 1. JavaScript creates a blob URL with URL.createObjectURL()
    // 2. JavaScript creates a Worker with the blob URL
    // 3. Later, cleanup code may call URL.revokeObjectURL()
    //
    // If we defer the script fetch to a queueTask callback, the blob URL may
    // be revoked by the time we try to fetch it, causing "Blob not found" errors.
    //
    // The fix is to fetch the script content immediately (while the blob URL
    // is still valid) and store it. Only the script EXECUTION is deferred.
    const fetched_script = workers.fetchWorkerScript(ctx.allocator, url_copy, .{
        .worker_type = worker_type,
        .requesting_origin = requesting_origin,
    }) catch |err| {
        std.log.warn("Failed to fetch worker script in constructor: {}", .{err});
        // Continue with null pending_script - initializeWorkerSync will handle this
        // by not executing any script (the worker will still be created but idle)
        internal_state.pending_script = null;
        internal_state.script_final_url = null;
        // Don't return error - still schedule initialization
        if (ctx.getOptionalEventLoop()) |event_loop| {
            WorkerTask.queue(event_loop, instance, &initializeWorker);
        }
        return instance;
    };

    // Store the fetched script content and final URL for later execution
    internal_state.pending_script = ctx.allocator.dupe(u8, fetched_script.source) catch {
        @constCast(&fetched_script).deinit();
        return error.OutOfMemory;
    };
    internal_state.script_final_url = ctx.allocator.dupe(u8, fetched_script.final_url) catch {
        ctx.allocator.free(internal_state.pending_script.?);
        internal_state.pending_script = null;
        @constCast(&fetched_script).deinit();
        return error.OutOfMemory;
    };

    // Clean up the fetched script metadata (we've copied what we need)
    @constCast(&fetched_script).deinit();

    // CRITICAL: Use queueTask to schedule worker initialization.
    // The initialization MUST be deferred because:
    // 1. The Worker constructor is called from within a V8 callback
    // 2. Entering the worker's isolate corrupts the current HandleScope
    // 3. Deferred execution runs after V8 has restored its state
    //
    // NOTE: The event loop processes ONE task per iteration, then polls timers.
    // This means worker init tasks may run AFTER JavaScript setTimeout callbacks
    // if there are many workers being initialized simultaneously.
    //
    // For reliable message delivery timing, the script fetch is done in the
    // constructor (above), only the script EXECUTION is deferred.
    if (ctx.getOptionalEventLoop()) |event_loop| {
        WorkerTask.queue(event_loop, instance, &initializeWorker);
    } else {
        // Fallback: try timer if no event loop available
        const timer = ctx.timer orelse WorkerV8Context.getTimerInterface();
        if (timer) |t| {
            WorkerTask.arm(t, 1, instance, &initializeWorker);
        } else {
            std.log.warn("Worker: no timer available, using synchronous initialization", .{});
            initializeWorkerSync(internal_state, ctx);
        }
    }

    return instance;
}

// Event handler IDL attributes (HTML § 8.1.8.1): their values live in
// EventTarget's event handler map, where firing `message` or `error` at this
// Worker finds them - in order with every listener.

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "error");
}

/// Getter for onmessage
pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "message");
}

/// Getter for onmessageerror
pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "messageerror");
}

/// Get internal state from instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return if (state.own._internal) |internal| @constCast(internal) else null;
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "error", value);
}

/// Setter for onmessage
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
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "message", value);

    if (getInternal(instance)) |internal| {
        // Process any messages that were queued before the handler was set
        // This ensures messages posted by the worker during script execution
        // are delivered now that there's a handler to receive them.
        if (internal.dedicated_worker) |dedicated_worker| {
            keepAliveWhileRunning(internal);
            dedicated_worker.processQueuedMessages();
        }
    }
}

/// Setter for onmessageerror
pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "messageerror", value);
}

/// The deferred half of the constructor, as a task (WorkerTask): ALL worker
/// creation is deferred, for nested workers too - entering and exiting the
/// worker's agent during a constructor disrupts the calling agent's scopes.
///
/// It does all the heavy work:
/// 1. Creates DedicatedWorker with timer backend
/// 2. Fetches and resolves the script URL
/// 3. Creates WorkerV8Context (new isolate)
/// 4. Sets up DedicatedWorkerGlobalScope
/// 5. Schedules script execution
fn initializeWorker(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    // Terminated before it ran: "terminate a worker" sets the closing flag,
    // and a worker whose flag is set runs nothing - not its script either
    // (workers/Worker-terminate-forever.html: a `while (1);` script ran, and
    // hung the page, once its URL resolved).
    if (internal.terminated) return;

    // Get the stored context - we need it for timer operations
    const ctx = internal.ctx orelse {
        std.log.warn("Worker: no runtime context available for deferred initialization", .{});
        return;
    };
    initializeWorkerSync(internal, ctx);
}

/// Initialize worker synchronously (internal helper)
/// Called from either initializeWorkerCallback or synchronous fallback
///
/// This does all the heavy work that was previously in the constructor:
/// - Creates DedicatedWorker
/// - Creates V8 context (enters/exits worker isolate)
/// - Sets up global scope
/// - Schedules script execution
///
/// NOTE: Script fetch is now done in the constructor to ensure blob URLs
/// are fetched before they can be revoked. The script content is already
/// stored in internal.pending_script and internal.script_final_url.
fn initializeWorkerSync(internal: *InternalState, ctx: runtime.Context) void {
    const allocator = internal.allocator;
    const url = internal.script_url;
    const name = internal.name;
    const worker_type = internal.worker_type;
    const credentials = internal.credentials;

    // Check if script was fetched successfully in the constructor
    // If not, we still create the worker but it won't execute any script
    const script_final_url = internal.script_final_url orelse blk: {
        std.log.warn("No script_final_url - script fetch failed in constructor", .{});
        // Still create worker for postMessage capability, but no script execution
        internal.pending_script = null;
        break :blk url; // Fall back to original URL for DedicatedWorker init
    };

    // Try to create the DedicatedWorker using the global timer backend
    const timer_backend = platform.getDefaultTimerBackend(allocator) catch |err| {
        std.log.warn("TimerBackend not available: {}, worker will not start", .{err});
        return;
    };

    const dedicated_worker = DedicatedWorker.init(
        allocator,
        timer_backend,
        url,
        .{
            .name = name,
            .worker_type = worker_type,
            .credentials = credentials,
        },
    ) catch |err| {
        std.log.warn("Failed to create DedicatedWorker: {}", .{err});
        return;
    };
    internal.dedicated_worker = dedicated_worker;

    // Store reference to Worker instance for message callbacks
    dedicated_worker.setUserData(internal.worker_instance);

    // Set up message handler on outside port to receive messages from worker
    dedicated_worker.setOnMessage(handleMessageFromWorkerCallback);

    // Set up error handler to receive errors from worker
    dedicated_worker.setParentErrorCallback(handleErrorFromWorkerCallback);

    // Enable message dispatch on outside port
    dedicated_worker.startMessageQueue();

    // NOTE: Pending messages are NOT flushed here. Per Chromium's implementation,
    // messages must be held until the worker script finishes evaluating.
    // See DedicatedWorkerMessagingProxy::was_script_evaluated_ flag.
    // The flush happens in executeWorkerScriptCallback AFTER script execution.

    // The worker's agent ("run a worker" step 4), through this realm's
    // engine, for the pre-fetched script's final URL.
    const engine = ctx.getEngine() orelse {
        std.log.warn("Worker: no engine in this realm", .{});
        return;
    };
    const host = WorkerV8Context.init(
        allocator,
        engine,
        script_final_url,
        worker_type,
    ) catch |err| {
        std.log.warn("Failed to create the worker's agent: {}", .{err});
        return;
    };
    internal.host = host;

    // Create the WorkerContext
    dedicated_worker.startWithContext() catch |err| {
        std.log.warn("Failed to start worker context: {}", .{err});
        return;
    };

    // Wire up the V8 context to the WorkerAgent's WorkerContext
    if (dedicated_worker.agent.worker_context) |worker_ctx| {
        worker_ctx.setEngineContext(host.getEngineContext(), host.getCallbacks());
    } else {
        std.log.warn("WorkerContext not created after startWithContext", .{});
        return;
    }

    // Set up the timer interface for worker timers
    if (ctx.timer) |timer| {
        WorkerV8Context.setTimerInterface(timer);
    }

    // Set up DedicatedWorkerGlobalScope with proper globals
    host.setupWorkerGlobalScope(dedicated_worker) catch |err| {
        std.log.warn("Failed to set up worker global scope: {}", .{err});
        return;
    };

    // Start the worker's message queue
    dedicated_worker.startWorkerMessageQueue();

    // NOTE: pending_script is already set from constructor - no need to fetch again

    // Execute worker script SYNCHRONOUSLY to prevent race with cleanup.
    //
    // The issue: If we defer script execution to a timer, test cleanup can call
    // worker.terminate() BEFORE the script runs. This happens because:
    // 1. Constructor schedules 1ms timer for script execution
    // 2. Test harness checks all_done() after window.load (0ms timer)
    // 3. If all_done() returns true, cleanup runs and terminates workers
    // 4. 1ms timer fires but workers are already terminated
    //
    // The fix: Execute script synchronously during construction. This ensures
    // the script runs before any cleanup can interfere.
    //
    // Per Chromium's DedicatedWorkerMessagingProxy pattern:
    // - Script executes synchronously
    // - Messages are queued in pending_outgoing_messages (not dispatched yet)
    // - script_evaluated flag is set after script completes
    // - Message dispatch happens in a deferred callback (for handler setup)
    _ = executeWorkerScriptSync(internal);

    // CRITICAL: Mark script as evaluated AFTER execution completes.
    // This flag gates message dispatch in postMessage() - without it, messages
    // posted before the script runs would be dispatched to a non-existent handler.
    internal.script_evaluated = true;

    // Schedule message dispatch to allow JavaScript to set up worker.onmessage
    // handlers before messages are dispatched. This is the deferred part.
    //
    // CRITICAL: Use queueTask instead of setTimeout to guarantee task ordering.
    // Per research on Chromium's DedicatedWorkerMessagingProxy and V8 event loop:
    // - Tasks queued via queueTask are processed BEFORE libuv timers
    // - This ensures message dispatch happens before test timeout timers
    // - Using setTimeout(1ms) creates a race condition with test timeouts
    if (ctx.getOptionalEventLoop()) |event_loop| {
        if (internal.worker_instance) |worker_instance| {
            WorkerTask.queue(event_loop, worker_instance, &dispatchMessagesOf);
        }
    } else if (ctx.timer) |timer| {
        // Fallback to timer if no event loop available (a worker's realm,
        // making a nested worker).
        if (internal.worker_instance) |worker_instance| {
            WorkerTask.arm(timer, 1, worker_instance, &dispatchMessagesOf);
        }
    } else {
        // No timer or event loop - dispatch messages synchronously (handlers may not be set up)
        dispatchWorkerMessages(internal);
    }
}

/// Timer callback for executing the worker script (deferred from constructor)
///
/// CRITICAL: Worker script execution is deferred to this callback to avoid
/// HandleScope corruption. Entering/exiting the worker isolate during the
/// constructor disrupts the main isolate's HandleScope state.
///
/// This callback runs after:
/// 1. The constructor returns and V8 has wrapped the instance
/// 2. JavaScript continues (fetch_tests_from_worker sets up handlers)
/// 3. The event loop runs this scheduled task
fn executeWorkerScriptCallback(user_data: ?*anyopaque) void {
    const instance: *runtime.Instance = @ptrCast(@alignCast(user_data orelse return));
    const internal = getInternal(instance) orelse return;

    // Execute worker script.
    //
    // Timeline (per Chromium's DedicatedWorkerMessagingProxy):
    // 1. new Worker(...) - constructor returns, fetch_tests_from_worker sets up handlers
    // 2. JavaScript calls worker.postMessage() - messages queued in pending_outgoing_messages
    // 3. setTimeout(0, executeWorkerScriptCallback) fires (we're here)
    // 4. Worker script runs, sets self.onmessage handler
    // 5. Script evaluation complete - NOW flush pending messages (was_script_evaluated_ = true)
    // 6. Messages dispatched to worker's onmessage handler
    _ = executeWorkerScriptSync(internal);

    // CRITICAL: Mark script as evaluated AFTER execution completes.
    // This flag gates message dispatch in postMessage() - without it, messages
    // posted before the script runs would be dispatched to a non-existent handler.
    internal.script_evaluated = true;

    // CRITICAL: Flush pending messages AFTER script evaluation (per Chromium pattern).
    // Before this point, was_script_evaluated_ was effectively false.
    // Now the worker's onmessage handler is set up and ready to receive messages.
    const dedicated_worker = internal.dedicated_worker orelse return;
    const pending_count = internal.pending_outgoing_messages.items.len;
    if (pending_count > 0) {
        std.log.debug("[Worker] Flushing {d} pending messages after script eval", .{pending_count});
        flushPendingOutgoing(internal, dedicated_worker);
    }

    // Now process the messages in the worker's realm.
    // The messages are in inside_port.message_queue (via port entanglement).
    if (internal.host) |host| {
        worker_host.processIncomingMessages(host);
    }

    // Check if worker sent any messages back and dispatch them to main thread
    const outside_queue_len = dedicated_worker.port_pair.outside_port.message_queue.items.len;
    const has_messages = outside_queue_len > 0;

    log.debug("[executeWorkerScriptCallback] outside_port queue len={d}, has_messages={}", .{ outside_queue_len, has_messages });

    // Dispatch worker→main messages synchronously.
    // Although worker script execution enters/exits the worker isolate (which could
    // corrupt the outer HandleScope), dispatchMessageEvent creates its own fresh
    // HandleScope for V8 operations. This is safe because:
    // 1. We've exited the worker isolate and are back in the main isolate
    // 2. dispatchMessageEvent creates a new HandleScope before any V8 operations
    // 3. This avoids timer scheduling delays that cause test timeouts
    if (has_messages) {
        log.debug("[executeWorkerScriptCallback] Calling processQueuedMessages", .{});
        keepAliveWhileRunning(internal);
        dedicated_worker.processQueuedMessages();

        // CRITICAL: Message handlers may have posted NEW messages via self.postMessage().
        // For nested workers, the outer worker's onmessage handler calling self.postMessage()
        // will queue messages in pending_messages. These may go to DIFFERENT worker ports!
        //
        // Example flow:
        // 1. Inner worker: self.postMessage("from inner") → queued in pending_messages
        // 2. flushPendingMessages() → moved to inner worker's outside_port.message_queue
        // 3. processQueuedMessages() → dispatches to outer worker's onmessage
        // 4. Outer worker's onmessage: self.postMessage("outer received: ...")
        //    → queued in pending_messages for OUTER worker's outside_port
        // 5. We need to flush and process ALL affected ports!
        processAllPendingMessages(internal);
    }
}

/// Dispatch the worker's messages, as a task (WorkerTask) armed after its
/// script ran - so JavaScript has set up worker.onmessage first.
fn dispatchMessagesOf(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    dispatchWorkerMessages(internal);
}

/// A running worker keeps its Worker object alive, as Blink's
/// ActiveScriptWrappable does. Dispatching the worker's messages runs the
/// page's handlers, and one of them can drop the last reference to the Worker
/// - the harness does, when the worker reports its tests complete. A
/// collection then freed the Worker, and its DedicatedWorker, while
/// processQueuedMessages was still walking its port: a segfault on every run
/// of html/webappapis/atob/base64.any.js once a turn stopped draining the
/// queue in one go. So the wrapper is held from the first dispatch on, until
/// the worker has ended and everything it posted is delivered - the worker
/// host releases it then (`releaseOwnerWhenIdle`), from a turn of its own.
fn keepAliveWhileRunning(internal: *InternalState) void {
    keepPendingActivity(internal.worker_instance orelse return);
}

/// Take the Engine table's pending-activity hold on a Worker.
fn keepPendingActivity(instance: *runtime.Instance) void {
    const engine = instance.ctx.getEngine() orelse return;
    if (engine.keepPlatformObjectAlive) |keep| keep(instance);
}

/// End it (idempotent).
fn releasePendingActivity(instance: *runtime.Instance) void {
    const engine = instance.ctx.getEngine() orelse return;
    if (engine.releasePlatformObject) |release| release(instance);
}

/// Post the messages queued before the worker existed, in order.
fn flushPendingOutgoing(internal: *InternalState, dedicated_worker: *DedicatedWorker) void {
    for (internal.pending_outgoing_messages.items) |*message| {
        dedicated_worker.port_pair.outside_port.postEngineMessage(message.*) catch |err| {
            std.log.warn("[Worker] Failed to flush pending message: {}", .{err});
            message.deinit();
        };
    }
    internal.pending_outgoing_messages.clearRetainingCapacity();
}

/// An event-loop task for a Worker, holding it as (address, slab generation).
///
/// A Worker nothing has dispatched to yet is not held (keepAliveWhileRunning),
/// so script can drop it and a collection free it - and reissue its slot -
/// between the task being queued and being run. The task then reads whatever
/// lives there; with the generation it runs only for the Worker it was for.
const WorkerTask = struct {
    instance: *runtime.Instance,
    generation: u64,
    allocator: std.mem.Allocator,
    step: *const fn (*runtime.Instance) void,

    fn queue(event_loop: anytype, instance: *runtime.Instance, step: *const fn (*runtime.Instance) void) void {
        const allocator = instance.ctx.allocator;
        const task = allocator.create(WorkerTask) catch return;
        task.* = .{
            .instance = instance,
            .generation = runtime.SlabAllocator.generationOf(instance),
            .allocator = allocator,
            .step = step,
        };
        event_loop.queueTask(event_loop_mod.Task{ .callback = &run, .context = task, .drop = &drop });
    }

    /// The same step, as a timer on `timer` after `delay_ms` - for a realm
    /// with no event loop (a worker's, making a nested worker). It used to be
    /// a timer carrying the bare Worker pointer, which a Worker collected in
    /// the meantime left pointing at a freed slot.
    fn arm(timer: runtime.TimerInterface, delay_ms: u64, instance: *runtime.Instance, step: *const fn (*runtime.Instance) void) void {
        const allocator = instance.ctx.allocator;
        const task = allocator.create(WorkerTask) catch return;
        task.* = .{
            .instance = instance,
            .generation = runtime.SlabAllocator.generationOf(instance),
            .allocator = allocator,
            .step = step,
        };
        if (timer.setTimeout(delay_ms, &run, task) == 0) allocator.destroy(task);
    }

    fn run(data: ?*anyopaque) void {
        const task: *WorkerTask = @ptrCast(@alignCast(data orelse return));
        defer task.allocator.destroy(task);
        if (runtime.SlabAllocator.generationOf(task.instance) != task.generation) return;
        task.step(task.instance);
    }

    fn drop(data: ?*anyopaque) void {
        const task: *WorkerTask = @ptrCast(@alignCast(data orelse return));
        task.allocator.destroy(task);
    }
};

/// Dispatch worker messages to main thread handlers.
/// This is called either from the timer callback or synchronously as fallback.
fn dispatchWorkerMessages(internal: *InternalState) void {
    const dedicated_worker = internal.dedicated_worker orelse return;

    // Flush pending messages to the inside port for worker to receive
    flushPendingOutgoing(internal, dedicated_worker);

    // Process messages in the worker's realm
    if (internal.host) |host| {
        worker_host.processIncomingMessages(host);
    }

    // CRITICAL: Flush messages from threadlocal pending_messages to port queues.
    // Worker's self.postMessage() adds messages to pending_messages, not directly
    // to outside_port.message_queue. This flush moves them to the actual port.
    DedicatedWorker.flushPendingMessages();

    // Check if worker sent any messages back and dispatch them to main thread
    const outside_queue_len = dedicated_worker.port_pair.outside_port.message_queue.items.len;
    const has_messages = outside_queue_len > 0;

    log.debug("[dispatchWorkerMessages] worker={*} outside_port={*} queue len={d}, has_messages={}", .{ dedicated_worker, dedicated_worker.port_pair.outside_port, outside_queue_len, has_messages });

    // Dispatch worker→main messages
    if (has_messages) {
        log.debug("[dispatchWorkerMessages] Calling processQueuedMessages", .{});
        keepAliveWhileRunning(internal);
        dedicated_worker.processQueuedMessages();
        processAllPendingMessages(internal);
    }
}

/// Process all pending messages across all worker ports.
/// This handles the case where message handlers post to different workers.
fn processAllPendingMessages(initial_internal: *InternalState) void {
    // Keep processing until no more messages are pending
    var iterations: usize = 0;
    const max_iterations: usize = 100; // Prevent infinite loops

    while (iterations < max_iterations) {
        iterations += 1;

        // Flush pending messages and get the ports that received them
        var affected_ports = DedicatedWorker.flushPendingMessagesAndGetPorts(initial_internal.allocator) catch return;
        defer affected_ports.deinit(initial_internal.allocator);

        if (affected_ports.items.len == 0) {
            break; // No more pending messages
        }

        // Process messages on each affected port
        for (affected_ports.items) |port| {
            while (port.message_queue.items.len > 0) {
                const queued_msg = port.message_queue.orderedRemove(0);
                if (port.on_message) |handler| {
                    handler(port, queued_msg, port.on_message_context);
                }
                queued_msg.deinit();
            }
        }
    }

    if (iterations >= max_iterations) {
        std.log.warn("processAllPendingMessages: hit max iterations", .{});
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
    keepAliveWhileRunning(internal);
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
    std.log.debug("[executeWorkerScriptSync] ENTRY", .{});
    const dedicated_worker = internal.dedicated_worker orelse {
        std.log.debug("[executeWorkerScriptSync] No dedicated_worker, returning", .{});
        return false;
    };
    const script = internal.pending_script orelse {
        std.log.debug("[executeWorkerScriptSync] No pending_script, returning", .{});
        return false;
    };
    std.log.debug("[executeWorkerScriptSync] Script len={d}, preview: {s}", .{ script.len, script[0..@min(script.len, 80)] });

    // Execute the script in WorkerV8Context - this is the SAME context used for message dispatch.
    // CRITICAL: We must use internal.v8_context, not dedicated_worker.executeScript(), because:
    // - internal.v8_context is WorkerV8Context (has onmessage dispatch)
    // - dedicated_worker.executeScript() uses WorkerContext (different V8 context!)
    // - If we execute in the wrong context, onmessage won't be set where we dispatch.
    if (internal.host) |host| {
        host.executeScript(script) catch |err| {
            std.log.err("[executeWorkerScriptSync] Failed to execute: {}", .{err});
        };
        log.debug("[executeWorkerScriptSync] executeScript returned", .{});
    } else {
        std.log.err("[executeWorkerScriptSync] No WorkerV8Context!", .{});
    }

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
    // Get the Worker instance from user_data stored in DedicatedWorker
    const user_data = dedicated_worker.getUserData() orelse return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(user_data));

    // Dispatch the message event to onmessage handler
    dispatchMessageEvent(instance, msg);
}

/// Callback to handle errors from the worker
///
/// This is called by DedicatedWorker when an uncaught error occurs in the worker
/// and self.onerror didn't handle it. We create an ErrorEvent and dispatch it
/// to the Worker object's onerror handler.
///
/// Spec: HTML Standard § 10.2.5 step 11
/// "Queue a task to fire an event named error at worker."
fn handleErrorFromWorkerCallback(dedicated_worker: *DedicatedWorker, error_event: *WorkerErrorEvent) void {
    // Get the Worker instance from user_data stored in DedicatedWorker
    const user_data = dedicated_worker.getUserData() orelse {
        error_event.deinit();
        return;
    };
    const instance: *runtime.Instance = @ptrCast(@alignCast(user_data));

    // Dispatch the error event to onerror handler
    dispatchWorkerErrorEvent(instance, error_event);
}

/// Fire `error` at the Worker - HTML "report an exception" for the worker's
/// global scope, when it went unhandled there: "fire an event named error at
/// workerObject, using ErrorEvent, with the cancelable attribute initialized
/// to true, and additional attributes initialized according to errorInfo" -
/// with `error` null: the exception value does not reach the owner's realm.
///
/// Every "error" listener hears it, and `onerror`, in the order they were
/// added (EventTarget's list holds both).
///
/// TODO(workers): "If notHandled is true, then report exception for
/// workerObject's relevant global object with omitError set to true" - the
/// owner's own error event. Not yet: the owner's global does not hear it.
fn dispatchWorkerErrorEvent(instance: *runtime.Instance, error_event: *WorkerErrorEvent) void {
    defer error_event.deinit();
    const internal = getInternal(instance) orelse return;
    const ctx = internal.ctx orelse return;
    const engine = ctx.getEngine() orelse return;
    const run = engine.runInRealm orelse return;
    // A task of the owner's realm, entered from the event loop.
    var fire = ErrorFire{ .worker = instance, .error_event = error_event };
    run(ctx, ErrorFire.steps, &fire) catch {};
}

const ErrorFire = struct {
    worker: *runtime.Instance,
    error_event: *WorkerErrorEvent,

    fn steps(data: ?*anyopaque) void {
        const self: *ErrorFire = @ptrCast(@alignCast(data orelse return));
        const worker = self.worker;
        const init_dict = dictionaries.ErrorEventInit{
            .base = .{ .cancelable = true },
            .message = runtime.DOMString.initInterned(self.error_event.message),
            .filename = self.error_event.filename,
            .lineno = self.error_event.lineno,
            .colno = self.error_event.colno,
            .@"error" = runtime.JSValue.jsNull,
        };
        const event = interfaces.ErrorEvent.call_constructor(
            worker.ctx,
            runtime.DOMString.initInterned("error"),
            webidl.Opt(dictionaries.ErrorEventInit).passed(init_dict),
        ) catch return;
        const generation = runtime.SlabAllocator.generationOf(event);
        // Fired by the user agent: trusted (DOM 2.10). EventTarget is an
        // ancestor, so its impl.
        _ = EventTargetImpl.dispatchTrusted(worker, event) catch {};
        event.releaseIfUnwrapped(generation);
    }
};

/// Deliver a message the worker posted: the receiving half of the message
/// port post message steps for the Worker's outside port - deserialized into
/// this realm, its transferred ports received here, and `message` fired at
/// the Worker (or `messageerror`, when it does not deserialize). Every
/// "message" listener hears it, and `onmessage`.
fn dispatchMessageEvent(instance: *runtime.Instance, msg: *QueuedMessage) void {
    const internal = getInternal(instance) orelse return;
    const ctx = internal.ctx orelse return;
    const message = if (msg.engine_message) |*m| m else return;
    const engine = ctx.getEngine() orelse return;
    const run = engine.runInRealm orelse return;
    var delivery = Delivery{ .worker = instance, .engine = engine, .message = message };
    run(ctx, Delivery.steps, &delivery) catch {};
}

const Delivery = struct {
    worker: *runtime.Instance,
    engine: *const runtime.EngineInterface,
    message: *EngineMessage,

    fn steps(data: ?*anyopaque) void {
        const self: *Delivery = @ptrCast(@alignCast(data orelse return));
        worker_host.deliverEngineMessage(self.engine, self.worker.ctx, self.worker, self.message, fireAtWorker);
    }
};

/// Fire a MessageEvent at the Worker `target`, made in `realm`. `data` is
/// borrowed: the event keeps its own.
fn fireAtWorker(
    realm: runtime.Context,
    target: *runtime.Instance,
    event_type: []const u8,
    data: runtime.JSValue,
    ports: []const *runtime.Instance,
) void {
    const init_dict = dictionaries.MessageEventInit{
        .base = .{},
        .data = data,
        .ports = ports,
    };
    const event = MessageEvent.call_constructor(
        realm,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.MessageEventInit).passed(init_dict),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    // Fired by the user agent: trusted (DOM 2.10).
    _ = EventTargetImpl.dispatchTrusted(target, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// Operation: terminate
///
/// Spec: HTML Standard § 10.2.3.1 terminate()
/// "The terminate() method, when invoked, must cause the terminate a worker
/// algorithm to be run on the worker with which the object is associated."
pub fn call_terminate(instance: *runtime.Instance) anyerror!void {
    log.debug("[Worker.call_terminate] ENTRY", .{});

    const state = instance.getState(State);
    if (state.own._internal) |internal_ptr| {
        // Mark as terminated
        const internal = @constCast(internal_ptr);
        internal.terminated = true;
        if (internal.dedicated_worker) |worker| {
            log.debug("[Worker.call_terminate] worker={*}, agent={*}", .{ worker, worker.agent });
            worker.terminate();
        }
        // The host's half: discard the worker's tasks, empty the port queue
        // its implicit port is entangled with, and let its realm and isolate
        // go (HTML "terminate a worker"). The host releases the Worker's
        // pending-activity hold once the realm is gone; a worker that never
        // started has no host, and nothing is left pending now.
        if (internal.host) |host| host.terminate() else releasePendingActivity(instance);
    }
}

/// Operation: postMessage(message, transfer)
///
/// Spec: HTML Standard § 10.2.3.1: "act as if, when invoked, it immediately
/// invoked the respective postMessage(message, transfer) ... on the port"
/// its outside port is entangled with - the message port post message steps
/// with options «[ "transfer" → transfer ]».
pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
    const engine = instance.ctx.getEngine() orelse return error.NoEngine;
    const convert = engine.convertToSequenceOfObjects orelse return error.NotSupported;
    const list = try convert(instance.ctx, transfer, instance.ctx.allocator);
    defer {
        if (engine.releaseValue) |release| for (list) |item| release(item);
        instance.ctx.allocator.free(list);
    }
    return postMessageSteps(instance, message, list);
}

/// Operation: postMessage(message, options)
pub fn call_postMessage__1(instance: *runtime.Instance, message: runtime.JSValue, options: webidl.Opt(dictionaries.StructuredSerializeOptions)) anyerror!void {
    const transfer: []const runtime.JSValue = if (options.wasPassed()) (options.getValue().transfer orelse &.{}) else &.{};
    return postMessageSteps(instance, message, transfer);
}

/// The message port post message steps for the outside port: serialize with
/// transfer in this realm (a MessagePort in `transfer` is shipped), then queue
/// the message for the worker - or hold it until the worker exists.
fn postMessageSteps(instance: *runtime.Instance, message: runtime.JSValue, transfer: []const runtime.JSValue) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    if (internal.terminated) return; // Worker is terminated, ignore message

    const engine = instance.ctx.getEngine() orelse return error.NoEngine;
    var serialized = try worker_host.serializeMessage(engine, instance.ctx, message, transfer, internal.allocator);

    if (internal.dedicated_worker) |worker| {
        worker.port_pair.outside_port.postEngineMessage(serialized) catch |err| {
            serialized.deinit();
            return switch (err) {
                error.PortClosed => error.WorkerClosed,
                error.NotEntangled => error.WorkerClosed,
                else => error.PostMessageFailed,
            };
        };
    } else {
        // Queue for later - worker not ready yet
        internal.pending_outgoing_messages.append(internal.allocator, serialized) catch |err| {
            serialized.deinit();
            return err;
        };
    }

    // CRITICAL: Only process messages if the worker script has been evaluated.
    // Per Chromium's DedicatedWorkerMessagingProxy::was_script_evaluated_ pattern:
    // - If script hasn't run yet, messages are queued and will be processed later
    //   in executeWorkerScriptCallback after the script finishes
    // - If script HAS run, we can immediately dispatch to self.onmessage
    if (internal.script_evaluated) {
        if (internal.host) |host| {
            worker_host.processIncomingMessages(host);

            // After processing, check if worker sent back any messages and dispatch them
            // This handles the echo pattern: main → worker → main
            if (internal.dedicated_worker) |dw| {
                if (dw.port_pair.outside_port.message_queue.items.len > 0) {
                    keepAliveWhileRunning(internal);
                    dw.processQueuedMessages();
                }
            }
        }
    }
}
