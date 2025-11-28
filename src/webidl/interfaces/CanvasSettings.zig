//! Generated from: html.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasSettingsImpl = @import("impls").CanvasSettings;
const mixins = @import("mixins");
const CanvasRenderingContext2DSettings = @import("dictionaries").CanvasRenderingContext2DSettings;

pub const CanvasSettings = struct {
    pub const Meta = struct {
        pub const name = "CanvasSettings";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getContextAttributes", "call_getContextAttributes", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getContextAttributes",
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
            _internal: ?*CanvasSettingsImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_getContextAttributes = &call_getContextAttributes,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasSettingsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasSettingsImpl.deinit(instance);
    }

    pub fn call_getContextAttributes(instance: *runtime.Instance) anyerror!CanvasRenderingContext2DSettings {
        return try CanvasSettingsImpl.call_getContextAttributes(instance);
    }

};
