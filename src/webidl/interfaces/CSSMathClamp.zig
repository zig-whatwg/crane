//! Generated from: css-typed-om.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSMathClampImpl = @import("impls").CSSMathClamp;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSMathValue = @import("CSSMathValue.zig").CSSMathValue;
const CSSNumericValue = @import("CSSNumericValue.zig").CSSNumericValue;
const CSSUnitValue = @import("CSSUnitValue.zig").CSSUnitValue;
const CSSMathSum = @import("CSSMathSum.zig").CSSMathSum;
const CSSNumericType = @import("dictionaries").CSSNumericType;
const CSSMathOperator = @import("enums").CSSMathOperator;
const CSSStyleValue = @import("CSSStyleValue.zig").CSSStyleValue;
const CSSNumberish = @import("typedefs").CSSNumberish;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSMathClamp = struct {
    pub const Meta = struct {
        pub const name = "CSSMathClamp";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSMathValue.State;
        pub const ParentInterface = CSSMathValue;
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
            .{ "lower", "get_lower", null },
            .{ "value", "get_value", null },
            .{ "upper", "get_upper", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "parse",
            "parseAll",
            "add",
            "sub",
            "mul",
            "div",
            "min",
            "max",
            "equals",
            "to",
            "toSum",
            "type",
            "parse",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "lower", "get_lower", null },
            .{ "value", "get_value", null },
            .{ "upper", "get_upper", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            lower: *runtime.Instance = undefined,
            value: *runtime.Instance = undefined,
            upper: *runtime.Instance = undefined,
            _internal: ?*CSSMathClampImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_lower = &get_lower,
        .get_upper = &get_upper,
        .get_value = &get_value,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSMathClampImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CSSMathClampImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSMathClampImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, lower: CSSNumberish, value: CSSNumberish, upper: CSSNumberish) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSMathClampImpl.call_constructor(ctx, lower, value, upper);
    }

    pub fn get_lower(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSMathClampImpl.get_lower(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSMathClampImpl.get_value(instance);
    }

    pub fn get_upper(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSMathClampImpl.get_upper(instance);
    }

};
