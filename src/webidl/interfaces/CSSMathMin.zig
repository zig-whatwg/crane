//! Generated from: css-typed-om.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSMathMinImpl = @import("impls").CSSMathMin;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSMathValue = @import("CSSMathValue.zig").CSSMathValue;
const CSSNumericArray = @import("CSSNumericArray.zig").CSSNumericArray;
const CSSNumericValue = @import("CSSNumericValue.zig").CSSNumericValue;
const CSSUnitValue = @import("CSSUnitValue.zig").CSSUnitValue;
const CSSMathSum = @import("CSSMathSum.zig").CSSMathSum;
const CSSNumericType = @import("dictionaries").CSSNumericType;
const CSSMathOperator = @import("enums").CSSMathOperator;
const CSSStyleValue = @import("CSSStyleValue.zig").CSSStyleValue;
const CSSNumberish = @import("typedefs").CSSNumberish;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSMathMin = struct {
    pub const Meta = struct {
        pub const name = "CSSMathMin";
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
            .{ "values", "get_values", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
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
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "values", "get_values", null },
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
            values: *runtime.Instance = undefined,
            _internal: ?*CSSMathMinImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_values = &get_values,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSMathMinImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CSSMathMinImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSMathMinImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, args: []const CSSNumberish) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSMathMinImpl.call_constructor(ctx, args);
    }

    pub fn get_values(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSMathMinImpl.get_values(instance);
    }

};
