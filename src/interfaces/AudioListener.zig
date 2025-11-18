//! Generated from: webaudio.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioListenerImpl = @import("../impls/AudioListener.zig");

pub const AudioListener = struct {
    pub const Meta = struct {
        pub const name = "AudioListener";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            positionX: AudioParam = undefined,
            positionY: AudioParam = undefined,
            positionZ: AudioParam = undefined,
            forwardX: AudioParam = undefined,
            forwardY: AudioParam = undefined,
            forwardZ: AudioParam = undefined,
            upX: AudioParam = undefined,
            upY: AudioParam = undefined,
            upZ: AudioParam = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AudioListener, .{
        .deinit_fn = &deinit_wrapper,

        .get_forwardX = &get_forwardX,
        .get_forwardY = &get_forwardY,
        .get_forwardZ = &get_forwardZ,
        .get_positionX = &get_positionX,
        .get_positionY = &get_positionY,
        .get_positionZ = &get_positionZ,
        .get_upX = &get_upX,
        .get_upY = &get_upY,
        .get_upZ = &get_upZ,

        .call_setOrientation = &call_setOrientation,
        .call_setPosition = &call_setPosition,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        AudioListenerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AudioListenerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_positionX(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioListenerImpl.get_positionX(state);
    }

    pub fn get_positionY(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioListenerImpl.get_positionY(state);
    }

    pub fn get_positionZ(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioListenerImpl.get_positionZ(state);
    }

    pub fn get_forwardX(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioListenerImpl.get_forwardX(state);
    }

    pub fn get_forwardY(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioListenerImpl.get_forwardY(state);
    }

    pub fn get_forwardZ(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioListenerImpl.get_forwardZ(state);
    }

    pub fn get_upX(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioListenerImpl.get_upX(state);
    }

    pub fn get_upY(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioListenerImpl.get_upY(state);
    }

    pub fn get_upZ(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioListenerImpl.get_upZ(state);
    }

    pub fn call_setPosition(instance: *runtime.Instance, x: f32, y: f32, z: f32) anyopaque {
        const state = instance.getState(State);
        
        return AudioListenerImpl.call_setPosition(state, x, y, z);
    }

    pub fn call_setOrientation(instance: *runtime.Instance, x: f32, y: f32, z: f32, xUp: f32, yUp: f32, zUp: f32) anyopaque {
        const state = instance.getState(State);
        
        return AudioListenerImpl.call_setOrientation(state, x, y, z, xUp, yUp, zUp);
    }

};
