//! Generated from: presentation-api.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PresentationConnectionListImpl = @import("impls").PresentationConnectionList;
const EventTarget = @import("interfaces").EventTarget;
const FrozenArray<PresentationConnection> = @import("interfaces").FrozenArray<PresentationConnection>;
const EventHandler = @import("typedefs").EventHandler;

pub const PresentationConnectionList = struct {
    pub const Meta = struct {
        pub const name = "PresentationConnectionList";
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
            connections: FrozenArray<PresentationConnection> = undefined,
            onconnectionavailable: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PresentationConnectionList, .{
        .deinit_fn = &deinit_wrapper,

        .get_connections = &get_connections,
        .get_onconnectionavailable = &get_onconnectionavailable,

        .set_onconnectionavailable = &set_onconnectionavailable,

        .call_addEventListener = &call_addEventListener,
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
        
        // Initialize the instance (Impl receives full instance)
        PresentationConnectionListImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PresentationConnectionListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_connections(instance: *runtime.Instance) anyerror!anyopaque {
        return try PresentationConnectionListImpl.get_connections(instance);
    }

    pub fn get_onconnectionavailable(instance: *runtime.Instance) anyerror!EventHandler {
        return try PresentationConnectionListImpl.get_onconnectionavailable(instance);
    }

    pub fn set_onconnectionavailable(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PresentationConnectionListImpl.set_onconnectionavailable(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try PresentationConnectionListImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try PresentationConnectionListImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try PresentationConnectionListImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try PresentationConnectionListImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
