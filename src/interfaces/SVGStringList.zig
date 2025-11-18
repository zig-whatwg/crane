//! Generated from: SVG.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGStringListImpl = @import("../impls/SVGStringList.zig");

pub const SVGStringList = struct {
    pub const Meta = struct {
        pub const name = "SVGStringList";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            length: u32 = undefined,
            numberOfItems: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SVGStringList, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_numberOfItems = &get_numberOfItems,

        .call_appendItem = &call_appendItem,
        .call_clear = &call_clear,
        .call_getItem = &call_getItem,
        .call_initialize = &call_initialize,
        .call_insertItemBefore = &call_insertItemBefore,
        .call_removeItem = &call_removeItem,
        .call_replaceItem = &call_replaceItem,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SVGStringListImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SVGStringListImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return SVGStringListImpl.get_length(state);
    }

    pub fn get_numberOfItems(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return SVGStringListImpl.get_numberOfItems(state);
    }

    pub fn call_removeItem(instance: *runtime.Instance, index: u32) runtime.DOMString {
        const state = instance.getState(State);
        
        return SVGStringListImpl.call_removeItem(state, index);
    }

    pub fn call_insertItemBefore(instance: *runtime.Instance, newItem: runtime.DOMString, index: u32) runtime.DOMString {
        const state = instance.getState(State);
        
        return SVGStringListImpl.call_insertItemBefore(state, newItem, index);
    }

    pub fn call_getItem(instance: *runtime.Instance, index: u32) runtime.DOMString {
        const state = instance.getState(State);
        
        return SVGStringListImpl.call_getItem(state, index);
    }

    pub fn call_replaceItem(instance: *runtime.Instance, newItem: runtime.DOMString, index: u32) runtime.DOMString {
        const state = instance.getState(State);
        
        return SVGStringListImpl.call_replaceItem(state, newItem, index);
    }

    pub fn call_clear(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGStringListImpl.call_clear(state);
    }

    pub fn call_initialize(instance: *runtime.Instance, newItem: runtime.DOMString) runtime.DOMString {
        const state = instance.getState(State);
        
        return SVGStringListImpl.call_initialize(state, newItem);
    }

    pub fn call_appendItem(instance: *runtime.Instance, newItem: runtime.DOMString) runtime.DOMString {
        const state = instance.getState(State);
        
        return SVGStringListImpl.call_appendItem(state, newItem);
    }

};
