//! Generated from: css-layout-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const LayoutFragmentImpl = @import("impls").LayoutFragment;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ChildBreakToken = @import("ChildBreakToken.zig").ChildBreakToken;

pub const LayoutFragment = struct {
    pub const Meta = struct {
        pub const name = "LayoutFragment";
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
            .{ "inlineSize", "get_inlineSize", null },
            .{ "blockSize", "get_blockSize", null },
            .{ "inlineOffset", "get_inlineOffset", "set_inlineOffset" },
            .{ "blockOffset", "get_blockOffset", "set_blockOffset" },
            .{ "data", "get_data", null },
            .{ "breakToken", "get_breakToken", null },
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
            .{ "inlineOffset", "get_inlineOffset", "set_inlineOffset" },
            .{ "blockOffset", "get_blockOffset", "set_blockOffset" },
            .{ "data", "get_data", null },
            .{ "breakToken", "get_breakToken", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            inlineSize: f64 = undefined,
            blockSize: f64 = undefined,
            inlineOffset: f64 = undefined,
            blockOffset: f64 = undefined,
            data: runtime.JSValue = undefined,
            breakToken: ?*runtime.Instance = null,
            _internal: ?*LayoutFragmentImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_blockOffset = &get_blockOffset,
        .get_blockSize = &get_blockSize,
        .get_breakToken = &get_breakToken,
        .get_data = &get_data,
        .get_inlineOffset = &get_inlineOffset,
        .get_inlineSize = &get_inlineSize,

        .set_blockOffset = &set_blockOffset,
        .set_inlineOffset = &set_inlineOffset,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return LayoutFragmentImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return LayoutFragmentImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LayoutFragmentImpl.deinit(instance);
    }

    pub fn get_inlineSize(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutFragmentImpl.get_inlineSize(instance);
    }

    pub fn get_blockSize(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutFragmentImpl.get_blockSize(instance);
    }

    pub fn get_inlineOffset(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutFragmentImpl.get_inlineOffset(instance);
    }

    pub fn set_inlineOffset(instance: *runtime.Instance, value: f64) anyerror!void {
        try LayoutFragmentImpl.set_inlineOffset(instance, value);
    }

    pub fn get_blockOffset(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutFragmentImpl.get_blockOffset(instance);
    }

    pub fn set_blockOffset(instance: *runtime.Instance, value: f64) anyerror!void {
        try LayoutFragmentImpl.set_blockOffset(instance, value);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try LayoutFragmentImpl.get_data(instance);
    }

    pub fn get_breakToken(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try LayoutFragmentImpl.get_breakToken(instance);
    }

};
