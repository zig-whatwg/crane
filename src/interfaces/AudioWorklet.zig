//! Generated from: webaudio.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioWorkletImpl = @import("../impls/AudioWorklet.zig");
const Worklet = @import("Worklet.zig");

pub const AudioWorklet = struct {
    pub const Meta = struct {
        pub const name = "AudioWorklet";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Worklet;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            port: MessagePort = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AudioWorklet, .{
        .deinit_fn = &deinit_wrapper,

        .get_port = &get_port,

        .call_addModule = &call_addModule,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        AudioWorkletImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AudioWorkletImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_port(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioWorkletImpl.get_port(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_addModule(instance: *runtime.Instance, moduleURL: runtime.USVString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return AudioWorkletImpl.call_addModule(state, moduleURL, options);
    }

};
