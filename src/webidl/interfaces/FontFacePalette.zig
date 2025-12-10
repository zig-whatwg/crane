//! Generated from: css-font-loading.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FontFacePaletteImpl = @import("impls").FontFacePalette;
const mixins = @import("mixins");
const DOMString = @import("typedefs").DOMString;

pub const FontFacePalette = struct {
    pub const Meta = struct {
        pub const name = "FontFacePalette";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
            .{ "usableWithLightBackground", "get_usableWithLightBackground", null },
            .{ "usableWithDarkBackground", "get_usableWithDarkBackground", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "forEach", "call_forEach", 1 },
            .{ "forEach", "call_forEach", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "forEach",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
            .{ "usableWithLightBackground", "get_usableWithLightBackground", null },
            .{ "usableWithDarkBackground", "get_usableWithDarkBackground", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
        
        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "runtime.DOMString",
            .key_type = null,
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            usableWithLightBackground: bool = undefined,
            usableWithDarkBackground: bool = undefined,
            _internal: ?*FontFacePaletteImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,
        .get_usableWithDarkBackground = &get_usableWithDarkBackground,
        .get_usableWithLightBackground = &get_usableWithLightBackground,

        .call_forEach = &call_forEach,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FontFacePaletteImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return FontFacePaletteImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FontFacePaletteImpl.deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try FontFacePaletteImpl.get_length(instance);
    }

    pub fn get_usableWithLightBackground(instance: *runtime.Instance) anyerror!bool {
        return try FontFacePaletteImpl.get_usableWithLightBackground(instance);
    }

    pub fn get_usableWithDarkBackground(instance: *runtime.Instance) anyerror!bool {
        return try FontFacePaletteImpl.get_usableWithDarkBackground(instance);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: runtime.JSValue) anyerror!void {
        
        return try FontFacePaletteImpl.call_forEach(instance, callback);
    }

};
