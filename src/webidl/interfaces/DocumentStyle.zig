//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-28T18:02:24Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DocumentStyleImpl = @import("impls").DocumentStyle;
const StyleSheetList = @import("interfaces").StyleSheetList;

pub const DocumentStyle = struct {
    pub const Meta = struct {
        pub const name = "DocumentStyle";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "styleSheets", "get_styleSheets", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "styleSheets", "get_styleSheets", null },
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
            styleSheets: *runtime.Instance = undefined,
            _internal: ?*DocumentStyleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_styleSheets = &get_styleSheets,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DocumentStyleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DocumentStyleImpl.deinit(instance);
    }

    pub fn get_styleSheets(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try DocumentStyleImpl.get_styleSheets(instance);
    }

};
