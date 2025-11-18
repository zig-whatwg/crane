//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMTokenListImpl = @import("../impls/DOMTokenList.zig");

pub const DOMTokenList = struct {
    pub const Meta = struct {
        pub const name = "DOMTokenList";
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
            value: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DOMTokenList, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_value = &get_value,

        .set_value = &set_value,

        .call_add = &call_add,
        .call_contains = &call_contains,
        .call_item = &call_item,
        .call_remove = &call_remove,
        .call_replace = &call_replace,
        .call_supports = &call_supports,
        .call_toggle = &call_toggle,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        DOMTokenListImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DOMTokenListImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return DOMTokenListImpl.get_length(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_value(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return DOMTokenListImpl.get_value(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        DOMTokenListImpl.set_value(state, value);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyopaque {
        const state = instance.getState(State);
        
        return DOMTokenListImpl.call_item(state, index);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_replace(instance: *runtime.Instance, token: runtime.DOMString, newToken: runtime.DOMString) bool {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return DOMTokenListImpl.call_replace(state, token, newToken);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_toggle(instance: *runtime.Instance, token: runtime.DOMString, force: bool) bool {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return DOMTokenListImpl.call_toggle(state, token, force);
    }

    pub fn call_contains(instance: *runtime.Instance, token: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return DOMTokenListImpl.call_contains(state, token);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_add(instance: *runtime.Instance, tokens: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return DOMTokenListImpl.call_add(state, tokens);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_remove(instance: *runtime.Instance, tokens: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return DOMTokenListImpl.call_remove(state, tokens);
    }

    pub fn call_supports(instance: *runtime.Instance, token: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return DOMTokenListImpl.call_supports(state, token);
    }

};
