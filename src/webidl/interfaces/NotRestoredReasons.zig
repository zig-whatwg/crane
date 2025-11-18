//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NotRestoredReasonsImpl = @import("impls").NotRestoredReasons;
const FrozenArray<NotRestoredReasonDetails> = @import("interfaces").FrozenArray<NotRestoredReasonDetails>;
const FrozenArray<NotRestoredReasons> = @import("interfaces").FrozenArray<NotRestoredReasons>;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const NotRestoredReasons = struct {
    pub const Meta = struct {
        pub const name = "NotRestoredReasons";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            src: ?runtime.USVString = null,
            id: ?runtime.DOMString = null,
            name: ?runtime.DOMString = null,
            url: ?runtime.USVString = null,
            reasons: ?FrozenArray<NotRestoredReasonDetails> = null,
            children: ?FrozenArray<NotRestoredReasons> = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NotRestoredReasons, .{
        .deinit_fn = &deinit_wrapper,

        .get_children = &get_children,
        .get_id = &get_id,
        .get_name = &get_name,
        .get_reasons = &get_reasons,
        .get_src = &get_src,
        .get_url = &get_url,

        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        NotRestoredReasonsImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NotRestoredReasonsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_src(instance: *runtime.Instance) anyerror!anyopaque {
        return try NotRestoredReasonsImpl.get_src(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!anyopaque {
        return try NotRestoredReasonsImpl.get_id(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!anyopaque {
        return try NotRestoredReasonsImpl.get_name(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!anyopaque {
        return try NotRestoredReasonsImpl.get_url(instance);
    }

    pub fn get_reasons(instance: *runtime.Instance) anyerror!anyopaque {
        return try NotRestoredReasonsImpl.get_reasons(instance);
    }

    pub fn get_children(instance: *runtime.Instance) anyerror!anyopaque {
        return try NotRestoredReasonsImpl.get_children(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try NotRestoredReasonsImpl.call_toJSON(instance);
    }

};
