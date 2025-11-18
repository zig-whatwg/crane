//! Generated from: webaudio.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioWorkletGlobalScopeImpl = @import("../impls/AudioWorkletGlobalScope.zig");
const WorkletGlobalScope = @import("WorkletGlobalScope.zig");

pub const AudioWorkletGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "AudioWorkletGlobalScope";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WorkletGlobalScope;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worklet", "AudioWorklet" } } },
            .{ .name = "Exposed", .value = .{ .identifier = "AudioWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .AudioWorklet = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            currentFrame: u64 = undefined,
            currentTime: f64 = undefined,
            sampleRate: f32 = undefined,
            renderQuantumSize: u32 = undefined,
            port: MessagePort = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AudioWorkletGlobalScope, .{
        .deinit_fn = &deinit_wrapper,

        .get_currentFrame = &get_currentFrame,
        .get_currentTime = &get_currentTime,
        .get_port = &get_port,
        .get_renderQuantumSize = &get_renderQuantumSize,
        .get_sampleRate = &get_sampleRate,

        .call_registerProcessor = &call_registerProcessor,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        AudioWorkletGlobalScopeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AudioWorkletGlobalScopeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_currentFrame(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return AudioWorkletGlobalScopeImpl.get_currentFrame(state);
    }

    pub fn get_currentTime(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return AudioWorkletGlobalScopeImpl.get_currentTime(state);
    }

    pub fn get_sampleRate(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return AudioWorkletGlobalScopeImpl.get_sampleRate(state);
    }

    pub fn get_renderQuantumSize(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return AudioWorkletGlobalScopeImpl.get_renderQuantumSize(state);
    }

    pub fn get_port(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioWorkletGlobalScopeImpl.get_port(state);
    }

    pub fn call_registerProcessor(instance: *runtime.Instance, name: runtime.DOMString, processorCtor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AudioWorkletGlobalScopeImpl.call_registerProcessor(state, name, processorCtor);
    }

};
