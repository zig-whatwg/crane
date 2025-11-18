//! Generated from: trusted-types.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TrustedTypePolicyImpl = @import("../impls/TrustedTypePolicy.zig");

pub const TrustedTypePolicy = struct {
    pub const Meta = struct {
        pub const name = "TrustedTypePolicy";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            name: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TrustedTypePolicy, .{
        .deinit_fn = &deinit_wrapper,

        .get_name = &get_name,

        .call_createHTML = &call_createHTML,
        .call_createScript = &call_createScript,
        .call_createScriptURL = &call_createScriptURL,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        TrustedTypePolicyImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TrustedTypePolicyImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return TrustedTypePolicyImpl.get_name(state);
    }

    pub fn call_createScriptURL(instance: *runtime.Instance, input: runtime.DOMString, arguments: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TrustedTypePolicyImpl.call_createScriptURL(state, input, arguments);
    }

    pub fn call_createHTML(instance: *runtime.Instance, input: runtime.DOMString, arguments: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TrustedTypePolicyImpl.call_createHTML(state, input, arguments);
    }

    pub fn call_createScript(instance: *runtime.Instance, input: runtime.DOMString, arguments: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TrustedTypePolicyImpl.call_createScript(state, input, arguments);
    }

};
