//! Create Fetch Event and Dispatch, on the service worker's thread (Service
//! Workers Appendix A, from step 17.4), and FetchEvent's respondWith()
//! steps (4.6.7): the event made and dispatched at the worker's global, the
//! answer Handle Fetch waits for - a response, a network error, or nothing -
//! handed to the fetch's call, its `handled` promise settled, and a
//! response's body read from its stream into the relay the fetching thread
//! drains.
//!
//! What crosses threads here is the call (service_worker_fetch.Call) and a
//! body's relay: the response handed back is a copy of the Response
//! object's response made with the Browser's allocator, its body null - the
//! bytes follow through the relay.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#create-fetch-event-and-dispatch
//! Spec: https://w3c.github.io/ServiceWorker/#fetch-event-respondwith

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const fetch = @import("fetch");
const manager_mod = @import("manager.zig");
const ExtendLifetime = @import("extend_lifetime.zig").ExtendLifetime;

const Manager = manager_mod.Manager;
const FetchDispatch = manager_mod.FetchDispatch;
const service_worker_fetch = fetch.internal.service_worker_fetch;
const Call = service_worker_fetch.Call;
const BodyRelay = service_worker_fetch.BodyRelay;
const InternalRequest = fetch.internal.InternalRequest;
const InternalResponse = fetch.internal.InternalResponse;

const log = std.log.scoped(.service_worker);

/// What the user agent's FetchEvent is made with (FetchEvent's
/// construction argument `fetch`). BORROWED for the construction.
pub const FetchEventInit = struct {
    /// The Request object (17.4.3).
    request: *runtime.Instance,
    client_id: []const u8,
    resulting_client_id: []const u8,
    replaces_client_id: []const u8,
    /// 17.4.7: preloadResponse - a promise resolved with undefined (no
    /// navigation preload).
    preload_response: runtime.JSValue,
    /// 17.4.11: handled - eventHandled.
    handled: runtime.JSValue,
    /// What respondWith() answers; the event takes a reference.
    responder: *Responder,
};

