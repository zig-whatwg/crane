//! HTML 9.2 Server-sent events.
//! https://html.spec.whatwg.org/multipage/server-sent-events.html
//!
//! Headers and incremental BodyPipe bytes are processed by remote-event
//! tasks. Each message task holds its event through run/drop, including
//! when a listener closes the source or destroys its document.
//!
//! Stated deviation (9.2.9): listener-conditioned retention is not modelled.
//! Like WebSocket/BroadcastChannel, active sources stay alive even without
//! listeners until close, failure or document end. Queued/running tasks also
//! hold the source until AFTER any script they run has returned.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const dom = @import("dom");
const html = @import("html");
const infra = @import("infra");
const fetch = @import("fetch");
const eventsource = @import("eventsource");
const EventSource = interfaces.EventSource;
const LiveSources = eventsource.Registry(*anyopaque, *anyopaque);
const same_object = @import("same_object.zig");

pub const State = EventSource.State;

/// The instance owns this record; tasks keep it independently after forced
/// realm teardown deinitializes the instance. Then they only free payloads.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    instance: ?*runtime.Instance,
    url: []const u8 = "",
    with_credentials: bool = false,
    connection: eventsource.Connection = .{},
    parser: eventsource.Parser,
    request: ?*fetch.internal.InternalRequest = null,
    active_fetch: ?*fetch.algorithms.AsyncFetch = null,
    outcome: ?(fetch.algorithms.FetchError!fetch.algorithms.FetchResult) = null,
    response: ?fetch.algorithms.FetchResult = null,
    pipe: ?*fetch.internal.BodyPipe = null,
    origin: []const u8 = "",
    read_queued: bool = false,
    retry: eventsource.Retry(runtime.TimerInterface) = .{},
    document: ?same_object.Link = null,
    generation: u64 = 0,
    document_abort_pending: ?u64 = null,

    fn syncPendingActivity(self: *InternalState) void {
        const instance = self.instance orelse return;
        if (self.connection.needsHold()) {
            engine.keepPlatformObjectAlive(instance);
        } else {
            engine.releasePlatformObject(instance);
        }
    }

    /// 9.2.2 close(), and 9.2.9 forcible close. No event is fired.
    fn close(self: *InternalState) void {
        self.document_abort_pending = null;
        self.connection.close();
        self.retry.cancel();
        self.endFetch();
        if (self.instance) |instance| {
            if (liveSources(instance.ctx)) |sources| sources.remove(instance);
        }
        self.syncPendingActivity();
    }

    /// Detach the consumer before terminating its producer or freeing its body.
    fn endFetch(self: *InternalState) void {
        if (self.pipe) |pipe| pipe.consumer = null;
        self.pipe = null;
        if (self.active_fetch) |active| {
            self.active_fetch = null;
            active.terminate();
        }
        if (self.outcome) |outcome| {
            self.outcome = null;
            freeOutcome(outcome);
        }
        if (self.response) |*response| response.deinit();
        self.response = null;
        self.parser.finish();
    }

    fn maybeFree(self: *InternalState) void {
        if (self.instance != null or self.connection.pending_tasks != 0) return;
        self.retry.cancel();
        self.endFetch();
        if (self.request) |request| request.deinit();
        self.parser.deinit();
        self.allocator.free(self.origin);
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }

    /// Constructor step 15 and reestablish step 5.4: an incremental fetch.
    fn connect(self: *InternalState) !void {
        self.generation +%= 1;
        self.document_abort_pending = null;
        self.read_queued = false;
        try self.parser.reset();
        const request = try self.request.?.clone();
        // 9.2.3 step 5.3: ID is already UTF-8. A fresh request clone also
        // ensures an empty ID never leaves a previous Last-Event-ID header.
        if (self.parser.lastEventId().len != 0) {
            request.header_list.set("Last-Event-ID", self.parser.lastEventId()) catch |err| {
                request.deinit();
                return err;
            };
        }
        // Owns request even on failure; no client callback runs inline.
        self.active_fetch = try fetch.algorithms.AsyncFetch.startStreaming(
            self.allocator,
            request,
            .{},
            fetch.network.scheduler.threadScheduler(),
            .{ .context = self, .done = fetched, .alive = alive, .gone = gone, .finished = finished },
        );
    }

    fn alive(context: *anyopaque) bool {
        const self: *InternalState = @ptrCast(@alignCast(context));
        const instance = self.instance orelse return false;
        return instance.ctx.hasEngine() and self.connection.state != .closed;
    }
    fn gone(context: *anyopaque) void {
        const self: *InternalState = @ptrCast(@alignCast(context));
        self.active_fetch = null;
        self.close();
    }
    fn finished(context: *anyopaque) void {
        const self: *InternalState = @ptrCast(@alignCast(context));
        self.active_fetch = null;
    }
    fn fetched(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        const self: *InternalState = @ptrCast(@alignCast(context));
        self.outcome = outcome;
        self.queueRead();
    }
    fn notify(context: *anyopaque) void {
        const self: *InternalState = @ptrCast(@alignCast(context));
        self.queueRead();
    }
    fn queueRead(self: *InternalState) void {
        if (self.read_queued or self.connection.state == .closed) return;
        self.read_queued = true;
        self.queue(.read) catch {
            self.read_queued = false;
            self.close();
        };
    }

    /// The ONE remote-event queue, always the relevant realm's live loop.
    fn queue(self: *InternalState, kind: Task.Kind) !void {
        const instance = self.instance orelse return error.InvalidStateError;
        const loop = instance.ctx.getOptionalEventLoop() orelse return error.NotSupportedError;
        const task = try self.allocator.create(Task);
        task.* = .{ .source = self, .kind = kind, .generation = self.generation };
        var queued: runtime.EventLoopTask = .{ .callback = Task.run, .context = task, .drop = Task.drop };
        if (globalOf(instance.ctx)) |global| {
            if (std.mem.eql(u8, global.vtable.name, "Window")) {
                queued.document = global;
                queued.document_generation = runtime.SlabAllocator.generationOf(global);
            }
        }
        self.connection.beginTask();
        self.syncPendingActivity();
        loop.queueTask(queued);
    }
    fn queueFailure(self: *InternalState) void {
        self.endFetch();
        self.retry.cancel();
        self.queue(.fail) catch self.close();
    }
    fn queueReestablish(self: *InternalState) void {
        self.endFetch();
        self.queue(.reestablish) catch self.close();
    }

    fn read(self: *InternalState) !void {
        if (self.outcome) |outcome| {
            self.outcome = null;
            const result = outcome catch {
                self.queueFailure();
                return;
            };
            self.response = result;
            const response = result.response;
            // 9.2.2 step 15.1–3. Blink EventSource::DidFail similarly closes
            // IsAccessCheck()/IsCancellation(), retrying transport failures.
            if (response.response_type == .@"error") {
                if (!response.aborted and response.network_error_cause == .transport)
                    self.queueReestablish()
                else
                    self.queueFailure();
                return;
            }
            if (response.status != 200 or !try isEventStream(self.allocator, response)) {
                self.queueFailure();
                return;
            }
            // Reestablish step 5 reuses the request after redirects. As in
            // Blink's current_url_, subsequent attempts start at its final
            // URL while the public url attribute keeps the constructor URL.
            if (response.url()) |final_url| {
                const request = self.request.?;
                if (!std.mem.eql(u8, request.currentUrl(), final_url)) {
                    const copy = try self.allocator.dupe(u8, final_url);
                    errdefer self.allocator.free(copy);
                    try request.url_list.append(self.allocator, copy);
                }
            }
            const origin = try fetch.internal.origins.serializedOriginOf(self.allocator, response.url() orelse self.url);
            self.allocator.free(self.origin);
            self.origin = origin;
            // Step 15.4: announcement precedes every message in the queue.
            try self.queue(.open);
            if (response.body) |body| {
                if (body.pipe) |pipe| {
                    self.pipe = pipe;
                    pipe.consumer = .{ .context = self, .notify = notify };
                } else {
                    try self.feed(body.getBytes());
                    self.queueReestablish();
                    return;
                }
            } else {
                self.queueReestablish();
                return;
            }
        }
        const pipe = self.pipe orelse return;
        if (pipe.hasBytes()) {
            const bytes = try pipe.take();
            defer pipe.allocator.free(bytes);
            try self.feed(bytes);
        }
        // take() may resume the producer and receive another chunk.
        if (pipe.hasBytes()) return self.queueRead();
        switch (pipe.state) {
            .open => {},
            .closed => self.queueReestablish(),
            .errored => {
                const failure = pipe.failure();
                if (failure.kind == .aborted) self.queueFailure() else self.queueReestablish();
            },
        }
    }

    fn feed(self: *InternalState, bytes: []const u8) !void {
        var messages = infra.List(eventsource.Message).init(self.allocator);
        defer {
            for (messages.toSliceMut()) |*message| message.deinit(self.allocator);
            messages.deinit();
        }
        try self.parser.feed(bytes, &messages);
        const instance = self.instance orelse return;
        for (messages.toSlice()) |message| {
            // 9.2.6 dispatch steps 4–6 precede step 8's task: the event's
            // creation time and this response's origin are captured now.
            // MessageEvent takes its own copies of the parser's strings.
            const event = try interfaces.MessageEvent.call_constructor(instance.ctx, runtime.DOMString.initInterned(message.event_type), webidl.Opt(dictionaries.MessageEventInit).passed(.{
                .base = .{},
                .data = .{ .string = .{ .data = message.data, .owned = false } },
                .origin = self.origin,
                .lastEventId = runtime.DOMString.initInterned(message.last_event_id),
            }));
            const generation = runtime.SlabAllocator.generationOf(event);
            defer event.releaseIfUnwrapped(generation);
            const hold = try engine.retainValue(instance.ctx, .{ .instance = event });
            errdefer hold.release();
            try self.queue(.{ .message = .{ .event = event, .hold = hold } });
        }
    }
    fn retryReady(context: *anyopaque) void {
        const self: *InternalState = @ptrCast(@alignCast(context));
        // A delayed wait only queues work; no Fetch or script runs here.
        self.queue(.reconnect) catch self.close();
    }
};

