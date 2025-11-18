//! Generated from: dom.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NamedNodeMapImpl = @import("impls").NamedNodeMap;
const Attr = @import("interfaces").Attr;
const DOMString = @import("typedefs").DOMString;

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
        
        // Initialize the instance (Impl receives full instance)
        NamedNodeMapImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NamedNodeMapImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try NamedNodeMapImpl.get_length(instance);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!anyopaque {
        
        return try NamedNodeMapImpl.call_item(instance, index);
    }

    pub fn call_getNamedItemNS(instance: *runtime.Instance, namespace: anyopaque, localName: DOMString) anyerror!anyopaque {
        
        return try NamedNodeMapImpl.call_getNamedItemNS(instance, namespace, localName);
    }

    pub fn call_getNamedItem(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!anyopaque {
        
        return try NamedNodeMapImpl.call_getNamedItem(instance, qualifiedName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setNamedItemNS(instance: *runtime.Instance, attr: Attr) anyerror!anyopaque {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try NamedNodeMapImpl.call_setNamedItemNS(instance, attr);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeNamedItem(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!Attr {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try NamedNodeMapImpl.call_removeNamedItem(instance, qualifiedName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeNamedItemNS(instance: *runtime.Instance, namespace: anyopaque, localName: DOMString) anyerror!Attr {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try NamedNodeMapImpl.call_removeNamedItemNS(instance, namespace, localName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setNamedItem(instance: *runtime.Instance, attr: Attr) anyerror!anyopaque {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try NamedNodeMapImpl.call_setNamedItem(instance, attr);
    }

};