/// The fetch a user agent's FetchEvent answers: Handle Fetch's call, the
/// event's handled promise, and the flags respondWith() sets. Reference
/// counted on the worker's thread: the dispatcher, the event, and a
/// respondWith() reaction each hold one.
pub const Responder = struct {
    /// The realm's.
    allocator: Allocator,
    refs: u32 = 1,
    manager: *Manager,
    realm: runtime.Context,
    /// The service worker side's reference, until the answer is given.
    call: ?*Call,
    /// eventHandled (17.2), until it is settled.
    handled: ?engine.PromiseCapability,
    /// The event's respond-with entered flag.
    respond_with_entered: bool = false,
    /// The event's wait to respond flag.
    wait_to_respond: bool = false,

    pub fn retain(self: *Responder) *Responder {
        self.refs += 1;
        return self;
    }

    pub fn release(self: *Responder) void {
        self.refs -= 1;
        if (self.refs > 0) return;
        // An answer never given (the realm ended first): handleFetchFailed.
        self.answer(.network_error);
        if (self.handled) |*capability| engine.releasePromiseCapability(capability);
        self.handled = null;
        self.allocator.destroy(self);
    }

    /// Handle Fetch's answer, once.
    fn answer(self: *Responder, value: Call.Answer) void {
        const call = self.call orelse return service_worker_fetch.freeAnswer(value);
        self.call = null;
        call.answer(value);
        call.release();
    }

    /// Steps 21.1.1 and 22.1 (rejected: a "NetworkError" DOMException) or
    /// 21.2 and 23 (resolved) for eventHandled, once.
    fn settleHandled(self: *Responder, resolved: bool) void {
        var capability = self.handled orelse return;
        self.handled = null;
        defer engine.releasePromiseCapability(&capability);
        if (resolved) {
            engine.resolvePromise(&capability, runtime.JSValue.jsUndefined) catch {};
            return;
        }
        const exception = engine.createDOMException(self.realm, "NetworkError", "The fetch event was not answered with a response") catch return;
        defer exception.release();
        engine.rejectPromise(&capability, exception.value) catch {};
    }

    /// Steps 21-23 once the task that dispatched the event has: an event
    /// respondWith() was not called on answers now - a network error when
    /// it was canceled, nothing (the network) otherwise. One it was called
    /// on is answered by its reaction.
    pub fn dispatchEnded(self: *Responder, canceled: bool) void {
        if (self.respond_with_entered) return;
        if (canceled) {
            self.settleHandled(false);
            return self.answer(.network_error);
        }
        self.settleHandled(true);
        self.answer(.fallback);
    }

    /// respondWith() steps 6-10, the caller having run 1-5: the flags, and
    /// the reactions to `r` (a promise in `realm`).
    pub fn respondWith(self: *Responder, realm: runtime.Context, r: runtime.JSValue) !void {
        // 6-7.
        self.respond_with_entered = true;
        self.wait_to_respond = true;
        const completion = try engine.promiseResolve(realm, r);
        const promise = switch (completion) {
            .normal => |owned| owned,
            .throw => |thrown| {
                thrown.release();
                return self.respondWithFailed();
            },
        };
        defer promise.release();
        engine.reactToPromise(realm, promise.borrow(), &respond_steps, self.retain()) catch |err| {
            self.release();
            return err;
        };
    }

    const respond_steps: engine.PromiseReactionSteps = .{
        .fulfilled = fulfilled,
        .rejected = rejected,
        .dropped = dropped,
    };

    /// 9: upon rejection of r - the respond-with error flag: a network
    /// error (step 22).
    fn rejected(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *Responder = @ptrCast(@alignCast(data.?));
        defer self.release();
        self.respondWithFailed();
    }

    fn dropped(data: ?*anyopaque) void {
        const self: *Responder = @ptrCast(@alignCast(data.?));
        self.release();
    }

    fn respondWithFailed(self: *Responder) void {
        self.wait_to_respond = false;
        self.settleHandled(false);
        self.answer(.network_error);
    }

    /// 10: upon fulfillment of r with `value`.
    fn fulfilled(data: ?*anyopaque, value: runtime.JSValue) void {
        const self: *Responder = @ptrCast(@alignCast(data.?));
        defer self.release();
        self.respondWithResponse(value) catch |err| {
            log.debug("respondWith(): {s}", .{@errorName(err)});
            self.respondWithFailed();
        };
    }

    /// 10.1-10.3: a Response object's response, copied (its body read into a
    /// relay as it comes), is the potential response.
    fn respondWithResponse(self: *Responder, value: runtime.JSValue) !void {
        const realm = self.realm;
        // 10.1. Not a Response object: the respond-with error flag.
        const object = engine.convertToPlatformObject(realm, value) orelse return error.TypeError;
        if (object.stateAs(interfaces.Response.State) == null) return error.TypeError;
        // A body already read, or locked, cannot be read for the fetch
        // (Chromium answers a network error: "body used").
        if (try interfaces.Response.get_bodyUsed(object)) return error.TypeError;
        const stream = try interfaces.Response.get_body(object);
        if (stream) |s| if (try interfaces.ReadableStream.get_locked(s)) return error.TypeError;
        const inner: *InternalResponse = @ptrCast(@alignCast(dom.fetch_objects.responseOf(object) orelse return error.TypeError));
        // 10.2.4. potentialResponse: a copy of the response, but its body.
        const allocator = self.manager.allocator;
        const copy = try potentialResponse(allocator, inner);
        errdefer copy.deinit();
        // An opaque response's body is its internal response's, which script
        // cannot read (the Response's body is null): it is copied as the
        // associated response is, from Zig.
        const internal_body: ?*fetch.internal.Body = if (isOpaque(inner)) (inner.internal orelse inner).body else null;
        // 10.2.5.2's body info: a body whose bytes are all here already
        // (a constructed response's) has its sizes now - the fetching side
        // reports its timing when the response is handed over, before a
        // body still arriving is known.
        if (internal_body orelse inner.body) |b| if (b.pipe == null and (b.source != .none or b.data.items.len > 0)) {
            copy.body_info.encoded_size = b.getBytes().len;
            copy.body_info.decoded_size = b.getBytes().len;
        };
        // 10.2.5. Its body: read from the body's stream, chunk by chunk.
        const has_body = stream != null or internal_body != null;
        const relay: ?*BodyRelay = if (has_body) try BodyRelay.create(allocator) else null;
        errdefer if (relay) |r| {
            r.release();
            r.release();
        };
        if (internal_body) |body| {
            try InternalBodyPump.start(body, relay.?);
        } else if (stream) |s| try BodyPump.start(realm, s, relay.?);
        // 10.3, then Handle Fetch step 23: the response, and eventHandled
        // resolved.
        self.wait_to_respond = false;
        self.answer(.{ .response = .{ .response = copy, .body = relay } });
        self.settleHandled(true);
    }
};

fn isOpaque(response: *const InternalResponse) bool {
    return response.response_type == .@"opaque" or response.response_type == .opaqueredirect;
}

