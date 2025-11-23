//! Generated from: html.idl
//! Generated at: 2025-11-23T19:17:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasDrawImageImpl = @import("impls").CanvasDrawImage;
const CanvasImageSource = @import("typedefs").CanvasImageSource;

pub const CanvasDrawImage = struct {
    pub const Meta = struct {
        pub const name = "CanvasDrawImage";
        pub const is_mixin = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "drawImage", "call_drawImage", 3 },
            .{ "drawImage", "call_drawImage", 5 },
            .{ "drawImage", "call_drawImage", 9 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "drawImage",
            "drawImage",
            "drawImage",
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
        struct {},
    );

    const delegates = .{

        .call_drawImage = &call_drawImage,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasDrawImageImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasDrawImageImpl.deinit(instance);
    }

    pub fn call_drawImage(instance: *runtime.Instance, image: CanvasImageSource, dx: f64, dy: f64) anyerror!void {
        
        return try CanvasDrawImageImpl.call_drawImage(instance, image, dx, dy);
    }

};
