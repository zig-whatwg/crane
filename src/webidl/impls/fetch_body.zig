//! Fetch "extract a body" (§5.2 BodyInit unions), for the Request and
//! Response constructors.
//!
//! The binding has already sorted a BodyInit by what the value is (WebIDL
//! §3.2.24, `conv.convertBodyInit`); this takes each kind's bytes and type:
//!
//!   ReadableStream   the stream itself is the body; no type
//!   Blob             its bytes; its type, if not empty
//!   BufferSource     a copy of its bytes; no type
//!   FormData         its multipart/form-data encoding; multipart/form-data
//!                    with the boundary
//!   URLSearchParams  its application/x-www-form-urlencoded serialization
//!   USVString        its UTF-8 encoding; text/plain;charset=UTF-8
//!
//! Every kind but a stream becomes a body of bytes here - the spec's stream
//! of them is made when script asks for it (`Response.body`), from those
//! bytes, which is the same stream: nothing can read or disturb it before.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const fetch = @import("fetch");
const blob_bytes = @import("dom").blob_bytes;
const srd = @import("streams_readable.zig");
const js = @import("streams_js.zig");
const engine = @import("engine");
const same_object = @import("same_object.zig");
const BodyPipe = fetch.internal.BodyPipe;

pub const Error = error{ TypeError, OutOfMemory };

/// An abort's reason, held for a body that fails with it - what
/// body_pipe.Failure's opaque `reason` is when fetch() is aborted: the value
/// and its realm, released with the body's source (`release`).
pub const AbortReason = struct {
    /// Owned.
    value: js.Value,
    allocator: std.mem.Allocator,

    /// Hold `reason` (BORROWED) in `realm`; null when it cannot be held.
    pub fn create(realm: runtime.Context, reason: runtime.JSValue) ?*AbortReason {
        const held = engine.retainValue(realm, reason) catch return null;
        const self = realm.allocator.create(AbortReason) catch {
            held.release();
            return null;
        };
        self.* = .{ .value = .{ .value = held.take(), .realm = realm }, .allocator = realm.allocator };
        return self;
    }

    /// body_pipe.Failure's `release_reason`.
    pub fn release(reason: *anyopaque) void {
        const self: *AbortReason = @ptrCast(@alignCast(reason));
        js.dispose(self.value);
        self.allocator.destroy(self);
    }
};

/// A body with type: the body, and the value for Content-Type, if any.
pub const Extracted = struct {
    allocator: std.mem.Allocator,
    /// The body's bytes, for every kind but a ReadableStream. Owned until
    /// taken.
    body: ?*fetch.internal.Body = null,
    /// The ReadableStream object given as the body: the body's stream IS
    /// this object. Not owned - the caller's wrapper holds it.
    stream: ?*runtime.Instance = null,
    /// The body's type, owned, or null.
    content_type: ?[]u8 = null,

    pub fn deinit(self: *Extracted) void {
        if (self.body) |b| b.deinit();
        if (self.content_type) |t| self.allocator.free(t);
        self.* = undefined;
    }

    /// The body, which is the caller's from here.
    pub fn takeBody(self: *Extracted) ?*fetch.internal.Body {
        const b = self.body;
        self.body = null;
        return b;
    }
};

/// Fetch "extract a body" from `object`, with `keepalive` (default false).
pub fn extract(allocator: std.mem.Allocator, object: typedefs.BodyInit, keepalive: bool) Error!Extracted {
    var result: Extracted = .{ .allocator = allocator };
    errdefer result.deinit();
    switch (object) {
        // ReadableStream: if keepalive is true, throw a TypeError; if object
        // is disturbed or locked, throw a TypeError. The body's stream is
        // object.
        .readable_stream => |stream| {
            if (keepalive) return error.TypeError;
            const slots = srd.streamOf(stream) orelse return error.TypeError;
            if (slots.disturbed or srd.isLocked(slots)) return error.TypeError;
            result.stream = stream;
            result.body = try fetch.internal.Body.fromSource(allocator, .none, null);
        },
        .xmlhttp_request_body_init => |inner| switch (inner) {
            // Blob: source is object, length its size, type its type if not
            // empty.
            .blob => |blob| {
                const bytes = blob_bytes.bytesOf(blob) orelse &.{};
                result.body = try fetch.internal.Body.fromBytes(allocator, bytes);
                var blob_type = interfaces.Blob.get_type(blob) catch return error.OutOfMemory;
                defer blob_type.deinit(blob.ctx.allocator);
                const type_bytes = blob_type.asSlice();
                if (type_bytes.len > 0) result.content_type = try allocator.dupe(u8, type_bytes);
            },
            // BufferSource: source is a copy of the bytes held by object. The
            // binding copied them (convertBodyInit); this is the copy the
            // body keeps.
            .buffer_source => |source| {
                const bytes = source.asBytes() catch &[_]u8{};
                result.body = try fetch.internal.Body.fromBytes(allocator, bytes);
            },
            // FormData: its multipart/form-data encoding, and that type with
            // the boundary the encoding used.
            .form_data => |form| {
                const boundary = multipartBoundary();
                const encoded = try encodeMultipart(allocator, form, &boundary);
                defer allocator.free(encoded);
                result.body = try fetch.internal.Body.fromBytes(allocator, encoded);
                result.content_type = try std.fmt.allocPrint(allocator, "multipart/form-data; boundary={s}", .{&boundary});
            },
            // URLSearchParams: the application/x-www-form-urlencoded
            // serializer over its list.
            .urlsearch_params => |params| {
                const serialized = interfaces.URLSearchParams.serialize(params) catch return error.OutOfMemory;
                defer if (serialized.len > 0) params.ctx.allocator.free(serialized);
                result.body = try fetch.internal.Body.fromBytes(allocator, serialized);
                result.content_type = try allocator.dupe(u8, "application/x-www-form-urlencoded;charset=UTF-8");
            },
            // Scalar value string: its UTF-8 encoding.
            .usvstring => |text| {
                result.body = try fetch.internal.Body.fromBytes(allocator, text);
                result.content_type = try allocator.dupe(u8, "text/plain;charset=UTF-8");
            },
        },
    }
    return result;
}

