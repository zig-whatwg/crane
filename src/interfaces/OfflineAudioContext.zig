//! Generated from: webaudio.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OfflineAudioContextImpl = @import("../impls/OfflineAudioContext.zig");
const BaseAudioContext = @import("BaseAudioContext.zig");

pub const OfflineAudioContext = struct {
    pub const Meta = struct {
        pub const name = "OfflineAudioContext";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *BaseAudioContext;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            length: u32 = undefined,
            oncomplete: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(OfflineAudioContext, .{
        .deinit_fn = &deinit_wrapper,

        .get_audioWorklet = &get_audioWorklet,
        .get_currentTime = &get_currentTime,
        .get_destination = &get_destination,
        .get_length = &get_length,
        .get_listener = &get_listener,
        .get_oncomplete = &get_oncomplete,
        .get_onstatechange = &get_onstatechange,
        .get_renderQuantumSize = &get_renderQuantumSize,
        .get_sampleRate = &get_sampleRate,
        .get_state = &get_state,

        .set_oncomplete = &set_oncomplete,
        .set_onstatechange = &set_onstatechange,

        .call_addEventListener = &call_addEventListener,
        .call_createAnalyser = &call_createAnalyser,
        .call_createBiquadFilter = &call_createBiquadFilter,
        .call_createBuffer = &call_createBuffer,
        .call_createBufferSource = &call_createBufferSource,
        .call_createChannelMerger = &call_createChannelMerger,
        .call_createChannelSplitter = &call_createChannelSplitter,
        .call_createConstantSource = &call_createConstantSource,
        .call_createConvolver = &call_createConvolver,
        .call_createDelay = &call_createDelay,
        .call_createDynamicsCompressor = &call_createDynamicsCompressor,
        .call_createGain = &call_createGain,
        .call_createIIRFilter = &call_createIIRFilter,
        .call_createOscillator = &call_createOscillator,
        .call_createPanner = &call_createPanner,
        .call_createPeriodicWave = &call_createPeriodicWave,
        .call_createScriptProcessor = &call_createScriptProcessor,
        .call_createStereoPanner = &call_createStereoPanner,
        .call_createWaveShaper = &call_createWaveShaper,
        .call_decodeAudioData = &call_decodeAudioData,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_resume = &call_resume,
        .call_startRendering = &call_startRendering,
        .call_suspend = &call_suspend,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        OfflineAudioContextImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        OfflineAudioContextImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, contextOptions: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try OfflineAudioContextImpl.constructor(state, contextOptions);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, numberOfChannels: u32, length: u32, sampleRate: f32) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try OfflineAudioContextImpl.constructor(state, numberOfChannels, length, sampleRate);
        
        return instance;
    }

    pub fn get_destination(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.get_destination(state);
    }

    pub fn get_sampleRate(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.get_sampleRate(state);
    }

    pub fn get_currentTime(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.get_currentTime(state);
    }

    pub fn get_listener(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.get_listener(state);
    }

    pub fn get_state(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.get_state(state);
    }

    pub fn get_renderQuantumSize(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.get_renderQuantumSize(state);
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_audioWorklet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_audioWorklet) |cached| {
            return cached;
        }
        const value = OfflineAudioContextImpl.get_audioWorklet(state);
        state.cached_audioWorklet = value;
        return value;
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.get_onstatechange(state);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        OfflineAudioContextImpl.set_onstatechange(state, value);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.get_length(state);
    }

    pub fn get_oncomplete(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.get_oncomplete(state);
    }

    pub fn set_oncomplete(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        OfflineAudioContextImpl.set_oncomplete(state, value);
    }

    pub fn call_createChannelMerger(instance: *runtime.Instance, numberOfInputs: u32) anyopaque {
        const state = instance.getState(State);
        
        return OfflineAudioContextImpl.call_createChannelMerger(state, numberOfInputs);
    }

    pub fn call_createDynamicsCompressor(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.call_createDynamicsCompressor(state);
    }

    pub fn call_startRendering(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.call_startRendering(state);
    }

    pub fn call_createWaveShaper(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.call_createWaveShaper(state);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OfflineAudioContextImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_createConstantSource(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.call_createConstantSource(state);
    }

    pub fn call_createAnalyser(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.call_createAnalyser(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return OfflineAudioContextImpl.call_dispatchEvent(state, event);
    }

    pub fn call_createBuffer(instance: *runtime.Instance, numberOfChannels: u32, length: u32, sampleRate: f32) anyopaque {
        const state = instance.getState(State);
        
        return OfflineAudioContextImpl.call_createBuffer(state, numberOfChannels, length, sampleRate);
    }

    pub fn call_createDelay(instance: *runtime.Instance, maxDelayTime: f64) anyopaque {
        const state = instance.getState(State);
        
        return OfflineAudioContextImpl.call_createDelay(state, maxDelayTime);
    }

    pub fn call_createPanner(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.call_createPanner(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OfflineAudioContextImpl.call_when(state, type_, options);
    }

    pub fn call_suspend(instance: *runtime.Instance, suspendTime: f64) anyopaque {
        const state = instance.getState(State);
        
        return OfflineAudioContextImpl.call_suspend(state, suspendTime);
    }

    pub fn call_createPeriodicWave(instance: *runtime.Instance, real: anyopaque, imag: anyopaque, constraints: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OfflineAudioContextImpl.call_createPeriodicWave(state, real, imag, constraints);
    }

    pub fn call_createConvolver(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.call_createConvolver(state);
    }

    pub fn call_createBufferSource(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.call_createBufferSource(state);
    }

    pub fn call_createStereoPanner(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.call_createStereoPanner(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OfflineAudioContextImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_createGain(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.call_createGain(state);
    }

    pub fn call_resume(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.call_resume(state);
    }

    pub fn call_createIIRFilter(instance: *runtime.Instance, feedforward: anyopaque, feedback: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OfflineAudioContextImpl.call_createIIRFilter(state, feedforward, feedback);
    }

    pub fn call_createBiquadFilter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.call_createBiquadFilter(state);
    }

    pub fn call_createOscillator(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OfflineAudioContextImpl.call_createOscillator(state);
    }

    pub fn call_createScriptProcessor(instance: *runtime.Instance, bufferSize: u32, numberOfInputChannels: u32, numberOfOutputChannels: u32) anyopaque {
        const state = instance.getState(State);
        
        return OfflineAudioContextImpl.call_createScriptProcessor(state, bufferSize, numberOfInputChannels, numberOfOutputChannels);
    }

    pub fn call_createChannelSplitter(instance: *runtime.Instance, numberOfOutputs: u32) anyopaque {
        const state = instance.getState(State);
        
        return OfflineAudioContextImpl.call_createChannelSplitter(state, numberOfOutputs);
    }

    pub fn call_decodeAudioData(instance: *runtime.Instance, audioData: anyopaque, successCallback: anyopaque, errorCallback: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OfflineAudioContextImpl.call_decodeAudioData(state, audioData, successCallback, errorCallback);
    }

};
