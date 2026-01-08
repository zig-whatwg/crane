//! Generated from: css-layout-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const LayoutChildImpl = @import("impls").LayoutChild;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const StylePropertyMapReadOnly = @import("StylePropertyMapReadOnly.zig").StylePropertyMapReadOnly;
const LayoutFragment = @import("LayoutFragment.zig").LayoutFragment;
const IntrinsicSizes = @import("IntrinsicSizes.zig").IntrinsicSizes;
const ChildBreakToken = @import("ChildBreakToken.zig").ChildBreakToken;
const LayoutConstraintsOptions = @import("dictionaries").LayoutConstraintsOptions;

pub const LayoutChild = struct {
    pub const Meta = struct {
        pub const name = "LayoutChild";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "LayoutWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .LayoutWorklet = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "styleMap", "get_styleMap", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "intrinsicSizes", "call_intrinsicSizes", 0 },
            .{ "layoutNextFragment", "call_layoutNextFragment", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "intrinsicSizes",
            "layoutNextFragment",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "styleMap", "get_styleMap", null },
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
            styleMap: *runtime.Instance = undefined,
            _internal: ?*LayoutChildImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_styleMap = &get_styleMap,

        .call_intrinsicSizes = &call_intrinsicSizes,
        .call_layoutNextFragment = &call_layoutNextFragment,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return LayoutChildImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return LayoutChildImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LayoutChildImpl.deinit(instance);
    }

    pub fn get_styleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try LayoutChildImpl.get_styleMap(instance);
    }

    pub fn call_intrinsicSizes(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try LayoutChildImpl.call_intrinsicSizes(instance);
    }

    pub fn call_layoutNextFragment(instance: *runtime.Instance, constraints: LayoutConstraintsOptions, breakToken: *runtime.Instance) anyerror!runtime.JSValue {
        
        return try LayoutChildImpl.call_layoutNextFragment(instance, constraints, breakToken);
    }

};
