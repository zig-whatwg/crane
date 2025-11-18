//! Generated from: netinfo.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NetworkInformationImpl = @import("../impls/NetworkInformation.zig");
const EventTarget = @import("EventTarget.zig");
const NetworkInformationSaveData = @import("NetworkInformationSaveData.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        NetworkInformationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NetworkInformationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NetworkInformationImpl.get_type(state);
    }

    pub fn get_effectiveType(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NetworkInformationImpl.get_effectiveType(state);
    }

    pub fn get_downlinkMax(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NetworkInformationImpl.get_downlinkMax(state);
    }

    pub fn get_downlink(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NetworkInformationImpl.get_downlink(state);
    }

    pub fn get_rtt(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NetworkInformationImpl.get_rtt(state);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NetworkInformationImpl.get_onchange(state);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        NetworkInformationImpl.set_onchange(state, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_saveData(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_saveData) |cached| {
            return cached;
        }
        const value = NetworkInformationImpl.get_saveData(state);
        state.cached_saveData = value;
        return value;
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return NetworkInformationImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NetworkInformationImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NetworkInformationImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NetworkInformationImpl.call_removeEventListener(state, type_, callback, options);
    }

};
