//! Generated from: translation-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TranslatorImpl = @import("impls").Translator;
const DestroyableModel = @import("interfaces").DestroyableModel;
const Promise<Translator> = @import("interfaces").Promise<Translator>;
const Promise<DOMString> = @import("interfaces").Promise<DOMString>;
const Promise<Availability> = @import("interfaces").Promise<Availability>;
const TranslatorCreateCoreOptions = @import("dictionaries").TranslatorCreateCoreOptions;
const TranslatorTranslateOptions = @import("dictionaries").TranslatorTranslateOptions;
const ReadableStream = @import("interfaces").ReadableStream;
const Promise<double> = @import("interfaces").Promise<double>;
const TranslatorCreateOptions = @import("dictionaries").TranslatorCreateOptions;

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
        
        // Initialize the instance (Impl receives full instance)
        TranslatorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TranslatorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_sourceLanguage(instance: *runtime.Instance) anyerror!DOMString {
        return try TranslatorImpl.get_sourceLanguage(instance);
    }

    pub fn get_targetLanguage(instance: *runtime.Instance) anyerror!DOMString {
        return try TranslatorImpl.get_targetLanguage(instance);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) anyerror!f64 {
        return try TranslatorImpl.get_inputQuota(instance);
    }

    pub fn call_availability(instance: *runtime.Instance, options: TranslatorCreateCoreOptions) anyerror!anyopaque {
        
        return try TranslatorImpl.call_availability(instance, options);
    }

    pub fn call_translate(instance: *runtime.Instance, input: DOMString, options: TranslatorTranslateOptions) anyerror!anyopaque {
        
        return try TranslatorImpl.call_translate(instance, input, options);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: DOMString, options: TranslatorTranslateOptions) anyerror!anyopaque {
        
        return try TranslatorImpl.call_measureInputUsage(instance, input, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try TranslatorImpl.call_destroy(instance);
    }

    pub fn call_translateStreaming(instance: *runtime.Instance, input: DOMString, options: TranslatorTranslateOptions) anyerror!ReadableStream {
        
        return try TranslatorImpl.call_translateStreaming(instance, input, options);
    }

    pub fn call_create(instance: *runtime.Instance, options: TranslatorCreateOptions) anyerror!anyopaque {
        
        return try TranslatorImpl.call_create(instance, options);
    }

};
