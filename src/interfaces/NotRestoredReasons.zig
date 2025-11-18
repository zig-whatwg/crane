//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NotRestoredReasonsImpl = @import("../impls/NotRestoredReasons.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        NotRestoredReasonsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NotRestoredReasonsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_src(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NotRestoredReasonsImpl.get_src(state);
    }

    pub fn get_id(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NotRestoredReasonsImpl.get_id(state);
    }

    pub fn get_name(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NotRestoredReasonsImpl.get_name(state);
    }

    pub fn get_url(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NotRestoredReasonsImpl.get_url(state);
    }

    pub fn get_reasons(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NotRestoredReasonsImpl.get_reasons(state);
    }

    pub fn get_children(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NotRestoredReasonsImpl.get_children(state);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NotRestoredReasonsImpl.call_toJSON(state);
    }

};