/// respondWith() step 10.2.4's potentialResponse for the Response object
/// whose response is `inner`: a copy of it but its body. An opaque or
/// opaque-redirect filtered response is copied with its internal
/// response's fields (InternalResponse.internal) and marked with its
/// filter, as main fetch hands one on: the fetching side reads the internal
/// response - a script element its status and body - and applies the filter
/// where script reads it. OWNED by the caller.
pub fn potentialResponse(allocator: Allocator, inner: *const InternalResponse) Allocator.Error!*InternalResponse {
    const source = if (isOpaque(inner)) inner.internal orelse inner else inner;
    const copy = try copyResponse(allocator, source);
    copy.response_type = inner.response_type;
    return copy;
}

/// A copy of `from`'s response but its body (respondWith() step 10.2.4),
/// made with `allocator` - the Browser's: it crosses to the fetching thread.
pub fn copyResponse(allocator: Allocator, from: *const InternalResponse) Allocator.Error!*InternalResponse {
    const copy = try InternalResponse.init(allocator);
    errdefer copy.deinit();
    copy.response_type = from.response_type;
    copy.status = from.status;
    if (from.status_message.len > 0) try copy.setStatusMessage(from.status_message);
    copy.header_list.deinit();
    copy.header_list = try from.header_list.clone(allocator);
    for (from.url_list.items) |url| try copy.addUrl(url);
    for (from.cors_exposed_header_name_list.items) |name| {
        const owned = try allocator.dupe(u8, name);
        copy.cors_exposed_header_name_list.append(allocator, owned) catch |err| {
            allocator.free(owned);
            return err;
        };
    }
    copy.cache_state = from.cache_state;
    copy.range_requested = from.range_requested;
    copy.request_includes_credentials = from.request_includes_credentials;
    copy.timing_allow_passed = from.timing_allow_passed;
    copy.body_info = from.body_info;
    copy.redirect_taint = from.redirect_taint;
    copy.aborted = from.aborted;
    return copy;
}

/// respondWith() step 10.2.5's reading of the response's body, in the
/// worker's realm: one read in flight at a time, each chunk written to the
/// relay - the observable equivalent of piping the body into the potential
/// response's. The relay's reader gone (the fetch ended), the stream is
/// canceled.
const BodyPump = struct {
    realm: runtime.Context,
    /// The writer's reference.
    relay: *BodyRelay,
    reader: *runtime.Instance,
    /// Keeps the reader (and through it the stream) alive.
    reader_hold: engine.Owned,

    fn start(realm: runtime.Context, stream: *runtime.Instance, relay: *BodyRelay) !void {
        // 10.2.5.1. A reader of the body's stream.
        const reader = switch (try interfaces.ReadableStream.call_getReader(stream, @import("webidl").Opt(@import("dictionaries").ReadableStreamGetReaderOptions).notPassed())) {
            .readable_stream_default_reader => |r| r,
            .readable_stream_byobreader => |r| r,
        };
        const hold = try engine.retainValue(realm, runtime.JSValue.fromInstance(reader));
        errdefer hold.release();
        const self = try realm.allocator.create(BodyPump);
        self.* = .{ .realm = realm, .relay = relay, .reader = reader, .reader_hold = hold };
        self.read();
    }

    /// 10.2.5.2.2: read a chunk.
    fn read(self: *BodyPump) void {
        const promise = interfaces.ReadableStreamDefaultReader.call_read(self.reader) catch {
            return self.finish(.errored);
        };
        const owned: engine.Owned = .{ .value = promise };
        defer owned.release();
        engine.reactToPromise(self.realm, promise, &read_steps, self) catch self.finish(.errored);
    }

    const read_steps: engine.PromiseReactionSteps = .{
        .fulfilled = chunkRead,
        .rejected = readFailed,
        .dropped = readDropped,
    };

    fn chunkRead(data: ?*anyopaque, value: runtime.JSValue) void {
        const self: *BodyPump = @ptrCast(@alignCast(data.?));
        const realm = self.realm;
        const done = engine.getProperty(realm, value, "done") catch return self.finish(.errored);
        defer done.release();
        // Close steps: end-of-body.
        if (engine.toBoolean(realm, done.value)) return self.finish(.closed);
        const chunk = engine.getProperty(realm, value, "value") catch return self.finish(.errored);
        defer chunk.release();
        // Chunk steps: the chunk's bytes (a Uint8Array; anything else errors
        // the body - Chromium's "not a Uint8Array" network error).
        const bytes = (engine.getCopyOfBufferSourceBytes(realm, chunk.value, realm.allocator) catch return self.finish(.errored)) orelse return self.finish(.errored);
        defer realm.allocator.free(bytes);
        if (!self.relay.write(bytes)) {
            // Nobody reads the body any more: cancel the stream.
            const canceled = interfaces.ReadableStreamDefaultReader.call_cancel(self.reader, @import("webidl").Opt(runtime.JSValue).notPassed()) catch null;
            if (canceled) |c| {
                const held: engine.Owned = .{ .value = c };
                engine.markPromiseAsHandled(realm, c);
                held.release();
            }
            return self.finish(.cancelled);
        }
        self.read();
    }

    /// Error steps: the body errors.
    fn readFailed(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *BodyPump = @ptrCast(@alignCast(data.?));
        self.finish(.errored);
    }

    /// The realm ended with a read pending: the body fails.
    fn readDropped(data: ?*anyopaque) void {
        const self: *BodyPump = @ptrCast(@alignCast(data.?));
        self.finish(.errored);
    }

    fn finish(self: *BodyPump, end: enum { closed, errored, cancelled }) void {
        switch (end) {
            .closed => self.relay.close(),
            .errored => self.relay.fail(),
            .cancelled => {},
        }
        self.relay.release();
        self.reader_hold.release();
        self.realm.allocator.destroy(self);
    }
};

