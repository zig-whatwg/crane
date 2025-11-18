//! Generated from: writing-assistance-apis.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SummarizerImpl = @import("../impls/Summarizer.zig");
const DestroyableModel = @import("DestroyableModel.zig");

pub const Summarizer = struct {
    pub const Meta = struct {
        pub const name = "Summarizer";
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
            sharedContext: runtime.DOMString = undefined,
            type: SummarizerType = undefined,
            format: SummarizerFormat = undefined,
            length: SummarizerLength = undefined,
            expectedInputLanguages: ?FrozenArray<DOMString> = null,
            expectedContextLanguages: ?FrozenArray<DOMString> = null,
            outputLanguage: ?runtime.DOMString = null,
            inputQuota: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Summarizer, .{
        .deinit_fn = &deinit_wrapper,

        .get_expectedContextLanguages = &get_expectedContextLanguages,
        .get_expectedInputLanguages = &get_expectedInputLanguages,
        .get_format = &get_format,
        .get_inputQuota = &get_inputQuota,
        .get_length = &get_length,
        .get_outputLanguage = &get_outputLanguage,
        .get_sharedContext = &get_sharedContext,
        .get_type = &get_type,

        .call_availability = &call_availability,
        .call_create = &call_create,
        .call_destroy = &call_destroy,
        .call_measureInputUsage = &call_measureInputUsage,
        .call_summarize = &call_summarize,
        .call_summarizeStreaming = &call_summarizeStreaming,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SummarizerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SummarizerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_sharedContext(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SummarizerImpl.get_sharedContext(state);
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SummarizerImpl.get_type(state);
    }

    pub fn get_format(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SummarizerImpl.get_format(state);
    }

    pub fn get_length(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SummarizerImpl.get_length(state);
    }

    pub fn get_expectedInputLanguages(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SummarizerImpl.get_expectedInputLanguages(state);
    }

    pub fn get_expectedContextLanguages(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SummarizerImpl.get_expectedContextLanguages(state);
    }

    pub fn get_outputLanguage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SummarizerImpl.get_outputLanguage(state);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return SummarizerImpl.get_inputQuota(state);
    }

    pub fn call_availability(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SummarizerImpl.call_availability(state, options);
    }

    pub fn call_summarizeStreaming(instance: *runtime.Instance, input: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SummarizerImpl.call_summarizeStreaming(state, input, options);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SummarizerImpl.call_measureInputUsage(state, input, options);
    }

    pub fn call_summarize(instance: *runtime.Instance, input: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SummarizerImpl.call_summarize(state, input, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SummarizerImpl.call_destroy(state);
    }

    pub fn call_create(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SummarizerImpl.call_create(state, options);
    }

};
