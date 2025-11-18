//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ElementContentEditableImpl = @import("impls").ElementContentEditable;

pub const ElementContentEditable = struct {
    pub const Meta = struct {
        pub const name = "ElementContentEditable";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            contentEditable: runtime.DOMString = undefined,
            enterKeyHint: runtime.DOMString = undefined,
            isContentEditable: bool = undefined,
            inputMode: runtime.DOMString = undefined,
            virtualKeyboardPolicy: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ElementContentEditable, .{
        .deinit_fn = &deinit_wrapper,

        .get_contentEditable = &get_contentEditable,
        .get_enterKeyHint = &get_enterKeyHint,
        .get_inputMode = &get_inputMode,
        .get_isContentEditable = &get_isContentEditable,
        .get_virtualKeyboardPolicy = &get_virtualKeyboardPolicy,

        .set_contentEditable = &set_contentEditable,
        .set_enterKeyHint = &set_enterKeyHint,
        .set_inputMode = &set_inputMode,
        .set_virtualKeyboardPolicy = &set_virtualKeyboardPolicy,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ElementContentEditableImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ElementContentEditableImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_contentEditable(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementContentEditableImpl.get_contentEditable(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_contentEditable(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementContentEditableImpl.set_contentEditable(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_enterKeyHint(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementContentEditableImpl.get_enterKeyHint(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_enterKeyHint(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementContentEditableImpl.set_enterKeyHint(instance, value);
    }

    pub fn get_isContentEditable(instance: *runtime.Instance) anyerror!bool {
        return try ElementContentEditableImpl.get_isContentEditable(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_inputMode(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementContentEditableImpl.get_inputMode(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_inputMode(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementContentEditableImpl.set_inputMode(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_virtualKeyboardPolicy(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementContentEditableImpl.get_virtualKeyboardPolicy(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_virtualKeyboardPolicy(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementContentEditableImpl.set_virtualKeyboardPolicy(instance, value);
    }

};
