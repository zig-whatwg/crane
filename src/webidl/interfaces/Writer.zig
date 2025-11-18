//! Generated from: writing-assistance-apis.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WriterImpl = @import("impls").Writer;
const DestroyableModel = @import("interfaces").DestroyableModel;
const Promise<Availability> = @import("interfaces").Promise<Availability>;
const WriterWriteOptions = @import("dictionaries").WriterWriteOptions;
const WriterCreateCoreOptions = @import("dictionaries").WriterCreateCoreOptions;
const WriterTone = @import("enums").WriterTone;
const FrozenArray<DOMString> = @import("interfaces").FrozenArray<DOMString>;
const WriterCreateOptions = @import("dictionaries").WriterCreateOptions;
const WriterFormat = @import("enums").WriterFormat;
const Promise<DOMString> = @import("interfaces").Promise<DOMString>;
const Promise<Writer> = @import("interfaces").Promise<Writer>;
const ReadableStream = @import("interfaces").ReadableStream;
const Promise<double> = @import("interfaces").Promise<double>;
const WriterLength = @import("enums").WriterLength;
const DOMString = @import("typedefs").DOMString;

pub const Writer = struct {
    pub const Meta = struct {
        pub const name = "Writer";
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
            tone: WriterTone = undefined,
            format: WriterFormat = undefined,
            length: WriterLength = undefined,
            expectedInputLanguages: ?FrozenArray<DOMString> = null,
            expectedContextLanguages: ?FrozenArray<DOMString> = null,
            outputLanguage: ?runtime.DOMString = null,
            inputQuota: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Writer, .{
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
        .call_write = &call_write,
        .call_writeStreaming = &call_writeStreaming,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WriterImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WriterImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_sharedContext(instance: *runtime.Instance) anyerror!DOMString {
        return try WriterImpl.get_sharedContext(instance);
    }

    pub fn get_tone(instance: *runtime.Instance) anyerror!WriterTone {
        return try WriterImpl.get_tone(instance);
    }

    pub fn get_format(instance: *runtime.Instance) anyerror!WriterFormat {
        return try WriterImpl.get_format(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!WriterLength {
        return try WriterImpl.get_length(instance);
    }

    pub fn get_expectedInputLanguages(instance: *runtime.Instance) anyerror!anyopaque {
        return try WriterImpl.get_expectedInputLanguages(instance);
    }

    pub fn get_expectedContextLanguages(instance: *runtime.Instance) anyerror!anyopaque {
        return try WriterImpl.get_expectedContextLanguages(instance);
    }

    pub fn get_outputLanguage(instance: *runtime.Instance) anyerror!anyopaque {
        return try WriterImpl.get_outputLanguage(instance);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) anyerror!f64 {
        return try WriterImpl.get_inputQuota(instance);
    }

    pub fn call_availability(instance: *runtime.Instance, options: WriterCreateCoreOptions) anyerror!anyopaque {
        
        return try WriterImpl.call_availability(instance, options);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: DOMString, options: WriterWriteOptions) anyerror!anyopaque {
        
        return try WriterImpl.call_measureInputUsage(instance, input, options);
    }

    pub fn call_write(instance: *runtime.Instance, input: DOMString, options: WriterWriteOptions) anyerror!anyopaque {
        
        return try WriterImpl.call_write(instance, input, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try WriterImpl.call_destroy(instance);
    }

    pub fn call_writeStreaming(instance: *runtime.Instance, input: DOMString, options: WriterWriteOptions) anyerror!ReadableStream {
        
        return try WriterImpl.call_writeStreaming(instance, input, options);
    }

    pub fn call_create(instance: *runtime.Instance, options: WriterCreateOptions) anyerror!anyopaque {
        
        return try WriterImpl.call_create(instance, options);
    }

};
