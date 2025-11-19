//! Generated from: webaudio.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioWorkletGlobalScopeImpl = @import("impls").AudioWorkletGlobalScope;
const WorkletGlobalScope = @import("interfaces").WorkletGlobalScope;
const AudioWorkletProcessorConstructor = @import("callbacks").AudioWorkletProcessorConstructor;
const MessagePort = @import("interfaces").MessagePort;
const DOMString = @import("typedefs").DOMString;

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
        return AudioWorkletGlobalScopeImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioWorkletGlobalScopeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_currentFrame(instance: *runtime.Instance) anyerror!u64 {
        return try AudioWorkletGlobalScopeImpl.get_currentFrame(instance);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!f64 {
        return try AudioWorkletGlobalScopeImpl.get_currentTime(instance);
    }

    pub fn get_sampleRate(instance: *runtime.Instance) anyerror!f32 {
        return try AudioWorkletGlobalScopeImpl.get_sampleRate(instance);
    }

    pub fn get_renderQuantumSize(instance: *runtime.Instance) anyerror!u32 {
        return try AudioWorkletGlobalScopeImpl.get_renderQuantumSize(instance);
    }

    pub fn get_port(instance: *runtime.Instance) anyerror!MessagePort {
        return try AudioWorkletGlobalScopeImpl.get_port(instance);
    }

    pub fn call_registerProcessor(instance: *runtime.Instance, name: DOMString, processorCtor: AudioWorkletProcessorConstructor) anyerror!void {
        
        return try AudioWorkletGlobalScopeImpl.call_registerProcessor(instance, name, processorCtor);
    }

};
