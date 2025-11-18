//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PluginImpl = @import("impls").Plugin;
const MimeType = @import("interfaces").MimeType;

pub const Plugin = struct {
    pub const Meta = struct {
        pub const name = "Plugin";
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
            name: runtime.DOMString = undefined,
            description: runtime.DOMString = undefined,
            filename: runtime.DOMString = undefined,
            length: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Plugin, .{
        .deinit_fn = &deinit_wrapper,

        .get_description = &get_description,
        .get_filename = &get_filename,
        .get_length = &get_length,
        .get_name = &get_name,

        .call_item = &call_item,
        .call_namedItem = &call_namedItem,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        PluginImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PluginImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try PluginImpl.get_name(instance);
    }

    pub fn get_description(instance: *runtime.Instance) anyerror!DOMString {
        return try PluginImpl.get_description(instance);
    }

    pub fn get_filename(instance: *runtime.Instance) anyerror!DOMString {
        return try PluginImpl.get_filename(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try PluginImpl.get_length(instance);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!anyopaque {
        
        return try PluginImpl.call_item(instance, index);
    }

    pub fn call_namedItem(instance: *runtime.Instance, name: DOMString) anyerror!anyopaque {
        
        return try PluginImpl.call_namedItem(instance, name);
    }

};
