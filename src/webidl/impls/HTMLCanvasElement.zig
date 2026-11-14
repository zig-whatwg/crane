//! Implementation for HTMLCanvasElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLCanvasElement = interfaces.HTMLCanvasElement;
const engine = @import("engine");
const dom = @import("dom");
const same_object = @import("same_object.zig");
const reflection = @import("dom").reflection;

const log = std.log.scoped(.html_canvas);

pub const State = HTMLCanvasElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// HTML 4.12.5: the canvas context mode (placeholder, bitmaprenderer,
/// webgl, webgl2 and webgpu are not modelled: getContext answers null for
/// them).
const ContextMode = enum { none, @"2d" };

/// A canvas's context mode and its rendering context. Its bitmap is the
/// context's output bitmap ("they are shared", the 2D context creation
/// algorithm step 4); with no context it is transparent black of the
/// width and height attributes' size, which nothing stores.
///
/// A block of the Browser's runtime arena, made with the element: it owns
/// nothing beyond itself (the context is a child its wrapper keeps), so a
/// canvas removed from its tree while nothing wrapped it - an orphan nothing
/// deinits - leaves its block to the arena's end. A block of its own leaked
/// once per orphaned canvas (lane orphanleak, crane/cl-orphan-canvas.html;
/// dom.orphan_states).
pub const InternalState = struct {
    mode: ContextMode = .none,
    /// The 2D context, made once and handed out by every getContext("2d").
    context: ?*runtime.Instance = null,
    /// The canvas keeps its context for as long as its wrapper lives (a
    /// traced edge: same_object.KeptChild), as Blink's
    /// HTMLCanvasElement::Trace visits context_.
    context_kept: same_object.KeptChild = .{},
};

fn internalOf(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The context's edge from its canvas.
const context_slot: engine.TracedSlot = .{ .name = "getContext" };

/// The width and height content attributes' numeric values: the rules for
/// parsing non-negative integers, with the defaults 300 and 150 for a
/// missing or erroneous value - as their reflection reads them (a value
/// above 2147483647 is the default too).
fn bitmapSize(instance: *runtime.Instance) struct { u32, u32 } {
    const width = reflection.get(u32, instance, .{ .name = "width", .default = 300 }) catch 300;
    const height = reflection.get(u32, instance, .{ .name = "height", .default = 150 }) catch 150;
    return .{ width, height };
}

/// HTMLCanvasElement's own construction steps: the generated chain runs
/// HTMLElement's first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    _ = allocator;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{};
    instance.getState(State).own._internal = internal;
}

/// HTMLCanvasElement's own teardown: the generated chain runs HTMLElement's
/// after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    if (instance.stateAs(State)) |state| if (state.own._internal) |internal| {
        // The context, if it is still the one this canvas made, loses its
        // state: script that still holds it gets InvalidStateError.
        if (internal.context) |context| internal.context_kept.releaseOwned(context);
        state.own._internal = null;
        runtime.arenaOf(instance).destroy(InternalState, internal);
    };
}

/// The hooks this type owns: its width and height attributes' change steps
/// (they set the bitmap dimensions), and its bitmap as a 2D context's image
/// source.
pub fn installHooks() void {
    dom.attribute_change_steps.install("canvas", &attributeChangeSteps);
    dom.image_sources.installCanvasElement(canvasUsability);
}

/// "Whenever the width and height content attributes are set, removed,
/// changed, or redundantly set to the value they already have": in the 2d
/// context mode, set bitmap dimensions to their numeric values; in none, do
/// nothing.
fn attributeChangeSteps(element: *runtime.Instance, local_name: []const u8, old_value: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    _ = .{ old_value, value };
    if (namespace != null) return;
    if (!std.mem.eql(u8, local_name, "width") and !std.mem.eql(u8, local_name, "height")) return;
    const internal = internalOf(element) orelse return;
    if (internal.mode != .@"2d") return;
    const context = internal.context orelse return;
    const width, const height = bitmapSize(element);
    dom.image_sources.setBitmapDimensions(context, width, height) catch {};
}

