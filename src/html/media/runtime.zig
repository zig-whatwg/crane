//! Runtime plumbing shared by the media and track owners. No implementation
//! module is named here; algorithms and state remain with their owners.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const fetch = @import("fetch");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");
const core = @import("html_core");
const requests = @import("../script_request.zig");
pub const Registry = core.media.Registry(*anyopaque, *anyopaque);

/// Q4: host wiring belongs to BrowserScope. This is the single realm lookup
/// that the host-backend follow-up will change; the platform stays realm-free.
pub fn forRealm(_: runtime.Context) @import("platform").media_backend.MediaBackend {
    return @import("platform").media_backend.no_decoder;
}

/// The one registry lookup: the relevant realm's agent, never thread-local state.
pub fn liveRegistry(ctx: runtime.Context) ?*Registry {
    const agent = ctx.agent orelse return null;
    const host: *core.agent_host.AgentHost = @ptrCast(@alignCast(engine.agentHost(agent) orelse return null));
    return &host.media_elements;
}
pub fn globalOf(ctx: runtime.Context) ?*runtime.Instance {
    const realm = ctx.getRealm() orelse return null;
    return @ptrCast(@alignCast(realm.global_object orelse return null));
}
pub fn isMedia(instance: *runtime.Instance) bool {
    return std.mem.eql(u8, instance.vtable.name, "HTMLAudioElement") or std.mem.eql(u8, instance.vtable.name, "HTMLVideoElement") or std.mem.eql(u8, instance.vtable.name, "HTMLMediaElement");
}
pub fn documentOf(instance: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Node.get_ownerDocument(instance) catch null;
}
pub fn queueTask(instance: *runtime.Instance, callback: *const fn (?*anyopaque) void, context: *anyopaque, drop: *const fn (?*anyopaque) void) !void {
    const loop = instance.ctx.getOptionalEventLoop() orelse return error.NotSupported;
    var task: runtime.EventLoopTask = .{ .callback = callback, .context = context, .drop = drop };
    if (globalOf(instance.ctx)) |global| if (std.mem.eql(u8, global.vtable.name, "Window")) {
        task.document = global;
        task.document_generation = runtime.SlabAllocator.generationOf(global);
    };
    loop.queueTask(task);
}

/// A fully initialized event, made BEFORE it is queued, with its target held
/// through dispatch and its microtask checkpoint. Exactly one release on run/drop.
pub const Event = struct {
    event: *runtime.Instance,
    target: *runtime.Instance,
    event_hold: engine.Owned,
    target_hold: engine.Owned,
    pub fn init(target: *runtime.Instance, name: []const u8) !Event {
        const event = try interfaces.Event.call_constructor(target.ctx, runtime.DOMString.initInterned(name), webidl.Opt(dictionaries.EventInit).notPassed());
        return take(target, event);
    }
    pub fn track(target: *runtime.Instance, name: []const u8, child: *runtime.Instance) !Event {
        const event = try interfaces.TrackEvent.call_constructor(target.ctx, .initInterned(name), .passed(.{ .base = .{}, .track = .{ .instance = child } }));
        return take(target, event);
    }
    fn take(target: *runtime.Instance, event: *runtime.Instance) !Event {
        const generation = runtime.SlabAllocator.generationOf(event);
        errdefer event.releaseIfUnwrapped(generation);
        const event_hold = try engine.retainValue(target.ctx, .{ .instance = event });
        errdefer event_hold.release();
        const target_hold = try engine.retainValue(target.ctx, .{ .instance = target });
        return .{ .event = event, .target = target, .event_hold = event_hold, .target_hold = target_hold };
    }
    pub fn dispatch(self: Event) void {
        _ = dom.fire_event.dispatchTrusted(self.target, self.event) catch {};
    }
    pub fn deinit(self: Event) void {
        self.event_hold.release();
        self.target_hold.release();
    }
};

/// HTML's potential-CORS request with the node document's policies and realm.
pub fn requestFor(instance: *runtime.Instance, url: []const u8, destination: fetch.internal.Destination, cors: requests.CorsSetting) !*fetch.internal.InternalRequest {
    const request = try fetch.internal.InternalRequest.init(instance.ctx.allocator, url);
    errdefer request.deinit();
    requests.createPotentialCorsRequest(request, destination, cors);
    // Track processing step 10.1 sets the same-origin fallback flag.
    if (destination == .track and cors == .no_cors) request.mode = .same_origin;
    request.initiator_type = switch (destination) {
        .audio => .audio,
        .video => .video,
        .track => .track,
        else => unreachable,
    };
    const doc = documentOf(instance);
    try requests.populateRequestFromClient(request, if (doc) |d| d.ctx else instance.ctx);
    return request;
}

