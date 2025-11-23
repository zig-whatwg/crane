//! Generated from: mediaqueries-5.idl
//! Generated at: 2025-11-23T14:26:29Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PreferenceManagerImpl = @import("impls").PreferenceManager;
const PreferenceObject = @import("interfaces").PreferenceObject;

pub const PreferenceManager = struct {
    pub const Meta = struct {
        pub const name = "PreferenceManager";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "colorScheme", "get_colorScheme", null },
            .{ "contrast", "get_contrast", null },
            .{ "reducedMotion", "get_reducedMotion", null },
            .{ "reducedTransparency", "get_reducedTransparency", null },
            .{ "reducedData", "get_reducedData", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "colorScheme", "get_colorScheme", null },
            .{ "contrast", "get_contrast", null },
            .{ "reducedMotion", "get_reducedMotion", null },
            .{ "reducedTransparency", "get_reducedTransparency", null },
            .{ "reducedData", "get_reducedData", null },
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
            colorScheme: PreferenceObject = undefined,
            contrast: PreferenceObject = undefined,
            reducedMotion: PreferenceObject = undefined,
            reducedTransparency: PreferenceObject = undefined,
            reducedData: PreferenceObject = undefined,
            _internal: ?*PreferenceManagerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_colorScheme = &get_colorScheme,
        .get_contrast = &get_contrast,
        .get_reducedData = &get_reducedData,
        .get_reducedMotion = &get_reducedMotion,
        .get_reducedTransparency = &get_reducedTransparency,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PreferenceManagerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PreferenceManagerImpl.deinit(instance);
    }

    pub fn get_colorScheme(instance: *runtime.Instance) anyerror!PreferenceObject {
        return try PreferenceManagerImpl.get_colorScheme(instance);
    }

    pub fn get_contrast(instance: *runtime.Instance) anyerror!PreferenceObject {
        return try PreferenceManagerImpl.get_contrast(instance);
    }

    pub fn get_reducedMotion(instance: *runtime.Instance) anyerror!PreferenceObject {
        return try PreferenceManagerImpl.get_reducedMotion(instance);
    }

    pub fn get_reducedTransparency(instance: *runtime.Instance) anyerror!PreferenceObject {
        return try PreferenceManagerImpl.get_reducedTransparency(instance);
    }

    pub fn get_reducedData(instance: *runtime.Instance) anyerror!PreferenceObject {
        return try PreferenceManagerImpl.get_reducedData(instance);
    }

};
