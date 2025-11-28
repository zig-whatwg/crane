//! Generated from: html.idl
//! Generated at: 2025-11-28T03:24:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorLanguageImpl = @import("impls").NavigatorLanguage;
const DOMString = @import("typedefs").DOMString;

pub const NavigatorLanguage = struct {
    pub const Meta = struct {
        pub const name = "NavigatorLanguage";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "language", "get_language", null },
            .{ "languages", "get_languages", null },
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
            .{ "language", "get_language", null },
            .{ "languages", "get_languages", null },
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
            language: runtime.DOMString = undefined,
            languages: runtime.FrozenArray(runtime.DOMString) = undefined,
            _internal: ?*NavigatorLanguageImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_language = &get_language,
        .get_languages = &get_languages,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigatorLanguageImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorLanguageImpl.deinit(instance);
    }

    pub fn get_language(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorLanguageImpl.get_language(instance);
    }

    pub fn get_languages(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigatorLanguageImpl.get_languages(instance);
    }

};