/// An opaque response's internal body, written to the relay on the worker's
/// thread: its bytes at once, or - still arriving from the network - as its
/// pipe hears of them, through a reader of its own (a tee).
const InternalBodyPump = struct {
    allocator: Allocator,
    relay: *BodyRelay,
    pipe: *fetch.internal.BodyPipe,

    fn start(body: *fetch.internal.Body, relay: *BodyRelay) !void {
        const pipe = body.pipe orelse {
            _ = relay.write(body.getBytes());
            relay.close();
            relay.release();
            return;
        };
        const branch = try pipe.tee();
        const self = body.allocator.create(InternalBodyPump) catch |err| {
            branch.release();
            return err;
        };
        self.* = .{ .allocator = body.allocator, .relay = relay, .pipe = branch };
        branch.consumer = .{ .context = self, .notify = notify };
        // What it holds already.
        notify(self);
    }

    fn notify(context: *anyopaque) void {
        const self: *InternalBodyPump = @ptrCast(@alignCast(context));
        if (self.pipe.hasBytes()) {
            const bytes = self.pipe.take() catch return self.finish(false);
            defer self.allocator.free(bytes);
            if (!self.relay.write(bytes)) return self.finish(false);
        }
        switch (self.pipe.state) {
            .open => {},
            .closed => self.finish(true),
            .errored => self.finish(false),
        }
    }

    fn finish(self: *InternalBodyPump, closed: bool) void {
        if (closed) self.relay.close() else self.relay.fail();
        self.relay.release();
        self.pipe.consumer = null;
        self.pipe.release();
        self.allocator.destroy(self);
    }
};

/// What a fetch event's end reports.
pub const FetchDone = struct {
    manager: *Manager,
    worker_id: u64,
    generation: u64,
    /// The registration to soft-update once the event is done (0: none).
    soft_update: u64 = 0,

    pub fn report(self: FetchDone) void {
        self.manager.report(.{ .fetch_done = .{ .worker = self.worker_id, .generation = self.generation, .soft_update = self.soft_update } });
    }
};

/// The extended lifetime's settled callback: the event is no longer active.
const FetchSettled = struct {
    done: FetchDone,

    fn run(ctx: *anyopaque, _: bool) void {
        const self: *FetchSettled = @ptrCast(@alignCast(ctx));
        const done = self.done;
        done.manager.allocator.destroy(self);
        done.report();
    }

    fn drop(ctx: *anyopaque) void {
        const self: *FetchSettled = @ptrCast(@alignCast(ctx));
        const done = self.done;
        done.manager.allocator.destroy(self);
        done.report();
    }
};

/// Create Fetch Event and Dispatch steps 17.4.1-17.4.15 and 18-23, on the
/// worker's thread, in its realm, for `dispatch` (taken): the event made
/// and dispatched at `global_scope`, its answer given to the dispatch's
/// call, its end reported through `done` once it is no longer active.
pub fn fire(manager: *Manager, realm: runtime.Context, global_scope: *runtime.Instance, dispatch: *FetchDispatch, done: FetchDone) void {
    defer dispatch.destroy();
    // Fetch gave up on it (its fetch ended): no event.
    if (dispatch.call.isAbandoned()) return done.report();
    fireEvent(manager, realm, global_scope, dispatch, done) catch |err| {
        log.debug("a fetch event was not fired: {s}", .{@errorName(err)});
    };
}

