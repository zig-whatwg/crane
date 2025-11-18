//! Generated from: webrtc-encoded-transform.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCEncodedAudioFrameImpl = @import("impls").RTCEncodedAudioFrame;
const RTCEncodedAudioFrameOptions = @import("dictionaries").RTCEncodedAudioFrameOptions;
const ArrayBuffer = @import("interfaces").ArrayBuffer;
const RTCEncodedAudioFrameMetadata = @import("dictionaries").RTCEncodedAudioFrameMetadata;

pub const RTCEncodedAudioFrame = struct {
    pub const Meta = struct {
        pub const name = "RTCEncodedAudioFrame";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            data: ArrayBuffer = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCEncodedAudioFrame, .{
        .deinit_fn = &deinit_wrapper,

        .get_data = &get_data,

        .set_data = &set_data,

        .call_getMetadata = &call_getMetadata,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        RTCEncodedAudioFrameImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCEncodedAudioFrameImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, originalFrame: RTCEncodedAudioFrame, options: RTCEncodedAudioFrameOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try RTCEncodedAudioFrameImpl.constructor(instance, originalFrame, options);
        
        return instance;
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCEncodedAudioFrameImpl.get_data(instance);
    }

    pub fn set_data(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try RTCEncodedAudioFrameImpl.set_data(instance, value);
    }

    pub fn call_getMetadata(instance: *runtime.Instance) anyerror!RTCEncodedAudioFrameMetadata {
        return try RTCEncodedAudioFrameImpl.call_getMetadata(instance);
    }

};
