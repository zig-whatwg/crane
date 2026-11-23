//! Implementation for OffscreenCanvas interface
//!
//! HTML 4.12.5.3: a canvas with no connection to the DOM, usable in workers.
//! It has a bitmap of its width and height - transparent black until a 2d
//! context draws on it; the context's output bitmap IS its bitmap once one
//! is made ("so that they are shared") - and a context mode: none, 2d, or
//! detached once transferred. The bitmaprenderer, webgl, webgl2 and webgpu
//! contexts are not modelled: getContext answers null for them, as for any
//! context it cannot make (the canvas element's getContext does the same).
//!
//! It is [Transferable]: its transfer steps hand its dimensions, inherited
//! language and direction to a data holder (dom.image_bitmaps.CanvasHolder,
//! run by the one shared transfer step, dom.transferables), whose
//! transfer-receiving steps make a new OffscreenCanvas from them in the
//! receiving realm (`construction_args`: `transferred`).
//!
//! Spec: https://html.spec.whatwg.org/multipage/canvas.html#the-offscreencanvas-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const engine = @import("engine");
const dom = @import("dom");
const html = @import("html");
const same_object = dom.same_object;
const OffscreenCanvas = interfaces.OffscreenCanvas;
const CanvasHolder = dom.image_bitmaps.CanvasHolder;

pub const State = OffscreenCanvas.State;

pub const ImplError = error{
    NotImplemented,
};

/// The transfer-receiving steps' data holder, given at construction.
pub const construction_args = .{"transferred"};

/// HTML 4.12.5.3 "context mode" - of the modes the spec names, those this
/// canvas can be in.
const ContextMode = enum { none, @"2d", detached };

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The bitmap's dimensions: the width and height attributes.
    width: u64 = 0,
    height: u64 = 0,
    mode: ContextMode = .none,
    /// The 2d context, made once and handed out by every getContext("2d");
    /// kept for as long as this canvas's wrapper lives (same_object), as
    /// the canvas element keeps its context.
    context_kept: same_object.KeptChild = .{},
    /// The inherited language: null is "explicitly unknown". OWNED.
    language: ?[]u8 = null,
    /// The inherited direction.
    direction: CanvasHolder.Direction = .ltr,

    fn context(self: *const InternalState) ?*runtime.Instance {
        return self.context_kept.get();
    }
};

const context_slot: engine.TracedSlot = .{ .name = "getContext" };

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// OffscreenCanvas's own construction steps (the generated chain runs
/// EventTarget's first). `args.transferred`, when given, is the data holder
/// of the transfer-receiving steps: taken on success only.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    if (comptime @hasField(@TypeOf(args), "transferred")) {
        const holder: *CanvasHolder = args.transferred;
        // Transfer-receiving steps: 1. a bitmap of [[Width]] x [[Height]],
        // transparent black; 2. the inherited language and direction.
        internal.width = holder.width;
        internal.height = holder.height;
        internal.language = holder.language;
        holder.language = null;
        internal.direction = holder.direction;
        // 3. [[PlaceholderCanvas]] is null: none is ever made here.
        holder.destroy();
    }
    instance.getState(State).own._internal = internal;
}

/// OffscreenCanvas's own teardown: its 2d context, if it is still the one
/// it made, loses its state (script that still holds it gets
/// InvalidStateError), as the canvas element's does.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.stateAs(State) orelse return;
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    if (internal.context()) |made| internal.context_kept.releaseOwned(made);
    if (internal.language) |language| internal.allocator.free(language);
    internal.allocator.destroy(internal);
}

/// The steps with no IDL member: its bitmap as an image source (HTML
/// 4.12.5.1.9) and its transfer and transfer-receiving steps.
pub fn installHooks() void {
    dom.image_sources.installOffscreenCanvas(usability);
    dom.image_bitmaps.installOffscreenCanvas(.{ .state = transferableState, .transfer = transferSteps, .receive = transferReceivingSteps });
}

/// HTML "check the usability of the image argument" for an OffscreenCanvas:
/// "If image has either a horizontal dimension or a vertical dimension
/// equal to zero, then throw an InvalidStateError" - a detached one has no
/// bitmap, so its dimensions are zero too. Its bitmap is its 2d context's
/// output bitmap; with no context it is transparent black (no pixels kept:
/// `pixels` empty).
fn usability(instance: *runtime.Instance) dom.image_sources.Usability {
    const internal = getInternal(instance) orelse return .invalid_state;
    if (internal.mode == .detached or internal.width == 0 or internal.height == 0) return .invalid_state;
    if (internal.context()) |made| if (dom.image_sources.outputBitmap(made)) |bitmap| return .{ .good = .{
        .width = bitmap.width,
        .height = bitmap.height,
        .pixels = bitmap.pixels,
        .alpha = .premultiplied,
        .origin_clean = bitmap.origin_clean,
    } };
    if (internal.width > std.math.maxInt(u32) or internal.height > std.math.maxInt(u32)) return .invalid_state;
    return .{ .good = .{ .width = @intCast(internal.width), .height = @intCast(internal.height), .pixels = &.{}, .alpha = .premultiplied, .origin_clean = true } };
}

