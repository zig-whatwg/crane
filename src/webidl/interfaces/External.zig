//! Generated from: html.idl
//! Generated at: 2025-11-29T05:01:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ExternalImpl = @import("impls").External;
const mixins = @import("mixins");

pub const External = struct {
    pub const Meta = struct {
        pub const name = "External";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "AddSearchProvider", "call_AddSearchProvider", 0 },
            .{ "IsSearchProviderInstalled", "call_IsSearchProviderInstalled", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "AddSearchProvider",
            "IsSearchProviderInstalled",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*ExternalImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_AddSearchProvider = &call_AddSearchProvider,
        .call_IsSearchProviderInstalled = &call_IsSearchProviderInstalled,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ExternalImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ExternalImpl.deinit(instance);
    }

    pub fn call_AddSearchProvider(instance: *runtime.Instance) anyerror!void {
        return try ExternalImpl.call_AddSearchProvider(instance);
    }

    pub fn call_IsSearchProviderInstalled(instance: *runtime.Instance) anyerror!void {
        return try ExternalImpl.call_IsSearchProviderInstalled(instance);
    }

};
