//! Implementation for WindowOrWorkerGlobalScope interface

const std = @import("std");
const runtime = @import("runtime");
const html_core = @import("html_core");
const global_settings = @import("dom").global_settings;
const message_ports = @import("dom").message_ports;
/// The one transfer step every carrier of a transfer list runs.
const transferables = @import("dom").transferables;
const streams_js = @import("dom").streams_js;
const dom = @import("dom");
const same_object = @import("dom").same_object;
const fetch_body = @import("fetch_body");
const engine = @import("engine");
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

/// Getter for trustedTypes (Trusted Types 4.1.1): "return this's relevant
/// global object's trusted type policy factory."
pub fn get_trustedTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const settings = global_settings.of(instance) orelse return error.InvalidStateError;
    const trusted_types = settings.trusted_types orelse return error.NotImplemented;
    return trusted_types(instance);
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
    const settings = global_settings.of(instance) orelse return error.InvalidStateError;
    const crypto = settings.crypto orelse return error.NotImplemented;
    return crypto(instance);
}

/// HTML 8.1.4.6 reportError(e): report an exception e for this global.
/// https://html.spec.whatwg.org/multipage/webappapis.html#dom-reporterror
/// As WebKit's WindowOrWorkerGlobalScope::reportError
/// (Source/WebCore/page/WindowOrWorkerGlobalScope.cpp) does, pass the value
/// to the existing exception reporter for the receiver's relevant global.
pub fn call_reportError(instance: *runtime.Instance, e: runtime.JSValue) anyerror!void {
    // Report an exception, step 2: extract error information. The strings
    // belong to this call; error_value stays borrowed from e.
    // reportError never throws: an engine that cannot extract the
    // information (error.NotSupported on JSC/QuickJS) or a failed
    // allocation still reports e, with empty details.
    const allocator = instance.ctx.allocator;
    const info = engine.extractErrorInformation(instance.ctx, e, allocator) catch null;
    defer if (info) |i| {
        allocator.free(i.message);
        allocator.free(i.filename);
    };
    const extracted: runtime.ErrorInfo = if (info) |i| .{
        .message = i.message,
        .filename = i.filename,
        .lineno = i.lineno,
        .colno = i.colno,
        .error_value = i.error_value,
    } else .{
        .message = "",
        .filename = "",
        .lineno = 0,
        .colno = 0,
        .error_value = e,
    };
    // Steps 4–7: the host reporter applies the reporting-mode guard, fires
    // the ErrorEvent, and forwards unhandled worker errors to their owner.
    _ = @import("html").report_exception.reportErrorInfo(instance, &extracted, .{});
}

/// Operation: setInterval
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-setinterval
///
/// "The setInterval(handler, timeout, ...arguments) method steps are to
/// return the result of running the timer initialization steps given this,
/// handler, timeout, arguments, and true." (`setTimer`)
pub fn call_setInterval(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    return setTimer(instance, handler, timeout, arguments, true);
}

/// Operation: atob
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#dom-atob
pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.ByteString {
    // Freed by the binding.
    return html_core.base64_utility.atobBytes(instance.ctx.allocator, data.asSlice());
}

/// Operation: btoa
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#dom-btoa
pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.DOMString {
    // Freed by the binding.
    return runtime.DOMString.initOwned(try html_core.base64_utility.btoa(instance.ctx.allocator, data.asSlice()));
}

/// Operation: createImageBitmap(image, options) - HTML 8.11.2.
pub fn call_createImageBitmap(instance: *runtime.Instance, image: typedefs.ImageBitmapSource, options: webidl.Opt(dictionaries.ImageBitmapOptions)) anyerror!runtime.JSValue {
    return createImageBitmap(instance, image, null, options.getOrDefault(.{}));
}

/// Operation: createImageBitmap(image, sx, sy, sw, sh, options) - HTML
/// 8.11.2.
pub fn call_createImageBitmap__1(instance: *runtime.Instance, image: typedefs.ImageBitmapSource, sx: i32, sy: i32, sw: i32, sh: i32, options: webidl.Opt(dictionaries.ImageBitmapOptions)) anyerror!runtime.JSValue {
    return createImageBitmap(instance, image, .{ .sx = sx, .sy = sy, .sw = sw, .sh = sh }, options.getOrDefault(.{}));
}

/// HTML 8.11.2, the createImageBitmap() method steps, for `global` (this).
/// The binding turns what they throw into a rejected promise ("return a
/// promise rejected with": the method returns a Promise, WebIDL 3.7.6).
///
/// The Blob arm's steps 1-4 run "in parallel" in the spec; here the read
/// and the decode run on the agent's thread before the call returns, as the
/// canvas element's toBlob encodes (stated there). The promise is still
/// settled by a task queued on the bitmap task source, so script sees the
/// same order.
fn createImageBitmap(global: *runtime.Instance, image: typedefs.ImageBitmapSource, crop: ?dom.image_bitmaps.Crop, options: dictionaries.ImageBitmapOptions) anyerror!runtime.JSValue {
    // 1. "If either sw or sh is given and is 0, then return a promise
    //    rejected with a RangeError."
    if (crop) |given| if (given.sw == 0 or given.sh == 0) return error.RangeError;
    // 2. "If either options's resizeWidth or options's resizeHeight is
    //    present and is 0, then return a promise rejected with an
    //    "InvalidStateError" DOMException."
    if (options.resizeWidth) |width| if (width == 0) return error.InvalidStateError;
    if (options.resizeHeight) |height| if (height == 0) return error.InvalidStateError;
    const formatting: dom.image_bitmaps.Formatting = .{
        .flip_y = (options.imageOrientation orelse ._from_image_) == ._flipY_,
        .premultiply_alpha = switch (options.premultiplyAlpha orelse ._default_) {
            ._default_ => .default,
            ._premultiply_ => .premultiply,
            ._none_ => .none,
        },
        .resize_width = options.resizeWidth,
        .resize_height = options.resizeHeight,
        .resize_quality = switch (options.resizeQuality orelse ._low_) {
            ._pixelated_ => .pixelated,
            ._low_ => .low,
            ._medium_ => .medium,
            ._high_ => .high,
        },
    };
    const allocator = global.ctx.allocator;
    // 3, 6: the bitmap data, cropped to the source rectangle with
    //    formatting, by kind of image; an InvalidStateError when no bitmap
    //    can be made from it. (Steps 4-5's promise and ImageBitmap follow:
    //    nothing in between is observable.)
    const bitmap: *dom.image_bitmaps.Bitmap = switch (image) {
        .canvas_image_source => |source| blk: {
            // 3. "Check the usability of the image argument. If this throws
            //    an exception or returns bad, then return a promise rejected
            //    with an "InvalidStateError" DOMException."
            const usability: dom.image_sources.Usability = switch (source) {
                .htmlor_svgimage_element => |element| switch (element) {
                    .htmlimage_element => |img| dom.image_sources.imageUsability(img),
                    // An SVG image element's image is not loaded here: it
                    // has no image to give (bad).
                    .svgimage_element => .bad,
                },
                // A video's readyState is not modelled past HAVE_NOTHING
                // (no media decoding): bad.
                .htmlvideo_element => .bad,
                .htmlcanvas_element => |canvas| dom.image_sources.canvasUsability(canvas),
                .image_bitmap => |source_bitmap| dom.image_sources.imageBitmapUsability(source_bitmap),
                .offscreen_canvas => |canvas| dom.image_sources.offscreenCanvasUsability(canvas),
                // VideoFrame is not implemented: no frame has pixels.
                .video_frame => .bad,
            };
            const good = switch (usability) {
                .good => |good| good,
                .bad, .invalid_state => return error.InvalidStateError,
            };
            // 6, img / canvas / ImageBitmap / OffscreenCanvas: "a copy of
            //    image's media data (bitmap data), cropped to the source
            //    rectangle with formatting", origin-clean as image is.
            break :blk try formatted(allocator, good, crop, formatting);
        },
        .image_data => |image_data| blk: {
            // 6, ImageData: 1-2. If its data's [[ViewedArrayBuffer]] is
            //    detached, an InvalidStateError.
            const realm = engine.currentRealm() orelse global.ctx;
            const data = switch (try interfaces.ImageData.get_data(image_data)) {
                .uint8clamped_array => |array| array,
                .float16array => return error.InvalidStateError,
            };
            const description = engine.describeArrayBufferView(realm, data) orelse return error.InvalidStateError;
            if (description.detached) return error.InvalidStateError;
            const buffer = try engine.getViewedArrayBuffer(realm, data);
            defer buffer.release();
            const bytes = engine.borrowArrayBufferBytes(realm, buffer.value) orelse return error.InvalidStateError;
            // 3. "image's image data" - straight alpha, origin-clean.
            const width = try interfaces.ImageData.get_width(image_data);
            const height = try interfaces.ImageData.get_height(image_data);
            break :blk try formatted(allocator, .{
                .width = width,
                .height = height,
                .pixels = bytes[description.byte_offset..][0..description.byte_length],
                .alpha = .straight,
                .origin_clean = true,
            }, crop, formatting);
        },
        .blob => |blob| blk: {
            // 6, Blob: 1. read image's data; 2. sniff it with its type as
            //    the official type; 3. not a supported image, or no
            //    dimensions: an InvalidStateError - in a task.
            const bytes = dom.blob_bytes.bytesOf(blob) orelse &.{};
            var blob_type = try interfaces.Blob.get_type(blob);
            defer blob_type.deinit(allocator);
            var decoded = dom.image_bitmaps.decodeBlob(allocator, bytes, blob_type.asSlice()) orelse
                return settleInTask(global, null);
            defer decoded.deinit();
            // 4. "Set imageBitmap's bitmap data to imageData, cropped to the
            //    source rectangle with formatting."
            break :blk formatted(allocator, decoded.source(), crop, formatting) catch |err| switch (err) {
                error.InvalidStateError => return settleInTask(global, null),
                else => return err,
            };
        },
    };
    return settleInTask(global, bitmap);
}