/// new OffscreenCanvas(width, height).
pub fn call_constructor(ctx: runtime.Context, width: u64, height: u64) !*runtime.Instance {
    const instance = try OffscreenCanvas.init(ctx.allocator, ctx);
    errdefer OffscreenCanvas.deinit(instance);
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // 1-3. A transparent black bitmap of width x height (nothing to store
    //      until a context draws), and the width and height.
    internal.width = width;
    internal.height = height;
    // 4-5. Inherited language "explicitly unknown", direction "ltr".
    // 6-7. A Window's document element gives its language and
    //      directionality instead.
    if (documentElementOf(ctx)) |element| {
        const language = dom.selector_matching.languageOf(dom.instance_bridge.getNodeBase(element) orelse return instance);
        internal.language = try ctx.allocator.dupe(u8, language);
        internal.direction = switch (html.form_associated.directionality(element)) {
            .ltr => .ltr,
            .rtl => .rtl,
        };
    }
    return instance;
}

/// The document element of the associated Document of `ctx`'s global, when
/// that global is a Window (constructor steps 6-7).
fn documentElementOf(ctx: runtime.Context) ?*runtime.Instance {
    if (!ctx.isWindow()) return null;
    const record = ctx.getRealm() orelse return null;
    const object = record.global_object orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(object));
    const document = interfaces.Window.get_document(global) catch return null;
    return interfaces.Document.get_documentElement(document) catch null;
}

/// Getter for width: the bitmap's width.
pub fn get_width(instance: *runtime.Instance) anyerror!u64 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.width;
}

/// Getter for height: the bitmap's height.
pub fn get_height(instance: *runtime.Instance) anyerror!u64 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.height;
}

/// Setter for width: "replace the bitmap with a new, transparent black
/// bitmap of the specified dimensions"; in the 2d mode, "reset the rendering
/// context to its default state and resize the OffscreenCanvas object's
/// bitmap to the new values of the width and height attributes".
pub fn set_width(instance: *runtime.Instance, value: u64) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.width = value;
    try resized(internal);
}

/// Setter for height, as width.
pub fn set_height(instance: *runtime.Instance, value: u64) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.height = value;
    try resized(internal);
}

fn resized(internal: *InternalState) !void {
    if (internal.mode != .@"2d") return;
    const made = internal.context() orelse return;
    try dom.canvas_2d.resizeOffscreen(made, internal.width, internal.height);
}

/// Operation: getContext (HTML 4.12.5.3).
///
/// 1-2. options is converted to a JavaScript value: it arrives as one.
/// 3. The table's cell for this canvas's context mode and contextId:
///    - "2d" in none: the offscreen 2D context creation algorithm given
///      this and options, then the mode is 2d; in 2d: the same object as
///      last time.
///    - "bitmaprenderer", "webgl", "webgl2", "webgpu": the contexts are not
///      modelled - null, the answer the spec gives a context that cannot be
///      created ("webgl"/"webgpu": "If context is null, then return null").
///    - any contextId in detached: an InvalidStateError.
///
/// The settings (alpha, colorSpace, willReadFrequently) are not modelled,
/// stated, as for the canvas element's context: an sRGB unorm8 context with
/// alpha.
pub fn call_getContext(instance: *runtime.Instance, contextId: enums.OffscreenRenderingContextId, options: webidl.Opt(runtime.JSValue)) anyerror!?typedefs.OffscreenRenderingContext {
    _ = options;
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.mode == .detached) return error.InvalidStateError;
    switch (contextId) {
        ._2d_ => {},
        ._bitmaprenderer_, ._webgl_, ._webgl2_, ._webgpu_ => return null,
    }
    switch (internal.mode) {
        .none => {
            // The offscreen 2D context creation algorithm: a new context
            // whose associated OffscreenCanvas is this, with an output
            // bitmap of this's width and height.
            const made = try interfaces.OffscreenCanvasRenderingContext2D.initWith(instance.ctx.allocator, instance.ctx, .{
                .offscreen_canvas = instance,
                .width = internal.width,
                .height = internal.height,
            });
            internal.context_kept.made(made);
            internal.mode = .@"2d";
        },
        .@"2d" => {},
        .detached => unreachable,
    }
    const made = internal.context() orelse return null;
    internal.context_kept.handOut(instance, made, context_slot);
    return .{ .offscreen_canvas_rendering_context2d = made };
}

