//! Generated from: media-source.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaSourceImpl = @import("impls").MediaSource;
const EventTarget = @import("interfaces").EventTarget;
const EndOfStreamError = @import("enums").EndOfStreamError;
const SourceBufferList = @import("interfaces").SourceBufferList;
const MediaSourceHandle = @import("interfaces").MediaSourceHandle;
const SourceBuffer = @import("interfaces").SourceBuffer;
const ReadyState = @import("enums").ReadyState;
const EventHandler = @import("typedefs").EventHandler;

pub const MediaSource = struct {
    pub const Meta = struct {
        pub const name = "MediaSource";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            handle: MediaSourceHandle = undefined,
            sourceBuffers: SourceBufferList = undefined,
            activeSourceBuffers: SourceBufferList = undefined,
            readyState: ReadyState = undefined,
            duration: f64 = undefined,
            onsourceopen: EventHandler = undefined,
            onsourceended: EventHandler = undefined,
            onsourceclose: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaSource, .{
        .deinit_fn = &deinit_wrapper,

        .get_activeSourceBuffers = &get_activeSourceBuffers,
        .get_canConstructInDedicatedWorker = &get_canConstructInDedicatedWorker,
        .get_duration = &get_duration,
        .get_handle = &get_handle,
        .get_onsourceclose = &get_onsourceclose,
        .get_onsourceended = &get_onsourceended,
        .get_onsourceopen = &get_onsourceopen,
        .get_readyState = &get_readyState,
        .get_sourceBuffers = &get_sourceBuffers,

        .set_duration = &set_duration,
        .set_onsourceclose = &set_onsourceclose,
        .set_onsourceended = &set_onsourceended,
        .set_onsourceopen = &set_onsourceopen,

        .call_addEventListener = &call_addEventListener,
        .call_addSourceBuffer = &call_addSourceBuffer,
        .call_clearLiveSeekableRange = &call_clearLiveSeekableRange,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_endOfStream = &call_endOfStream,
        .call_isTypeSupported = &call_isTypeSupported,
        .call_removeEventListener = &call_removeEventListener,
        .call_removeSourceBuffer = &call_removeSourceBuffer,
        .call_setLiveSeekableRange = &call_setLiveSeekableRange,
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
        MediaSourceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaSourceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try MediaSourceImpl.constructor(instance);
        
        return instance;
    }

    /// Extended attributes: [SameObject], [Exposed=DedicatedWorker]
    pub fn get_handle(instance: *runtime.Instance) anyerror!MediaSourceHandle {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_handle) |cached| {
            return cached;
        }
        const value = try MediaSourceImpl.get_handle(instance);
        state.cached_handle = value;
        return value;
    }

    pub fn get_sourceBuffers(instance: *runtime.Instance) anyerror!SourceBufferList {
        return try MediaSourceImpl.get_sourceBuffers(instance);
    }

    pub fn get_activeSourceBuffers(instance: *runtime.Instance) anyerror!SourceBufferList {
        return try MediaSourceImpl.get_activeSourceBuffers(instance);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyerror!ReadyState {
        return try MediaSourceImpl.get_readyState(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!f64 {
        return try MediaSourceImpl.get_duration(instance);
    }

    pub fn set_duration(instance: *runtime.Instance, value: f64) anyerror!void {
        try MediaSourceImpl.set_duration(instance, value);
    }

    pub fn get_onsourceopen(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaSourceImpl.get_onsourceopen(instance);
    }

    pub fn set_onsourceopen(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaSourceImpl.set_onsourceopen(instance, value);
    }

    pub fn get_onsourceended(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaSourceImpl.get_onsourceended(instance);
    }

    pub fn set_onsourceended(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaSourceImpl.set_onsourceended(instance, value);
    }

    pub fn get_onsourceclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaSourceImpl.get_onsourceclose(instance);
    }

    pub fn set_onsourceclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaSourceImpl.set_onsourceclose(instance, value);
    }

    pub fn get_canConstructInDedicatedWorker(instance: *runtime.Instance) anyerror!bool {
        return try MediaSourceImpl.get_canConstructInDedicatedWorker(instance);
    }

    pub fn call_endOfStream(instance: *runtime.Instance, error_: EndOfStreamError) anyerror!void {
        
        return try MediaSourceImpl.call_endOfStream(instance, error_);
    }

    pub fn call_setLiveSeekableRange(instance: *runtime.Instance, start: f64, end: f64) anyerror!void {
        
        return try MediaSourceImpl.call_setLiveSeekableRange(instance, start, end);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try MediaSourceImpl.call_when(instance, type_, options);
    }

    pub fn call_addSourceBuffer(instance: *runtime.Instance, type_: DOMString) anyerror!SourceBuffer {
        
        return try MediaSourceImpl.call_addSourceBuffer(instance, type_);
    }

    pub fn call_removeSourceBuffer(instance: *runtime.Instance, sourceBuffer: SourceBuffer) anyerror!void {
        
        return try MediaSourceImpl.call_removeSourceBuffer(instance, sourceBuffer);
    }

    pub fn call_isTypeSupported(instance: *runtime.Instance, type_: DOMString) anyerror!bool {
        
        return try MediaSourceImpl.call_isTypeSupported(instance, type_);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try MediaSourceImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_clearLiveSeekableRange(instance: *runtime.Instance) anyerror!void {
        return try MediaSourceImpl.call_clearLiveSeekableRange(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try MediaSourceImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try MediaSourceImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
