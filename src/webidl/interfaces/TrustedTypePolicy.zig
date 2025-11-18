//! Generated from: trusted-types.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TrustedTypePolicyImpl = @import("impls").TrustedTypePolicy;
const TrustedHTML = @import("interfaces").TrustedHTML;
const TrustedScript = @import("interfaces").TrustedScript;
const TrustedScriptURL = @import("interfaces").TrustedScriptURL;

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
        
        // Initialize the instance (Impl receives full instance)
        TrustedTypePolicyImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TrustedTypePolicyImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try TrustedTypePolicyImpl.get_name(instance);
    }

    pub fn call_createScriptURL(instance: *runtime.Instance, input: DOMString, arguments: anyopaque) anyerror!TrustedScriptURL {
        
        return try TrustedTypePolicyImpl.call_createScriptURL(instance, input, arguments);
    }

    pub fn call_createHTML(instance: *runtime.Instance, input: DOMString, arguments: anyopaque) anyerror!TrustedHTML {
        
        return try TrustedTypePolicyImpl.call_createHTML(instance, input, arguments);
    }

    pub fn call_createScript(instance: *runtime.Instance, input: DOMString, arguments: anyopaque) anyerror!TrustedScript {
        
        return try TrustedTypePolicyImpl.call_createScript(instance, input, arguments);
    }

};
