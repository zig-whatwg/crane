//! Generated from: html.idl
//! Generated at: 2025-11-23T19:17:37Z
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
        pub const is_mixin = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "plugins", "get_plugins", null },
            .{ "mimeTypes", "get_mimeTypes", null },
            .{ "pdfViewerEnabled", "get_pdfViewerEnabled", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "javaEnabled", "call_javaEnabled", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "javaEnabled",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "plugins", "get_plugins", null },
            .{ "mimeTypes", "get_mimeTypes", null },
            .{ "pdfViewerEnabled", "get_pdfViewerEnabled", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            plugins: PluginArray = undefined,
            mimeTypes: MimeTypeArray = undefined,
            pdfViewerEnabled: bool = undefined,
            cached_plugins: ?PluginArray = null,
            cached_mimeTypes: ?MimeTypeArray = null,
            _internal: ?*NavigatorPluginsImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_mimeTypes = &get_mimeTypes,
        .get_pdfViewerEnabled = &get_pdfViewerEnabled,
        .get_plugins = &get_plugins,

        .call_javaEnabled = &call_javaEnabled,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigatorPluginsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorPluginsImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_plugins(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_plugins) |cached| {
            return cached;
        }
        const value = try NavigatorPluginsImpl.get_plugins(instance);
        state.own.cached_plugins = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_mimeTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_mimeTypes) |cached| {
            return cached;
        }
        const value = try NavigatorPluginsImpl.get_mimeTypes(instance);
        state.own.cached_mimeTypes = value;
        return value;
    }

    pub fn get_pdfViewerEnabled(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorPluginsImpl.get_pdfViewerEnabled(instance);
    }

    pub fn call_javaEnabled(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorPluginsImpl.call_javaEnabled(instance);
    }

};
