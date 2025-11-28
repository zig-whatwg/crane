//! Generated from: resize-observer.idl
//! Generated at: 2025-11-28T22:33:18Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ResizeObserverSizeImpl = @import("impls").ResizeObserverSize;
const mixins = @import("mixins");

pub const ResizeObserverSize = struct {
    pub const Meta = struct {
        pub const name = "ResizeObserverSize";
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
            .{ "inlineSize", "get_inlineSize", null },
            .{ "blockSize", "get_blockSize", null },
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
            .{ "inlineSize", "get_inlineSize", null },
            .{ "blockSize", "get_blockSize", null },
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
            inlineSize: f64 = undefined,
            blockSize: f64 = undefined,
            _internal: ?*ResizeObserverSizeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_blockSize = &get_blockSize,
        .get_inlineSize = &get_inlineSize,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ResizeObserverSizeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ResizeObserverSizeImpl.deinit(instance);
    }

    pub fn get_inlineSize(instance: *runtime.Instance) anyerror!f64 {
        return try ResizeObserverSizeImpl.get_inlineSize(instance);
    }

    pub fn get_blockSize(instance: *runtime.Instance) anyerror!f64 {
        return try ResizeObserverSizeImpl.get_blockSize(instance);
    }

};
