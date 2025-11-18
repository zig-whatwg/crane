//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSMatrixComponentImpl = @import("impls").CSSMatrixComponent;
const CSSTransformComponent = @import("interfaces").CSSTransformComponent;
const DOMMatrixReadOnly = @import("interfaces").DOMMatrixReadOnly;
const CSSMatrixComponentOptions = @import("dictionaries").CSSMatrixComponentOptions;
const DOMMatrix = @import("interfaces").DOMMatrix;

pub const CSSMatrixComponent = struct {
    pub const Meta = struct {
        pub const name = "CSSMatrixComponent";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSTransformComponent;
        pub const MixinTypes = .{};
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
    };

    pub const State = runtime.FlattenedState(
        struct {
            matrix: DOMMatrix = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSMatrixComponent, .{
        .deinit_fn = &deinit_wrapper,

        .get_is2D = &get_is2D,
        .get_matrix = &get_matrix,

        .set_is2D = &set_is2D,
        .set_matrix = &set_matrix,

        .call_toMatrix = &call_toMatrix,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSSMatrixComponentImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSMatrixComponentImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, matrix: DOMMatrixReadOnly, options: CSSMatrixComponentOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSMatrixComponentImpl.constructor(instance, matrix, options);
        
        return instance;
    }

    pub fn get_is2D(instance: *runtime.Instance) anyerror!bool {
        return try CSSMatrixComponentImpl.get_is2D(instance);
    }

    pub fn set_is2D(instance: *runtime.Instance, value: bool) anyerror!void {
        try CSSMatrixComponentImpl.set_is2D(instance, value);
    }

    pub fn get_matrix(instance: *runtime.Instance) anyerror!DOMMatrix {
        return try CSSMatrixComponentImpl.get_matrix(instance);
    }

    pub fn set_matrix(instance: *runtime.Instance, value: DOMMatrix) anyerror!void {
        try CSSMatrixComponentImpl.set_matrix(instance, value);
    }

    pub fn call_toMatrix(instance: *runtime.Instance) anyerror!DOMMatrix {
        return try CSSMatrixComponentImpl.call_toMatrix(instance);
    }

};
