//! Generated from: css-parser-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSParserDeclarationImpl = @import("impls").CSSParserDeclaration;
const CSSParserRule = @import("interfaces").CSSParserRule;
const FrozenArray<CSSParserValue> = @import("interfaces").FrozenArray<CSSParserValue>;

pub const CSSParserDeclaration = struct {
    pub const Meta = struct {
        pub const name = "CSSParserDeclaration";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSParserRule;
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

    pub const vtable = runtime.buildVTable(CSSParserDeclaration, .{
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
        
        // Initialize the instance (Impl receives full instance)
        CSSParserDeclarationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSParserDeclarationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, name: DOMString, body: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSParserDeclarationImpl.constructor(instance, name, body);
        
        return instance;
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSParserDeclarationImpl.get_name(instance);
    }

    pub fn get_body(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSParserDeclarationImpl.get_body(instance);
    }

};