/// "Crop bitmap data to the source rectangle with formatting", an
/// InvalidStateError for a bitmap too large to make.
fn formatted(allocator: std.mem.Allocator, source: dom.image_sources.ImageSource, crop: ?dom.image_bitmaps.Crop, formatting: dom.image_bitmaps.Formatting) !*dom.image_bitmaps.Bitmap {
    return dom.image_bitmaps.cropWithFormatting(allocator, source, crop, formatting) catch |err| switch (err) {
        error.TooLarge => error.InvalidStateError,
        error.OutOfMemory => error.OutOfMemory,
    };
}

/// createImageBitmap steps 4-5 and 7, then 6's last step: "Let promise be a
/// new promise"; "Let imageBitmap be a new ImageBitmap object" with
/// `bitmap` (taken); "Queue a global task, using the bitmap task source, to
/// resolve promise with imageBitmap"; return promise. A null `bitmap` is the
/// Blob arm's failure: the task rejects promise with an "InvalidStateError"
/// DOMException instead.
fn settleInTask(global: *runtime.Instance, bitmap: ?*dom.image_bitmaps.Bitmap) !runtime.JSValue {
    const realm = global.ctx;
    const allocator = realm.allocator;
    // `bitmap` is ours until the ImageBitmap takes it (step 5).
    var bitmap_owned = bitmap != null;
    errdefer if (bitmap_owned) bitmap.?.destroy();
    // 4.
    var promise = try engine.createPromise(realm);
    errdefer engine.releasePromiseCapability(&promise);
    const result = try engine.retainValue(realm, promise.promise);
    errdefer result.release();
    // 5. The ImageBitmap, made now: unwrapped until the task resolves the
    //    promise with it (its wrapper is made then, in this realm).
    const image_bitmap: ?*runtime.Instance = if (bitmap) |b| try interfaces.ImageBitmap.initWith(allocator, realm, .{ .bitmap = b }) else null;
    bitmap_owned = false;
    errdefer if (image_bitmap) |made| made.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(made));
    const task = try allocator.create(BitmapTask);
    task.* = .{
        .allocator = allocator,
        .realm = realm,
        .capability = promise,
        .image_bitmap = image_bitmap,
        .generation = if (image_bitmap) |made| runtime.SlabAllocator.generationOf(made) else 0,
    };
    const loop = realm.getOptionalEventLoop() orelse {
        BitmapTask.run(task);
        return result.take();
    };
    var queued: runtime.EventLoopTask = .{ .callback = BitmapTask.run, .context = task, .drop = BitmapTask.drop };
    // "Queue a global task": a Window's runs only while its Document is
    // fully active.
    if (realm.isWindow()) {
        if (realm.getRealm()) |record| if (record.global_object) |object| {
            const window: *runtime.Instance = @ptrCast(@alignCast(object));
            queued.document = window;
            queued.document_generation = runtime.SlabAllocator.generationOf(window);
        };
    }
    loop.queueTask(queued);
    // 7.
    return result.take();
}

/// createImageBitmap's global task on the bitmap task source.
const BitmapTask = struct {
    allocator: std.mem.Allocator,
    realm: runtime.Context,
    capability: engine.PromiseCapability,
    /// The ImageBitmap to resolve with, unwrapped until then; null rejects.
    image_bitmap: ?*runtime.Instance,
    generation: u64,

    fn run(data: ?*anyopaque) void {
        const self: *BitmapTask = @ptrCast(@alignCast(data.?));
        defer self.deinit();
        engine.runTaskInRealm(self.realm, steps, self) catch {};
    }

    fn steps(data: ?*anyopaque) void {
        const self: *BitmapTask = @ptrCast(@alignCast(data.?));
        const made = self.image_bitmap orelse {
            const exception = engine.createDOMException(self.realm, "InvalidStateError", "The source image could not be decoded.") catch return;
            defer exception.release();
            engine.rejectPromise(&self.capability, exception.value) catch {};
            return;
        };
        // Resolving wraps it: it is the wrapper's from then on.
        engine.resolvePromise(&self.capability, .{ .instance = made }) catch {};
    }

    fn drop(data: ?*anyopaque) void {
        const self: *BitmapTask = @ptrCast(@alignCast(data.?));
        self.deinit();
    }

    fn deinit(self: *BitmapTask) void {
        engine.releasePromiseCapability(&self.capability);
        // Never wrapped (the task was dropped, or the resolution failed
        // before wrapping it): ours to let go.
        if (self.image_bitmap) |made| made.releaseIfUnwrapped(self.generation);
        self.allocator.destroy(self);
    }
};

/// Operation: clearInterval
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-clearinterval
///
/// "The clearTimeout(id) and clearInterval(id) method steps are to remove
/// this's map of setTimeout and setInterval IDs[id]." (`clearTimer`)
pub fn call_clearInterval(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    return clearTimer(instance, id);
}

/// Operation: queueMicrotask
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-queuemicrotask
///
/// "Queue a microtask to invoke callback with « » and "report"."
pub fn call_queueMicrotask(instance: *runtime.Instance, callback: callbacks.VoidFunction) anyerror!void {
    // The binding hands the callback over: take it before anything can fail.
    const function = engine.takeCallbackFunction(@ptrCast(callback));
    const task = instance.ctx.allocator.create(Microtask) catch {
        function.release();
        return error.OutOfMemory;
    };
    task.* = .{ .callback = function, .realm = instance.ctx, .allocator = instance.ctx.allocator };
    // A realm microtask, whose dropped end lets the task go when it never
    // runs: the realm's end, or the agent's queue discarded under it (a
    // terminated checkpoint - a worker's termination, a script deadline).
    // engine.queueMicrotask has none, and the task and its callback leaked
    // (lane leaks1, tests/v8/microtask_dropped_end_test.zig).
    engine.queueRealmMicrotask(instance.ctx, &Microtask.steps, task) catch |err| {
        task.deinit();
        return err;
    };
}