/// An incremental fetch whose producer callbacks only schedule the owner's task.
/// The owner stops it before destruction and retains itself while fetching/tasks
/// are pending. All returned slices are borrowed until next() or stop().
pub const Resource = struct {
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    owner: *anyopaque,
    notify: *const fn (*anyopaque) void,
    active: ?*fetch.algorithms.AsyncFetch = null,
    outcome: ?(fetch.algorithms.FetchError!fetch.algorithms.FetchResult) = null,
    response: ?fetch.algorithms.FetchResult = null,
    pipe: ?*fetch.internal.BodyPipe = null,
    chunk: ?[]u8 = null,
    chunk_allocator: ?std.mem.Allocator = null,
    sent_buffer: bool = false,
    ended: bool = false,
    gone: bool = false,
    pub const Piece = union(enum) { headers: *fetch.internal.InternalResponse, bytes: []const u8, eof, failed };
    pub fn start(self: *Resource, request: *fetch.internal.InternalRequest) !void {
        self.stop();
        self.ended = false;
        self.gone = false;
        self.sent_buffer = false;
        // startStreaming owns request even when it returns an error.
        self.active = try fetch.algorithms.AsyncFetch.startStreaming(self.allocator, request, .{}, fetch.network.scheduler.threadScheduler(), .{ .context = self, .done = fetched, .alive = alive, .gone = realmGone, .finished = finished });
    }
    fn alive(context: *anyopaque) bool {
        const self: *Resource = @ptrCast(@alignCast(context));
        return self.ctx.hasEngine() and !self.ended;
    }
    fn realmGone(context: *anyopaque) void {
        const self: *Resource = @ptrCast(@alignCast(context));
        self.active = null;
        self.gone = true;
        self.notify(self.owner);
    }
    fn finished(context: *anyopaque) void {
        const self: *Resource = @ptrCast(@alignCast(context));
        self.active = null;
    }
    fn fetched(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        const self: *Resource = @ptrCast(@alignCast(context));
        self.outcome = outcome;
        self.notify(self.owner);
    }
    fn bytesReady(context: *anyopaque) void {
        const self: *Resource = @ptrCast(@alignCast(context));
        self.notify(self.owner);
    }
    pub fn next(self: *Resource) !?Piece {
        if (self.chunk) |bytes| self.chunk_allocator.?.free(bytes);
        self.chunk = null;
        if (self.ended) return null;
        if (self.gone) {
            self.ended = true;
            return .failed;
        }
        if (self.outcome) |outcome| {
            self.outcome = null;
            self.response = outcome catch {
                self.ended = true;
                return .failed;
            };
            const response = self.response.?.response;
            if (response.body) |body| if (body.pipe) |pipe| {
                self.pipe = pipe;
                pipe.consumer = .{ .context = self, .notify = bytesReady };
            };
            return .{ .headers = response };
        }
        if (self.pipe) |pipe| {
            if (pipe.hasBytes()) {
                const bytes = try pipe.take();
                self.chunk = bytes;
                self.chunk_allocator = pipe.allocator;
                return .{ .bytes = bytes };
            }
            switch (pipe.state) {
                .open => return null,
                .closed => {
                    self.ended = true;
                    return .eof;
                },
                .errored => {
                    self.ended = true;
                    return .failed;
                },
            }
        }
        if (self.response) |response| {
            if (!self.sent_buffer) {
                self.sent_buffer = true;
                if (response.response.body) |body| return .{ .bytes = body.getBytes() };
            }
            self.ended = true;
            return .eof;
        }
        return null;
    }
    pub fn stop(self: *Resource) void {
        if (self.pipe) |pipe| pipe.consumer = null;
        self.pipe = null;
        if (self.active) |active| {
            self.active = null;
            active.terminate();
        }
        if (self.outcome) |outcome| {
            self.outcome = null;
            if (outcome) |value| {
                var result = value;
                result.deinit();
            } else |_| {}
        }
        if (self.response) |*result| result.deinit();
        self.response = null;
        if (self.chunk) |bytes| self.chunk_allocator.?.free(bytes);
        self.chunk = null;
        self.ended = true;
    }
};

