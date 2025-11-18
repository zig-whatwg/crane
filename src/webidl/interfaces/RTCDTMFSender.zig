//! Generated from: webrtc.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCDTMFSenderImpl = @import("impls").RTCDTMFSender;
const EventTarget = @import("interfaces").EventTarget;
const EventHandler = @import("typedefs").EventHandler;

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
        
        // Initialize the instance (Impl receives full instance)
        RTCDTMFSenderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCDTMFSenderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_ontonechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCDTMFSenderImpl.get_ontonechange(instance);
    }

    pub fn set_ontonechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCDTMFSenderImpl.set_ontonechange(instance, value);
    }

    pub fn get_canInsertDTMF(instance: *runtime.Instance) anyerror!bool {
        return try RTCDTMFSenderImpl.get_canInsertDTMF(instance);
    }

    pub fn get_toneBuffer(instance: *runtime.Instance) anyerror!DOMString {
        return try RTCDTMFSenderImpl.get_toneBuffer(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try RTCDTMFSenderImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_insertDTMF(instance: *runtime.Instance, tones: DOMString, duration: u32, interToneGap: u32) anyerror!void {
        
        return try RTCDTMFSenderImpl.call_insertDTMF(instance, tones, duration, interToneGap);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try RTCDTMFSenderImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try RTCDTMFSenderImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try RTCDTMFSenderImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
