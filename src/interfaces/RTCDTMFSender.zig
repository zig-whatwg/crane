//! Generated from: webrtc.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCDTMFSenderImpl = @import("../impls/RTCDTMFSender.zig");
const EventTarget = @import("EventTarget.zig");

pub const RTCDTMFSender = struct {
    pub const Meta = struct {
        pub const name = "RTCDTMFSender";
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
            ontonechange: EventHandler = undefined,
            canInsertDTMF: bool = undefined,
            toneBuffer: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCDTMFSender, .{
        .deinit_fn = &deinit_wrapper,

        .get_canInsertDTMF = &get_canInsertDTMF,
        .get_ontonechange = &get_ontonechange,
        .get_toneBuffer = &get_toneBuffer,

        .set_ontonechange = &set_ontonechange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_insertDTMF = &call_insertDTMF,
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
        RTCDTMFSenderImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RTCDTMFSenderImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_ontonechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDTMFSenderImpl.get_ontonechange(state);
    }

    pub fn set_ontonechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCDTMFSenderImpl.set_ontonechange(state, value);
    }

    pub fn get_canInsertDTMF(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return RTCDTMFSenderImpl.get_canInsertDTMF(state);
    }

    pub fn get_toneBuffer(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return RTCDTMFSenderImpl.get_toneBuffer(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return RTCDTMFSenderImpl.call_dispatchEvent(state, event);
    }

    pub fn call_insertDTMF(instance: *runtime.Instance, tones: runtime.DOMString, duration: u32, interToneGap: u32) anyopaque {
        const state = instance.getState(State);
        
        return RTCDTMFSenderImpl.call_insertDTMF(state, tones, duration, interToneGap);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCDTMFSenderImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCDTMFSenderImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCDTMFSenderImpl.call_removeEventListener(state, type_, callback, options);
    }

};
