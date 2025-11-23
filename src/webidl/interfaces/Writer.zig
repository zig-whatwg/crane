//! Generated from: writing-assistance-apis.idl
//! Generated at: 2025-11-23T19:57:36Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WriterImpl = @import("impls").Writer;
const DestroyableModel = @import("interfaces").DestroyableModel;
const DOMString = @import("typedefs").DOMString;
const WriterCreateOptions = @import("dictionaries").WriterCreateOptions;
const Availability = @import("enums").Availability;
const ReadableStream = @import("interfaces").ReadableStream;
const WriterWriteOptions = @import("dictionaries").WriterWriteOptions;
const WriterFormat = @import("enums").WriterFormat;
const WriterCreateCoreOptions = @import("dictionaries").WriterCreateCoreOptions;
const WriterTone = @import("enums").WriterTone;
const WriterLength = @import("enums").WriterLength;

pub const Writer = struct {
    pub const Meta = struct {
        pub const name = "Writer";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{
            DestroyableModel,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "sharedContext", "get_sharedContext", null },
            .{ "tone", "get_tone", null },
            .{ "format", "get_format", null },
            .{ "length", "get_length", null },
            .{ "expectedInputLanguages", "get_expectedInputLanguages", null },
            .{ "expectedContextLanguages", "get_expectedContextLanguages", null },
            .{ "outputLanguage", "get_outputLanguage", null },
            .{ "inputQuota", "get_inputQuota", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "create", "call_create", 0 },
            .{ "availability", "call_availability", 0 },
            .{ "write", "call_write", 1 },
            .{ "writeStreaming", "call_writeStreaming", 1 },
            .{ "measureInputUsage", "call_measureInputUsage", 1 },
            .{ "destroy", "call_destroy", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "create",
            "availability",
            "write",
            "writeStreaming",
            "measureInputUsage",
            "destroy",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sharedContext", "get_sharedContext", null },
            .{ "tone", "get_tone", null },
            .{ "format", "get_format", null },
            .{ "length", "get_length", null },
            .{ "expectedInputLanguages", "get_expectedInputLanguages", null },
            .{ "expectedContextLanguages", "get_expectedContextLanguages", null },
            .{ "outputLanguage", "get_outputLanguage", null },
            .{ "inputQuota", "get_inputQuota", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            sharedContext: runtime.DOMString = undefined,
            tone: WriterTone = undefined,
            format: WriterFormat = undefined,
            length: WriterLength = undefined,
            expectedInputLanguages: ?runtime.FrozenArray(runtime.DOMString) = null,
            expectedContextLanguages: ?runtime.FrozenArray(runtime.DOMString) = null,
            outputLanguage: ?runtime.DOMString = null,
            inputQuota: f64 = undefined,
            _internal: ?*WriterImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WriterImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WriterImpl.deinit(instance);
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

    pub fn get_expectedInputLanguages(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WriterImpl.get_expectedInputLanguages(instance);
    }

    pub fn get_expectedContextLanguages(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WriterImpl.get_expectedContextLanguages(instance);
    }

    pub fn get_outputLanguage(instance: *runtime.Instance) anyerror!DOMString {
        return try WriterImpl.get_outputLanguage(instance);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) anyerror!f64 {
        return try WriterImpl.get_inputQuota(instance);
    }

    pub fn call_availability(instance: *runtime.Instance, options: WriterCreateCoreOptions) anyerror!*const anyopaque {
        
        return try WriterImpl.call_availability(instance, options);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: DOMString, options: WriterWriteOptions) anyerror!*const anyopaque {
        
        return try WriterImpl.call_measureInputUsage(instance, input, options);
    }

    pub fn call_write(instance: *runtime.Instance, input: DOMString, options: WriterWriteOptions) anyerror!*const anyopaque {
        
        return try WriterImpl.call_write(instance, input, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try WriterImpl.call_destroy(instance);
    }

    pub fn call_writeStreaming(instance: *runtime.Instance, input: DOMString, options: WriterWriteOptions) anyerror!*runtime.Instance {
        
        return try WriterImpl.call_writeStreaming(instance, input, options);
    }

    pub fn call_create(instance: *runtime.Instance, options: WriterCreateOptions) anyerror!*const anyopaque {
        
        return try WriterImpl.call_create(instance, options);
    }

};
