//! Generated from: webaudio.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioWorkletProcessorImpl = @import("impls").AudioWorkletProcessor;
const MessagePort = @import("interfaces").MessagePort;

pub const AudioWorkletProcessor = struct {
    pub const Meta = struct {
        pub const name = "AudioWorkletProcessor";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "AudioWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .AudioWorklet = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            port: MessagePort = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AudioWorkletProcessor, .{
        .deinit_fn = &deinit_wrapper,

        .get_port = &get_port,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        AudioWorkletProcessorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioWorkletProcessorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try AudioWorkletProcessorImpl.constructor(instance);
        
        return instance;
    }

    pub fn get_port(instance: *runtime.Instance) anyerror!MessagePort {
        return try AudioWorkletProcessorImpl.get_port(instance);
    }

};