/// Operation: transferToImageBitmap (HTML 4.12.5.3).
pub fn call_transferToImageBitmap(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // 1. "If the value of this OffscreenCanvas object's [[Detached]]
    //    internal slot is set to true, then throw an InvalidStateError".
    if (internal.mode == .detached) return error.InvalidStateError;
    // 2. "If this OffscreenCanvas object's context mode is set to none, then
    //    throw an InvalidStateError".
    if (internal.mode == .none) return error.InvalidStateError;
    const made = internal.context() orelse return error.InvalidStateError;
    const output = dom.image_sources.outputBitmap(made) orelse return error.InvalidStateError;
    // 3. "Let image be a newly created ImageBitmap object that references
    //    the same underlying bitmap data as this OffscreenCanvas object's
    //    bitmap."
    const allocator = instance.ctx.allocator;
    const bitmap = try dom.image_bitmaps.Bitmap.create(allocator, output.width, output.height);
    @memcpy(bitmap.pixels, output.pixels);
    bitmap.origin_clean = output.origin_clean;
    const image = interfaces.ImageBitmap.initWith(allocator, instance.ctx, .{ .bitmap = bitmap }) catch |err| {
        bitmap.destroy();
        return err;
    };
    // 4. "Set this OffscreenCanvas object's bitmap to reference a newly
    //    created bitmap of the same dimensions and color space as the
    //    previous bitmap, and with its pixels initialized to transparent
    //    black" (the context's alpha is true). The context's drawing state
    //    is not reset: only its bitmap is replaced.
    @memset(output.pixels, 0);
    output.origin_clean = true;
    // 5.
    return image;
}

/// Operation: convertToBlob (HTML 4.12.5.3).
///
/// Step 7's serialization runs on the agent's thread before the call
/// returns, as the canvas element's toBlob does (stated there); the task
/// that settles the promise is still queued, so script sees the same order.
pub fn call_convertToBlob(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ImageEncodeOptions)) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // 1. "If the value of this's [[Detached]] internal slot is true, then
    //    return a promise rejected with an InvalidStateError".
    if (internal.mode == .detached) return error.InvalidStateError;
    const output: ?*dom.image_sources.OutputBitmap = if (internal.context()) |made| dom.image_sources.outputBitmap(made) else null;
    // 2. "If this's context mode is 2d and the rendering context's output
    //    bitmap's origin-clean flag is set to false, then return a promise
    //    rejected with a SecurityError".
    if (output) |bitmap| if (!bitmap.origin_clean) return error.SecurityError;
    // 3. "If this's bitmap has no pixels (i.e., either its horizontal
    //    dimension or its vertical dimension is zero), then return a promise
    //    rejected with an IndexSizeError".
    if (internal.width == 0 or internal.height == 0) return error.IndexSizeError;
    if (internal.width > std.math.maxInt(u32) or internal.height > std.math.maxInt(u32)) return error.IndexSizeError;
    // 4. "Let bitmap be a copy of this's bitmap."
    const bitmap: dom.bitmap_serialization.Bitmap = if (output) |b|
        .{ .width = b.width, .height = b.height, .pixels = b.pixels }
    else
        .{ .width = @intCast(internal.width), .height = @intCast(internal.height), .pixels = null };
    const given = options.getOrDefault(.{});
    const allocator = instance.ctx.allocator;
    // 7.1. "Let file be a serialization of bitmap as a file, with options's
    //      type and quality if present."
    const quality: ?f64 = if (given.quality) |q| (if (q >= 0.0 and q <= 1.0) q else null) else null;
    const requested_type: []const u8 = if (given.type) |t| t.asSlice() else "image/png";
    const file = dom.bitmap_serialization.serialize(allocator, bitmap, requested_type, quality);
    // 5. "Let result be a new promise object."
    var promise = try engine.createPromise(instance.ctx);
    errdefer engine.releasePromiseCapability(&promise);
    const result = try engine.retainValue(instance.ctx, promise.promise);
    errdefer result.release();
    // 7.2. "Queue a global task on the canvas blob serialization task source
    //      given global" to settle it.
    try BlobTask.queue(instance, promise, file);
    // 8.
    return result.take();
}

