//! Generated from: speech-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechGrammarImpl = @import("impls").SpeechGrammar;

pub const SpeechGrammar = struct {
    pub const Meta = struct {
        pub const name = "SpeechGrammar";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            src: runtime.DOMString = undefined,
            weight: f32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SpeechGrammar, .{
        .deinit_fn = &deinit_wrapper,

        .get_src = &get_src,
        .get_weight = &get_weight,

        .set_src = &set_src,
        .set_weight = &set_weight,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SpeechGrammarImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechGrammarImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_src(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechGrammarImpl.get_src(instance);
    }

    pub fn set_src(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try SpeechGrammarImpl.set_src(instance, value);
    }

    pub fn get_weight(instance: *runtime.Instance) anyerror!f32 {
        return try SpeechGrammarImpl.get_weight(instance);
    }

    pub fn set_weight(instance: *runtime.Instance, value: f32) anyerror!void {
        try SpeechGrammarImpl.set_weight(instance, value);
    }

};
