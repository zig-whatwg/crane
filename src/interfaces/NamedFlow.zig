//! Generated from: css-regions.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NamedFlowImpl = @import("../impls/NamedFlow.zig");
const EventTarget = @import("EventTarget.zig");

pub const NamedFlow = struct {
    pub const Meta = struct {
        pub const name = "NamedFlow";
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
            name: CSSOMString = undefined,
            overset: bool = undefined,
            firstEmptyRegionIndex: i16 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NamedFlow, .{
        .deinit_fn = &deinit_wrapper,

        .get_firstEmptyRegionIndex = &get_firstEmptyRegionIndex,
        .get_name = &get_name,
        .get_overset = &get_overset,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getContent = &call_getContent,
        .call_getRegions = &call_getRegions,
        .call_getRegionsByContent = &call_getRegionsByContent,
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
        NamedFlowImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NamedFlowImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NamedFlowImpl.get_name(state);
    }

    pub fn get_overset(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NamedFlowImpl.get_overset(state);
    }

    pub fn get_firstEmptyRegionIndex(instance: *runtime.Instance) i16 {
        const state = instance.getState(State);
        return NamedFlowImpl.get_firstEmptyRegionIndex(state);
    }

    pub fn call_getRegions(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NamedFlowImpl.call_getRegions(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NamedFlowImpl.call_when(state, type_, options);
    }

    pub fn call_getContent(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NamedFlowImpl.call_getContent(state);
    }

    pub fn call_getRegionsByContent(instance: *runtime.Instance, node: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NamedFlowImpl.call_getRegionsByContent(state, node);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return NamedFlowImpl.call_dispatchEvent(state, event);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NamedFlowImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NamedFlowImpl.call_removeEventListener(state, type_, callback, options);
    }

};