// =============================================================================
// The Body mixin (§5.3), for Request and Response
// =============================================================================

pub const Method = enum { array_buffer, blob, bytes, form_data, json, text };

/// What the Body mixin's steps need of a Request or Response object.
///
/// A body is bytes, or a pipe the network fills (a response fetch() made),
/// or a ReadableStream script gave it; its stream - Fetch's "body's
/// stream" - is made when script first asks (`bodyStream`), from the pipe
/// or the bytes, since nothing can read or disturb it before. From then on
/// everything goes through the stream.
pub const Owner = struct {
    instance: *runtime.Instance,
    /// This object's body's stream, once made: the [SameObject] `body`
    /// (the generated state's `body`).
    stream: *?*runtime.Instance,
    /// Holds that stream's wrapper for as long as this object - see
    /// same_object.zig: `stream` is a pointer V8 cannot see.
    pin: *same_object.Pin,
    /// This object's body; null for a null body.
    body: ?*fetch.internal.Body,
    kind: *const Kind,

    pub const Kind = struct {
        /// The Owner of `instance`, asked again when a read finishes.
        of: *const fn (instance: *runtime.Instance) ?Owner,
        /// The method's own steps on a body that is its bytes (`body`'s
        /// data): the promise the method returns.
        steps: *const fn (instance: *runtime.Instance, method: Method) anyerror!runtime.JSValue,
        /// A reason consuming the body rejects with before anything else
        /// is looked at, owned - a Response's followed signal's abort
        /// reason.
        rejection: ?*const fn (instance: *runtime.Instance, realm: js.Realm) ?js.Value = null,
        /// Told of a stream just made for the body.
        made: ?*const fn (instance: *runtime.Instance, stream: *runtime.Instance) void = null,
    };
};

/// The `body` getter: this's body's stream, or null for a null body.
///
/// A body still arriving streams from its pipe; a body that is bytes becomes
/// a stream of them - a pipe that has already ended. Either way the stream
/// takes the bytes over.
pub fn bodyStream(o: Owner) !?*runtime.Instance {
    if (o.stream.*) |stream| return stream;
    const body = o.body orelse return null;
    const pipe = if (body.pipe) |p| p else blk: {
        const source = try fetch.internal.PipeSource.create(body.allocator);
        const p = source.branch() catch |err| {
            source.finish();
            return err;
        };
        source.push(body.data.items);
        source.finish();
        break :blk p;
    };
    body.pipe = null;

    const stream = try PipeStream.create(o.instance.ctx, pipe);
    o.stream.* = stream;
    o.pin.hold(stream);
    if (o.kind.made) |made| made(o.instance, stream);
    return stream;
}

/// The `bodyUsed` getter: this's body is non-null and its stream is
/// disturbed. A body whose stream was never made cannot have been.
pub fn bodyUsed(o: Owner) bool {
    const stream = o.stream.* orelse return false;
    const slots = srd.streamOf(stream) orelse return false;
    return slots.disturbed;
}

/// "Unusable": this's body is non-null and its stream is disturbed or
/// locked.
pub fn isUnusable(o: Owner) bool {
    const stream = o.stream.* orelse return false;
    const slots = srd.streamOf(stream) orelse return false;
    return slots.disturbed or srd.isLocked(slots);
}

/// "Clone a body", for `clone` - which has cloned the body itself (a pipe
/// still arriving is teed there): a stream already made is teed too, this
/// body reading the first branch and the clone the second.
pub fn cloneStream(o: Owner, clone: Owner) !void {
    const stream = o.stream.* orelse return;
    const realm = try js.Realm.of(o.instance);
    const branches = try srd.tee(realm, stream);
    o.pin.release();
    o.stream.* = branches[0];
    o.pin.hold(branches[0]);
    clone.stream.* = branches[1];
    clone.pin.hold(branches[1]);
}