/// Pending activity belongs to an element, not to its realm's global. The
/// native owner record outlives forced instance teardown until every task and
/// stable-state continuation has completed or dropped.
pub const Activity = struct {
    allocator: std.mem.Allocator,
    instance: ?*runtime.Instance,
    owner: *anyopaque,
    run: *const fn (*anyopaque, *Task) void,
    abort: *const fn (*anyopaque) void,
    free: *const fn (*anyopaque) void,
    head: ?*Task = null,
    tail: ?*Task = null,
    microtasks: std.ArrayList(*StableContinuation) = .empty,
    running_stable: usize = 0,
    fetching: bool = false,

    pub fn sync(self: *Activity) void {
        const instance = self.instance orelse return;
        if (self.fetching or self.head != null or self.microtasks.items.len != 0 or self.running_stable != 0)
            engine.keepPlatformObjectAlive(instance)
        else
            engine.releasePlatformObject(instance);
    }
    /// HTML await-a-stable-state steps 1–2: enqueue one synchronous section.
    /// The fulfilled reaction uses the engine's FIFO microtask queue and its
    /// drop contract also releases the continuation if the realm ends.
    pub fn stable(self: *Activity, generation: u64, callback: *const fn (*anyopaque, u64) void) !void {
        const instance = self.instance orelse return error.InvalidStateError;
        const realm = instance.ctx;
        const continuation = try self.allocator.create(StableContinuation);
        continuation.* = .{
            .activity = self,
            .realm = realm,
            .instance_generation = runtime.SlabAllocator.generationOf(instance),
            .generation = generation,
            .callback = callback,
        };
        errdefer self.allocator.destroy(continuation);
        try self.microtasks.append(self.allocator, continuation);
        self.sync();
        errdefer {
            continuation.unlink();
            self.sync();
        }
        try engine.queueResolvedPromiseReaction(realm, &StableContinuation.steps, continuation);
    }
    /// Whether this resource selection already has a pending stable section.
    pub fn hasStable(self: *const Activity, generation: u64) bool {
        for (self.microtasks.items) |continuation| if (continuation.generation == generation) return true;
        return false;
    }
    pub fn queue(self: *Activity, kind: u16, generation: u64, target: ?*runtime.Instance, name: ?[]const u8) !void {
        const instance = self.instance orelse return error.InvalidStateError;
        const event = if (name) |event_name| try Event.init(target orelse instance, event_name) else null;
        return self.queuePrepared(kind, generation, event, null, null, true);
    }
    pub fn queueIndependent(self: *Activity, kind: u16, target: ?*runtime.Instance, name: ?[]const u8) !void {
        const instance = self.instance orelse return error.InvalidStateError;
        const event = if (name) |event_name| try Event.init(target orelse instance, event_name) else null;
        return self.queuePrepared(kind, 0, event, null, null, false);
    }
    pub fn queueTrack(self: *Activity, kind: u16, generation: u64, target: *runtime.Instance, name: []const u8, track: *runtime.Instance) !void {
        return self.queuePrepared(kind, generation, try Event.track(target, name, track), null, null, false);
    }
    pub fn queuePlay(self: *Activity, kind: u16, generation: u64, name: []const u8, promises: *std.ArrayList(engine.PromiseCapability), rejection: []const u8) !void {
        const instance = self.instance orelse return error.InvalidStateError;
        return self.queuePrepared(kind, generation, try Event.init(instance, name), promises, rejection, true);
    }
    fn queuePrepared(self: *Activity, kind: u16, generation: u64, event: ?Event, promises: ?*std.ArrayList(engine.PromiseCapability), rejection: ?[]const u8, resource_bound: bool) !void {
        errdefer if (event) |value| value.deinit();
        const instance = self.instance orelse return error.InvalidStateError;
        // Check before moving promises: this call may synchronously DROP an
        // enqueued task on allocation failure, so callers never get its pointer.
        _ = instance.ctx.getOptionalEventLoop() orelse return error.NotSupported;
        const task = try self.allocator.create(Task);
        task.* = .{ .activity = self, .kind = kind, .generation = generation, .event = event, .previous = self.tail, .rejection = rejection, .resource_bound = resource_bound };
        if (promises) |pending| {
            task.promises = pending.*;
            pending.* = .empty;
        }
        if (self.tail) |tail| tail.next = task else self.head = task;
        self.tail = task;
        self.sync();
        queueTask(instance, Task.run, task, Task.drop) catch unreachable;
    }
    /// Load algorithm steps 3–5: immediately settle promises from queued tasks
    /// in their original order, then discard the tasks' remaining behavior.
    pub fn discardTasks(self: *Activity, settle: bool) void {
        var cursor = self.head;
        while (cursor) |task| : (cursor = task.next) {
            if (settle and !task.resource_bound) continue;
            if (settle) task.rejectPromises(task.rejection orelse "AbortError");
            task.cancelled = true;
        }
    }
    /// Queued tasks and continuations retain the owner after its element ends.
    pub fn detach(self: *Activity) void {
        const instance = self.instance;
        self.instance = null;
        if (instance) |object| engine.releasePlatformObject(object);
    }
    pub fn maybeFree(self: *Activity) void {
        if (self.instance == null and self.head == null and self.microtasks.items.len == 0 and self.running_stable == 0) self.free(self.owner);
    }
};

