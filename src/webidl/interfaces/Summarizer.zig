//! Generated from: writing-assistance-apis.idl
//! Generated at: 2025-11-18T18:28:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SummarizerImpl = @import("impls").Summarizer;
const DestroyableModel = @import("interfaces").DestroyableModel;
const Promise<Availability> = @import("interfaces").Promise<Availability>;
const Promise<Summarizer> = @import("interfaces").Promise<Summarizer>;
const SummarizerCreateOptions = @import("dictionaries").SummarizerCreateOptions;
const SummarizerLength = @import("enums").SummarizerLength;
const FrozenArray<DOMString> = @import("interfaces").FrozenArray<DOMString>;
const Promise<DOMString> = @import("interfaces").Promise<DOMString>;
const SummarizerSummarizeOptions = @import("dictionaries").SummarizerSummarizeOptions;
const ReadableStream = @import("interfaces").ReadableStream;
const SummarizerCreateCoreOptions = @import("dictionaries").SummarizerCreateCoreOptions;
const SummarizerType = @import("enums").SummarizerType;
const Promise<double> = @import("interfaces").Promise<double>;
const SummarizerFormat = @import("enums").SummarizerFormat;
const DOMString = @import("typedefs").DOMString;

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
        
        // Initialize the instance (Impl receives full instance)
        SummarizerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SummarizerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_sharedContext(instance: *runtime.Instance) anyerror!DOMString {
        return try SummarizerImpl.get_sharedContext(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!SummarizerType {
        return try SummarizerImpl.get_type(instance);
    }

    pub fn get_format(instance: *runtime.Instance) anyerror!SummarizerFormat {
        return try SummarizerImpl.get_format(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!SummarizerLength {
        return try SummarizerImpl.get_length(instance);
    }

    pub fn get_expectedInputLanguages(instance: *runtime.Instance) anyerror!anyopaque {
        return try SummarizerImpl.get_expectedInputLanguages(instance);
    }

    pub fn get_expectedContextLanguages(instance: *runtime.Instance) anyerror!anyopaque {
        return try SummarizerImpl.get_expectedContextLanguages(instance);
    }

    pub fn get_outputLanguage(instance: *runtime.Instance) anyerror!anyopaque {
        return try SummarizerImpl.get_outputLanguage(instance);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) anyerror!f64 {
        return try SummarizerImpl.get_inputQuota(instance);
    }

    pub fn call_availability(instance: *runtime.Instance, options: SummarizerCreateCoreOptions) anyerror!anyopaque {
        
        return try SummarizerImpl.call_availability(instance, options);
    }

    pub fn call_summarizeStreaming(instance: *runtime.Instance, input: DOMString, options: SummarizerSummarizeOptions) anyerror!ReadableStream {
        
        return try SummarizerImpl.call_summarizeStreaming(instance, input, options);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: DOMString, options: SummarizerSummarizeOptions) anyerror!anyopaque {
        
        return try SummarizerImpl.call_measureInputUsage(instance, input, options);
    }

    pub fn call_summarize(instance: *runtime.Instance, input: DOMString, options: SummarizerSummarizeOptions) anyerror!anyopaque {
        
        return try SummarizerImpl.call_summarize(instance, input, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try SummarizerImpl.call_destroy(instance);
    }

    pub fn call_create(instance: *runtime.Instance, options: SummarizerCreateOptions) anyerror!anyopaque {
        
        return try SummarizerImpl.call_create(instance, options);
    }

};
