//! Generated from: cssom.idl
//! Generated at: 2025-11-23T19:47:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LinkStyleImpl = @import("impls").LinkStyle;
const StyleSheet = @import("interfaces").StyleSheet;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;

pub const LinkStyle = struct {
    pub const Meta = struct {
        pub const name = "LinkStyle";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "sheet", "get_sheet", null },
            .{ "sheet", "get_sheet", null },
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
            .{ "sheet", "get_sheet", null },
            .{ "sheet", "get_sheet", null },
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
            sheet: ?*runtime.Instance = null,
            _internal: ?*LinkStyleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_sheet = &get_sheet,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return LinkStyleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LinkStyleImpl.deinit(instance);
    }

    pub fn get_sheet(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try LinkStyleImpl.get_sheet(instance);
    }

};
