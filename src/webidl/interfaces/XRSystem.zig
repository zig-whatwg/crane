//! Generated from: webxr.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRSystemImpl = @import("impls").XRSystem;
const EventTarget = @import("interfaces").EventTarget;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const Promise<XRSession> = @import("interfaces").Promise<XRSession>;
const XRSessionInit = @import("dictionaries").XRSessionInit;
const EventHandler = @import("typedefs").EventHandler;
const XRSessionMode = @import("enums").XRSessionMode;

pub const XRSystem = struct {
    pub const Meta = struct {
        pub const name = "XRSystem";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            ondevicechange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRSystem, .{
        .deinit_fn = &deinit_wrapper,

        .get_ondevicechange = &get_ondevicechange,

        .set_ondevicechange = &set_ondevicechange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_isSessionSupported = &call_isSessionSupported,
        .call_removeEventListener = &call_removeEventListener,
        .call_requestSession = &call_requestSession,
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
        XRSystemImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRSystemImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_ondevicechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRSystemImpl.get_ondevicechange(instance);
    }

    pub fn set_ondevicechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRSystemImpl.set_ondevicechange(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try XRSystemImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_isSessionSupported(instance: *runtime.Instance, mode: XRSessionMode) anyerror!anyopaque {
        
        return try XRSystemImpl.call_isSessionSupported(instance, mode);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try XRSystemImpl.call_when(instance, type_, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_requestSession(instance: *runtime.Instance, mode: XRSessionMode, options: XRSessionInit) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try XRSystemImpl.call_requestSession(instance, mode, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XRSystemImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XRSystemImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
