//! Generated from: speech-api.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechGrammarImpl = @import("../impls/SpeechGrammar.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        SpeechGrammarImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SpeechGrammarImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_src(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SpeechGrammarImpl.get_src(state);
    }

    pub fn set_src(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        SpeechGrammarImpl.set_src(state, value);
    }

    pub fn get_weight(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return SpeechGrammarImpl.get_weight(state);
    }

    pub fn set_weight(instance: *runtime.Instance, value: f32) void {
        const state = instance.getState(State);
        SpeechGrammarImpl.set_weight(state, value);
    }

};