const Task = struct {
    source: *InternalState,
    kind: Kind,
    generation: u64,
    const Kind = union(enum) {
        read,
        open,
        reestablish,
        reconnect,
        fail,
        message: struct { event: *runtime.Instance, hold: engine.Owned },
    };
    fn run(context: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(context.?));
        defer self.finish();
        const source = self.source;
        if (self.generation != source.generation) return;
        if (self.kind == .read) source.read_queued = false;
        const instance = source.instance orelse return;
        if (source.connection.state == .closed) return;
        engine.runTaskInRealm(instance.ctx, steps, self) catch source.close();
    }
    fn steps(context: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(context.?));
        const source = self.source;
        if (self.generation != source.generation) return;
        const instance = source.instance orelse return;
        if (source.connection.state == .closed) return;
        switch (self.kind) {
            .read => source.read() catch source.queueFailure(),
            .open => if (source.connection.announce()) fire(instance, "open"),
            .message => |payload| {
                // 9.2.6 step 8 dispatches the already-created event. Its
                // hold lasts until finish(), after script and microtasks.
                _ = dom.fire_event.dispatchTrusted(instance, payload.event) catch {};
            },
            .reestablish => {
                // 9.2.3 steps 1.1–1.3: CONNECTING before firing error.
                if (!source.connection.reestablish()) return;
                fire(instance, "error");
                if (self.generation != source.generation or source.instance == null or !source.connection.canReconnect()) return;
                const timer = instance.ctx.getOptionalTimer() orelse {
                    source.queueFailure();
                    return;
                };
                // Steps 2–4: delay before queueing the reconnect. This also
                // waits for the preceding error task as step 4 requires.
                source.retry.start(source.allocator, timer, source.parser.reconnection_time, InternalState.retryReady, source) catch source.queueFailure();
            },
            .reconnect => {
                // Step 5.1: close() during the wait wins.
                if (source.connection.canReconnect()) source.connect() catch source.queueFailure();
            },
            .fail => {
                if (!source.connection.fail()) return;
                source.close();
                fire(instance, "error");
            },
        }
    }
    fn drop(context: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(context.?));
        if (self.generation == self.source.generation) self.source.close();
        self.finish();
    }
    fn finish(self: *Task) void {
        const source = self.source;
        switch (self.kind) {
            .message => |payload| payload.hold.release(),
            else => {},
        }
        source.allocator.destroy(self);
        source.connection.endTask();
        source.syncPendingActivity();
        source.maybeFree();
    }
};

