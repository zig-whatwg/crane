//! Generated from: gpc.idl
//! Generated at: 2025-11-23T14:26:29Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GlobalPrivacyControlImpl = @import("impls").GlobalPrivacyControl;

pub const GlobalPrivacyControl = struct {
    pub const Meta = struct {
        pub const name = "GlobalPrivacyControl";
        pub const is_mixin = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "globalPrivacyControl", "get_globalPrivacyControl", null },
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
            .{ "globalPrivacyControl", "get_globalPrivacyControl", null },
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
            globalPrivacyControl: bool = undefined,
            _internal: ?*GlobalPrivacyControlImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_globalPrivacyControl = &get_globalPrivacyControl,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GlobalPrivacyControlImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GlobalPrivacyControlImpl.deinit(instance);
    }

    pub fn get_globalPrivacyControl(instance: *runtime.Instance) anyerror!bool {
        return try GlobalPrivacyControlImpl.get_globalPrivacyControl(instance);
    }

};
