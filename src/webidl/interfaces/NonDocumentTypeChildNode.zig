//! Generated from: dom.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NonDocumentTypeChildNodeImpl = @import("impls").NonDocumentTypeChildNode;
const Element = @import("interfaces").Element;

pub const NonDocumentTypeChildNode = struct {
    pub const Meta = struct {
        pub const name = "NonDocumentTypeChildNode";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            previousElementSibling: ?Element = null,
            nextElementSibling: ?Element = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NonDocumentTypeChildNode, .{
        .deinit_fn = &deinit_wrapper,

        .get_nextElementSibling = &get_nextElementSibling,
        .get_previousElementSibling = &get_previousElementSibling,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        NonDocumentTypeChildNodeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NonDocumentTypeChildNodeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_previousElementSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try NonDocumentTypeChildNodeImpl.get_previousElementSibling(instance);
    }

    pub fn get_nextElementSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try NonDocumentTypeChildNodeImpl.get_nextElementSibling(instance);
    }

};