/// Streams "create a proxy" for `input`'s body, as `target`'s body's
/// stream (the Request constructor's step 41.2). The proxy is `input`'s
/// stream piped through an identity transform, so from here `input`'s body
/// is locked, and disturbed (ReadableStreamPipeTo step 11 disturbs the
/// source at once). A tee stands in for the pipe: the first branch is
/// `target`'s stream, the second is cancelled - nobody reads it - and the
/// source is marked disturbed as the pipe would.
pub fn proxyInto(input: Owner, target: Owner) !void {
    const input_body = input.body orelse return;
    const stream = (try bodyStream(input)) orelse return;
    const realm = try js.Realm.of(input.instance);
    if (input_body.source != .none) {
        // A body of bytes: `target` has its own copy of them (the request
        // copy carried them), so nothing need flow through a pipe. `input`'s
        // stream is locked and disturbed, as piping it would leave it.
        const reader = try srd.acquireDefaultReader(realm, stream);
        _ = try realm.wrap(reader);
        if (srd.streamOf(stream)) |slots| slots.disturbed = true;
        return;
    }
    const branches = try srd.tee(realm, stream);
    if (srd.streamOf(stream)) |slots| slots.disturbed = true;
    target.pin.release();
    target.stream.* = branches[0];
    target.pin.hold(branches[0]);
    const reason = try realm.undefinedValue();
    defer js.dispose(reason);
    const cancelled = srd.cancel(realm, branches[1], reason) catch return;
    js.dispose(cancelled);
}

