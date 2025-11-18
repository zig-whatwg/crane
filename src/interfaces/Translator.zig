//! Generated from: translation-api.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TranslatorImpl = @import("../impls/Translator.zig");
const DestroyableModel = @import("DestroyableModel.zig");

pub const Translator = struct {
    pub const Meta = struct {
        pub const name = "Translator";
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
            sourceLanguage: runtime.DOMString = undefined,
            targetLanguage: runtime.DOMString = undefined,
            inputQuota: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Translator, .{
        .deinit_fn = &deinit_wrapper,

        .get_inputQuota = &get_inputQuota,
        .get_sourceLanguage = &get_sourceLanguage,
        .get_targetLanguage = &get_targetLanguage,

        .call_availability = &call_availability,
        .call_create = &call_create,
        .call_destroy = &call_destroy,
        .call_measureInputUsage = &call_measureInputUsage,
        .call_translate = &call_translate,
        .call_translateStreaming = &call_translateStreaming,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        TranslatorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TranslatorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_sourceLanguage(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return TranslatorImpl.get_sourceLanguage(state);
    }

    pub fn get_targetLanguage(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return TranslatorImpl.get_targetLanguage(state);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TranslatorImpl.get_inputQuota(state);
    }

    pub fn call_availability(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TranslatorImpl.call_availability(state, options);
    }

    pub fn call_translate(instance: *runtime.Instance, input: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TranslatorImpl.call_translate(state, input, options);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TranslatorImpl.call_measureInputUsage(state, input, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TranslatorImpl.call_destroy(state);
    }

    pub fn call_translateStreaming(instance: *runtime.Instance, input: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TranslatorImpl.call_translateStreaming(state, input, options);
    }

    pub fn call_create(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TranslatorImpl.call_create(state, options);
    }

};
