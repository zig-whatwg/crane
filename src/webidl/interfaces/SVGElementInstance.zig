//! Generated from: SVG.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGElementInstanceImpl = @import("impls").SVGElementInstance;
const SVGUseElement = @import("interfaces").SVGUseElement;
const SVGElement = @import("interfaces").SVGElement;

pub const SVGElementInstance = struct {
    pub const Meta = struct {
        pub const name = "SVGElementInstance";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            correspondingElement: ?SVGElement = null,
            correspondingUseElement: ?SVGUseElement = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SVGElementInstance, .{
        .deinit_fn = &deinit_wrapper,

        .get_correspondingElement = &get_correspondingElement,
        .get_correspondingUseElement = &get_correspondingUseElement,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SVGElementInstanceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGElementInstanceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_correspondingElement(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_correspondingElement) |cached| {
            return cached;
        }
        const value = try SVGElementInstanceImpl.get_correspondingElement(instance);
        state.cached_correspondingElement = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_correspondingUseElement(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_correspondingUseElement) |cached| {
            return cached;
        }
        const value = try SVGElementInstanceImpl.get_correspondingUseElement(instance);
        state.cached_correspondingUseElement = value;
        return value;
    }

};
