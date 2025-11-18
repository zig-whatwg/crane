//! Generated from: css-regions.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NamedFlowImpl = @import("impls").NamedFlow;
const EventTarget = @import("interfaces").EventTarget;
const Node = @import("interfaces").Node;
const CSSOMString = @import("interfaces").CSSOMString;

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
        
        // Initialize the instance (Impl receives full instance)
        NamedFlowImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NamedFlowImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!anyopaque {
        return try NamedFlowImpl.get_name(instance);
    }

    pub fn get_overset(instance: *runtime.Instance) anyerror!bool {
        return try NamedFlowImpl.get_overset(instance);
    }

    pub fn get_firstEmptyRegionIndex(instance: *runtime.Instance) anyerror!i16 {
        return try NamedFlowImpl.get_firstEmptyRegionIndex(instance);
    }

    pub fn call_getRegions(instance: *runtime.Instance) anyerror!anyopaque {
        return try NamedFlowImpl.call_getRegions(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try NamedFlowImpl.call_when(instance, type_, options);
    }

    pub fn call_getContent(instance: *runtime.Instance) anyerror!anyopaque {
        return try NamedFlowImpl.call_getContent(instance);
    }

    pub fn call_getRegionsByContent(instance: *runtime.Instance, node: Node) anyerror!anyopaque {
        
        return try NamedFlowImpl.call_getRegionsByContent(instance, node);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try NamedFlowImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try NamedFlowImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try NamedFlowImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
