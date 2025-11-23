//! Generated from: web-app-launch.idl
//! Generated at: 2025-11-23T01:18:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LaunchParamsImpl = @import("impls").LaunchParams;
const DOMString = @import("typedefs").DOMString;
const FileSystemHandle = @import("interfaces").FileSystemHandle;

pub const LaunchParams = struct {
    pub const Meta = struct {
        pub const name = "LaunchParams";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "targetURL", "get_targetURL", null },
            .{ "files", "get_files", null },
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
            .{ "targetURL", "get_targetURL", null },
            .{ "files", "get_files", null },
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
            targetURL: ?runtime.DOMString = null,
            files: runtime.FrozenArray(FileSystemHandle) = undefined,
        },
    );

    const delegates = .{

        .get_files = &get_files,
        .get_targetURL = &get_targetURL,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return LaunchParamsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LaunchParamsImpl.deinit(instance);
    }

    pub fn get_targetURL(instance: *runtime.Instance) anyerror!DOMString {
        return try LaunchParamsImpl.get_targetURL(instance);
    }

    pub fn get_files(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try LaunchParamsImpl.get_files(instance);
    }

};