fn fireEvent(manager: *Manager, realm: runtime.Context, global_scope: *runtime.Instance, dispatch: *FetchDispatch, done: FetchDone) !void {
    // The responder answers the call from here; failures below answer it
    // with a network error (its last release).
    const responder = try realm.allocator.create(Responder);
    responder.* = .{
        .allocator = realm.allocator,
        .manager = manager,
        .realm = realm,
        // The responder's own reference: the dispatch lets go of its own.
        .call = dispatch.call.retain(),
        .handled = null,
    };
    defer responder.release();
    errdefer done.report();
    // 17.2. eventHandled: a new promise in workerRealm.
    responder.handled = try engine.createPromise(realm);
    // 17.4.3. requestObject: a Request object for the request, with a new
    // AbortController's signal (dom.fetch_objects' adopt makes one), its
    // Headers immutable.
    const request_copy = (try manager_mod.copyRequestForWorker(realm.allocator, dispatch.request)) orelse return error.OutOfMemory;
    const request_object = interfaces.Request.init(realm.allocator, realm) catch |err| {
        request_copy.deinit();
        return err;
    };
    const adopted = dom.fetch_objects.adoptRequest(request_object, request_copy, .immutable) catch |err| blk: {
        log.debug("a fetch event's request: {s}", .{@errorName(err)});
        break :blk false;
    };
    if (!adopted) {
        request_copy.deinit();
        request_object.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(request_object));
        return error.InvalidStateError;
    }
    const request_hold = try engine.retainValue(realm, runtime.JSValue.fromInstance(request_object));
    defer request_hold.release();
    // 17.4.7. preloadResponse: resolved with undefined.
    const preload = try engine.createResolvedPromise(realm, runtime.JSValue.jsUndefined);
    defer preload.release();
    const handled_promise = responder.handled.?.promise;

    const settled = try manager.allocator.create(FetchSettled);
    settled.* = .{ .done = done };
    const lifetime = ExtendLifetime.create(realm.allocator, .{ .ctx = settled, .run = FetchSettled.run, .drop = FetchSettled.drop }) catch |err| {
        manager.allocator.destroy(settled);
        return err;
    };
    // The dispatcher's reference. From here the lifetime reports the end.
    defer lifetime.release();
    var client_id_buffer: [36]u8 = undefined;
    var resulting_buffer: [36]u8 = undefined;
    const client_id: []const u8 = if (dispatch.client_id) |id| blk: {
        client_id_buffer = id;
        break :blk &client_id_buffer;
    } else "";
    const resulting_client_id: []const u8 = if (dispatch.resulting_client_id) |id| blk: {
        resulting_buffer = id;
        break :blk &resulting_buffer;
    } else "";
    // 17.4.1-17.4.11. e: a FetchEvent named fetch, cancelable, with its
    // request, preloadResponse, client ids and handled.
    const instance = interfaces.FetchEvent.initWith(realm.allocator, realm, .{
        .lifetime = lifetime,
        .fetch = FetchEventInit{
            .request = request_object,
            .client_id = client_id,
            .resulting_client_id = resulting_client_id,
            .replaces_client_id = if (dispatch.request.isNavigationRequest()) dispatch.replaces_client_id else "",
            .preload_response = preload.value,
            .handled = handled_promise,
            .responder = responder,
        },
    }) catch |err| {
        log.debug("no fetch event: {s}", .{@errorName(err)});
        lifetime.dispatchEnded();
        return;
    };
    const generation = runtime.SlabAllocator.generationOf(instance);
    defer instance.releaseIfUnwrapped(generation);
    dom.event_construction.innerEventCreationSteps(instance, runtime.DOMString.initInterned("fetch"), dom.event_construction.eventInitFrom(@import("dictionaries").EventInit{ .cancelable = true })) catch |err| {
        log.debug("no fetch event: {s}", .{@errorName(err)});
        lifetime.dispatchEnded();
        return;
    };
    lifetime.dispatching = true;
    // 17.4.13. Dispatch e at activeWorker's global object.
    _ = dom.fire_event.dispatchTrusted(global_scope, instance) catch {};
    // 17.4.14. Update Service Worker Extended Events Set.
    lifetime.dispatchEnded();
    // 17.4.19, 18-23: the answer, unless respondWith() waits for its own.
    const canceled = interfaces.Event.get_defaultPrevented(instance) catch false;
    responder.dispatchEnded(canceled);
}
