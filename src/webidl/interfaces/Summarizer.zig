//! Generated from: writing-assistance-apis.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SummarizerImpl = @import("impls").Summarizer;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DestroyableModel = @import("mixins").DestroyableModel;
const Availability = @import("enums").Availability;
const ReadableStream = @import("ReadableStream.zig").ReadableStream;
const SummarizerSummarizeOptions = @import("dictionaries").SummarizerSummarizeOptions;
const SummarizerCreateCoreOptions = @import("dictionaries").SummarizerCreateCoreOptions;
const SummarizerType = @import("enums").SummarizerType;
const SummarizerCreateOptions = @import("dictionaries").SummarizerCreateOptions;
const SummarizerLength = @import("enums").SummarizerLength;
const SummarizerFormat = @import("enums").SummarizerFormat;
const DOMString = @import("typedefs").DOMString;

pub const Summarizer = struct {
    pub const Meta = struct {
        pub const name = "Summarizer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
            .{ "type", "get_type", null },
            .{ "format", "get_format", null },
            .{ "length", "get_length", null },
            .{ "expectedInputLanguages", "get_expectedInputLanguages", null },
            .{ "expectedContextLanguages", "get_expectedContextLanguages", null },
            .{ "outputLanguage", "get_outputLanguage", null },
            .{ "inputQuota", "get_inputQuota", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "summarize", "call_summarize", 1 },
            .{ "summarizeStreaming", "call_summarizeStreaming", 1 },
            .{ "measureInputUsage", "call_measureInputUsage", 1 },
            .{ "destroy", "call_destroy", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "create", "call_static_create", 0 },
            .{ "availability", "call_static_availability", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "create",
            "availability",
            "summarize",
            "summarizeStreaming",
            "measureInputUsage",
            "destroy",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sharedContext", "get_sharedContext", null },
            .{ "type", "get_type", null },
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
            sharedContext: typedefs.DOMString = undefined,
            @"type": enums.SummarizerType = undefined,
            format: enums.SummarizerFormat = undefined,
            length: enums.SummarizerLength = undefined,
            expectedInputLanguages: ?runtime.JSValue = null,
            expectedContextLanguages: ?runtime.JSValue = null,
            outputLanguage: ?typedefs.DOMString = null,
            inputQuota: f64 = undefined,
            _internal: ?*SummarizerImpl.InternalState = null,
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
        .get_type = &get_type,

        .call_destroy = &call_destroy,
        .call_measureInputUsage = &call_measureInputUsage,
        .call_summarize = &call_summarize,
        .call_summarizeStreaming = &call_summarizeStreaming,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SummarizerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SummarizerImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SummarizerImpl.deinit(instance);
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

    pub fn get_expectedInputLanguages(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try SummarizerImpl.get_expectedInputLanguages(instance);
    }

    pub fn get_expectedContextLanguages(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try SummarizerImpl.get_expectedContextLanguages(instance);
    }

    pub fn get_outputLanguage(instance: *runtime.Instance) anyerror!?DOMString {
        return try SummarizerImpl.get_outputLanguage(instance);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) anyerror!f64 {
        return try SummarizerImpl.get_inputQuota(instance);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: DOMString, options: webidl.Opt(SummarizerSummarizeOptions)) anyerror!runtime.JSValue {
        
        return try SummarizerImpl.call_measureInputUsage(instance, input, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try SummarizerImpl.call_destroy(instance);
    }

    pub fn call_summarizeStreaming(instance: *runtime.Instance, input: DOMString, options: webidl.Opt(SummarizerSummarizeOptions)) anyerror!*runtime.Instance {
        
        return try SummarizerImpl.call_summarizeStreaming(instance, input, options);
    }

    pub fn call_static_create(instance: *runtime.Instance, options: webidl.Opt(SummarizerCreateOptions)) anyerror!runtime.JSValue {
        
        return try SummarizerImpl.call_static_create(instance, options);
    }

    pub fn call_static_availability(instance: *runtime.Instance, options: webidl.Opt(SummarizerCreateCoreOptions)) anyerror!runtime.JSValue {
        
        return try SummarizerImpl.call_static_availability(instance, options);
    }

    pub fn call_summarize(instance: *runtime.Instance, input: DOMString, options: webidl.Opt(SummarizerSummarizeOptions)) anyerror!runtime.JSValue {
        
        return try SummarizerImpl.call_summarize(instance, input, options);
    }

};
