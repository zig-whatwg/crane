//! Generated from: webcodecs.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const VideoFrameImpl = @import("impls").VideoFrame;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const VideoFrameMetadata = @import("dictionaries").VideoFrameMetadata;
const VideoFrameInit = @import("dictionaries").VideoFrameInit;
const VideoFrameCopyToOptions = @import("dictionaries").VideoFrameCopyToOptions;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const VideoColorSpace = @import("interfaces").VideoColorSpace;
const CanvasImageSource = @import("typedefs").CanvasImageSource;
const VideoFrameBufferInit = @import("dictionaries").VideoFrameBufferInit;
const VideoPixelFormat = @import("enums").VideoPixelFormat;

pub const VideoFrame = struct {
    pub const Meta = struct {
        pub const name = "VideoFrame";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "Serializable" },
            .{ .name = "Transferable" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "format", "get_format", null },
            .{ "codedWidth", "get_codedWidth", null },
            .{ "codedHeight", "get_codedHeight", null },
            .{ "codedRect", "get_codedRect", null },
            .{ "visibleRect", "get_visibleRect", null },
            .{ "rotation", "get_rotation", null },
            .{ "flip", "get_flip", null },
            .{ "displayWidth", "get_displayWidth", null },
            .{ "displayHeight", "get_displayHeight", null },
            .{ "duration", "get_duration", null },
            .{ "timestamp", "get_timestamp", null },
            .{ "colorSpace", "get_colorSpace", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "metadata", "call_metadata", 0 },
            .{ "allocationSize", "call_allocationSize", 0 },
            .{ "copyTo", "call_copyTo", 1 },
            .{ "clone", "call_clone", 0 },
            .{ "close", "call_close", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "metadata",
            "allocationSize",
            "copyTo",
            "clone",
            "close",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "format", "get_format", null },
            .{ "codedWidth", "get_codedWidth", null },
            .{ "codedHeight", "get_codedHeight", null },
            .{ "codedRect", "get_codedRect", null },
            .{ "visibleRect", "get_visibleRect", null },
            .{ "rotation", "get_rotation", null },
            .{ "flip", "get_flip", null },
            .{ "displayWidth", "get_displayWidth", null },
            .{ "displayHeight", "get_displayHeight", null },
            .{ "duration", "get_duration", null },
            .{ "timestamp", "get_timestamp", null },
            .{ "colorSpace", "get_colorSpace", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            format: ?enums.VideoPixelFormat = null,
            codedWidth: u32 = undefined,
            codedHeight: u32 = undefined,
            codedRect: ?*runtime.Instance = null,
            visibleRect: ?*runtime.Instance = null,
            rotation: f64 = undefined,
            flip: bool = undefined,
            displayWidth: u32 = undefined,
            displayHeight: u32 = undefined,
            duration: ?u64 = null,
            timestamp: i64 = undefined,
            colorSpace: *runtime.Instance = undefined,
            _internal: ?*VideoFrameImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_codedHeight = &get_codedHeight,
        .get_codedRect = &get_codedRect,
        .get_codedWidth = &get_codedWidth,
        .get_colorSpace = &get_colorSpace,
        .get_displayHeight = &get_displayHeight,
        .get_displayWidth = &get_displayWidth,
        .get_duration = &get_duration,
        .get_flip = &get_flip,
        .get_format = &get_format,
        .get_rotation = &get_rotation,
        .get_timestamp = &get_timestamp,
        .get_visibleRect = &get_visibleRect,

        .call_allocationSize = &call_allocationSize,
        .call_clone = &call_clone,
        .call_close = &call_close,
        .call_copyTo = &call_copyTo,
        .call_metadata = &call_metadata,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return VideoFrameImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return VideoFrameImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VideoFrameImpl.deinit(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "VideoFrame")) {
            if (comptime @hasDecl(impls.VideoFrame, "installHooks")) impls.VideoFrame.installHooks();
        }
    }

    // HTML 2.7.1 serializable objects: VideoFrame is [Serializable].

    /// VideoFrame's serialization steps, given `value` and `serialized`: its impl's.
    pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) anyerror!void {
        return @import("impls").VideoFrame.serializationSteps(value, serialized);
    }

    /// VideoFrame's deserialization steps, given `serialized`, `value` and
    /// `target_realm`: its impl's.
    pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) anyerror!void {
        return @import("impls").VideoFrame.deserializationSteps(serialized, value, target_realm);
    }

    /// HTML StructuredDeserialize steps 22.3 and 24.4: a new instance of
    /// VideoFrame, created in `target_realm`, set up by its deserialization steps.
    /// Unwrapped: the engine wraps it in `target_realm`.
    fn deserializeNew(serialized: *runtime.DeserializationRecord, target_realm: runtime.Context) anyerror!*runtime.Instance {
        const value = try init(target_realm.allocator, target_realm);
        const generation = runtime.SlabAllocator.generationOf(value);
        errdefer value.releaseIfUnwrapped(generation);
        try deserializationSteps(serialized, value, target_realm);
        return value;
    }

    /// VideoFrame's serialization and deserialization steps, as an engine finds
    /// them by interface identifier; null while its impl defines none.
    pub const serializable_steps: ?runtime.SerializableSteps = if (has_serializable_steps) .{
        .serialize = &serializationSteps,
        .deserialize = &deserializeNew,
    } else null;

    const has_serializable_steps = blk: {
        const impls = @import("impls");
        if (!@hasDecl(impls, "VideoFrame")) break :blk false;
        break :blk @hasDecl(impls.VideoFrame, "serializationSteps") and @hasDecl(impls.VideoFrame, "deserializationSteps");
    };

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor(image, init)
        CanvasImageSource_VideoFrameInit: struct {
            image: CanvasImageSource,
            init: webidl.Opt(VideoFrameInit),
        },
        /// constructor(data, init)
        AllowSharedBufferSource_VideoFrameBufferInit: struct {
            data: AllowSharedBufferSource,
            init: VideoFrameBufferInit,
        },
    };

    /// WebIDL overload set of the constructor: one entry per variant of
    /// ConstructorArgs, in its order, for the overload resolution algorithm
    /// (webidl.overload_resolution) the binding runs to pick the variant.
    pub const constructor_overloads = &[_]webidl.overload_resolution.Overload{
        .{ .function = "CanvasImageSource_VideoFrameInit", .args = &.{ .{ .kinds = &.{ (if (@hasDecl(@import("interfaces"), "HTMLImageElement")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").HTMLImageElement.State) } else .other), (if (@hasDecl(@import("interfaces"), "SVGImageElement")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").SVGImageElement.State) } else .other), (if (@hasDecl(@import("interfaces"), "HTMLVideoElement")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").HTMLVideoElement.State) } else .other), (if (@hasDecl(@import("interfaces"), "HTMLCanvasElement")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").HTMLCanvasElement.State) } else .other), (if (@hasDecl(@import("interfaces"), "ImageBitmap")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").ImageBitmap.State) } else .other), (if (@hasDecl(@import("interfaces"), "OffscreenCanvas")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").OffscreenCanvas.State) } else .other), (if (@hasDecl(@import("interfaces"), "VideoFrame")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").VideoFrame.State) } else .other) } }, .{ .kinds = &.{.dictionary}, .optionality = .optional } } },
        .{ .function = "AllowSharedBufferSource_VideoFrameBufferInit", .args = &.{ .{ .kinds = &.{ .array_buffer, .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view } }, .{ .kinds = &.{.dictionary} } } },
    };

    /// WebIDL constructor (overloaded)
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try VideoFrameImpl.call_constructor(ctx, args);
    }

    pub fn get_format(instance: *runtime.Instance) anyerror!?VideoPixelFormat {
        return try VideoFrameImpl.get_format(instance);
    }

    pub fn get_codedWidth(instance: *runtime.Instance) anyerror!u32 {
        return try VideoFrameImpl.get_codedWidth(instance);
    }

    pub fn get_codedHeight(instance: *runtime.Instance) anyerror!u32 {
        return try VideoFrameImpl.get_codedHeight(instance);
    }

    pub fn get_codedRect(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try VideoFrameImpl.get_codedRect(instance);
    }

    pub fn get_visibleRect(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try VideoFrameImpl.get_visibleRect(instance);
    }

    pub fn get_rotation(instance: *runtime.Instance) anyerror!f64 {
        return try VideoFrameImpl.get_rotation(instance);
    }

    pub fn get_flip(instance: *runtime.Instance) anyerror!bool {
        return try VideoFrameImpl.get_flip(instance);
    }

    pub fn get_displayWidth(instance: *runtime.Instance) anyerror!u32 {
        return try VideoFrameImpl.get_displayWidth(instance);
    }

    pub fn get_displayHeight(instance: *runtime.Instance) anyerror!u32 {
        return try VideoFrameImpl.get_displayHeight(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!?u64 {
        return try VideoFrameImpl.get_duration(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!i64 {
        return try VideoFrameImpl.get_timestamp(instance);
    }

    pub fn get_colorSpace(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try VideoFrameImpl.get_colorSpace(instance);
    }

    pub fn call_allocationSize(instance: *runtime.Instance, options: webidl.Opt(VideoFrameCopyToOptions)) anyerror!u32 {
        return try VideoFrameImpl.call_allocationSize(instance, options);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try VideoFrameImpl.call_close(instance);
    }

    pub fn call_metadata(instance: *runtime.Instance) anyerror!VideoFrameMetadata {
        return try VideoFrameImpl.call_metadata(instance);
    }

    pub fn call_copyTo(instance: *runtime.Instance, destination: AllowSharedBufferSource, options: webidl.Opt(VideoFrameCopyToOptions)) anyerror!runtime.JSValue {
        return try VideoFrameImpl.call_copyTo(instance, destination, options);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try VideoFrameImpl.call_clone(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_copyTo",
    };
};
