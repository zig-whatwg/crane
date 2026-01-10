//! Generated from: css-typed-om.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSUnparsedValueImpl = @import("impls").CSSUnparsedValue;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSStyleValue = @import("CSSStyleValue.zig").CSSStyleValue;
const CSSUnparsedSegment = @import("typedefs").CSSUnparsedSegment;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSUnparsedValue = struct {
    pub const Meta = struct {
        pub const name = "CSSUnparsedValue";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSStyleValue.State;
        pub const ParentInterface = CSSStyleValue;
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
            .{ "length", "get_length", null },
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
            length: u32 = undefined,
            _internal: ?*CSSUnparsedValueImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,

        .call_forEach = &call_forEach,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSUnparsedValueImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CSSUnparsedValueImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSUnparsedValueImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, members: runtime.JSValue) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSUnparsedValueImpl.call_constructor(ctx, members);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSUnparsedValueImpl.get_length(instance);
    }

    pub fn call_setter(instance: *runtime.Instance, index: u32, val: CSSUnparsedSegment) anyerror!void {
        
        return try CSSUnparsedValueImpl.call_setter(instance, index, val);
    }

    pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!CSSUnparsedSegment {
        
        return try CSSUnparsedValueImpl.call_getter(instance, index);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: runtime.JSValue) anyerror!void {
        
        return try CSSUnparsedValueImpl.call_forEach(instance, callback);
    }

};
