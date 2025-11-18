//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorPluginsImpl = @import("impls").NavigatorPlugins;
const MimeTypeArray = @import("interfaces").MimeTypeArray;
const PluginArray = @import("interfaces").PluginArray;

pub const NavigatorPlugins = struct {
    pub const Meta = struct {
        pub const name = "NavigatorPlugins";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            plugins: PluginArray = undefined,
            mimeTypes: MimeTypeArray = undefined,
            pdfViewerEnabled: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigatorPlugins, .{
        .deinit_fn = &deinit_wrapper,

        .get_mimeTypes = &get_mimeTypes,
        .get_pdfViewerEnabled = &get_pdfViewerEnabled,
        .get_plugins = &get_plugins,

        .call_javaEnabled = &call_javaEnabled,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        NavigatorPluginsImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorPluginsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_plugins(instance: *runtime.Instance) anyerror!PluginArray {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_plugins) |cached| {
            return cached;
        }
        const value = try NavigatorPluginsImpl.get_plugins(instance);
        state.cached_plugins = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_mimeTypes(instance: *runtime.Instance) anyerror!MimeTypeArray {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_mimeTypes) |cached| {
            return cached;
        }
        const value = try NavigatorPluginsImpl.get_mimeTypes(instance);
        state.cached_mimeTypes = value;
        return value;
    }

    pub fn get_pdfViewerEnabled(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorPluginsImpl.get_pdfViewerEnabled(instance);
    }

    pub fn call_javaEnabled(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorPluginsImpl.call_javaEnabled(instance);
    }

};
