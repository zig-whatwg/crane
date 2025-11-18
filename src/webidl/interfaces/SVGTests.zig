//! Generated from: SVG.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGTestsImpl = @import("impls").SVGTests;
const SVGStringList = @import("interfaces").SVGStringList;

pub const SVGTests = struct {
    pub const Meta = struct {
        pub const name = "SVGTests";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            requiredExtensions: SVGStringList = undefined,
            systemLanguage: SVGStringList = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SVGTests, .{
        .deinit_fn = &deinit_wrapper,

        .get_requiredExtensions = &get_requiredExtensions,
        .get_systemLanguage = &get_systemLanguage,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SVGTestsImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGTestsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_requiredExtensions(instance: *runtime.Instance) anyerror!SVGStringList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_requiredExtensions) |cached| {
            return cached;
        }
        const value = try SVGTestsImpl.get_requiredExtensions(instance);
        state.cached_requiredExtensions = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_systemLanguage(instance: *runtime.Instance) anyerror!SVGStringList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_systemLanguage) |cached| {
            return cached;
        }
        const value = try SVGTestsImpl.get_systemLanguage(instance);
        state.cached_systemLanguage = value;
        return value;
    }

};
