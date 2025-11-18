//! Generated from: translation-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LanguageDetectorImpl = @import("../impls/LanguageDetector.zig");
const DestroyableModel = @import("DestroyableModel.zig");

pub const LanguageDetector = struct {
    pub const Meta = struct {
        pub const name = "LanguageDetector";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            DestroyableModel,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            expectedInputLanguages: ?FrozenArray<DOMString> = null,
            inputQuota: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(LanguageDetector, .{
        .deinit_fn = &deinit_wrapper,

        .get_expectedInputLanguages = &get_expectedInputLanguages,
        .get_inputQuota = &get_inputQuota,

        .call_availability = &call_availability,
        .call_create = &call_create,
        .call_destroy = &call_destroy,
        .call_detect = &call_detect,
        .call_measureInputUsage = &call_measureInputUsage,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        LanguageDetectorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        LanguageDetectorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_expectedInputLanguages(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LanguageDetectorImpl.get_expectedInputLanguages(state);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return LanguageDetectorImpl.get_inputQuota(state);
    }

    pub fn call_availability(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return LanguageDetectorImpl.call_availability(state, options);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return LanguageDetectorImpl.call_measureInputUsage(state, input, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LanguageDetectorImpl.call_destroy(state);
    }

    pub fn call_detect(instance: *runtime.Instance, input: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return LanguageDetectorImpl.call_detect(state, input, options);
    }

    pub fn call_create(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return LanguageDetectorImpl.call_create(state, options);
    }

};
