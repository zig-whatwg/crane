//! Generated from: geometry.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DOMRectImpl = @import("impls").DOMRect;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMRectReadOnly = @import("DOMRectReadOnly.zig").DOMRectReadOnly;
const DOMRectInit = @import("dictionaries").DOMRectInit;

pub const DOMRect = struct {
    pub const Meta = struct {
        pub const name = "DOMRect";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = DOMRectReadOnly.State;
        pub const ParentInterface = DOMRectReadOnly;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
            .{ .name = "LegacyWindowAlias", .value = .{ .identifier = "SVGRect" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "toJSON",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "fromRect", "call_static_fromRect", 0 },
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            x: f64 = undefined,
            y: f64 = undefined,
            width: f64 = undefined,
            height: f64 = undefined,
            _internal: ?*DOMRectImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_height = &get_height,
        .get_width = &get_width,
        .get_x = &get_x,
        .get_y = &get_y,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DOMRectImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return DOMRectImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMRectImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, x: webidl.Opt(f64), y: webidl.Opt(f64), width: webidl.Opt(f64), height: webidl.Opt(f64)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DOMRectImpl.call_constructor(ctx, x, y, width, height);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectImpl.get_y(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectImpl.get_height(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_fromRect(instance: *runtime.Instance, other: webidl.Opt(DOMRectInit)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMRectImpl.call_static_fromRect(instance, other);
    }

};
