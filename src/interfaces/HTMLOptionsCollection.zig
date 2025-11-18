//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLOptionsCollectionImpl = @import("../impls/HTMLOptionsCollection.zig");
const HTMLCollection = @import("HTMLCollection.zig");

pub const HTMLOptionsCollection = struct {
    pub const Meta = struct {
        pub const name = "HTMLOptionsCollection";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *HTMLCollection;
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
            selectedIndex: i32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(HTMLOptionsCollection, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_length = &get_length,
        .get_selectedIndex = &get_selectedIndex,

        .set_length = &set_length,
        .set_selectedIndex = &set_selectedIndex,

        .call_add = &call_add,
        .call_item = &call_item,
        .call_namedItem = &call_namedItem,
        .call_remove = &call_remove,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        HTMLOptionsCollectionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        HTMLOptionsCollectionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return HTMLOptionsCollectionImpl.get_length(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return HTMLOptionsCollectionImpl.get_length(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_length(instance: *runtime.Instance, value: u32) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLOptionsCollectionImpl.set_length(state, value);
    }

    pub fn get_selectedIndex(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return HTMLOptionsCollectionImpl.get_selectedIndex(state);
    }

    pub fn set_selectedIndex(instance: *runtime.Instance, value: i32) void {
        const state = instance.getState(State);
        HTMLOptionsCollectionImpl.set_selectedIndex(state, value);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyopaque {
        const state = instance.getState(State);
        
        return HTMLOptionsCollectionImpl.call_item(state, index);
    }

    pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return HTMLOptionsCollectionImpl.call_namedItem(state, name);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_add(instance: *runtime.Instance, element: anyopaque, before: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLOptionsCollectionImpl.call_add(state, element, before);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_remove(instance: *runtime.Instance, index: i32) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLOptionsCollectionImpl.call_remove(state, index);
    }

};
