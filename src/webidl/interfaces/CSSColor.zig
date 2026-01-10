//! Generated from: css-typed-om.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSColorImpl = @import("impls").CSSColor;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSColorValue = @import("CSSColorValue.zig").CSSColorValue;
const CSSKeywordish = @import("typedefs").CSSKeywordish;
const CSSColorPercent = @import("typedefs").CSSColorPercent;
const CSSStyleValue = @import("CSSStyleValue.zig").CSSStyleValue;
const CSSNumberish = @import("typedefs").CSSNumberish;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSColor = struct {
    pub const Meta = struct {
        pub const name = "CSSColor";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSColorValue.State;
        pub const ParentInterface = CSSColorValue;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "PaintWorklet", "LayoutWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .PaintWorklet = true,
            .LayoutWorklet = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "colorSpace", "get_colorSpace", "set_colorSpace" },
            .{ "channels", "get_channels", "set_channels" },
            .{ "alpha", "get_alpha", "set_alpha" },
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
            .{ "colorSpace", "get_colorSpace", "set_colorSpace" },
            .{ "channels", "get_channels", "set_channels" },
            .{ "alpha", "get_alpha", "set_alpha" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            colorSpace: typedefs.CSSKeywordish = undefined,
            channels: runtime.JSValue = undefined,
            alpha: typedefs.CSSNumberish = undefined,
            _internal: ?*CSSColorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_alpha = &get_alpha,
        .get_channels = &get_channels,
        .get_colorSpace = &get_colorSpace,

        .set_alpha = &set_alpha,
        .set_channels = &set_channels,
        .set_colorSpace = &set_colorSpace,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSColorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CSSColorImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSColorImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, colorSpace: CSSKeywordish, channels: runtime.JSValue, alpha: webidl.Opt(CSSNumberish)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSColorImpl.call_constructor(ctx, colorSpace, channels, alpha);
    }

    pub fn get_colorSpace(instance: *runtime.Instance) anyerror!CSSKeywordish {
        return try CSSColorImpl.get_colorSpace(instance);
    }

    pub fn set_colorSpace(instance: *runtime.Instance, value: CSSKeywordish) anyerror!void {
        try CSSColorImpl.set_colorSpace(instance, value);
    }

    pub fn get_channels(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try CSSColorImpl.get_channels(instance);
    }

    pub fn set_channels(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try CSSColorImpl.set_channels(instance, value);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyerror!CSSNumberish {
        return try CSSColorImpl.get_alpha(instance);
    }

    pub fn set_alpha(instance: *runtime.Instance, value: CSSNumberish) anyerror!void {
        try CSSColorImpl.set_alpha(instance, value);
    }

};
