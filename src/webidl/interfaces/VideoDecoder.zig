//! Generated from: webcodecs.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VideoDecoderImpl = @import("impls").VideoDecoder;
const EventTarget = @import("interfaces").EventTarget;
const EncodedVideoChunk = @import("interfaces").EncodedVideoChunk;
const CodecState = @import("enums").CodecState;
const VideoDecoderConfig = @import("dictionaries").VideoDecoderConfig;
const VideoDecoderInit = @import("dictionaries").VideoDecoderInit;
const Promise<VideoDecoderSupport> = @import("interfaces").Promise<VideoDecoderSupport>;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const EventHandler = @import("typedefs").EventHandler;

pub const VideoDecoder = struct {
    pub const Meta = struct {
        pub const name = "VideoDecoder";
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
            decodeQueueSize: u32 = undefined,
            ondequeue: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(VideoDecoder, .{
        .deinit_fn = &deinit_wrapper,

        .get_decodeQueueSize = &get_decodeQueueSize,
        .get_ondequeue = &get_ondequeue,
        .get_state = &get_state,

        .set_ondequeue = &set_ondequeue,

        .call_addEventListener = &call_addEventListener,
        .call_close = &call_close,
        .call_configure = &call_configure,
        .call_decode = &call_decode,
        .call_dispatchEvent = &call_dispatchEvent,
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
        VideoDecoderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VideoDecoderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: VideoDecoderInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try VideoDecoderImpl.constructor(instance, init);
        
        return instance;
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!CodecState {
        return try VideoDecoderImpl.get_state(instance);
    }

    pub fn get_decodeQueueSize(instance: *runtime.Instance) anyerror!u32 {
        return try VideoDecoderImpl.get_decodeQueueSize(instance);
    }

    pub fn get_ondequeue(instance: *runtime.Instance) anyerror!EventHandler {
        return try VideoDecoderImpl.get_ondequeue(instance);
    }

    pub fn set_ondequeue(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try VideoDecoderImpl.set_ondequeue(instance, value);
    }

    pub fn call_decode(instance: *runtime.Instance, chunk: EncodedVideoChunk) anyerror!void {
        
        return try VideoDecoderImpl.call_decode(instance, chunk);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try VideoDecoderImpl.call_when(instance, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try VideoDecoderImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_flush(instance: *runtime.Instance) anyerror!anyopaque {
        return try VideoDecoderImpl.call_flush(instance);
    }

    pub fn call_isConfigSupported(instance: *runtime.Instance, config: VideoDecoderConfig) anyerror!anyopaque {
        
        return try VideoDecoderImpl.call_isConfigSupported(instance, config);
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        return try VideoDecoderImpl.call_reset(instance);
    }

    pub fn call_configure(instance: *runtime.Instance, config: VideoDecoderConfig) anyerror!void {
        
        return try VideoDecoderImpl.call_configure(instance, config);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try VideoDecoderImpl.call_close(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try VideoDecoderImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try VideoDecoderImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
