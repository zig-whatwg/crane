//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NamedNodeMapImpl = @import("../impls/NamedNodeMap.zig");

pub const NamedNodeMap = struct {
    pub const Meta = struct {
        pub const name = "NamedNodeMap";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "LegacyUnenumerableNamedProperties" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            length: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NamedNodeMap, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,

        .call_getNamedItem = &call_getNamedItem,
        .call_getNamedItemNS = &call_getNamedItemNS,
        .call_item = &call_item,
        .call_removeNamedItem = &call_removeNamedItem,
        .call_removeNamedItemNS = &call_removeNamedItemNS,
        .call_setNamedItem = &call_setNamedItem,
        .call_setNamedItemNS = &call_setNamedItemNS,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        NamedNodeMapImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NamedNodeMapImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return NamedNodeMapImpl.get_length(state);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyopaque {
        const state = instance.getState(State);
        
        return NamedNodeMapImpl.call_item(state, index);
    }

    pub fn call_getNamedItemNS(instance: *runtime.Instance, namespace: anyopaque, localName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return NamedNodeMapImpl.call_getNamedItemNS(state, namespace, localName);
    }

    pub fn call_getNamedItem(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return NamedNodeMapImpl.call_getNamedItem(state, qualifiedName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setNamedItemNS(instance: *runtime.Instance, attr: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return NamedNodeMapImpl.call_setNamedItemNS(state, attr);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeNamedItem(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return NamedNodeMapImpl.call_removeNamedItem(state, qualifiedName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeNamedItemNS(instance: *runtime.Instance, namespace: anyopaque, localName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return NamedNodeMapImpl.call_removeNamedItemNS(state, namespace, localName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setNamedItem(instance: *runtime.Instance, attr: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return NamedNodeMapImpl.call_setNamedItem(state, attr);
    }

};