/// HTML "check the usability of the image argument" for a canvas: a zero
/// dimension is an InvalidStateError; otherwise its bitmap.
fn canvasUsability(instance: *runtime.Instance) dom.image_sources.Usability {
    const width, const height = bitmapSize(instance);
    if (width == 0 or height == 0) return .invalid_state;
    const internal = internalOf(instance) orelse return .bad;
    if (internal.mode == .@"2d") if (internal.context) |context| if (dom.image_sources.outputBitmap(context)) |bitmap| {
        return .{ .good = .{
            .width = bitmap.width,
            .height = bitmap.height,
            .pixels = bitmap.pixels,
            .alpha = .premultiplied,
            .origin_clean = bitmap.origin_clean,
        } };
    };
    // No context: a transparent black bitmap, whose drawing changes no
    // pixel and keeps the target origin-clean - nothing to draw.
    return .bad;
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try HTMLCanvasElement.init(ctx.allocator, ctx);
    errdefer HTMLCanvasElement.deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for width: it reflects the width content attribute, default 300.
pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
    return bitmapSize(instance)[0];
}

/// Getter for height: it reflects the height content attribute, default 150.
pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
    return bitmapSize(instance)[1];
}

/// Setter for width: reflection of an unsigned long with the default 300 -
/// a value above 2147483647 sets the default. The attribute's change steps
/// set the bitmap dimensions.
pub fn set_width(instance: *runtime.Instance, value: u32) anyerror!void {
    try reflection.set(u32, instance, .{ .name = "width", .default = 300 }, value);
}

/// Setter for height: as width's, with the default 150.
pub fn set_height(instance: *runtime.Instance, value: u32) anyerror!void {
    try reflection.set(u32, instance, .{ .name = "height", .default = 150 }, value);
}

/// Operation: captureStream
pub fn call_captureStream(instance: *runtime.Instance, frameRequestRate: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = frameRequestRate;
    return error.NotImplemented;
}

/// Operation: getContext
/// Returns a rendering context for the canvas, or null if the contextId is not supported.
/// Per HTML spec: https://html.spec.whatwg.org/multipage/canvas.html#dom-canvas-getcontext
///
/// Not modelled, stated: `options` (the CanvasRenderingContext2DSettings:
/// alpha, colorSpace, colorType, willReadFrequently - a context is an opaque-
/// capable sRGB unorm8 one), and the other context types, which answer null
/// as an unsupported value does.
pub fn call_getContext(instance: *runtime.Instance, contextId: runtime.DOMString, options: webidl.Opt(runtime.JSValue)) anyerror!?typedefs.RenderingContext {
    _ = options;
    const internal = internalOf(instance) orelse return error.InvalidStateError;
    if (!std.mem.eql(u8, contextId.asSlice(), "2d")) return null;
    switch (internal.mode) {
        // "2d" in the none mode: the 2D context creation algorithm, then the
        // mode is 2d.
        .none => {
            const context = try interfaces.CanvasRenderingContext2D.init(instance.ctx.allocator, instance.ctx);
            errdefer interfaces.CanvasRenderingContext2D.deinit(context);
            const width, const height = bitmapSize(instance);
            try dom.image_sources.attachContext(context, instance, width, height);
            internal.context = context;
            internal.context_kept.made(context);
            internal.mode = .@"2d";
        },
        // "Return the same object as was returned the last time the method
        // was invoked with this same first argument."
        .@"2d" => {},
    }
    const context = internal.context orelse return null;
    internal.context_kept.handOut(instance, context, context_slot);
    return typedefs.RenderingContext{ .canvas_rendering_context2d = context };
}

/// This canvas element's bitmap: its 2D context's output bitmap, or - with
/// no context - transparent black of the width and height attributes' size,
/// origin-clean (nothing has been drawn on it).
const CanvasBitmap = struct {
    width: u32,
    height: u32,
    /// Premultiplied RGBA8, BORROWED from the context; null for transparent
    /// black.
    pixels: ?[]const u8,
    origin_clean: bool,

    fn of(instance: *runtime.Instance) CanvasBitmap {
        if (internalOf(instance)) |internal| if (internal.mode == .@"2d") if (internal.context) |context| {
            if (dom.image_sources.outputBitmap(context)) |bitmap| return .{
                .width = bitmap.width,
                .height = bitmap.height,
                .pixels = bitmap.pixels,
                .origin_clean = bitmap.origin_clean,
            };
        };
        const width, const height = bitmapSize(instance);
        return .{ .width = width, .height = height, .pixels = null, .origin_clean = true };
    }

    fn hasPixels(self: CanvasBitmap) bool {
        return self.width != 0 and self.height != 0;
    }

    fn serializable(self: CanvasBitmap) dom.bitmap_serialization.Bitmap {
        return .{ .width = self.width, .height = self.height, .pixels = self.pixels };
    }
};