/// Installed once at process start, never lazily in a constructor.
pub fn installHooks() void {
    dom.document_fetches.install(.{ .discard = closeInRealm, .prepare_abort = prepareDocumentAbort, .abort = abortDocument });
    dom.unloading_cleanup.install(closeInRealm);
}
fn prepareDocumentAbort(document: *runtime.Instance) bool {
    const sources = liveSources(document.ctx) orelse return false;
    var canceled = false;
    for (sources.entries.toSlice()) |entry| {
        const instance: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
        const self = getInternal(instance);
        const link = self.document orelse continue;
        if (link.instance != document or !link.isLive() or self.connection.state == .closed) continue;
        self.document_abort_pending = self.generation;
        canceled = true;
    }
    return canceled;
}
fn abortDocument(document: *runtime.Instance) void {
    const sources = liveSources(document.ctx) orelse return;
    while (true) {
        const self: *InternalState = blk: {
            for (sources.entries.toSlice()) |entry| {
                const instance: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
                const candidate = getInternal(instance);
                const link = candidate.document orelse continue;
                if (candidate.document_abort_pending != null and link.instance == document and link.isLive()) break :blk candidate;
            }
            return;
        };
        const generation = self.document_abort_pending.?;
        self.document_abort_pending = null;
        if (generation != self.generation or self.connection.state == .closed) continue;
        // An external cancellation fails the connection. Old network tasks
        // discard their payloads; the new failure task alone can fire error.
        self.generation +%= 1;
        self.read_queued = false;
        self.queueFailure();
    }
}
fn liveSources(realm: runtime.Context) ?*LiveSources {
    const agent = realm.agent orelse return null;
    const host: *@import("html_core").agent_host.AgentHost = @ptrCast(@alignCast(engine.agentHost(agent) orelse return null));
    return &host.event_sources;
}
fn closeInRealm(realm: runtime.Context) void {
    const sources = liveSources(realm) orelse return;
    var i = sources.entries.len;
    while (i > 0) {
        i -= 1;
        if (i >= sources.entries.len) continue;
        const entry = sources.entries.get(i).?;
        if (entry.realm != @as(*anyopaque, @ptrCast(realm))) continue;
        const instance: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
        getInternal(instance).close();
    }
}
pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.EventTarget.initWithState(allocator, StateType, vtable, ctx);
    const state = instance.getState(State);
    state.own._internal = null;
    errdefer instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator, .instance = instance, .parser = eventsource.Parser.init(allocator) };
    state.own._internal = internal;
    return instance;
}
/// GC frees the slab; queued tasks own only the detached native record.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        state.own._internal = null;
        internal.close();
        internal.instance = null;
        engine.releasePlatformObject(instance);
        internal.maybeFree();
    }
    interfaces.EventTarget.deinit(instance);
}
pub fn call_constructor(ctx: runtime.Context, url: runtime.USVString, eventSourceInitDict: webidl.Opt(dictionaries.EventSourceInit)) !*runtime.Instance {
    // 9.2.2 steps 2–5: encoding-parse against this realm's settings.
    const parsed = (try parseUrl(ctx, url)) orelse return error.SyntaxError;
    var url_taken = false;
    defer if (!url_taken) ctx.allocator.free(parsed);
    // Stated deviation until workers 1B supplies their realm event loop:
    // refuse an API that could never deliver its queued events.
    if (ctx.getOptionalEventLoop() == null) {
        const exception = try engine.createDOMException(ctx, "NotSupportedError", "EventSource needs the realm's event loop");
        defer exception.release();
        try engine.throwValue(ctx, exception.borrow());
        return error.ExceptionPending;
    }
    const instance = try init(ctx.allocator, State, &EventSource.vtable, ctx);
    errdefer instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
    const internal = getInternal(instance);
    if (globalOf(ctx)) |global| if (std.mem.eql(u8, global.vtable.name, "Window")) {
        if (interfaces.Window.get_document(global) catch null) |document| internal.document = same_object.Link.to(document);
    };
    internal.url = parsed;
    url_taken = true;
    // Steps 6–13: potential-CORS request with the relevant client/settings.
    internal.with_credentials = eventSourceInitDict.was_passed and (eventSourceInitDict.value.withCredentials orelse false);
    const request = try fetch.internal.InternalRequest.init(ctx.allocator, parsed);
    internal.request = request;
    html.script_request.createPotentialCorsRequest(request, .empty, if (internal.with_credentials) .use_credentials else .anonymous);
    try html.script_request.populateRequestFromClient(request, ctx);
    try request.header_list.set("Accept", "text/event-stream");
    request.cache_mode = .no_store;
    request.initiator_type = .other;
    const sources = liveSources(ctx) orelse return error.NotSupportedError;
    try sources.add(instance, ctx);
    // Before wrapping: a Pin here would create a competing wrapper.
    internal.syncPendingActivity();
    try internal.connect();
    return instance;
}
fn parseUrl(ctx: runtime.Context, input: []const u8) !?[]const u8 {
    const sniffing = @import("html_core").parser.encoding_sniffing;
    var encoding = sniffing.utf_8;
    var base = ctx.documentUrl();
    var owned_base: ?[]const u8 = null;
    defer if (owned_base) |value| ctx.allocator.free(value);
    if (globalOf(ctx)) |global| {
        if (std.mem.eql(u8, global.vtable.name, "Window")) {
            const document = interfaces.Window.get_document(global) catch null;
            if (document) |doc| {
                owned_base = try interfaces.Node.get_baseURI(doc);
                // Harness globals can have an empty Document URL but an
                // actual resource URL recorded in their settings object.
                if (owned_base.?.len > 0) base = owned_base;
                var charset = try interfaces.Document.get_characterSet(doc);
                defer charset.deinit(doc.ctx.allocator);
                encoding = sniffing.lookup(charset.asSlice()) orelse sniffing.utf_8;
            }
        }
    }
    return @import("api_parser").encodingParseAndSerialize(ctx.allocator, input, base, encoding);
}
fn globalOf(ctx: runtime.Context) ?*runtime.Instance {
    const realm = ctx.getRealm() orelse return null;
    return @ptrCast(@alignCast(realm.global_object orelse return null));
}
fn getInternal(instance: *runtime.Instance) *InternalState {
    return instance.getState(State).own._internal.?;
}
fn isEventStream(allocator: std.mem.Allocator, response: *fetch.internal.InternalResponse) !bool {
    const essence = (try fetch.internal.mime.extractMimeEssence(allocator, &response.header_list)) orelse return false;
    defer allocator.free(essence);
    return std.mem.eql(u8, essence, "text/event-stream");
}
fn freeOutcome(outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
    var result = outcome catch return;
    result.deinit();
}
fn fire(instance: *runtime.Instance, name: []const u8) void {
    const event = interfaces.Event.call_constructor(instance.ctx, runtime.DOMString.initInterned(name), webidl.Opt(dictionaries.EventInit).notPassed()) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    _ = dom.fire_event.dispatchTrusted(instance, event) catch {};
}
pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
    return instance.ctx.allocator.dupe(u8, getInternal(instance).url);
}
pub fn get_withCredentials(instance: *runtime.Instance) anyerror!bool {
    return getInternal(instance).with_credentials;
}
pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
    return @intFromEnum(getInternal(instance).connection.state);
}
pub fn get_onopen(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "open");
}
pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "message");
}
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "error");
}
pub fn set_onopen(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "open", value);
}
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "message", value);
}
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "error", value);
}
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    getInternal(instance).close();
}
