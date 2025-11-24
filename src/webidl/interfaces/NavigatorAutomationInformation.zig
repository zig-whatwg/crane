//! Generated from: webdriver.idl
//! Generated at: 2025-11-24T18:47:08Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorAutomationInformationImpl = @import("impls").NavigatorAutomationInformation;

pub const NavigatorAutomationInformation = struct {
    pub const Meta = struct {
        pub const name = "NavigatorAutomationInformation";
        pub const is_mixin = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "webdriver", "get_webdriver", null },
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
            .{ "webdriver", "get_webdriver", null },
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
            webdriver: bool = undefined,
            _internal: ?*NavigatorAutomationInformationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_webdriver = &get_webdriver,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigatorAutomationInformationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorAutomationInformationImpl.deinit(instance);
    }

    pub fn get_webdriver(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorAutomationInformationImpl.get_webdriver(instance);
    }

};
