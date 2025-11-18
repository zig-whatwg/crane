//! Generated from: dom.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XPathResultImpl = @import("impls").XPathResult;
const Node = @import("interfaces").Node;

pub const XPathResult = struct {
    pub const Meta = struct {
        pub const name = "XPathResult";
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
            resultType: u16 = undefined,
            numberValue: f64 = undefined,
            stringValue: runtime.DOMString = undefined,
            booleanValue: bool = undefined,
            singleNodeValue: ?Node = null,
            invalidIteratorState: bool = undefined,
            snapshotLength: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short ANY_TYPE = 0;
    pub fn get_ANY_TYPE() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short NUMBER_TYPE = 1;
    pub fn get_NUMBER_TYPE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short STRING_TYPE = 2;
    pub fn get_STRING_TYPE() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short BOOLEAN_TYPE = 3;
    pub fn get_BOOLEAN_TYPE() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short UNORDERED_NODE_ITERATOR_TYPE = 4;
    pub fn get_UNORDERED_NODE_ITERATOR_TYPE() u16 {
        return 4;
    }

    /// WebIDL constant: const unsigned short ORDERED_NODE_ITERATOR_TYPE = 5;
    pub fn get_ORDERED_NODE_ITERATOR_TYPE() u16 {
        return 5;
    }

    /// WebIDL constant: const unsigned short UNORDERED_NODE_SNAPSHOT_TYPE = 6;
    pub fn get_UNORDERED_NODE_SNAPSHOT_TYPE() u16 {
        return 6;
    }

    /// WebIDL constant: const unsigned short ORDERED_NODE_SNAPSHOT_TYPE = 7;
    pub fn get_ORDERED_NODE_SNAPSHOT_TYPE() u16 {
        return 7;
    }

    /// WebIDL constant: const unsigned short ANY_UNORDERED_NODE_TYPE = 8;
    pub fn get_ANY_UNORDERED_NODE_TYPE() u16 {
        return 8;
    }

    /// WebIDL constant: const unsigned short FIRST_ORDERED_NODE_TYPE = 9;
    pub fn get_FIRST_ORDERED_NODE_TYPE() u16 {
        return 9;
    }

    pub const vtable = runtime.buildVTable(XPathResult, .{
        .deinit_fn = &deinit_wrapper,

        .get_ANY_TYPE = &get_ANY_TYPE,
        .get_ANY_UNORDERED_NODE_TYPE = &get_ANY_UNORDERED_NODE_TYPE,
        .get_BOOLEAN_TYPE = &get_BOOLEAN_TYPE,
        .get_FIRST_ORDERED_NODE_TYPE = &get_FIRST_ORDERED_NODE_TYPE,
        .get_NUMBER_TYPE = &get_NUMBER_TYPE,
        .get_ORDERED_NODE_ITERATOR_TYPE = &get_ORDERED_NODE_ITERATOR_TYPE,
        .get_ORDERED_NODE_SNAPSHOT_TYPE = &get_ORDERED_NODE_SNAPSHOT_TYPE,
        .get_STRING_TYPE = &get_STRING_TYPE,
        .get_UNORDERED_NODE_ITERATOR_TYPE = &get_UNORDERED_NODE_ITERATOR_TYPE,
        .get_UNORDERED_NODE_SNAPSHOT_TYPE = &get_UNORDERED_NODE_SNAPSHOT_TYPE,
        .get_booleanValue = &get_booleanValue,
        .get_invalidIteratorState = &get_invalidIteratorState,
        .get_numberValue = &get_numberValue,
        .get_resultType = &get_resultType,
        .get_singleNodeValue = &get_singleNodeValue,
        .get_snapshotLength = &get_snapshotLength,
        .get_stringValue = &get_stringValue,

        .call_iterateNext = &call_iterateNext,
        .call_snapshotItem = &call_snapshotItem,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        XPathResultImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XPathResultImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_resultType(instance: *runtime.Instance) anyerror!u16 {
        return try XPathResultImpl.get_resultType(instance);
    }

    pub fn get_numberValue(instance: *runtime.Instance) anyerror!f64 {
        return try XPathResultImpl.get_numberValue(instance);
    }

    pub fn get_stringValue(instance: *runtime.Instance) anyerror!DOMString {
        return try XPathResultImpl.get_stringValue(instance);
    }

    pub fn get_booleanValue(instance: *runtime.Instance) anyerror!bool {
        return try XPathResultImpl.get_booleanValue(instance);
    }

    pub fn get_singleNodeValue(instance: *runtime.Instance) anyerror!anyopaque {
        return try XPathResultImpl.get_singleNodeValue(instance);
    }

    pub fn get_invalidIteratorState(instance: *runtime.Instance) anyerror!bool {
        return try XPathResultImpl.get_invalidIteratorState(instance);
    }

    pub fn get_snapshotLength(instance: *runtime.Instance) anyerror!u32 {
        return try XPathResultImpl.get_snapshotLength(instance);
    }

    pub fn call_snapshotItem(instance: *runtime.Instance, index: u32) anyerror!anyopaque {
        
        return try XPathResultImpl.call_snapshotItem(instance, index);
    }

    pub fn call_iterateNext(instance: *runtime.Instance) anyerror!anyopaque {
        return try XPathResultImpl.call_iterateNext(instance);
    }

};
