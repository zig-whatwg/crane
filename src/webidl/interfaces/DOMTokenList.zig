//! Generated from: dom.idl
//! Generated at: 2025-11-18T18:28:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMTokenListImpl = @import("impls").DOMTokenList;
const DOMString = @import("typedefs").DOMString;

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
        
        // Initialize the instance (Impl receives full instance)
        DOMTokenListImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMTokenListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try DOMTokenListImpl.get_length(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_value(instance: *runtime.Instance) anyerror!DOMString {
        return try DOMTokenListImpl.get_value(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_value(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try DOMTokenListImpl.set_value(instance, value);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!anyopaque {
        
        return try DOMTokenListImpl.call_item(instance, index);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_replace(instance: *runtime.Instance, token: DOMString, newToken: DOMString) anyerror!bool {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DOMTokenListImpl.call_replace(instance, token, newToken);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_toggle(instance: *runtime.Instance, token: DOMString, force: bool) anyerror!bool {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DOMTokenListImpl.call_toggle(instance, token, force);
    }

    pub fn call_contains(instance: *runtime.Instance, token: DOMString) anyerror!bool {
        
        return try DOMTokenListImpl.call_contains(instance, token);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_add(instance: *runtime.Instance, tokens: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DOMTokenListImpl.call_add(instance, tokens);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_remove(instance: *runtime.Instance, tokens: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DOMTokenListImpl.call_remove(instance, tokens);
    }

    pub fn call_supports(instance: *runtime.Instance, token: DOMString) anyerror!bool {
        
        return try DOMTokenListImpl.call_supports(instance, token);
    }

};