/// A queueMicrotask() callback waiting for its microtask. A realm torn down
/// meanwhile runs nothing: the microtask is dropped, and the task let go.
const Microtask = struct {
    /// OWNED.
    callback: engine.CallbackFunction,
    realm: runtime.Context,
    allocator: std.mem.Allocator,

    const steps: engine.PromiseReactionSteps = .{ .fulfilled = run, .dropped = dropped };

    fn dropped(data: ?*anyopaque) void {
        const self: *Microtask = @ptrCast(@alignCast(data.?));
        self.deinit();
    }

    fn run(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *Microtask = @ptrCast(@alignCast(data.?));
        defer self.deinit();
        const completion = engine.invokeCallbackFunction(self.realm, &self.callback, .undefined, &.{}, .{
            .report = .{ .report = reportException, .host = self.realm },
        }) catch return;
        switch (completion) {
            inline else => |value| value.release(),
        }
    }

    fn deinit(self: *Microtask) void {
        self.callback.release();
        self.allocator.destroy(self);
    }
};

/// HTML "report an exception" for the global of the realm the engine names -
/// the callback's associated realm - or else the queueing global's (`host`).
fn reportException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const queued_in: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse queued_in;
    const record = realm.getRealm() orelse return;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = @import("html").report_exception.reportErrorInfo(global, &extracted, .{});
}

/// Operation: structuredClone
/// Spec: https://html.spec.whatwg.org/multipage/structured-data.html#dom-structuredclone
///
/// 1. Let serialized be ? StructuredSerializeWithTransfer(value,
///    options["transfer"]).
/// 2. Let deserializeRecord be ? StructuredDeserializeWithTransfer(
///    serialized, this's relevant realm).
/// 3. Return deserializeRecord.[[Deserialized]].
///
/// A transferable platform object in the transfer list is transferred as
/// postMessage transfers one, by the one shared step (dom.transferables): its
/// transfer steps (StructuredSerializeWithTransfer step 5.5) make its data
/// holder - a MessagePort's shipped end, a stream's cross-realm transform
/// port - and its transfer-receiving steps (StructuredDeserializeWithTransfer
/// step 3.4.4) make the new object of this's relevant realm from it.
pub fn call_structuredClone(instance: *runtime.Instance, value: runtime.JSValue, options: webidl.Opt(dictionaries.StructuredSerializeOptions)) anyerror!runtime.JSValue {
    const allocator = instance.ctx.allocator;
    const transfer: []const runtime.JSValue = if (options.was_passed) (options.value.transfer orelse &.{}) else &.{};
    // Step 1, and its step 5.5: each transferred object's data holder.
    var serialized = try engine.structuredSerializeWithTransfer(instance.ctx, value, transfer, transferables.check, null, allocator);
    defer serialized.deinit(allocator);
    const holders = try transferables.transferAll(instance.ctx, serialized.platform_objects, allocator);
    defer allocator.free(holders);
    // Step 2, StructuredDeserializeWithTransfer step 3: each data holder
    // received in this's relevant realm, in transfer-list order (every
    // holder is taken - received, or discarded when one fails).
    var received = try transferables.receiveAll(instance.ctx, holders, allocator);
    defer received.deinit();
    // transferredValues: objects of this's relevant realm, wrapped, which the
    // collector owns like any other once this returns (structuredClone returns
    // only [[Deserialized]], so an object the value does not refer to is
    // garbage). The array holds them until the value is deserialized.
    const transferred_values: ?engine.Owned = if (received.values.len > 0) try engine.createSequenceOfPlatformObjects(instance.ctx, received.values) else null;
    defer if (transferred_values) |values| values.release();
    // Steps 2-3: the value, deserialized with the received objects as the
    // transferred objects it refers to (memory, step 3.5).
    const deserialized = try engine.structuredDeserializeWithOptions(instance.ctx, serialized.serialized, .{ .array_buffers = serialized.array_buffers, .transferred = received.values, .shared_memory = serialized.shared_memory });
    return deserialized.take();
}

/// Operation: setTimeout
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-settimeout
///
/// "The setTimeout(handler, timeout, ...arguments) method steps are to
/// return the result of running the timer initialization steps given this,
/// handler, timeout, arguments, and false." (`setTimer`)
pub fn call_setTimeout(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    return setTimer(instance, handler, timeout, arguments, false);
}

/// Operation: clearTimeout
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-cleartimeout
pub fn call_clearTimeout(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    return clearTimer(instance, id);
}

/// HTML 8.6's timer initialization steps for `instance`, run by its kind of
/// global (dom.global_settings `set_timer`): its map of setTimeout and
/// setInterval IDs, its event loop and its realm are the global's own. A
/// WorkerGlobalScope's reach here - the members are its prototype's,
/// WindowOrWorkerGlobalScope being a mixin it includes (WebIDL 3.7.3) - and
/// a Window's are its own operations ([Global]: page_realm's window
/// operations), which answer first.
fn setTimer(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue, repeat: bool) anyerror!i32 {
    // The binding hands a Function over: take it before anything can fail.
    const converted: global_settings.TimerHandler = switch (handler) {
        .function => |function| .{ .function = engine.takeCallbackFunction(@ptrCast(function)) },
        .trusted_script => |trusted| .{ .trusted_script = trusted },
        .domstring => |text| .{ .string = text.asSlice() },
    };
    const settings = global_settings.of(instance) orelse {
        converted.release();
        return error.NotImplemented;
    };
    const set = settings.set_timer orelse {
        converted.release();
        return error.NotImplemented;
    };
    // `optional long timeout = 0`.
    return set(instance, converted, timeout.getOrDefault(0), arguments, repeat);
}

/// clearTimeout() and clearInterval(): `optional long id = 0`; an id no timer
/// of this global has names nothing.
fn clearTimer(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    const settings = global_settings.of(instance) orelse return error.NotImplemented;
    const clear = settings.clear_timer orelse return error.NotImplemented;
    clear(instance, id.getOrDefault(0));
}

