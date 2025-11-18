//! Generated from: presentation-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PresentationRequestImpl = @import("impls").PresentationRequest;
const EventTarget = @import("interfaces").EventTarget;
const EventHandler = @import("typedefs").EventHandler;
const Promise<PresentationConnection> = @import("interfaces").Promise<PresentationConnection>;
const Promise<PresentationAvailability> = @import("interfaces").Promise<PresentationAvailability>;

pub const PresentationRequest = struct {
    pub const Meta = struct {
        pub const name = "PresentationRequest";
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
            onconnectionavailable: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PresentationRequest, .{
        .deinit_fn = &deinit_wrapper,

        .get_onconnectionavailable = &get_onconnectionavailable,

        .set_onconnectionavailable = &set_onconnectionavailable,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getAvailability = &call_getAvailability,
        .call_reconnect = &call_reconnect,
        .call_removeEventListener = &call_removeEventListener,
        .call_start = &call_start,
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
        PresentationRequestImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PresentationRequestImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, url: runtime.USVString) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try PresentationRequestImpl.constructor(instance, url);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, urls: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try PresentationRequestImpl.constructor(instance, urls);
        
        return instance;
    }

    pub fn get_onconnectionavailable(instance: *runtime.Instance) anyerror!EventHandler {
        return try PresentationRequestImpl.get_onconnectionavailable(instance);
    }

    pub fn set_onconnectionavailable(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PresentationRequestImpl.set_onconnectionavailable(instance, value);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try PresentationRequestImpl.call_when(instance, type_, options);
    }

    pub fn call_reconnect(instance: *runtime.Instance, presentationId: runtime.USVString) anyerror!anyopaque {
        
        return try PresentationRequestImpl.call_reconnect(instance, presentationId);
    }

    pub fn call_getAvailability(instance: *runtime.Instance) anyerror!anyopaque {
        return try PresentationRequestImpl.call_getAvailability(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try PresentationRequestImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!anyopaque {
        return try PresentationRequestImpl.call_start(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try PresentationRequestImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try PresentationRequestImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