/// Independently owned identity for a queued stable section. An element's slab
/// slot may be reused while this record remains in the engine's queue.
const StableContinuation = struct {
    activity: *Activity,
    realm: runtime.Context,
    instance_generation: u64,
    generation: u64,
    callback: *const fn (*anyopaque, u64) void,

    const steps: engine.PromiseReactionSteps = .{ .fulfilled = fulfilled, .dropped = dropped };

    fn unlink(self: *StableContinuation) void {
        for (self.activity.microtasks.items, 0..) |entry, index| {
            if (entry == self) {
                _ = self.activity.microtasks.orderedRemove(index);
                return;
            }
        }
        unreachable;
    }

    fn alive(self: *const StableContinuation) bool {
        const instance = self.activity.instance orelse return false;
        return self.realm.hasEngine() and
            runtime.SlabAllocator.generationOf(instance) == self.instance_generation and
            !runtime.instance_lifecycle.isCleanupStarted(instance);
    }

    fn begin(self: *StableContinuation) void {
        self.activity.running_stable += 1;
        self.unlink();
    }

    fn finish(self: *StableContinuation) void {
        // Owner code may have retired the realm. Nothing after it returns
        // may read the captured realm or element; the Activity alone survives.
        const activity = self.activity;
        activity.allocator.destroy(self);
        activity.running_stable -= 1;
        activity.sync();
        activity.maybeFree();
    }

    fn fulfilled(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *StableContinuation = @ptrCast(@alignCast(data.?));
        self.begin();
        defer self.finish();
        if (!self.alive()) return;
        // Promise reactions enter their registered realm. A second realm scope
        // would itself outlive forced retirement from inside the callback.
        self.callback(self.activity.owner, self.generation);
    }

    fn dropped(data: ?*anyopaque) void {
        const self: *StableContinuation = @ptrCast(@alignCast(data.?));
        self.begin();
        defer self.finish();
        if (self.alive()) self.activity.abort(self.activity.owner);
    }
};

pub const Task = struct {
    activity: *Activity,
    kind: u16,
    generation: u64,
    previous: ?*Task = null,
    next: ?*Task = null,
    cancelled: bool = false,
    resource_bound: bool = true,
    event: ?Event = null,
    promises: std.ArrayList(engine.PromiseCapability) = .empty,
    rejection: ?[]const u8 = null,

    pub fn rejectPromises(self: *Task, name: []const u8) void {
        if (self.promises.items.len == 0) return;
        if (self.activity.instance) |instance| {
            if (engine.createDOMException(instance.ctx, name, "")) |exception| {
                defer exception.release();
                for (self.promises.items) |*promise| engine.rejectPromise(promise, exception.value) catch {};
            } else |_| {}
        }
        self.releasePromises();
    }
    fn releasePromises(self: *Task) void {
        for (self.promises.items) |*promise| engine.releasePromiseCapability(promise);
        self.promises.deinit(self.activity.allocator);
        self.promises = .empty;
    }
    fn run(context: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(context.?));
        defer self.finish();
        const instance = self.activity.instance orelse return;
        if (self.cancelled) return;
        engine.runTaskInRealm(instance.ctx, steps, self) catch self.activity.abort(self.activity.owner);
    }
    fn steps(context: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(context.?));
        if (self.cancelled or self.activity.instance == null) return;
        self.activity.run(self.activity.owner, self);
    }
    fn drop(context: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(context.?));
        self.activity.abort(self.activity.owner);
        self.finish();
    }
    fn unlink(self: *Task) void {
        if (self.previous) |previous| previous.next = self.next else self.activity.head = self.next;
        if (self.next) |next| next.previous = self.previous else self.activity.tail = self.previous;
    }
    fn finish(self: *Task) void {
        const activity = self.activity;
        if (self.event) |event| event.deinit();
        self.releasePromises();
        self.unlink();
        activity.allocator.destroy(self);
        activity.sync();
        activity.maybeFree();
    }
};