// One call, from the moment the fetch starts until it is entirely over:
// the fetch's client, the task that settles p, and the abort steps on
// requestObject's signal - which outlive p's settling, since the body is
// still arriving and an abort then errors it.
//
// Two things hold it, each letting go once: the fetch, until it is over
// (`finished`), gone (`gone`) or aborted; and the settle task, from
// `done` until it runs (or its `drop`). The last to let go frees it.
const FetchCall = struct {
    const fetch = @import("fetch");
    const fetch_objects = @import("dom").fetch_objects;
    const abort_algorithms = @import("dom").abort_algorithms;

    allocator: std.mem.Allocator,
    /// The relevant realm's runtime context. A page that ends RETIRES its
    /// context rather than freeing it, and empties it - `engine_ctx`
    /// becomes null - which is how `alive` tells that the realm is gone.
    ctx: runtime.Context,
    /// The Window's document when this call starts. A realm can be reused
    /// by a later document, whose requests an old abort must not touch.
    document: ?same_object.Link = null,
    document_abort_pending: bool = false,
    /// Cancellation can invoke an upload stream's script; the active call
    /// owns this record until that script returns.
    canceling: usize = 0,
    /// p's capability, this call's until p is settled or its realm is
    /// gone. Keeping it keeps p, and so the realm, alive while the fetch
    /// is in flight.
    capability: engine.PromiseCapability,
    outcome: ?(fetch.algorithms.FetchError!fetch.algorithms.FetchResult) = null,
    /// The fetch, from start until it ends (`done` or `gone`) or is
    /// aborted.
    in_flight: ?*fetch.algorithms.AsyncFetch = null,
    /// requestObject's signal while this call's abort steps are on it,
    /// as (address, slab generation).
    signal: ?*runtime.Instance = null,
    signal_generation: u64 = 0,
    /// Keeps that signal alive for as long as this call. requestObject
    /// goes when fetch() returns, and with it its own pin, but DOM
    /// § 3.3.1: a signal with source signals and abort algorithms must
    /// not be collected - `controller.abort()` reaches the abort steps
    /// through it. The generation check stays for a pin that could not
    /// be taken (no isolate).
    signal_pin: same_object.Pin = .{},
    /// Step 9's locallyAborted.
    locally_aborted: bool = false,
    /// "Abort a document" canceled this call's fetch (`abortIn`).
    document_aborted: bool = false,
    /// The request's keepalive flag: such a fetch outlives its document
    /// (`abortIn` leaves it).
    keepalive: bool = false,
    /// A keepalive request's body bytes in this's relevant settings
    /// object's fetch group, from the start of the fetch until it is done
    /// or terminated (dom.keepalive_fetch.Reservation). Released once
    /// (`releaseKeepalive`).
    keepalive_reservation: ?@import("dom").keepalive_fetch.Reservation = null,
    /// p is settled (or never will be), and its resolver released.
    settled: bool = false,
    /// The fetch holds this call, until it lets go.
    fetch_holds: bool = true,
    /// A settle task holds this call, until it runs.
    task_holds: bool = false,
    /// While requestObject's body is read from its stream to be sent:
    /// the read, and the request waiting for its bytes. The fetch
    /// starts once they are all read (`uploadRead`). Until then the
    /// read stands for the fetch in `fetch_holds`.
    upload: ?*fetch_body.ReadAll = null,
    pending_request: ?*fetch.internal.InternalRequest = null,
    /// While requestObject's stream body is read as it comes into the
    /// request's body pipe - a request a service worker is asked to handle
    /// (`offeredToServiceWorker`): the fetch is under way meanwhile. Cleared
    /// when the pump is gone (`uploadPumpEnded`); the abort steps cancel it
    /// with their reason.
    upload_pump: ?*fetch_body.UploadPump = null,

    const Self = @This();

    fn client(self: *Self) fetch.algorithms.AsyncFetch.Client {
        return .{ .context = self, .done = done, .alive = alive, .gone = gone, .finished = finished };
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
        self.releaseKeepalive();
        self.fetch_holds = false;
        self.maybeRelease();
    }

    /// The fetch is over - its body ended, or nobody read it - after p
    /// was settled. An abort now has nothing to abort.
    fn finished(context: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(context));
        self.in_flight = null;
        self.releaseKeepalive();
        self.fetch_holds = false;
        self.maybeRelease();
    }

    /// Fetch has its response: queue the fetch task that runs
    /// processResponse (step 12) - a global task on the networking task
    /// source, given relevantRealm's global object, on its event loop (a
    /// window's, or a worker's own). A bare realm with none (a unit test's)
    /// is in the event loop's network step already, a task boundary, and
    /// settles now.
    fn done(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        const self: *Self = @ptrCast(@alignCast(context));
        // The fetch is still this call's: its body is arriving, and the
        // abort steps can still end it.
        self.outcome = outcome;
        self.queueSettle();
    }

    /// Queue the fetch task that settles p with `outcome` (or settle now, in
    /// a bare realm with no event loop).
    fn queueSettle(self: *Self) void {
        self.task_holds = true;
        if (self.ctx.getOptionalEventLoop()) |loop| {
            const window = self.taskWindow();
            loop.queueTask(.{
                .callback = settle,
                .context = self,
                .drop = drop,
                .document = window,
                .document_generation = if (window) |w| runtime.SlabAllocator.generationOf(w) else 0,
            });
            return;
        }
        settle(self);
    }

    /// The Window whose global task this call's fetch task is ("queue a
    /// global task on the networking task source given relevantRealm's
    /// global object"), or null in a worker's realm, whose tasks have no
    /// document. Naming it lets the event loop hold the task while the
    /// Window's document is not fully active - a page the back/forward cache
    /// keeps, shown again later - and drop it once that document is gone,
    /// instead of running the page's promise reactions while it is cached.
    fn taskWindow(self: *const Self) ?*runtime.Instance {
        if (!self.ctx.isWindow()) return null;
        const record = self.ctx.getRealm() orelse return null;
        return @ptrCast(@alignCast(record.global_object orelse return null));
    }

    /// The fetch task: HTML "queue a global task", its run side - it runs
    /// in the realm, which ends it (a worker's end of task too).
    fn settle(context: ?*anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(context.?));
        // The realm can end while the task waits in the queue. And
        // processResponse step 1: if locallyAborted is true, abort these
        // steps - the abort steps settled p already.
        if (!alive(self) or self.locally_aborted) return self.taskDone();
        // An error means the steps never ran (the realm is gone): the
        // task is over either way.
        engine.runTaskInRealm(self.ctx, settleSteps, self) catch {};
        self.taskDone();
    }

    fn settleSteps(data: ?*anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(data.?));
        self.processResponse();
    }

    /// processResponse, given fetch's outcome.
    fn processResponse(self: *Self) void {
        const outcome = self.outcome orelse return;
        self.outcome = null;
        var result = outcome catch return self.rejectTypeError("Failed to fetch");
        result.timing_info.deinit();
        const response = result.response;

        // Step 3: a network error rejects p with a TypeError.
        if (response.response_type == .@"error") {
            response.deinit();
            return self.rejectTypeError("Failed to fetch");
        }

        // Step 4: responseObject is the result of creating a Response
        // object given response, "immutable" and relevantRealm - the
        // filtered response main fetch made, which is all script sees. An
        // opaque one keeps its internal response (InternalResponse.filter),
        // which a service worker's respondWith() and the Cache API read.
        response.filter() catch {
            response.deinit();
            return self.rejectTypeError("Failed to fetch");
        };
        const response_object = interfaces.Response.call_constructor(self.ctx, webidl.Opt(?typedefs.BodyInit).notPassed(), webidl.Opt(dictionaries.ResponseInit).notPassed()) catch {
            response.deinit();
            return self.rejectTypeError("Failed to fetch");
        };
        if (!fetch_objects.adoptResponse(response_object, @ptrCast(response), .immutable)) {
            response.deinit();
            return self.rejectTypeError("Failed to fetch");
        }
        // The abort steps name responseObject from here: an abort after
        // this errors its body (step 11.4's "abort the fetch() call",
        // step 5) - also once this call is over, so the response carries
        // the signal itself.
        if (self.liveSignal()) |signal| _ = fetch_objects.followSignal(response_object, signal);

        // Step 5: resolve p with responseObject - its wrapper in its
        // relevant realm.
        engine.resolvePromise(&self.capability, .{ .instance = response_object }) catch {};
        self.settleResolver();
    }

    /// The fetch is done, or terminated, or never started: its body's
    /// bytes leave the fetch group (Fetch "done flag"; Blink releases them
    /// in ResourceFetcher::HandleLoaderFinish / HandleLoaderError). Once.
    fn releaseKeepalive(self: *Self) void {
        const reservation = self.keepalive_reservation orelse return;
        self.keepalive_reservation = null;
        reservation.release();
    }

    /// p is settled: its capability has done its job. Holding it longer
    /// keeps p, and through it the realm, for nothing.
    fn settleResolver(self: *Self) void {
        if (self.settled) return;
        self.settled = true;
        engine.releasePromiseCapability(&self.capability);
    }

    fn rejectTypeError(self: *Self, message: []const u8) void {
        if (self.settled) return;
        const reason = engine.createSimpleException(self.ctx, .TypeError, message) catch return self.settleResolver();
        defer reason.release();
        engine.rejectPromise(&self.capability, reason.value) catch {};
        self.settleResolver();
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

        // Step 11.4's "abort the fetch() call", step 2: cancel request's
        // body with the reason, while it is being read to be sent - the
        // stream's source hears it at once. (A body of bytes has nothing
        // script can see to cancel.)
        if (self.upload) |u| {
            self.upload = null;
            if (self.pending_request) |r| r.deinit();
            self.pending_request = null;
            const cancel_realm = streams_js.Realm.ofContext(self.ctx) catch null;
            const reason: ?streams_js.Value = if (signal) |s| blk: {
                // The getter's result is a hold of ours; the Value
                // takes its own.
                const value: engine.Owned = .{ .value = interfaces.AbortSignal.get_reason(s) catch break :blk null };
                defer value.release();
                const r = cancel_realm orelse break :blk null;
                break :blk r.fromRuntime(value.value) catch null;
            } else null;
            if (reason) |r| {
                defer streams_js.dispose(r);
                u.cancel(r);
            } else if (cancel_realm) |r| {
                const undef = r.undefinedValue() catch null;
                if (undef) |v| {
                    defer streams_js.dispose(v);
                    u.cancel(v);
                }
            }
            self.fetch_holds = false;
        }
        // The same for a stream body read as it comes (`upload_pump`): its
        // stream hears the reason now; the fetch is ended below.
        if (self.upload_pump) |pump| {
            self.upload_pump = null;
            self.cancelPump(pump, if (signal) |s| abortReasonOf(s) else null);
        }

        // Step 11.3: Abort controller with the signal's abort reason -
        // the fetch ends here, its transfer cancelled, and a body still
        // arriving errors with that reason: step 11.4's "abort the
        // fetch() call" step 5, "error response's body with error", once
        // responseObject exists, reaches the body's stream through its
        // pipe.
        if (self.in_flight) |f| {
            self.in_flight = null;
            f.terminateWith(self.abortFailure(signal));
            self.fetch_holds = false;
        }
        self.releaseKeepalive();

        // Step 11.4, step 1: reject p with the reason - a no-op once p
        // is settled.
        if (!self.settled) {
            if (signal) |s| self.rejectWithAbortReason(s);
        }
        self.maybeRelease();
    }

    /// The failure a body errors with when the fetch is aborted: the
    /// signal's abort reason, held for as long as the body needs it.
    fn abortFailure(self: *Self, signal: ?*runtime.Instance) fetch.algorithms.async_fetch.Failure {
        const s = signal orelse return .{ .kind = .aborted };
        // The getter's result is a hold of ours; AbortReason takes its own.
        const reason_value: engine.Owned = .{ .value = interfaces.AbortSignal.get_reason(s) catch return .{ .kind = .aborted } };
        defer reason_value.release();
        const held = fetch_body.AbortReason.create(self.ctx, reason_value.value) orelse return .{ .kind = .aborted };
        return .{ .kind = .aborted, .reason = held, .release_reason = fetch_body.AbortReason.release };
    }

    fn rejectWithAbortReason(self: *Self, signal: *runtime.Instance) void {
        // The getter's result is a hold of ours.
        const reason_value: engine.Owned = .{ .value = interfaces.AbortSignal.get_reason(signal) catch return };
        defer reason_value.release();
        engine.rejectPromise(&self.capability, reason_value.value) catch {};
    }

    /// `signal`'s abort reason, held by the caller.
    fn abortReasonOf(signal: *runtime.Instance) ?engine.Owned {
        return .{ .value = interfaces.AbortSignal.get_reason(signal) catch return null };
    }

    /// Cancel a stream body read as it comes (`upload_pump`) with `reason`
    /// (released here), or undefined: Fetch "abort the fetch() call" step 2.
    fn cancelPump(self: *Self, pump: *fetch_body.UploadPump, reason: ?engine.Owned) void {
        defer if (reason) |r| r.release();
        const cancel_realm = streams_js.Realm.ofContext(self.ctx) catch return;
        const value = if (reason) |r| cancel_realm.fromRuntime(r.value) catch null else cancel_realm.undefinedValue() catch null;
        const v = value orelse return;
        defer streams_js.dispose(v);
        pump.cancel(v);
    }

    /// The pump reading requestObject's stream body is gone: its body ended,
    /// failed, or nobody read it.
    fn uploadPumpEnded(context: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(context));
        self.upload_pump = null;
    }

    fn liveSignal(self: *const Self) ?*runtime.Instance {
        const signal = self.signal orelse return null;
        if (runtime.SlabAllocator.generationOf(signal) != self.signal_generation) return null;
        return signal;
    }

    /// requestObject's body is read: it is the request's body now, and
    /// the fetch starts.
    fn uploadRead(context: *anyopaque, bytes: []const u8) void {
        const self: *Self = @ptrCast(@alignCast(context));
        self.upload = null;
        const request = self.pending_request orelse return self.startFailed();
        self.pending_request = null;
        // A body made from a ReadableStream: its source is null (Fetch
        // "extract a body"), which is what HTTP-network fetch and
        // HTTP-redirect fetch ask of it. Its bytes are here already.
        const body = fetch.internal.Body.fromSource(self.allocator, .none, bytes.len) catch {
            request.deinit();
            return self.startFailed();
        };
        body.data.appendSlice(self.allocator, bytes) catch {
            body.deinit();
            request.deinit();
            return self.startFailed();
        };
        if (request.body) |old| switch (old) {
            .body => |b| b.deinit(),
            .bytes => {},
        };
        request.body = .{ .body = body };
        // The fetch owns the request from here, and frees it on failure.
        self.in_flight = fetch.algorithms.AsyncFetch.startStreaming(self.allocator, request, .{}, @import("dom").agent_fetches.of(self.ctx), self.client()) catch
            return self.startFailed();
    }

    /// requestObject's body could not be read - its stream errored, or a
    /// chunk was no Uint8Array: a network error. Or the read was dropped
    /// (`e` null): the realm is going, its stream torn down, and nothing
    /// may be made in it - p is let go unsettled, as `gone` does.
    fn uploadFailed(context: *anyopaque, e: ?streams_js.Value) void {
        const self: *Self = @ptrCast(@alignCast(context));
        self.upload = null;
        if (self.pending_request) |r| r.deinit();
        self.pending_request = null;
        if (e == null) {
            self.releaseKeepalive();
            self.settleResolver();
            self.fetch_holds = false;
            return self.maybeRelease();
        }
        self.startFailed();
    }

    /// The fetch never started: p rejects with a TypeError, as for a
    /// network error, and the fetch lets go of this call.
    fn startFailed(self: *Self) void {
        self.releaseKeepalive();
        self.rejectTypeError("Failed to fetch");
        self.fetch_holds = false;
        self.maybeRelease();
    }

    /// A task that will never run: its loop is going.
    fn drop(context: ?*anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(context.?));
        self.taskDone();
    }

    fn taskDone(self: *Self) void {
        self.task_holds = false;
        // A response the task did not adopt goes: its body with it,
        // which lets the transfer go too.
        if (self.outcome) |outcome| {
            self.outcome = null;
            var result = outcome catch null;
            if (result) |*r| r.deinit();
        }
        self.settleResolver();
        self.maybeRelease();
    }

    fn maybeRelease(self: *Self) void {
        if (self.fetch_holds or self.task_holds or self.canceling != 0) return;
        if (self.liveSignal()) |signal| abort_algorithms.remove(signal, self);
        self.signal = null;
        self.signal_pin.release();
        if (self.outcome) |outcome| {
            var result = outcome catch null;
            if (result) |*r| r.deinit();
        }
        self.settleResolver();
        self.releaseKeepalive();
        self.untrack();
        // A pump still reading the stream body outlives the call (the
        // request's pipe still has a reader): it tells nobody when it ends.
        if (self.upload_pump) |pump| pump.owner = null;
        self.upload_pump = null;
        self.allocator.destroy(self);
    }

    // Every call whose fetch is under way is on its realm's list of fetch
    // calls (runtime.ContextData objects(.fetch_calls)), for "abort a
    // document" (`abortIn`): "the fetch algorithm in the context of
    // document", its realm's. It was one list per thread, every realm's calls
    // in it, never given back.

    /// The calls of `realm` under way (BORROWED: one that ends leaves it, so a
    /// walk that can end one re-reads it).
    fn liveIn(realm: runtime.Context) []const *Self {
        return @ptrCast(realm.objects(.fetch_calls).items);
    }

    fn track(self: *Self) void {
        self.ctx.addObject(.fetch_calls, self) catch {};
    }

    fn untrack(self: *Self) void {
        self.ctx.forgetObject(.fetch_calls, self);
    }

    /// HTML "abort a document" step 2, for the fetches fetch() started in
    /// `realm` (dom.document_fetches): "cancel any instances of the fetch
    /// algorithm in the context of document, discarding any tasks queued
    /// for them, and discarding any further data received from the
    /// network for them". p never settles, and its capability - which
    /// kept the realm - goes. Blink: FetchManager::ContextDestroyed.
    fn abortIn(realm: runtime.Context) void {
        // Backwards: a cancel frees its call, which swapRemove replaces
        // with one already visited.
        var i = liveIn(realm).len;
        while (i > 0) {
            i -= 1;
            if (i >= liveIn(realm).len) continue;
            const call = liveIn(realm)[i];
            if (call.ctx != realm or call.document_aborted) continue;
            // Fetch "when a fetch group is terminated", step 1: a record
            // whose request's keepalive is true is not terminated - it is
            // meant to outlive its document (a beacon, a fetch made in
            // unload; fetch/api/redirect/redirect-keepalive.any.js).
            if (call.keepalive) continue;
            call.cancelForDocument(false);
        }
    }

    /// dom.bfcache store step, for the realm of a document the back/forward
    /// cache keeps (unload step 18): each fetch() call of that document still
    /// in flight - one its pagehide or unload listeners started, after the
    /// navigation's "abort a document" (navigate step 24.3) cancelled the
    /// others - is cancelled as a network failure, and p - or, once p was
    /// resolved, the response's body - fails with a TypeError when the page is
    /// shown again. Nothing of it reaches the page while it is cached. A
    /// keepalive fetch goes on: it is meant to outlive its document (Fetch
    /// "terminated" step 1). WebKit cancels a page's loads as it caches it
    /// (BackForwardCache::addIfCacheable -> FrameLoader::stopForBackForwardCache
    /// -> DocumentLoader::stopLoading), and a fetch so cancelled fails with
    /// "TypeError: Load failed". Its settling is a fetch task of the page's
    /// Window (`queueSettle`), so it waits with the page; a body still
    /// arriving fails through its pipe, whose stream hears it in a task of
    /// that Window too (fetch_body.PipeStream).
    fn storeInCache(realm: runtime.Context) void {
        // Backwards: a cancel can free its call, which swapRemove replaces
        // with one already visited.
        var i = liveIn(realm).len;
        while (i > 0) {
            i -= 1;
            if (i >= liveIn(realm).len) continue;
            const call = liveIn(realm)[i];
            if (call.ctx != realm or call.document_aborted or call.keepalive) continue;
            call.cancelForCache();
        }
    }

    /// `storeInCache` for this call: its fetch ends as a network failure.
    /// No script runs here: p settles in a fetch task, and the body's stream
    /// hears of its failure in one.
    fn cancelForCache(self: *Self) void {
        self.canceling += 1;
        defer {
            self.canceling -= 1;
            self.maybeRelease();
        }
        // Nothing is left for a later abort of the document to cancel.
        self.document_aborted = true;
        self.document_abort_pending = false;
        var failed = false;
        // The body being read to be sent: the fetch has not started, and now
        // never will. Its stream is cancelled with the TypeError, in the
        // realm (fetch()'s "cancel request's body with error"; the page is
        // still being unloaded, as its pagehide listeners were).
        if (self.upload) |u| {
            self.upload = null;
            if (self.pending_request) |r| r.deinit();
            self.pending_request = null;
            engine.runInRealm(self.ctx, cancelUploadForCache, u) catch {};
            self.fetch_holds = false;
            failed = true;
        }
        // A stream body read as it comes: cancelled with the same TypeError.
        if (self.upload_pump) |pump| {
            self.upload_pump = null;
            engine.runInRealm(self.ctx, cancelPumpForCache, pump) catch {};
        }
        if (self.in_flight) |f| {
            self.in_flight = null;
            // A body still arriving fails as the network failing would:
            // reading it rejects with a TypeError.
            f.terminateWith(.{ .kind = .network });
            self.fetch_holds = false;
            failed = true;
        }
        if (!failed) return;
        self.releaseKeepalive();
        // p not settled, and no settle task queued for it: its fetch task
        // settles it as a network error ("Failed to fetch", a TypeError).
        // A settle task already queued (the response arrived before the
        // page was left) settles it with that response, whose body has just
        // failed.
        if (!self.settled and !self.task_holds) {
            self.outcome = error.NetworkError;
            self.queueSettle();
        }
    }

    fn cancelPumpForCache(data: ?*anyopaque) void {
        const pump: *fetch_body.UploadPump = @ptrCast(@alignCast(data.?));
        const e = pump.realm.typeError("Failed to fetch") catch return;
        defer streams_js.dispose(e);
        pump.cancel(e);
    }

    fn cancelUploadForCache(data: ?*anyopaque) void {
        const upload: *fetch_body.ReadAll = @ptrCast(@alignCast(data.?));
        const e = upload.realm.typeError("Failed to fetch") catch return;
        defer streams_js.dispose(e);
        upload.cancel(e);
    }

    /// Navigate step 24.3's "abort a document": the document's fetch() calls
    /// are cancelled as for any live abort (marked here, failed with a
    /// TypeError by `abortDocument`) - Firefox (nsDocShell::InternalLoad's
    /// StopInternal(STOP_NETWORK)) and Safari (FrameLoader::
    /// continueLoadAfterNavigationPolicy's stopAllLoaders, which stops the
    /// current document's loader) cancel them when the navigation starts;
    /// Chrome does not. But a fetch() so cancelled does not make the document
    /// unsalvageable ("fetch", "abort a document" step 2): this reports no
    /// request marked. Chrome keeps such a page in the back/forward cache (its
    /// fetch goes on) and Safari keeps it (its cancelled loads do not block
    /// the cache); Firefox does not (wpt.fyi stable at 2358bd4835,
    /// back-forward-cache/eligibility/inflight-fetch-*.html). Golden rule 2,
    /// mechanism by mechanism - cancelled at the navigation's start (Firefox,
    /// Safari), the page kept (Chrome, Safari), a TypeError (all three) - is
    /// Safari's behaviour; the integrator's ruling, 2026-11-14 8:53 PM ET.
    /// Stated deviation from HTML "abort a document" step 2 for fetch() only:
    /// the other fetch owners still make the document unsalvageable.
    fn prepareNavigationDocumentAbort(document: *runtime.Instance) bool {
        _ = prepareDocumentAbort(document);
        return false;
    }

    /// Mark all fetch() calls before XHR/script-owner abort callbacks run.
    fn prepareDocumentAbort(document: *runtime.Instance) bool {
        var marked = false;
        for (liveIn(document.ctx)) |call| {
            if (call.document_aborted) continue;
            const owner = call.document orelse continue;
            if (owner.instance != document or !owner.isLive()) continue;
            call.document_abort_pending = true;
            marked = true;
        }
        return marked;
    }

    fn abortDocument(document: *runtime.Instance) void {
        while (true) {
            const next: ?*Self = blk: {
                for (liveIn(document.ctx)) |call| {
                    if (!call.document_abort_pending or call.document_aborted) continue;
                    const owner = call.document orelse continue;
                    if (owner.instance == document and owner.isLive()) break :blk call;
                }
                break :blk null;
            };
            const call = next orelse return;
            call.document_abort_pending = false;
            call.canceling += 1;
            // A synchronous document.open switches realms without a task
            // checkpoint. Promise reactions cannot run until script returns.
            engine.runInRealm(call.ctx, documentAbortSteps, call) catch call.cancelForDocument(false);
            call.canceling -= 1;
            call.maybeRelease();
        }
    }

    fn documentAbortSteps(context: ?*anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(context.?));
        self.cancelForDocument(true);
    }

    /// A live document's abort (window.stop(), document.open(), a
    /// navigation's start) fails the fetch as a network error: p rejects
    /// with a TypeError, and a body still arriving errors with one.
    /// Destruction discards both silently. Detach signal callbacks and
    /// network state before invoking stream cancellation.
    ///
    /// A TypeError, never an "AbortError" DOMException: the fetch was not
    /// aborted through its signal (Fetch's "abort the fetch() call") but
    /// cancelled with its document, and every browser rejects such a fetch
    /// with a TypeError - a three-browser probe (lane nav4, 2026-11-14,
    /// tmp/nav4/fetch-abort-probe-results.jsonl; Chrome 157, Firefox 159,
    /// Safari 27.0): window.stop() with the fetch pending, TypeError in all
    /// three ("Failed to fetch", "NetworkError when attempting to fetch
    /// resource.", "Load failed"); location.href then document.open(),
    /// TypeError in all three; a navigation's start, TypeError in Firefox and
    /// Safari (Chrome does not cancel then); a body still arriving at
    /// window.stop() or document.open(), TypeError in Chrome and Safari
    /// (Firefox lets the body finish). A keepalive fetch at window.stop()
    /// splits three ways (Chrome rejects with a TypeError, Firefox lets it
    /// finish, Safari leaves it pending); Crane cancels it, as Chrome, with
    /// the same TypeError.
    fn cancelForDocument(self: *Self, observable: bool) void {
        if (self.document_aborted) return;
        self.canceling += 1;
        defer {
            self.canceling -= 1;
            self.maybeRelease();
        }
        self.document_aborted = true;
        // A settle task still queued does nothing when it runs (or is
        // dropped): processResponse step 1's locallyAborted check.
        self.locally_aborted = true;
        if (self.liveSignal()) |signal| abort_algorithms.remove(signal, self);
        self.signal = null;
        const reason: ?engine.Owned = if (observable)
            engine.createSimpleException(self.ctx, .TypeError, "Failed to fetch") catch null
        else
            null;
        defer if (reason) |r| r.release();
        // Fetch "abort a fetch() call" step 1 precedes upload cancellation.
        if (!self.settled) {
            if (reason) |r| engine.rejectPromise(&self.capability, r.value) catch {};
            self.settleResolver();
        }
        // The body being read to be sent: its stream is canceled.
        if (self.upload) |u| {
            self.upload = null;
            if (self.pending_request) |r| r.deinit();
            self.pending_request = null;
            if (streams_js.Realm.ofContext(self.ctx) catch null) |r| {
                const value = if (reason) |e| r.fromRuntime(e.value) catch null else r.undefinedValue() catch null;
                if (value) |v| {
                    defer streams_js.dispose(v);
                    u.cancel(v);
                }
            }
            self.fetch_holds = false;
        }
        if (self.upload_pump) |pump| {
            self.upload_pump = null;
            if (streams_js.Realm.ofContext(self.ctx) catch null) |r| {
                const value = if (reason) |e| r.fromRuntime(e.value) catch null else r.undefinedValue() catch null;
                if (value) |v| {
                    defer streams_js.dispose(v);
                    pump.cancel(v);
                }
            }
        }
        if (self.in_flight) |f| {
            self.in_flight = null;
            // An already exposed response body fails as the network failing
            // would (a TypeError on read); a destroyed document's body is
            // only ended.
            f.terminateWith(.{ .kind = if (observable) .network else .aborted });
            self.fetch_holds = false;
        }
        self.releaseKeepalive();
        self.settleResolver();
    }
};

