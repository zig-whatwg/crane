//! Generated from: webaudio.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BaseAudioContextImpl = @import("../impls/BaseAudioContext.zig");
const EventTarget = @import("EventTarget.zig");

pub const BaseAudioContext = struct {
    pub const Meta = struct {
        pub const name = "BaseAudioContext";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            destination: AudioDestinationNode = undefined,
            sampleRate: f32 = undefined,
            currentTime: f64 = undefined,
            listener: AudioListener = undefined,
            state: AudioContextState = undefined,
            renderQuantumSize: u32 = undefined,
            audioWorklet: AudioWorklet = undefined,
            onstatechange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BaseAudioContext, .{
        .deinit_fn = &deinit_wrapper,

        .get_audioWorklet = &get_audioWorklet,
        .get_currentTime = &get_currentTime,
        .get_destination = &get_destination,
        .get_listener = &get_listener,
        .get_onstatechange = &get_onstatechange,
        .get_renderQuantumSize = &get_renderQuantumSize,
        .get_sampleRate = &get_sampleRate,
        .get_state = &get_state,

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
        BaseAudioContextImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BaseAudioContextImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_destination(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BaseAudioContextImpl.get_destination(state);
    }

    pub fn get_sampleRate(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return BaseAudioContextImpl.get_sampleRate(state);
    }

    pub fn get_currentTime(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return BaseAudioContextImpl.get_currentTime(state);
    }

    pub fn get_listener(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BaseAudioContextImpl.get_listener(state);
    }

    pub fn get_state(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BaseAudioContextImpl.get_state(state);
    }

    pub fn get_renderQuantumSize(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return BaseAudioContextImpl.get_renderQuantumSize(state);
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_audioWorklet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_audioWorklet) |cached| {
            return cached;
        }
        const value = BaseAudioContextImpl.get_audioWorklet(state);
        state.cached_audioWorklet = value;
        return value;
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BaseAudioContextImpl.get_onstatechange(state);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BaseAudioContextImpl.set_onstatechange(state, value);
    }

    pub fn call_createPanner(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BaseAudioContextImpl.call_createPanner(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BaseAudioContextImpl.call_when(state, type_, options);
    }

    pub fn call_createChannelMerger(instance: *runtime.Instance, numberOfInputs: u32) anyopaque {
        const state = instance.getState(State);
        
        return BaseAudioContextImpl.call_createChannelMerger(state, numberOfInputs);
    }

    pub fn call_createDynamicsCompressor(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BaseAudioContextImpl.call_createDynamicsCompressor(state);
    }

    pub fn call_createPeriodicWave(instance: *runtime.Instance, real: anyopaque, imag: anyopaque, constraints: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BaseAudioContextImpl.call_createPeriodicWave(state, real, imag, constraints);
    }

    pub fn call_createConvolver(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BaseAudioContextImpl.call_createConvolver(state);
    }

    pub fn call_createBufferSource(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BaseAudioContextImpl.call_createBufferSource(state);
    }

    pub fn call_createStereoPanner(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BaseAudioContextImpl.call_createStereoPanner(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BaseAudioContextImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BaseAudioContextImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_createConstantSource(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BaseAudioContextImpl.call_createConstantSource(state);
    }

    pub fn call_createGain(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BaseAudioContextImpl.call_createGain(state);
    }

    pub fn call_createAnalyser(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BaseAudioContextImpl.call_createAnalyser(state);
    }

    pub fn call_createIIRFilter(instance: *runtime.Instance, feedforward: anyopaque, feedback: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BaseAudioContextImpl.call_createIIRFilter(state, feedforward, feedback);
    }

    pub fn call_createWaveShaper(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BaseAudioContextImpl.call_createWaveShaper(state);
    }

    pub fn call_createBiquadFilter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BaseAudioContextImpl.call_createBiquadFilter(state);
    }

    pub fn call_createOscillator(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BaseAudioContextImpl.call_createOscillator(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return BaseAudioContextImpl.call_dispatchEvent(state, event);
    }

    pub fn call_createBuffer(instance: *runtime.Instance, numberOfChannels: u32, length: u32, sampleRate: f32) anyopaque {
        const state = instance.getState(State);
        
        return BaseAudioContextImpl.call_createBuffer(state, numberOfChannels, length, sampleRate);
    }

    pub fn call_createScriptProcessor(instance: *runtime.Instance, bufferSize: u32, numberOfInputChannels: u32, numberOfOutputChannels: u32) anyopaque {
        const state = instance.getState(State);
        
        return BaseAudioContextImpl.call_createScriptProcessor(state, bufferSize, numberOfInputChannels, numberOfOutputChannels);
    }

    pub fn call_createDelay(instance: *runtime.Instance, maxDelayTime: f64) anyopaque {
        const state = instance.getState(State);
        
        return BaseAudioContextImpl.call_createDelay(state, maxDelayTime);
    }

    pub fn call_createChannelSplitter(instance: *runtime.Instance, numberOfOutputs: u32) anyopaque {
        const state = instance.getState(State);
        
        return BaseAudioContextImpl.call_createChannelSplitter(state, numberOfOutputs);
    }

    pub fn call_decodeAudioData(instance: *runtime.Instance, audioData: anyopaque, successCallback: anyopaque, errorCallback: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BaseAudioContextImpl.call_decodeAudioData(state, audioData, successCallback, errorCallback);
    }

};