/// Read every byte of a request body's stream, for fetch() to send them:
/// Fetch's "transmit request body" reads the stream chunk by chunk, and
/// each chunk must be a Uint8Array.
///
/// Deviation: HTTP-network fetch would stream the bytes onto the wire as
/// they are read; here they are all read first and sent as one body, since
/// the network layer takes a body of bytes.
///
/// Every chunk is read from the last one's chunk steps (Streams "read
/// loop"), so a pending read is the only state: the stream's teardown drops
/// it (`drop`), which ends this too.
pub const ReadAll = struct {
    allocator: std.mem.Allocator,
    realm: js.Realm,
    reader: *runtime.Instance,
    bytes: std.ArrayListUnmanaged(u8) = .empty,
    context: *anyopaque,
    done: *const fn (context: *anyopaque, bytes: []const u8) void,
    /// The read failed - an errored stream, a chunk that is not a
    /// Uint8Array - or was dropped (the realm went). `e` is borrowed, null
    /// for a drop.
    failed: *const fn (context: *anyopaque, e: ?js.Value) void,
    /// `cancel` ran: nothing is reported, and this ends at the next step.
    cancelled: bool = false,

    const vtable = srd.ReadRequest.VTable{ .chunk = chunk, .close = close, .err = fail, .drop = drop };

    /// Acquire a reader for `stream`, to read it all from `begin` - kept
    /// apart so the caller can hold the pointer before a stream that has
    /// every chunk already reports, and frees this, inside the first read.
    pub fn start(
        allocator: std.mem.Allocator,
        realm: js.Realm,
        stream: *runtime.Instance,
        context: *anyopaque,
        done: *const fn (context: *anyopaque, bytes: []const u8) void,
        failed: *const fn (context: *anyopaque, e: ?js.Value) void,
    ) !*ReadAll {
        const reader = try srd.acquireDefaultReader(realm, stream);
        // Held through a Zig pointer: the wrapper cache keeps streams-graph
        // objects for the realm once they are wrapped.
        _ = try realm.wrap(reader);
        const self = try allocator.create(ReadAll);
        self.* = .{ .allocator = allocator, .realm = realm, .reader = reader, .context = context, .done = done, .failed = failed };
        return self;
    }

    /// Start reading. `done` or `failed` may run before this returns.
    pub fn begin(self: *ReadAll) void {
        self.readNext();
    }

    /// Cancel the stream with `reason` - fetch()'s abort steps' "cancel
    /// request's body with error" - through the reader that holds it.
    /// Nothing more is reported; this frees itself.
    pub fn cancel(self: *ReadAll, reason: js.Value) void {
        self.cancelled = true;
        const realm = self.realm;
        const reader = srd.readerOf(self.reader) orelse return;
        // The pending read's close steps run inside, and free this.
        const promise = srd.readerGenericCancel(realm, reader, reason) catch return;
        js.dispose(promise);
    }

    fn readNext(self: *ReadAll) void {
        const reader = srd.readerOf(self.reader) orelse return self.fail2(null);
        srd.defaultReaderRead(self.realm, reader, .{ .ctx = self, .vtable = &vtable });
    }

    fn chunk(ctx: *anyopaque, realm: js.Realm, value: js.Value) void {
        const self: *ReadAll = @ptrCast(@alignCast(ctx));
        if (self.cancelled) return self.destroy();
        const info = js.describeView(value) orelse return self.typeError(realm);
        if (info.kind != .uint8) return self.typeError(realm);
        const buffer = js.viewBuffer(value) catch return self.typeError(realm);
        defer js.dispose(buffer);
        const all = js.bufferBytes(buffer) orelse return self.typeError(realm);
        self.bytes.appendSlice(self.allocator, all[info.byte_offset..][0..info.byte_length]) catch return self.fail2(null);
        self.readNext();
    }

    fn close(ctx: *anyopaque, realm: js.Realm) void {
        _ = realm;
        const self: *ReadAll = @ptrCast(@alignCast(ctx));
        if (!self.cancelled) self.done(self.context, self.bytes.items);
        self.destroy();
    }

    fn fail(ctx: *anyopaque, realm: js.Realm, e: js.Value) void {
        _ = realm;
        const self: *ReadAll = @ptrCast(@alignCast(ctx));
        self.fail2(e);
    }

    fn drop(ctx: *anyopaque) void {
        const self: *ReadAll = @ptrCast(@alignCast(ctx));
        self.fail2(null);
    }

    /// A chunk that is not a Uint8Array: the fetch fails, and the stream is
    /// cancelled with the TypeError - nothing will read it again, and a pipe
    /// feeding it (pipeThrough) must hear so, or it waits forever.
    fn typeError(self: *ReadAll, realm: js.Realm) void {
        const e = realm.typeError("a request body chunk is not a Uint8Array") catch return self.fail2(null);
        defer js.dispose(e);
        if (!self.cancelled) self.failed(self.context, e);
        self.cancelled = true;
        if (srd.readerOf(self.reader)) |reader| {
            if (srd.readerGenericCancel(realm, reader, e)) |promise| js.dispose(promise) else |_| {}
        }
        self.destroy();
    }

    fn fail2(self: *ReadAll, e: ?js.Value) void {
        if (!self.cancelled) self.failed(self.context, e);
        self.destroy();
    }

    fn destroy(self: *ReadAll) void {
        self.bytes.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

/// Cancel `stream` with `reason` if it is readable and nobody holds it -
/// fetch()'s "abort the fetch() call" step 2, "cancel request's body with
/// error", before anything reads it.
pub fn cancelStream(realm: js.Realm, stream: *runtime.Instance, reason: js.Value) void {
    const slots = srd.streamOf(stream) orelse return;
    if (slots.state != .readable or srd.isLocked(slots)) return;
    const promise = srd.cancel(realm, stream, reason) catch return;
    js.dispose(promise);
}

/// Fetch "consume body": step 1's unusable check, then "fully read body" - a
/// reader takes every chunk - and the method's own steps on the bytes
/// (`settleWithBytes`).
pub fn consume(o: Owner, method: Method) anyerror!runtime.JSValue {
    const instance = o.instance;
    const realm = try js.Realm.of(instance);
    const deferred = try js.Deferred.init(realm);
    var deferred_taken = false;
    errdefer if (!deferred_taken) deferred.deinit();

    if (o.kind.rejection) |rejection| {
        if (rejection(instance, realm)) |reason| {
            defer js.dispose(reason);
            deferred.reject(realm, reason);
            deferred_taken = true;
            return finishReturn(deferred);
        }
    }

    // Step 1: If object is unusable, return a promise rejected with a
    // TypeError.
    if (isUnusable(o)) {
        const e = try realm.typeError("Body is unusable: it has been read or is locked");
        defer js.dispose(e);
        deferred.reject(realm, e);
        deferred_taken = true;
        return finishReturn(deferred);
    }

    const stream = (try bodyStream(o)) orelse {
        // Step 5: a null body reads as no bytes.
        try settleWithBytes(instance, o.kind, method, &.{}, realm, deferred);
        deferred_taken = true;
        return finishReturn(deferred);
    };
    const reader = try srd.acquireDefaultReader(realm, stream);
    // The read holds it through a Zig pointer; wrapping registers it with the
    // wrapper cache, which keeps streams-graph objects for the realm and
    // frees them with it - as ReadableStreamTee and pipeTo do. Unwrapped,
    // nothing ever freed it.
    _ = try realm.wrap(reader);

    const read = try instance.ctx.allocator.create(FullRead);
    deferred_taken = true;
    read.* = .{
        .allocator = instance.ctx.allocator,
        .instance = instance,
        .method = method,
        .kind = o.kind,
        .realm = realm,
        .deferred = deferred,
        .reader = reader,
    };
    // The object is what the method's own steps read - its headers, for a
    // blob's type - so it lives until they have run.
    read.keep.hold(instance);
    // Taken first: a stream already closed settles, and frees, the read
    // before readNext returns.
    const promise = js.clone(deferred.promise) catch |err| {
        read.destroy();
        return err;
    };
    read.readNext();
    return js.toReturnOwned(promise);
}

/// The promise of a Deferred settled already, as the method's return value:
/// ours to hand over, and its resolver let go.
fn finishReturn(deferred: js.Deferred) js.Error!runtime.JSValue {
    defer deferred.deinit();
    return js.toReturnOwned(try js.clone(deferred.promise));
}

/// The method's own steps - what it does to a body that is its bytes - on
/// `bytes`, the whole of a body read through its stream, settling
/// `deferred` with their outcome.
fn settleWithBytes(instance: *runtime.Instance, kind: *const Owner.Kind, method: Method, bytes: []const u8, realm: js.Realm, deferred: js.Deferred) !void {
    // A null body stays null (consume body step 5: the steps run on an empty
    // byte sequence), so bodyUsed stays false - the bytes forms read a null
    // body as empty and mark nothing.
    if (kind.of(instance)) |o| if (o.body) |body| {
        // As a body of these bytes that nobody has read yet: the stream was
        // the one disturbed, and the bytes form does its own marking.
        body.data.clearRetainingCapacity();
        try body.data.appendSlice(body.allocator, bytes);
        body.used = false;
        body.disturbed = false;
    };

    // The steps make their value - an ArrayBuffer, a Blob - in this's
    // relevant realm, which is not always the caller's (a method borrowed
    // from another window). A stream that has already ended reads to its
    // end inside the method call, before any microtask would enter it.
    var run: MethodSteps = .{ .instance = instance, .kind = kind, .method = method, .realm = realm, .deferred = deferred };
    engine.runInRealm(instance.ctx, MethodSteps.steps, &run) catch {
        // The realm could not be entered (none behind it, or no handle
        // left): the steps still settle the promise, from the current realm -
        // the value lands in the wrong realm only for a method borrowed from
        // another window, which is better than a promise never settled.
        MethodSteps.steps(&run);
    };
}

/// The method's own steps and the settling of its promise, run in the
/// object's realm.
const MethodSteps = struct {
    instance: *runtime.Instance,
    kind: *const Owner.Kind,
    method: Method,
    realm: js.Realm,
    deferred: js.Deferred,

    fn steps(data: ?*anyopaque) void {
        const self: *MethodSteps = @ptrCast(@alignCast(data.?));
        const realm = self.realm;
        const result = self.kind.steps(self.instance, self.method) catch |err| {
            const e = realm.typeError(@errorName(err)) catch return;
            defer js.dispose(e);
            self.deferred.reject(realm, e);
            return;
        };
        // The bytes form returns its promise; ours takes on its outcome.
        switch (result) {
            .handle => |h| {
                const promise: js.Value = .{ .value = result, .realm = realm.ctx };
                self.deferred.resolve(realm, promise);
                if (h.needs_disposal) js.dispose(promise);
            },
            else => self.deferred.resolveUndefined(realm),
        }
    }
};

/// Fetch "fully read body" through the body's stream: read every chunk,
/// then run the method's steps. Streams "read-loop": each chunk step reads
/// again - from a microtask, so a queue of many chunks is not a deep stack.
const FullRead = struct {
    allocator: std.mem.Allocator,
    instance: *runtime.Instance,
    method: Method,
    kind: *const Owner.Kind,
    realm: js.Realm,
    deferred: js.Deferred,
    reader: *runtime.Instance,
    bytes: std.ArrayListUnmanaged(u8) = .empty,
    keep: same_object.Pin = .{},

    const vtable = srd.ReadRequest.VTable{ .chunk = chunk, .close = close, .err = fail, .drop = drop };

    fn readNext(self: *FullRead) void {
        const reader = srd.readerOf(self.reader) orelse return self.finishWithTypeError("the body's reader is gone");
        srd.defaultReaderRead(self.realm, reader, .{ .ctx = self, .vtable = &vtable });
    }

    fn chunk(ctx: *anyopaque, realm: js.Realm, value: js.Value) void {
        const self: *FullRead = @ptrCast(@alignCast(ctx));
        _ = realm;
        // "If chunk is not a Uint8Array object, reject with a TypeError."
        const info = js.describeView(value) orelse return self.finishWithTypeError("a body chunk is not a Uint8Array");
        if (info.kind != .uint8) return self.finishWithTypeError("a body chunk is not a Uint8Array");
        const buffer = js.viewBuffer(value) catch return self.finishWithTypeError("a body chunk has no buffer");
        defer js.dispose(buffer);
        const all = js.bufferBytes(buffer) orelse return self.finishWithTypeError("a body chunk's buffer is detached");
        self.bytes.appendSlice(self.allocator, all[info.byte_offset..][0..info.byte_length]) catch return self.finishWithTypeError("out of memory");
        js.queueMicrotask(self.realm, FullRead, self, readNext);
    }

    fn close(ctx: *anyopaque, realm: js.Realm) void {
        const self: *FullRead = @ptrCast(@alignCast(ctx));
        settleWithBytes(self.instance, self.kind, self.method, self.bytes.items, realm, self.deferred) catch {};
        self.destroy();
    }

    fn fail(ctx: *anyopaque, realm: js.Realm, e: js.Value) void {
        const self: *FullRead = @ptrCast(@alignCast(ctx));
        self.deferred.reject(realm, e);
        self.destroy();
    }

    fn drop(ctx: *anyopaque) void {
        const self: *FullRead = @ptrCast(@alignCast(ctx));
        self.destroy();
    }

    fn finishWithTypeError(self: *FullRead, message: []const u8) void {
        const e = self.realm.typeError(message) catch return self.destroy();
        defer js.dispose(e);
        self.deferred.reject(self.realm, e);
        self.destroy();
    }

    fn destroy(self: *FullRead) void {
        self.keep.release();
        self.deferred.deinit();
        self.bytes.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

/// The underlying source of a body's stream: the body's pipe.
///
/// Fetch's HTTP-network fetch sets the stream up with byte reading support
/// and enqueues bytes as they arrive; here the bytes wait in the pipe until a
/// read asks for them (pull), so what nobody has read stays where a clone can
/// still tee it. The network's news - bytes, the end, a failure - comes as a
/// notification from the event loop's network step, and is acted on in a
/// task in the stream's realm: a pending read gets the bytes, the end closes
/// the stream, a failure errors it at once, read or not.
const PipeStream = struct {
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    /// The body's pipe, this source's from creation until cancel or
    /// deinit.
    pipe: ?*BodyPipe,
    /// The stream's controller, from start until deinit.
    controller: ?*runtime.Instance = null,
    /// The promise a pull is waiting on, while the pipe has nothing.
    pending_pull: ?js.Deferred = null,
    /// A task is queued to act on the pipe; it owns this until it runs.
    task_queued: bool = false,
    /// The stream is done with this source (its algorithms were cleared).
    detached: bool = false,
    /// Calls into the stream under way from here: freeing waits for them.
    busy: u32 = 0,

    const vtable = srd.Source.VTable{ .start = start, .pull = pull, .cancel = cancel, .deinit = deinitSource };

    /// CreateReadableByteStream over `pipe`, whose ownership passes in -
    /// on failure too.
    fn create(ctx: runtime.Context, pipe: *BodyPipe) !*runtime.Instance {
        const realm = js.Realm.ofContext(ctx) catch |err| {
            pipe.release();
            return err;
        };
        const self = ctx.allocator.create(PipeStream) catch |err| {
            pipe.release();
            return err;
        };
        self.* = .{ .allocator = ctx.allocator, .ctx = ctx, .pipe = pipe };
        pipe.consumer = .{ .context = self, .notify = notify };
        // Held while the stream is set up: a failed setup clears the
        // source's algorithms, which must not free it under this call.
        self.busy += 1;
        const stream = srd.createReadableByteStream(realm, ctx, .{ .ctx = self, .vtable = &vtable });
        if (stream) |_| {
            // A body that ended with nothing left to read, or failed, before
            // its stream was made: the stream is made in the state it would
            // have reached had it existed all along - closed (an empty queue
            // closes at once), or errored.
            if (self.controller) |controller| {
                if (pipe.state == .errored) {
                    self.errorStream(realm, controller, pipe);
                } else if (pipe.state == .closed and !pipe.hasBytes()) {
                    srd.byteControllerClose(realm, controller) catch {};
                }
            }
        } else |_| {}
        self.busy -= 1;
        if (stream) |s| {
            self.freeIfDone();
            return s;
        } else |err| {
            self.detached = true;
            self.releasePipe();
            self.freeIfDone();
            return err;
        }
    }

    fn start(ctx: ?*anyopaque, realm: js.Realm, controller: *runtime.Instance) js.Error!js.Completion {
        const self: *PipeStream = @ptrCast(@alignCast(ctx.?));
        self.controller = controller;
        return .{ .normal = try realm.undefinedValue() };
    }

    fn pull(ctx: ?*anyopaque, realm: js.Realm, controller: *runtime.Instance) js.Error!js.Value {
        const self: *PipeStream = @ptrCast(@alignCast(ctx.?));
        self.controller = controller;
        self.busy += 1;
        const acted = self.deliver(realm);
        self.busy -= 1;
        if (acted or self.detached) {
            self.freeIfDone();
            return realm.promiseResolvedWithUndefined();
        }
        // Nothing yet: the pull waits for the network.
        const d = try js.Deferred.init(realm);
        self.pending_pull = d;
        return js.clone(d.promise);
    }

    /// Act on what the pipe has: enqueue its bytes, close at its end, error
    /// on its failure. Returns whether there was anything to act on.
    fn deliver(self: *PipeStream, realm: js.Realm) bool {
        const pipe = self.pipe orelse return false;
        const controller = self.controller orelse return false;
        if (pipe.state == .errored) {
            self.errorStream(realm, controller, pipe);
            return true;
        }
        if (pipe.hasBytes()) {
            const bytes = pipe.take() catch return false;
            defer self.allocator.free(bytes);
            self.enqueue(realm, controller, bytes);
            if (self.detached) return true;
            if (pipe.state == .closed) srd.byteControllerClose(realm, controller) catch {};
            return true;
        }
        if (pipe.state == .closed) {
            srd.byteControllerClose(realm, controller) catch {};
            return true;
        }
        return false;
    }

    fn enqueue(self: *PipeStream, realm: js.Realm, controller: *runtime.Instance, bytes: []const u8) void {
        _ = self;
        const buffer = js.allocateBufferIn(realm, bytes.len) orelse return;
        defer js.dispose(buffer);
        if (js.bufferBytes(buffer)) |dest| @memcpy(dest[0..bytes.len], bytes);
        const view = js.newView(.uint8, buffer, 0, bytes.len) catch return;
        defer js.dispose(view);
        srd.byteControllerEnqueue(realm, controller, view) catch {};
    }

    /// Error the stream with the pipe's failure: an abort's reason, or a
    /// TypeError for a network error.
    fn errorStream(self: *PipeStream, realm: js.Realm, controller: *runtime.Instance, pipe: *BodyPipe) void {
        const failure = pipe.failure();
        if (failure.kind == .aborted) {
            if (failure.reason) |reason| {
                // Our own handle to it: erroring the controller clears the
                // stream's algorithms, which lets this source's pipe go -
                // and with the last reader, the source and the reason it
                // holds - before the error reaches the stream.
                const held: *const AbortReason = @ptrCast(@alignCast(reason));
                const e = js.clone(held.value) catch return;
                defer js.dispose(e);
                srd.byteControllerError(realm, controller, e);
                return;
            }
            // No reason given: an "AbortError" DOMException.
            const exception = engine.createDOMException(self.ctx, "AbortError", "The operation was aborted.") catch return;
            defer exception.release();
            const e = realm.fromRuntime(exception.value) catch return;
            defer js.dispose(e);
            srd.byteControllerError(realm, controller, e);
            return;
        }
        const e = realm.typeError("network error") catch return;
        defer js.dispose(e);
        srd.byteControllerError(realm, controller, e);
    }

    /// The pipe has news. Called from the event loop's network step, outside
    /// the realm: act on it in a task there.
    fn notify(context: *anyopaque) void {
        const self: *PipeStream = @ptrCast(@alignCast(context));
        if (self.task_queued or self.detached) return;
        if (self.ctx.getOptionalEventLoop()) |loop| {
            self.task_queued = true;
            loop.queueTask(.{ .callback = runTask, .context = self, .drop = dropTask });
            return;
        }
        if (self.ctx.getOptionalTimer()) |timer| {
            if (timer.setTimeout(0, runTask, self) != 0) {
                self.task_queued = true;
                return;
            }
        }
    }

    fn runTask(context: ?*anyopaque) void {
        const self: *PipeStream = @ptrCast(@alignCast(context.?));
        self.task_queued = false;
        if (self.detached or self.ctx.engine_ctx == null) return self.freeIfDone();
        // A task from the event loop, not from script: HTML "queue a global
        // task" - it runs in the realm, which ends it (a microtask
        // checkpoint; a worker's end of task).
        self.busy += 1;
        // An error means the steps never ran (the realm is gone): the news
        // has nobody to reach, and freeIfDone lets this go.
        engine.runTaskInRealm(self.ctx, taskSteps, self) catch {};
        self.busy -= 1;
        self.freeIfDone();
    }

    /// The task's steps: act on the pipe's news.
    fn taskSteps(data: ?*anyopaque) void {
        const self: *PipeStream = @ptrCast(@alignCast(data.?));
        const realm = js.Realm.ofContext(self.ctx) catch return;
        const pipe = self.pipe orelse return;
        const controller = self.controller orelse return;
        if (pipe.state == .errored) {
            // Errored at once, read or not: an aborted body's stream
            // errors with the abort reason even while nobody reads.
            self.errorStream(realm, controller, pipe);
        } else if (self.pending_pull != null) {
            if (self.deliver(realm)) {
                if (self.pending_pull) |d| {
                    self.pending_pull = null;
                    d.resolveUndefined(realm);
                    d.deinit();
                }
            }
        }
    }

    fn dropTask(context: ?*anyopaque) void {
        const self: *PipeStream = @ptrCast(@alignCast(context.?));
        self.task_queued = false;
        self.freeIfDone();
    }

    fn cancel(ctx: ?*anyopaque, realm: js.Realm, _: *runtime.Instance, _: js.Value) js.Error!js.Value {
        const self: *PipeStream = @ptrCast(@alignCast(ctx.?));
        // Nobody will read what is left: let the pipe go, which stops the
        // transfer if this was its last reader.
        self.releasePipe();
        return realm.promiseResolvedWithUndefined();
    }

    fn deinitSource(ctx: ?*anyopaque, allocator: std.mem.Allocator) void {
        _ = allocator;
        const self: *PipeStream = @ptrCast(@alignCast(ctx.?));
        self.detached = true;
        self.controller = null;
        self.releasePipe();
        if (self.pending_pull) |d| {
            self.pending_pull = null;
            d.deinit();
        }
        self.freeIfDone();
    }

    fn releasePipe(self: *PipeStream) void {
        const pipe = self.pipe orelse return;
        self.pipe = null;
        pipe.consumer = null;
        pipe.release();
    }

    fn freeIfDone(self: *PipeStream) void {
        if (!self.detached or self.task_queued or self.busy > 0) return;
        self.allocator.destroy(self);
    }
};

// =============================================================================
// multipart/form-data (HTML § 4.10.21.8)
// =============================================================================

const boundary_len = 38;

extern "c" fn getentropy(buf: [*]u8, len: usize) c_int;
threadlocal var boundary_counter: u64 = 0;

/// A multipart/form-data boundary string: "----formdata-crane-" and 19
/// random alphanumerics. HTML leaves the string to the user agent; it must
/// not occur in the parts, which random bytes of this length do not.
fn multipartBoundary() [boundary_len]u8 {
    const prefix = "----formdata-crane-";
    const alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    var out: [boundary_len]u8 = undefined;
    @memcpy(out[0..prefix.len], prefix);
    // getentropy(2): std.crypto.random needs an Io in Zig 0.16. A boundary
    // only has to be unlikely to occur in the parts, so the counter below
    // is enough if it fails.
    var random: [boundary_len - prefix.len]u8 = undefined;
    if (getentropy(&random, random.len) != 0) {
        boundary_counter +%= 0x9E3779B97F4A7C15;
        var fallback = std.Random.DefaultPrng.init(boundary_counter);
        fallback.random().bytes(&random);
    }
    for (out[prefix.len..], random) |*c, r| c.* = alphabet[r % alphabet.len];
    return out;
}

/// The multipart/form-data encoding algorithm over `form`'s entry list, with
/// UTF-8. Owned.
fn encodeMultipart(allocator: std.mem.Allocator, form: *runtime.Instance, boundary: []const u8) Error![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    const entries = interfaces.FormData.getEntriesForIterable(form) orelse &.{};
    // No entries, no parts - and no closing delimiter either: an empty
    // FormData is an empty body in every engine
    // (fetch/api/response/response-consume-empty.any.js).
    if (entries.len == 0) return out.toOwnedSlice(allocator);
    for (entries) |entry| {
        try out.appendSlice(allocator, "--");
        try out.appendSlice(allocator, boundary);
        try out.appendSlice(allocator, "\r\nContent-Disposition: form-data; name=\"");
        try appendEscapedName(allocator, &out, entry.name);
        try out.append(allocator, '"');
        switch (entry.value) {
            .usvstring => |value| {
                try out.appendSlice(allocator, "\r\n\r\n");
                try appendNormalizedNewlines(allocator, &out, value);
            },
            .file => |blob| {
                // A Blob in an entry list is a File named "blob" (XHR
                // "create an entry").
                try out.appendSlice(allocator, "; filename=\"");
                if (blob.stateAs(interfaces.File.State) != null) {
                    var name = interfaces.File.get_name(blob) catch return error.OutOfMemory;
                    defer name.deinit(blob.ctx.allocator);
                    try appendEscapedName(allocator, &out, name.asSlice());
                } else {
                    try out.appendSlice(allocator, "blob");
                }
                try out.appendSlice(allocator, "\"\r\nContent-Type: ");
                var blob_type = interfaces.Blob.get_type(blob) catch return error.OutOfMemory;
                defer blob_type.deinit(blob.ctx.allocator);
                const type_bytes = blob_type.asSlice();
                try out.appendSlice(allocator, if (type_bytes.len > 0) type_bytes else "application/octet-stream");
                try out.appendSlice(allocator, "\r\n\r\n");
                try out.appendSlice(allocator, blob_bytes.bytesOf(blob) orelse &.{});
            },
        }
        try out.appendSlice(allocator, "\r\n");
    }
    try out.appendSlice(allocator, "--");
    try out.appendSlice(allocator, boundary);
    try out.appendSlice(allocator, "--\r\n");
    return out.toOwnedSlice(allocator);
}

/// A field name or filename, escaped: LF as %0A, CR as %0D, " as %22. A
/// name's newlines are normalized to CRLF first ("convert to a list of
/// name-value pairs"), so a lone CR or LF is escaped as the pair.
fn appendEscapedName(allocator: std.mem.Allocator, out: *std.ArrayListUnmanaged(u8), name: []const u8) Error!void {
    var normalized: std.ArrayListUnmanaged(u8) = .empty;
    defer normalized.deinit(allocator);
    try appendNormalizedNewlines(allocator, &normalized, name);
    for (normalized.items) |c| switch (c) {
        '\n' => try out.appendSlice(allocator, "%0A"),
        '\r' => try out.appendSlice(allocator, "%0D"),
        '"' => try out.appendSlice(allocator, "%22"),
        else => try out.append(allocator, c),
    };
}

/// Every CR not followed by LF, and every LF not preceded by CR, as CRLF.
fn appendNormalizedNewlines(allocator: std.mem.Allocator, out: *std.ArrayListUnmanaged(u8), text: []const u8) Error!void {
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        const c = text[i];
        if (c == '\r') {
            try out.appendSlice(allocator, "\r\n");
            if (i + 1 < text.len and text[i + 1] == '\n') i += 1;
        } else if (c == '\n') {
            try out.appendSlice(allocator, "\r\n");
        } else {
            try out.append(allocator, c);
        }
    }
}