/// The hooks this mixin owns (src/dom), installed once, at process start,
/// by crane.Process through the generated mixin module (docs/instances.md):
/// "abort a document" reaches fetch()'s calls through their realm's list (`FetchCall.liveIn`).
pub fn installHooks() void {
    @import("dom").extract_origin.install(.global, .{ .owns = &ownsOriginExtraction, .extract = &extractOrigin });
    @import("dom").document_fetches.install(.{
        .discard = &FetchCall.abortIn,
        .prepare_abort = &FetchCall.prepareDocumentAbort,
        .abort = &FetchCall.abortDocument,
        .prepare_navigation_document_abort = &FetchCall.prepareNavigationDocumentAbort,
    });
    // A page the back/forward cache keeps: its fetches in flight end as
    // network failures (Safari's behaviour; FetchCall.storeInCache).
    @import("dom").bfcache.installStoreStep(&FetchCall.storeInCache);
}

fn ownsOriginExtraction(instance: *runtime.Instance) bool {
    return global_settings.of(instance) != null;
}

/// WindowOrWorkerGlobalScope extract-an-origin steps 1-2. Read the
/// settings object's origin, never derive a Window's origin from its URL.
fn extractOrigin(instance: *runtime.Instance) !?*@import("dom").origin_record.OriginRecord {
    if (engine.entryRealm()) |entry| {
        const realm = entry.getRealm() orelse return null;
        const global: *runtime.Instance = @ptrCast(@alignCast(realm.global_object orelse return null));
        if (!global_settings.sameOriginDomain(instance, global)) return null;
    }
    if (try global_settings.shareableOriginOf(instance)) |record| return record.retain();
    // Globals without a record hook still expose their serialized origin.
    // Stable opaque worker identity depends on WorkerGlobalScope installing
    // its origin_record hook (row 45 ANSWER Q5; workers4 owns that change).
    const settings = global_settings.of(instance) orelse return null;
    const serialized = try settings.origin(instance);
    defer instance.ctx.allocator.free(serialized);
    return try @import("dom").origin_record.OriginRecord.create(instance.ctx.allocator, serialized);
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
    const keepalive_fetch = @import("dom").keepalive_fetch;
    const allocator = instance.ctx.allocator;

    const Call = FetchCall;

    // Step 8: relevantRealm, this's relevant realm.
    const realm = try streams_js.Realm.of(instance);

    // Step 1: Let p be a new promise.
    var capability = try engine.createPromise(instance.ctx);
    // What this call returns: p, held now, before anything can settle p and
    // release the capability (and its view of p) - a body read to the end
    // inside this call does. Handed to the binding with the result; kept, it
    // pinned the page.
    const p = engine.retainValue(instance.ctx, capability.promise) catch |err| {
        engine.releasePromiseCapability(&capability);
        return err;
    };
    errdefer p.release();
    // The capability is released here unless the fetch takes it.
    var capability_taken = false;
    defer if (!capability_taken) engine.releasePromiseCapability(&capability);

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
            rejectWithTypeError(instance.ctx, &capability, "Failed to execute 'fetch': the Request could not be constructed.");
            return p.take();
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
        // The getter's result is a hold of ours; the Value takes its own.
        const reason_value: engine.Owned = .{ .value = try interfaces.AbortSignal.get_reason(signal) };
        defer reason_value.release();
        const reason = try realm.fromRuntime(reason_value.value);
        defer streams_js.dispose(reason);
        // "Abort the fetch() call" step 1: reject p; step 2: cancel
        // request's body, if it is readable.
        engine.rejectPromise(&capability, reason.value) catch {};
        if (fetch_objects.requestBodyStream(request_object)) |stream| fetch_body.cancelStream(realm, stream, reason);
        return p.take();
    }

    // Steps 5-6: no ServiceWorkerGlobalScope exists here.
    // Steps 9-11 are added to requestObject's signal below, once the fetch -
    // step 12's controller - exists for them to abort. Nothing can run in
    // between.

    // Step 12: fetch request. The fetch outlives this call, and requestObject
    // may not, so it fetches a clone: nothing script can observe tells the
    // two apart, since the fetch changes only request's current URL.
    const fetched_request = try request.clone();
    // Fetch "populate request from client": the request's client is this
    // global's settings object.
    populateRequestFromClient(instance, fetched_request) catch {
        fetched_request.deinit();
        return error.OutOfMemory;
    };
    const call = allocator.create(Call) catch {
        fetched_request.deinit();
        return error.OutOfMemory;
    };
    // Fetch HTTP-network-or-cache fetch step 8.10: a keepalive request's
    // body and the keepalive bodies in flight in its client's fetch group
    // may not exceed 64 KiB, or the fetch is a network error - p rejects
    // with a TypeError. Reserved as the fetch starts and held until it is
    // done, as the browsers count (dom.keepalive_fetch.Reservation.take).
    const keepalive_reservation = keepalive_fetch.Reservation.take(instance, fetched_request, .fetch) catch {
        fetched_request.deinit();
        allocator.destroy(call);
        rejectWithTypeError(instance.ctx, &capability, "Failed to fetch");
        return p.take();
    };
    call.* = .{
        .allocator = allocator,
        .ctx = instance.ctx,
        .capability = capability,
        .keepalive = fetched_request.keepalive,
        .keepalive_reservation = keepalive_reservation,
        .document = if (fetchDocument(instance.ctx)) |document| same_object.Link.to(document) else null,
    };
    // Only HTTP(S) transmits a request body (HTTP-network fetch); a data:,
    // blob: or about: fetch never reads it, so neither does this - a stream
    // that never closes must not hold such a fetch up.
    const url = fetched_request.getUrl();
    const transmits_body = std.ascii.startsWithIgnoreCase(url, "http:") or std.ascii.startsWithIgnoreCase(url, "https:");
    const body_stream = if (transmits_body) fetch_objects.requestBodyStream(request_object) else null;
    if (body_stream != null and offeredToServiceWorker(fetched_request)) {
        // A service worker is asked to handle the request (HTTP fetch step
        // 3): its fetch event's request.body is a stream of the bytes as the
        // page's stream gives them (step 3.2's tee, service_worker_fetch.
        // Upload), so the fetch starts now, its body a pipe the stream is
        // read into as it comes (fetch_body.UploadPump). Waiting for the
        // whole body first left a stream that never closes - an upload the
        // worker cancels - with a fetch that never started
        // (service-workers/service-worker/fetch-request-body-cancel.https.html).
        // Should the network get the request after all (no worker handles
        // it, or it falls back), HTTP fetch step 4 waits for the bytes then.
        const started = fetch_body.UploadPump.start(allocator, realm, body_stream.?, .{ .context = call, .ended = Call.uploadPumpEnded }) catch {
            fetched_request.deinit();
            call.releaseKeepalive();
            allocator.destroy(call);
            rejectWithTypeError(instance.ctx, &capability, "Failed to fetch");
            return p.take();
        };
        // A stream's body: no source, its bytes through the pipe.
        const body = fetch.internal.Body.fromPipe(allocator, started.pipe) catch {
            started.pipe.release();
            fetched_request.deinit();
            call.releaseKeepalive();
            allocator.destroy(call);
            rejectWithTypeError(instance.ctx, &capability, "Failed to fetch");
            return p.take();
        };
        if (fetched_request.body) |old| switch (old) {
            .body => |b| b.deinit(),
            .bytes => {},
        };
        fetched_request.body = .{ .body = body };
        call.upload_pump = started.pump;
        call.in_flight = fetch.algorithms.AsyncFetch.startStreaming(allocator, fetched_request, .{}, @import("dom").agent_fetches.of(instance.ctx), call.client()) catch {
            // The fetch owned the request, and freed it - its pipe with it,
            // which leaves the pump to cancel the stream in a task.
            call.releaseKeepalive();
            if (call.upload_pump) |pump| pump.owner = null;
            call.upload_pump = null;
            allocator.destroy(call);
            rejectWithTypeError(instance.ctx, &capability, "Failed to fetch");
            return p.take();
        };
    } else if (body_stream) |stream| {
        // The body's bytes are only in its stream: read them first (the
        // read starts below, once the abort steps can reach it).
        call.pending_request = fetched_request;
        call.upload = fetch_body.ReadAll.start(allocator, realm, stream, call, Call.uploadRead, Call.uploadFailed) catch {
            fetched_request.deinit();
            call.releaseKeepalive();
            allocator.destroy(call);
            rejectWithTypeError(instance.ctx, &capability, "Failed to fetch");
            return p.take();
        };
    } else {
        call.in_flight = fetch.algorithms.AsyncFetch.startStreaming(allocator, fetched_request, .{}, @import("dom").agent_fetches.of(instance.ctx), call.client()) catch {
            // The fetch owned the request, and freed it.
            call.releaseKeepalive();
            allocator.destroy(call);
            rejectWithTypeError(instance.ctx, &capability, "Failed to fetch");
            return p.take();
        };
    }
    capability_taken = true;
    // "Abort a document" reaches the call from here (dom.document_fetches).
    call.track();

    // Step 11: Add the abort steps to requestObject's signal. Without them
    // the call still settles; it just cannot be aborted.
    if (abort_algorithms.add(signal, .{ .ctx = call, .run = Call.aborted })) {
        call.signal = signal;
        call.signal_generation = runtime.SlabAllocator.generationOf(signal);
        call.signal_pin.hold(signal);
    } else |err| {
        std.log.scoped(.fetch).warn("fetch(): abort steps not added: {s}", .{@errorName(err)});
    }

    // Read the body to send. It may be read - and the fetch started, or p
    // rejected and the call freed - before this returns: `call` is not
    // touched after.
    if (call.upload) |u| u.begin() else if (call.upload_pump) |pump| pump.begin();

    // Step 13.
    return p.take();
}

