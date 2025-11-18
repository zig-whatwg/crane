//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NodeFilterImpl = @import("../impls/NodeFilter.zig");

pub const NodeFilter = struct {
    pub const Meta = struct {
        pub const name = "NodeFilter";
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short FILTER_ACCEPT = 1;
    pub fn get_FILTER_ACCEPT() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short FILTER_REJECT = 2;
    pub fn get_FILTER_REJECT() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short FILTER_SKIP = 3;
    pub fn get_FILTER_SKIP() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned long SHOW_ALL = 4294967295;
    pub fn get_SHOW_ALL() u32 {
        return 4294967295;
    }

    /// WebIDL constant: const unsigned long SHOW_ELEMENT = 1;
    pub fn get_SHOW_ELEMENT() u32 {
        return 1;
    }

    /// WebIDL constant: const unsigned long SHOW_ATTRIBUTE = 2;
    pub fn get_SHOW_ATTRIBUTE() u32 {
        return 2;
    }

    /// WebIDL constant: const unsigned long SHOW_TEXT = 4;
    pub fn get_SHOW_TEXT() u32 {
        return 4;
    }

    /// WebIDL constant: const unsigned long SHOW_CDATA_SECTION = 8;
    pub fn get_SHOW_CDATA_SECTION() u32 {
        return 8;
    }

    /// WebIDL constant: const unsigned long SHOW_ENTITY_REFERENCE = 16;
    pub fn get_SHOW_ENTITY_REFERENCE() u32 {
        return 16;
    }

    /// WebIDL constant: const unsigned long SHOW_ENTITY = 32;
    pub fn get_SHOW_ENTITY() u32 {
        return 32;
    }

    /// WebIDL constant: const unsigned long SHOW_PROCESSING_INSTRUCTION = 64;
    pub fn get_SHOW_PROCESSING_INSTRUCTION() u32 {
        return 64;
    }

    /// WebIDL constant: const unsigned long SHOW_COMMENT = 128;
    pub fn get_SHOW_COMMENT() u32 {
        return 128;
    }

    /// WebIDL constant: const unsigned long SHOW_DOCUMENT = 256;
    pub fn get_SHOW_DOCUMENT() u32 {
        return 256;
    }

    /// WebIDL constant: const unsigned long SHOW_DOCUMENT_TYPE = 512;
    pub fn get_SHOW_DOCUMENT_TYPE() u32 {
        return 512;
    }

    /// WebIDL constant: const unsigned long SHOW_DOCUMENT_FRAGMENT = 1024;
    pub fn get_SHOW_DOCUMENT_FRAGMENT() u32 {
        return 1024;
    }

    /// WebIDL constant: const unsigned long SHOW_NOTATION = 2048;
    pub fn get_SHOW_NOTATION() u32 {
        return 2048;
    }

    pub const vtable = runtime.buildVTable(NodeFilter, .{
        .deinit_fn = &deinit_wrapper,

        .get_FILTER_ACCEPT = &get_FILTER_ACCEPT,
        .get_FILTER_REJECT = &get_FILTER_REJECT,
        .get_FILTER_SKIP = &get_FILTER_SKIP,
        .get_SHOW_ALL = &get_SHOW_ALL,
        .get_SHOW_ATTRIBUTE = &get_SHOW_ATTRIBUTE,
        .get_SHOW_CDATA_SECTION = &get_SHOW_CDATA_SECTION,
        .get_SHOW_COMMENT = &get_SHOW_COMMENT,
        .get_SHOW_DOCUMENT = &get_SHOW_DOCUMENT,
        .get_SHOW_DOCUMENT_FRAGMENT = &get_SHOW_DOCUMENT_FRAGMENT,
        .get_SHOW_DOCUMENT_TYPE = &get_SHOW_DOCUMENT_TYPE,
        .get_SHOW_ELEMENT = &get_SHOW_ELEMENT,
        .get_SHOW_ENTITY = &get_SHOW_ENTITY,
        .get_SHOW_ENTITY_REFERENCE = &get_SHOW_ENTITY_REFERENCE,
        .get_SHOW_NOTATION = &get_SHOW_NOTATION,
        .get_SHOW_PROCESSING_INSTRUCTION = &get_SHOW_PROCESSING_INSTRUCTION,
        .get_SHOW_TEXT = &get_SHOW_TEXT,

        .call_acceptNode = &call_acceptNode,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        NodeFilterImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NodeFilterImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_acceptNode(instance: *runtime.Instance, node: anyopaque) u16 {
        const state = instance.getState(State);
        
        return NodeFilterImpl.call_acceptNode(state, node);
    }

};
