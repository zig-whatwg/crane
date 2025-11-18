//! Generated from: writing-assistance-apis.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RewriterImpl = @import("impls").Rewriter;
const DestroyableModel = @import("interfaces").DestroyableModel;
const RewriterLength = @import("enums").RewriterLength;
const Promise<Availability> = @import("interfaces").Promise<Availability>;
const RewriterFormat = @import("enums").RewriterFormat;
const FrozenArray<DOMString> = @import("interfaces").FrozenArray<DOMString>;
const RewriterCreateOptions = @import("dictionaries").RewriterCreateOptions;
const RewriterTone = @import("enums").RewriterTone;
const Promise<DOMString> = @import("interfaces").Promise<DOMString>;
const ReadableStream = @import("interfaces").ReadableStream;
const RewriterCreateCoreOptions = @import("dictionaries").RewriterCreateCoreOptions;
const RewriterRewriteOptions = @import("dictionaries").RewriterRewriteOptions;
const Promise<double> = @import("interfaces").Promise<double>;
const Promise<Rewriter> = @import("interfaces").Promise<Rewriter>;
const DOMString = @import("typedefs").DOMString;

pub const Rewriter = struct {
    pub const Meta = struct {
        pub const name = "Rewriter";
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
            tone: RewriterTone = undefined,
            format: RewriterFormat = undefined,
            length: RewriterLength = undefined,
            expectedInputLanguages: ?FrozenArray<DOMString> = null,
            expectedContextLanguages: ?FrozenArray<DOMString> = null,
            outputLanguage: ?runtime.DOMString = null,
            inputQuota: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Rewriter, .{
        .deinit_fn = &deinit_wrapper,

        .get_expectedContextLanguages = &get_expectedContextLanguages,
        .get_expectedInputLanguages = &get_expectedInputLanguages,
        .get_format = &get_format,
        .get_inputQuota = &get_inputQuota,
        .get_length = &get_length,
        .get_outputLanguage = &get_outputLanguage,
        .get_sharedContext = &get_sharedContext,
        .get_tone = &get_tone,

        .call_availability = &call_availability,
        .call_create = &call_create,
        .call_destroy = &call_destroy,
        .call_measureInputUsage = &call_measureInputUsage,
        .call_rewrite = &call_rewrite,
        .call_rewriteStreaming = &call_rewriteStreaming,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        RewriterImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RewriterImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_sharedContext(instance: *runtime.Instance) anyerror!DOMString {
        return try RewriterImpl.get_sharedContext(instance);
    }

    pub fn get_tone(instance: *runtime.Instance) anyerror!RewriterTone {
        return try RewriterImpl.get_tone(instance);
    }

    pub fn get_format(instance: *runtime.Instance) anyerror!RewriterFormat {
        return try RewriterImpl.get_format(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!RewriterLength {
        return try RewriterImpl.get_length(instance);
    }

    pub fn get_expectedInputLanguages(instance: *runtime.Instance) anyerror!anyopaque {
        return try RewriterImpl.get_expectedInputLanguages(instance);
    }

    pub fn get_expectedContextLanguages(instance: *runtime.Instance) anyerror!anyopaque {
        return try RewriterImpl.get_expectedContextLanguages(instance);
    }

    pub fn get_outputLanguage(instance: *runtime.Instance) anyerror!anyopaque {
        return try RewriterImpl.get_outputLanguage(instance);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) anyerror!f64 {
        return try RewriterImpl.get_inputQuota(instance);
    }

    pub fn call_availability(instance: *runtime.Instance, options: RewriterCreateCoreOptions) anyerror!anyopaque {
        
        return try RewriterImpl.call_availability(instance, options);
    }

    pub fn call_rewrite(instance: *runtime.Instance, input: DOMString, options: RewriterRewriteOptions) anyerror!anyopaque {
        
        return try RewriterImpl.call_rewrite(instance, input, options);
    }

    pub fn call_rewriteStreaming(instance: *runtime.Instance, input: DOMString, options: RewriterRewriteOptions) anyerror!ReadableStream {
        
        return try RewriterImpl.call_rewriteStreaming(instance, input, options);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: DOMString, options: RewriterRewriteOptions) anyerror!anyopaque {
        
        return try RewriterImpl.call_measureInputUsage(instance, input, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try RewriterImpl.call_destroy(instance);
    }

    pub fn call_create(instance: *runtime.Instance, options: RewriterCreateOptions) anyerror!anyopaque {
        
        return try RewriterImpl.call_create(instance, options);
    }

};
