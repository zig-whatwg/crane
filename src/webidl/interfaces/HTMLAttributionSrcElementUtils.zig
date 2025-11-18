//! Generated from: attribution-reporting-api.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLAttributionSrcElementUtilsImpl = @import("impls").HTMLAttributionSrcElementUtils;

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
        
        // Initialize the instance (Impl receives full instance)
        HTMLAttributionSrcElementUtilsImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLAttributionSrcElementUtilsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn get_attributionSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLAttributionSrcElementUtilsImpl.get_attributionSrc(instance);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn set_attributionSrc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAttributionSrcElementUtilsImpl.set_attributionSrc(instance, value);
    }

};
