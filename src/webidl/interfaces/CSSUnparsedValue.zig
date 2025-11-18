//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSUnparsedValueImpl = @import("impls").CSSUnparsedValue;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSUnparsedSegment = @import("typedefs").CSSUnparsedSegment;

pub const CSSUnparsedValue = struct {
    pub const Meta = struct {
        pub const name = "CSSUnparsedValue";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSStyleValue;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "PaintWorklet", "LayoutWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .PaintWorklet = true,
            .LayoutWorklet = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            length: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSUnparsedValue, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,

        .call_parse = &call_parse,
        .call_parseAll = &call_parseAll,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSSUnparsedValueImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSUnparsedValueImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, members: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSUnparsedValueImpl.constructor(instance, members);
        
        return instance;
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSUnparsedValueImpl.get_length(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!anyopaque {
        
        return try CSSUnparsedValueImpl.call_parseAll(instance, property, cssText);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parse(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!CSSStyleValue {
        
        return try CSSUnparsedValueImpl.call_parse(instance, property, cssText);
    }

};