/// The `type` argument, when given (its IDL default "image/png" counts as
/// given: the serialization's PNG either way).
fn typeArgument(@"type": webidl.Opt(runtime.DOMString)) ?[]const u8 {
    if (!@"type".was_passed) return null;
    return @"type".value.asSlice();
}

/// HTML 4.12.5.5: "if quality is a Number in the range 0.0 to 1.0
/// inclusive, the user agent must treat quality as the desired quality
/// level. Otherwise, the user agent must use its default quality value" -
/// null. ("The use of type-testing here, instead of simply declaring quality
/// as a Web IDL double, is a historical artifact.")
fn qualityArgument(quality: webidl.Opt(runtime.JSValue)) ?f64 {
    if (!quality.was_passed) return null;
    return switch (quality.value) {
        .number => |n| if (n >= 0.0 and n <= 1.0) n else null,
        else => null,
    };
}

/// HTML 4.12.5.1, toDataURL(type, quality).
///
/// Spec: https://html.spec.whatwg.org/multipage/canvas.html#dom-canvas-todataurl
pub fn call_toDataURL(instance: *runtime.Instance, @"type": webidl.Opt(runtime.DOMString), quality: webidl.Opt(runtime.JSValue)) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;
    const bitmap = CanvasBitmap.of(instance);
    // 1. "If this canvas element's bitmap's origin-clean flag is set to
    //    false, then throw a "SecurityError" DOMException."
    if (!bitmap.origin_clean) return error.SecurityError;
    // 2. "If this canvas element's bitmap has no pixels (i.e. either its
    //    horizontal dimension or its vertical dimension is zero), then
    //    return the string "data:,"."
    if (!bitmap.hasPixels()) return allocator.dupe(u8, "data:,");
    // 3. "Let file be a serialization of this canvas element's bitmap as a
    //    file, passing type and quality if given."
    const file = dom.bitmap_serialization.serialize(allocator, bitmap.serializable(), typeArgument(@"type"), qualityArgument(quality)) orelse {
        // 4. "If file is null, then return "data:,"."
        return allocator.dupe(u8, "data:,");
    };
    defer file.deinit(allocator);
    // 5. "Return a data: URL representing file."
    return dom.bitmap_serialization.dataUrl(allocator, &file);
}

/// HTML 4.12.5.1, toBlob(callback, type, quality).
///
/// Deviation, stated (the integrator's condition, 2026-11-12): step 4's
/// serialization runs "in parallel" in the spec, and here on the agent's
/// thread, before the call returns - as image decoding runs today. The task
/// that hands the Blob over is still queued, so script sees the same order.
/// TODO(platform thread pool): move the encode to the platform's thread
/// pool when it exists (queued by the integrator), with the copy of step 3
/// as its input.
///
/// Spec: https://html.spec.whatwg.org/multipage/canvas.html#dom-canvas-toblob
pub fn call_toBlob(instance: *runtime.Instance, _callback: callbacks.BlobCallback, @"type": webidl.Opt(runtime.DOMString), quality: webidl.Opt(runtime.JSValue)) anyerror!void {
    // The binding hands the callback over: take it before anything can fail.
    const callback = engine.takeCallbackFunction(@ptrCast(_callback));
    var callback_owned = true;
    defer if (callback_owned) callback.release();
    const allocator = instance.ctx.allocator;
    const bitmap = CanvasBitmap.of(instance);
    // 1. "If this canvas element's bitmap's origin-clean flag is set to
    //    false, then throw a "SecurityError" DOMException."
    if (!bitmap.origin_clean) return error.SecurityError;
    // 2-3. "Let result be null." "If this canvas element's bitmap has pixels
    //    ..., then set result to a copy of this canvas element's bitmap."
    // 4.1. "If result is non-null, then set result to a serialization of
    //    result as a file with type and quality if given" (stated above).
    const file: ?dom.bitmap_serialization.File = if (bitmap.hasPixels())
        dom.bitmap_serialization.serialize(allocator, bitmap.serializable(), typeArgument(@"type"), qualityArgument(quality))
    else
        null;
    var file_owned = true;
    defer if (file_owned) if (file) |f| f.deinit(allocator);

    // 4.2. "Queue an element task on the canvas blob serialization task
    //    source given the canvas element".
    const global = realmGlobal(instance.ctx) orelse return;
    const loop = instance.ctx.getOptionalEventLoop() orelse return error.InvalidStateError;
    const task = try allocator.create(BlobTask);
    task.* = .{
        .allocator = allocator,
        .global = global,
        .global_generation = runtime.SlabAllocator.generationOf(global),
        .callback = callback,
        .file = file,
    };
    callback_owned = false;
    file_owned = false;
    var queued: runtime.EventLoopTask = .{ .callback = BlobTask.run, .context = task, .drop = BlobTask.drop };
    if (interfaces.Node.get_ownerDocument(instance) catch null) |document| {
        queued.document = document;
        queued.document_generation = runtime.SlabAllocator.generationOf(document);
    }
    loop.queueTask(queued);
}

