//! Generated from: css-parser-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSParserBlockImpl = @import("../impls/CSSParserBlock.zig");
const CSSParserValue = @import("CSSParserValue.zig");

pub const CSSParserBlock = struct {
    pub const Meta = struct {
        pub const name = "CSSParserBlock";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSParserValue;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            name: runtime.DOMString = undefined,
            body: FrozenArray<CSSParserValue> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSParserBlock, .{
        .deinit_fn = &deinit_wrapper,

        .get_body = &get_body,
        .get_name = &get_name,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CSSParserBlockImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSParserBlockImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, name: runtime.DOMString, body: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CSSParserBlockImpl.constructor(state, name, body);
        
        return instance;
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSParserBlockImpl.get_name(state);
    }

    pub fn get_body(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSParserBlockImpl.get_body(state);
    }

};
