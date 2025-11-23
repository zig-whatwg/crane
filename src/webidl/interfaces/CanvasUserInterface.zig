//! Generated from: html.idl
//! Generated at: 2025-11-23T19:47:41Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasUserInterfaceImpl = @import("impls").CanvasUserInterface;
const Element = @import("interfaces").Element;
const Path2D = @import("interfaces").Path2D;

pub const CanvasUserInterface = struct {
    pub const Meta = struct {
        pub const name = "CanvasUserInterface";
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
            .{ "drawFocusIfNeeded", "call_drawFocusIfNeeded", 1 },
            .{ "drawFocusIfNeeded", "call_drawFocusIfNeeded", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "drawFocusIfNeeded",
            "drawFocusIfNeeded",
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

        .call_drawFocusIfNeeded = &call_drawFocusIfNeeded,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasUserInterfaceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasUserInterfaceImpl.deinit(instance);
    }

    pub fn call_drawFocusIfNeeded(instance: *runtime.Instance, element: *runtime.Instance) anyerror!void {
        
        return try CanvasUserInterfaceImpl.call_drawFocusIfNeeded(instance, element);
    }

};
