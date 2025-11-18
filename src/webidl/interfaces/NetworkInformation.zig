//! Generated from: netinfo.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NetworkInformationImpl = @import("impls").NetworkInformation;
const EventTarget = @import("interfaces").EventTarget;
const NetworkInformationSaveData = @import("interfaces").NetworkInformationSaveData;
const Millisecond = @import("typedefs").Millisecond;
const Megabit = @import("typedefs").Megabit;
const ConnectionType = @import("enums").ConnectionType;
const EffectiveConnectionType = @import("enums").EffectiveConnectionType;
const EventHandler = @import("typedefs").EventHandler;

pub const NetworkInformation = struct {
    pub const Meta = struct {
        pub const name = "NetworkInformation";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{
            NetworkInformationSaveData,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            type: ConnectionType = undefined,
            effectiveType: EffectiveConnectionType = undefined,
            downlinkMax: Megabit = undefined,
            downlink: Megabit = undefined,
            rtt: Millisecond = undefined,
            onchange: EventHandler = undefined,
            saveData: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NetworkInformation, .{
        .deinit_fn = &deinit_wrapper,

        .get_downlink = &get_downlink,
        .get_downlinkMax = &get_downlinkMax,
        .get_effectiveType = &get_effectiveType,
        .get_onchange = &get_onchange,
        .get_rtt = &get_rtt,
        .get_saveData = &get_saveData,
        .get_type = &get_type,

        .set_onchange = &set_onchange,

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
        NetworkInformationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NetworkInformationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!ConnectionType {
        return try NetworkInformationImpl.get_type(instance);
    }

    pub fn get_effectiveType(instance: *runtime.Instance) anyerror!EffectiveConnectionType {
        return try NetworkInformationImpl.get_effectiveType(instance);
    }

    pub fn get_downlinkMax(instance: *runtime.Instance) anyerror!Megabit {
        return try NetworkInformationImpl.get_downlinkMax(instance);
    }

    pub fn get_downlink(instance: *runtime.Instance) anyerror!Megabit {
        return try NetworkInformationImpl.get_downlink(instance);
    }

    pub fn get_rtt(instance: *runtime.Instance) anyerror!Millisecond {
        return try NetworkInformationImpl.get_rtt(instance);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try NetworkInformationImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NetworkInformationImpl.set_onchange(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_saveData(instance: *runtime.Instance) anyerror!bool {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_saveData) |cached| {
            return cached;
        }
        const value = try NetworkInformationImpl.get_saveData(instance);
        state.cached_saveData = value;
        return value;
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try NetworkInformationImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try NetworkInformationImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try NetworkInformationImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try NetworkInformationImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