/// Whether HTTP fetch step 3 will ask a service worker to handle `request`:
/// its service-workers mode is "all" and its client is controlled - "populate
/// request from client" gave it a route to its Browser's service workers
/// only then (service_worker_fetch.Route). Handle Fetch may still return
/// null (no fetch event handler, a router rule), sending it to the network.
fn offeredToServiceWorker(request: *const fetch.internal.InternalRequest) bool {
    return request.service_workers_mode == .all and request.service_worker != null;
}

/// Fetch "populate request from client", for a request whose client is
/// `global`'s settings object.
fn populateRequestFromClient(global: *runtime.Instance, request: *@import("fetch").internal.InternalRequest) !void {
    var client = try global_settings.requestClient(global);
    defer client.deinit();
    try @import("fetch").internal.populateRequestFromClient(request, client.request);
}

/// Request-start document of a Window; workers have no associated document.
fn fetchDocument(ctx: runtime.Context) ?*runtime.Instance {
    const record = ctx.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return interfaces.Window.get_document(global) catch null;
}

fn rejectWithTypeError(realm: runtime.Context, capability: *engine.PromiseCapability, message: []const u8) void {
    const reason = engine.createSimpleException(realm, .TypeError, message) catch return;
    defer reason.release();
    engine.rejectPromise(capability, reason.value) catch {};
}
