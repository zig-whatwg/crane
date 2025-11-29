//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-29T05:01:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSUnparsedValueImpl = @import("impls").CSSUnparsedValue;
const mixins = @import("mixins");
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSUnparsedSegment = @import("typedefs").CSSUnparsedSegment;
const USVString = @import("interfaces").USVString;
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
            "parse",
            "parseAll",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
        
        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "CSSUnparsedSegment",
            .key_type = null,
        };
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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSUnparsedValueImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSUnparsedValueImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, members: *const anyopaque) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSUnparsedValueImpl.call_constructor(allocator, ctx, members);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSUnparsedValueImpl.get_length(instance);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) anyerror!void {
        
        return try CSSUnparsedValueImpl.call_forEach(instance, callback);
    }

};
