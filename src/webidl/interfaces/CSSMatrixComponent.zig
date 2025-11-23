//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-23T19:47:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSMatrixComponentImpl = @import("impls").CSSMatrixComponent;
const CSSTransformComponent = @import("interfaces").CSSTransformComponent;
const DOMMatrixReadOnly = @import("interfaces").DOMMatrixReadOnly;
const CSSMatrixComponentOptions = @import("dictionaries").CSSMatrixComponentOptions;
const DOMMatrix = @import("interfaces").DOMMatrix;
const DOMString = @import("typedefs").DOMString;

pub const CSSMatrixComponent = struct {
    pub const Meta = struct {
        pub const name = "CSSMatrixComponent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSTransformComponent;
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
            .{ "matrix", "get_matrix", "set_matrix" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "toMatrix",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "matrix", "get_matrix", "set_matrix" },
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
            matrix: *runtime.Instance = undefined,
            _internal: ?*CSSMatrixComponentImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_matrix = &get_matrix,

        .set_matrix = &set_matrix,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSMatrixComponentImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSMatrixComponentImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, matrix: *runtime.Instance, options: CSSMatrixComponentOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSMatrixComponentImpl.call_constructor(allocator, ctx, matrix, options);
    }

    pub fn get_matrix(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSMatrixComponentImpl.get_matrix(instance);
    }

    pub fn set_matrix(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try CSSMatrixComponentImpl.set_matrix(instance, value);
    }

};