/// The global of `realm`.
fn realmGlobal(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

/// toBlob step 4.2's task: the file and the callback, OWNED until it runs
/// or is dropped. It keeps the canvas's relevant global, not the canvas: the
/// Blob is made in the canvas's relevant realm, and the canvas itself may be
/// gone by then (document.open removes it from its tree;
/// opening-the-input-stream/tasks.window.js "canvas.toBlob()").
const BlobTask = struct {
    allocator: std.mem.Allocator,
    global: *runtime.Instance,
    global_generation: u64,
    callback: engine.CallbackFunction,
    file: ?dom.bitmap_serialization.File,

    fn deinit(self: *BlobTask) void {
        self.callback.release();
        if (self.file) |file| file.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *BlobTask = @ptrCast(@alignCast(data.?));
        self.deinit();
    }

    fn run(data: ?*anyopaque) void {
        const self: *BlobTask = @ptrCast(@alignCast(data.?));
        defer self.deinit();
        // A realm that has gone runs nothing.
        if (runtime.SlabAllocator.generationOf(self.global) != self.global_generation) return;
        const realm = self.global.ctx;
        if (!realm.hasEngine()) return;
        // 4.2.1. "If result is non-null, then set result to a new Blob
        //    object, created in the relevant realm of this canvas element,
        //    representing result." Its type is the file's.
        const blob: ?*runtime.Instance = if (self.file) |*file| dom.blob_bytes.create(realm, file.bytes, file.mime()) catch |err| blk: {
            // Not modelled, stated: a Blob that cannot be made hands null
            // over, as a failed serialization does.
            log.debug("toBlob: the Blob was not made: {s}", .{@errorName(err)});
            break :blk null;
        } else null;
        // Wrapped, the Blob is its wrapper's; never wrapped, it is ours.
        const generation = if (blob) |b| runtime.SlabAllocator.generationOf(b) else 0;
        defer if (blob) |b| runtime.Instance.releaseIfUnwrapped(b, generation);
        // 4.2.2. "Invoke callback with « result » and "report"."
        const argument: runtime.JSValue = if (blob) |b| .{ .instance = b } else .null;
        const completion = engine.invokeCallbackFunction(realm, &self.callback, .undefined, &.{argument}, .{
            .report = .{ .report = reportCallbackException, .host = realm },
        }) catch |err| {
            log.debug("toBlob: the callback was not invoked: {s}", .{@errorName(err)});
            return;
        };
        switch (completion) {
            inline else => |value| value.release(),
        }
    }
};

/// HTML "report an exception" for the global of the realm the engine names -
/// the callback's - or else the canvas's (`host`).
fn reportCallbackException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const canvas_realm: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse canvas_realm;
    const global = realmGlobal(realm) orelse return;
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = @import("html").report_exception.reportErrorInfo(global, &extracted, .{});
}

/// Operation: transferControlToOffscreen
pub fn call_transferControlToOffscreen(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}
