//! Generated from: webcodecs.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VideoEncoderImpl = @import("impls").VideoEncoder;
const EventTarget = @import("interfaces").EventTarget;
const VideoEncoderEncodeOptions = @import("dictionaries").VideoEncoderEncodeOptions;
const VideoEncoderConfig = @import("dictionaries").VideoEncoderConfig;
const VideoFrame = @import("interfaces").VideoFrame;
const CodecState = @import("enums").CodecState;
const Promise<VideoEncoderSupport> = @import("interfaces").Promise<VideoEncoderSupport>;
const VideoEncoderInit = @import("dictionaries").VideoEncoderInit;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const EventHandler = @import("typedefs").EventHandler;

pub const VideoEncoder = struct {
    pub const Meta = struct {
        pub const name = "VideoEncoder";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            state: CodecState = undefined,
            encodeQueueSize: u32 = undefined,
            ondequeue: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(VideoEncoder, .{
        .deinit_fn = &deinit_wrapper,

        .get_encodeQueueSize = &get_encodeQueueSize,
        .get_ondequeue = &get_ondequeue,
        .get_state = &get_state,

        .set_ondequeue = &set_ondequeue,

        .call_addEventListener = &call_addEventListener,
        .call_close = &call_close,
        .call_configure = &call_configure,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_encode = &call_encode,
        .call_flush = &call_flush,
        .call_isConfigSupported = &call_isConfigSupported,
        .call_removeEventListener = &call_removeEventListener,
        .call_reset = &call_reset,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        VideoEncoderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VideoEncoderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: VideoEncoderInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try VideoEncoderImpl.constructor(instance, init);
        
        return instance;
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!CodecState {
        return try VideoEncoderImpl.get_state(instance);
    }

    pub fn get_encodeQueueSize(instance: *runtime.Instance) anyerror!u32 {
        return try VideoEncoderImpl.get_encodeQueueSize(instance);
    }

    pub fn get_ondequeue(instance: *runtime.Instance) anyerror!EventHandler {
        return try VideoEncoderImpl.get_ondequeue(instance);
    }

    pub fn set_ondequeue(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try VideoEncoderImpl.set_ondequeue(instance, value);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try VideoEncoderImpl.call_when(instance, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try VideoEncoderImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_flush(instance: *runtime.Instance) anyerror!anyopaque {
        return try VideoEncoderImpl.call_flush(instance);
    }

    pub fn call_encode(instance: *runtime.Instance, frame: VideoFrame, options: VideoEncoderEncodeOptions) anyerror!void {
        
        return try VideoEncoderImpl.call_encode(instance, frame, options);
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        return try VideoEncoderImpl.call_reset(instance);
    }

    pub fn call_isConfigSupported(instance: *runtime.Instance, config: VideoEncoderConfig) anyerror!anyopaque {
        
        return try VideoEncoderImpl.call_isConfigSupported(instance, config);
    }

    pub fn call_configure(instance: *runtime.Instance, config: VideoEncoderConfig) anyerror!void {
        
        return try VideoEncoderImpl.call_configure(instance, config);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try VideoEncoderImpl.call_close(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try VideoEncoderImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try VideoEncoderImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
