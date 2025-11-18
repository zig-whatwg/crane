//! Generated from: speech-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechRecognitionResultImpl = @import("impls").SpeechRecognitionResult;
const SpeechRecognitionAlternative = @import("interfaces").SpeechRecognitionAlternative;

pub const SpeechRecognitionResult = struct {
    pub const Meta = struct {
        pub const name = "SpeechRecognitionResult";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            length: u32 = undefined,
            isFinal: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SpeechRecognitionResult, .{
        .deinit_fn = &deinit_wrapper,

        .get_isFinal = &get_isFinal,
        .get_length = &get_length,

        .call_item = &call_item,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SpeechRecognitionResultImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechRecognitionResultImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try SpeechRecognitionResultImpl.get_length(instance);
    }

    pub fn get_isFinal(instance: *runtime.Instance) anyerror!bool {
        return try SpeechRecognitionResultImpl.get_isFinal(instance);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!SpeechRecognitionAlternative {
        
        return try SpeechRecognitionResultImpl.call_item(instance, index);
    }

};
