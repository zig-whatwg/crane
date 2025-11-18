//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLOptionsCollectionImpl = @import("impls").HTMLOptionsCollection;
const HTMLCollection = @import("interfaces").HTMLCollection;
const HTMLOptionElement = @import("interfaces").HTMLOptionElement;
const (HTMLOptionElement or HTMLOptGroupElement) = @import("interfaces").(HTMLOptionElement or HTMLOptGroupElement);
const (HTMLElement or long) = @import("interfaces").(HTMLElement or long);

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
        
        // Initialize the instance (Impl receives full instance)
        HTMLOptionsCollectionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLOptionsCollectionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLOptionsCollectionImpl.get_length(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLOptionsCollectionImpl.get_length(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_length(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLOptionsCollectionImpl.set_length(instance, value);
    }

    pub fn get_selectedIndex(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLOptionsCollectionImpl.get_selectedIndex(instance);
    }

    pub fn set_selectedIndex(instance: *runtime.Instance, value: i32) anyerror!void {
        try HTMLOptionsCollectionImpl.set_selectedIndex(instance, value);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!anyopaque {
        
        return try HTMLOptionsCollectionImpl.call_item(instance, index);
    }

    pub fn call_namedItem(instance: *runtime.Instance, name: DOMString) anyerror!anyopaque {
        
        return try HTMLOptionsCollectionImpl.call_namedItem(instance, name);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_add(instance: *runtime.Instance, element: anyopaque, before: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try HTMLOptionsCollectionImpl.call_add(instance, element, before);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_remove(instance: *runtime.Instance, index: i32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try HTMLOptionsCollectionImpl.call_remove(instance, index);
    }

};