/// convertToBlob step 7.2's global task.
const BlobTask = struct {
    allocator: std.mem.Allocator,
    realm: runtime.Context,
    capability: engine.PromiseCapability,
    /// The serialization, OWNED; null when it failed.
    file: ?dom.bitmap_serialization.File,

    fn queue(instance: *runtime.Instance, capability: engine.PromiseCapability, file: ?dom.bitmap_serialization.File) !void {
        const allocator = instance.ctx.allocator;
        const task = allocator.create(BlobTask) catch |err| {
            if (file) |f| f.deinit(allocator);
            return err;
        };
        task.* = .{ .allocator = allocator, .realm = instance.ctx, .capability = capability, .file = file };
        const loop = instance.ctx.getOptionalEventLoop() orelse {
            run(task);
            return;
        };
        queueGlobalTask(instance, loop, .{ .callback = run, .context = task, .drop = drop });
    }

    fn run(data: ?*anyopaque) void {
        const self: *BlobTask = @ptrCast(@alignCast(data.?));
        defer self.deinit();
        engine.runTaskInRealm(self.realm, steps, self) catch {};
    }

    fn steps(data: ?*anyopaque) void {
        const self: *BlobTask = @ptrCast(@alignCast(data.?));
        const file = &(self.file orelse {
            // 7.2.1. "If file is null, then reject result with an
            //        EncodingError DOMException."
            const exception = engine.createDOMException(self.realm, "EncodingError", "The canvas could not be serialized.") catch return;
            defer exception.release();
            engine.rejectPromise(&self.capability, exception.value) catch {};
            return;
        });
        // 7.2.2. "Otherwise, resolve result with a new Blob object, created
        //        in global's relevant realm, representing file."
        const blob = dom.blob_bytes.create(self.realm, file.bytes, file.mime()) catch return;
        // Wrapped by the resolution, the Blob is its wrapper's; never
        // wrapped, it is ours.
        const generation = runtime.SlabAllocator.generationOf(blob);
        defer runtime.Instance.releaseIfUnwrapped(blob, generation);
        engine.resolvePromise(&self.capability, .{ .instance = blob }) catch {};
    }

    fn drop(data: ?*anyopaque) void {
        const self: *BlobTask = @ptrCast(@alignCast(data.?));
        self.deinit();
    }

    fn deinit(self: *BlobTask) void {
        engine.releasePromiseCapability(&self.capability);
        if (self.file) |f| f.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

/// HTML "queue a global task" given `instance`'s relevant global, on `loop`
/// (its realm's): a Window's names the Window as the task's document, so the
/// window loop runs it only while the Window's Document is fully active. A
/// worker's realm has no Document: its loop runs every task.
fn queueGlobalTask(instance: *runtime.Instance, loop: runtime.EventLoop, task: runtime.EventLoopTask) void {
    var global_task = task;
    if (instance.ctx.isWindow()) {
        if (instance.ctx.getRealm()) |record| if (record.global_object) |object| {
            const global: *runtime.Instance = @ptrCast(@alignCast(object));
            global_task.document = global;
            global_task.document_generation = runtime.SlabAllocator.generationOf(global);
        };
    }
    loop.queueTask(global_task);
}

// ============================================================================
// Transferable objects (HTML 2.7.2): OffscreenCanvas is [Transferable]
// ============================================================================

/// Whether `instance` is an OffscreenCanvas, and its [[Detached]] (its
/// context mode is detached).
fn transferableState(instance: *runtime.Instance) runtime.TransferableState {
    const internal = getInternal(instance) orelse return .not_transferable;
    return if (internal.mode == .detached) .detached else .transferable;
}

/// HTML 4.12.5.3, OffscreenCanvas's transfer steps, given `value` and
/// `dataHolder`.
fn transferSteps(instance: *runtime.Instance) anyerror!*CanvasHolder {
    const internal = getInternal(instance) orelse return error.DataCloneError;
    // 1. "If value's context mode is not equal to none, then throw an
    //    InvalidStateError DOMException."
    if (internal.mode != .none) return error.InvalidStateError;
    const allocator = instance.ctx.allocator;
    const holder = try allocator.create(CanvasHolder);
    // 3-4, 6-7. [[Width]], [[Height]], [[Language]], [[Direction]].
    holder.* = .{
        .allocator = allocator,
        .width = internal.width,
        .height = internal.height,
        .language = internal.language,
        .direction = internal.direction,
    };
    internal.language = null;
    // 2. "Set value's context mode to detached." 5. "Unset value's bitmap."
    // (8: no placeholder canvas element.)
    internal.mode = .detached;
    internal.width = 0;
    internal.height = 0;
    return holder;
}

/// HTML 4.12.5.3, OffscreenCanvas's transfer-receiving steps, given
/// `dataHolder` and `value` - a new OffscreenCanvas of `realm`. The holder
/// is taken, also on failure.
fn transferReceivingSteps(realm: runtime.Context, holder: *CanvasHolder) anyerror!*runtime.Instance {
    return OffscreenCanvas.initWith(realm.allocator, realm, .{ .transferred = holder }) catch |err| {
        holder.destroy();
        return err;
    };
}
