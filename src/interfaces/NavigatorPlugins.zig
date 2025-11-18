//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorPluginsImpl = @import("../impls/NavigatorPlugins.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        NavigatorPluginsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NavigatorPluginsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_plugins(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_plugins) |cached| {
            return cached;
        }
        const value = NavigatorPluginsImpl.get_plugins(state);
        state.cached_plugins = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_mimeTypes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_mimeTypes) |cached| {
            return cached;
        }
        const value = NavigatorPluginsImpl.get_mimeTypes(state);
        state.cached_mimeTypes = value;
        return value;
    }

    pub fn get_pdfViewerEnabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigatorPluginsImpl.get_pdfViewerEnabled(state);
    }

    pub fn call_javaEnabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigatorPluginsImpl.call_javaEnabled(state);
    }

};
