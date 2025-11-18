//! Generated from: attribution-reporting-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLAttributionSrcElementUtilsImpl = @import("../impls/HTMLAttributionSrcElementUtils.zig");

pub const HTMLAttributionSrcElementUtils = struct {
    pub const Meta = struct {
        pub const name = "HTMLAttributionSrcElementUtils";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            attributionSrc: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(HTMLAttributionSrcElementUtils, .{
        .deinit_fn = &deinit_wrapper,

        .get_attributionSrc = &get_attributionSrc,

        .set_attributionSrc = &set_attributionSrc,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        HTMLAttributionSrcElementUtilsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        HTMLAttributionSrcElementUtilsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn get_attributionSrc(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return HTMLAttributionSrcElementUtilsImpl.get_attributionSrc(state);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn set_attributionSrc(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAttributionSrcElementUtilsImpl.set_attributionSrc(state, value);
    }

};
