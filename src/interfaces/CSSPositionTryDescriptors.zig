//! Generated from: css-anchor-position.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSPositionTryDescriptorsImpl = @import("../impls/CSSPositionTryDescriptors.zig");
const CSSStyleDeclaration = @import("CSSStyleDeclaration.zig");

pub const CSSPositionTryDescriptors = struct {
    pub const Meta = struct {
        pub const name = "CSSPositionTryDescriptors";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSStyleDeclaration;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            margin: CSSOMString = undefined,
            marginTop: CSSOMString = undefined,
            marginRight: CSSOMString = undefined,
            marginBottom: CSSOMString = undefined,
            marginLeft: CSSOMString = undefined,
            marginBlock: CSSOMString = undefined,
            marginBlockStart: CSSOMString = undefined,
            marginBlockEnd: CSSOMString = undefined,
            marginInline: CSSOMString = undefined,
            marginInlineStart: CSSOMString = undefined,
            marginInlineEnd: CSSOMString = undefined,
            margin-top: CSSOMString = undefined,
            margin-right: CSSOMString = undefined,
            margin-bottom: CSSOMString = undefined,
            margin-left: CSSOMString = undefined,
            margin-block: CSSOMString = undefined,
            margin-block-start: CSSOMString = undefined,
            margin-block-end: CSSOMString = undefined,
            margin-inline: CSSOMString = undefined,
            margin-inline-start: CSSOMString = undefined,
            margin-inline-end: CSSOMString = undefined,
            inset: CSSOMString = undefined,
            insetBlock: CSSOMString = undefined,
            insetBlockStart: CSSOMString = undefined,
            insetBlockEnd: CSSOMString = undefined,
            insetInline: CSSOMString = undefined,
            insetInlineStart: CSSOMString = undefined,
            insetInlineEnd: CSSOMString = undefined,
            top: CSSOMString = undefined,
            left: CSSOMString = undefined,
            right: CSSOMString = undefined,
            bottom: CSSOMString = undefined,
            inset-block: CSSOMString = undefined,
            inset-block-start: CSSOMString = undefined,
            inset-block-end: CSSOMString = undefined,
            inset-inline: CSSOMString = undefined,
            inset-inline-start: CSSOMString = undefined,
            inset-inline-end: CSSOMString = undefined,
            width: CSSOMString = undefined,
            minWidth: CSSOMString = undefined,
            maxWidth: CSSOMString = undefined,
            height: CSSOMString = undefined,
            minHeight: CSSOMString = undefined,
            maxHeight: CSSOMString = undefined,
            blockSize: CSSOMString = undefined,
            minBlockSize: CSSOMString = undefined,
            maxBlockSize: CSSOMString = undefined,
            inlineSize: CSSOMString = undefined,
            minInlineSize: CSSOMString = undefined,
            maxInlineSize: CSSOMString = undefined,
            min-width: CSSOMString = undefined,
            max-width: CSSOMString = undefined,
            min-height: CSSOMString = undefined,
            max-height: CSSOMString = undefined,
            block-size: CSSOMString = undefined,
            min-block-size: CSSOMString = undefined,
            max-block-size: CSSOMString = undefined,
            inline-size: CSSOMString = undefined,
            min-inline-size: CSSOMString = undefined,
            max-inline-size: CSSOMString = undefined,
            placeSelf: CSSOMString = undefined,
            alignSelf: CSSOMString = undefined,
            justifySelf: CSSOMString = undefined,
            place-self: CSSOMString = undefined,
            align-self: CSSOMString = undefined,
            justify-self: CSSOMString = undefined,
            positionAnchor: CSSOMString = undefined,
            position-anchor: CSSOMString = undefined,
            positionArea: CSSOMString = undefined,
            position-area: CSSOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSPositionTryDescriptors, .{
        .deinit_fn = &deinit_wrapper,

        .get_align-self = &get_align-self,
        .get_alignSelf = &get_alignSelf,
        .get_block-size = &get_block-size,
        .get_blockSize = &get_blockSize,
        .get_bottom = &get_bottom,
        .get_cssText = &get_cssText,
        .get_cssText = &get_cssText,
        .get_height = &get_height,
        .get_inline-size = &get_inline-size,
        .get_inlineSize = &get_inlineSize,
        .get_inset = &get_inset,
        .get_inset-block = &get_inset-block,
        .get_inset-block-end = &get_inset-block-end,
        .get_inset-block-start = &get_inset-block-start,
        .get_inset-inline = &get_inset-inline,
        .get_inset-inline-end = &get_inset-inline-end,
        .get_inset-inline-start = &get_inset-inline-start,
        .get_insetBlock = &get_insetBlock,
        .get_insetBlockEnd = &get_insetBlockEnd,
        .get_insetBlockStart = &get_insetBlockStart,
        .get_insetInline = &get_insetInline,
        .get_insetInlineEnd = &get_insetInlineEnd,
        .get_insetInlineStart = &get_insetInlineStart,
        .get_justify-self = &get_justify-self,
        .get_justifySelf = &get_justifySelf,
        .get_left = &get_left,
        .get_length = &get_length,
        .get_length = &get_length,
        .get_margin = &get_margin,
        .get_margin-block = &get_margin-block,
        .get_margin-block-end = &get_margin-block-end,
        .get_margin-block-start = &get_margin-block-start,
        .get_margin-bottom = &get_margin-bottom,
        .get_margin-inline = &get_margin-inline,
        .get_margin-inline-end = &get_margin-inline-end,
        .get_margin-inline-start = &get_margin-inline-start,
        .get_margin-left = &get_margin-left,
        .get_margin-right = &get_margin-right,
        .get_margin-top = &get_margin-top,
        .get_marginBlock = &get_marginBlock,
        .get_marginBlockEnd = &get_marginBlockEnd,
        .get_marginBlockStart = &get_marginBlockStart,
        .get_marginBottom = &get_marginBottom,
        .get_marginInline = &get_marginInline,
        .get_marginInlineEnd = &get_marginInlineEnd,
        .get_marginInlineStart = &get_marginInlineStart,
        .get_marginLeft = &get_marginLeft,
        .get_marginRight = &get_marginRight,
        .get_marginTop = &get_marginTop,
        .get_max-block-size = &get_max-block-size,
        .get_max-height = &get_max-height,
        .get_max-inline-size = &get_max-inline-size,
        .get_max-width = &get_max-width,
        .get_maxBlockSize = &get_maxBlockSize,
        .get_maxHeight = &get_maxHeight,
        .get_maxInlineSize = &get_maxInlineSize,
        .get_maxWidth = &get_maxWidth,
        .get_min-block-size = &get_min-block-size,
        .get_min-height = &get_min-height,
        .get_min-inline-size = &get_min-inline-size,
        .get_min-width = &get_min-width,
        .get_minBlockSize = &get_minBlockSize,
        .get_minHeight = &get_minHeight,
        .get_minInlineSize = &get_minInlineSize,
        .get_minWidth = &get_minWidth,
        .get_parentRule = &get_parentRule,
        .get_parentRule = &get_parentRule,
        .get_place-self = &get_place-self,
        .get_placeSelf = &get_placeSelf,
        .get_position-anchor = &get_position-anchor,
        .get_position-area = &get_position-area,
        .get_positionAnchor = &get_positionAnchor,
        .get_positionArea = &get_positionArea,
        .get_right = &get_right,
        .get_top = &get_top,
        .get_width = &get_width,

        .set_align-self = &set_align-self,
        .set_alignSelf = &set_alignSelf,
        .set_block-size = &set_block-size,
        .set_blockSize = &set_blockSize,
        .set_bottom = &set_bottom,
        .set_cssText = &set_cssText,
        .set_cssText = &set_cssText,
        .set_height = &set_height,
        .set_inline-size = &set_inline-size,
        .set_inlineSize = &set_inlineSize,
        .set_inset = &set_inset,
        .set_inset-block = &set_inset-block,
        .set_inset-block-end = &set_inset-block-end,
        .set_inset-block-start = &set_inset-block-start,
        .set_inset-inline = &set_inset-inline,
        .set_inset-inline-end = &set_inset-inline-end,
        .set_inset-inline-start = &set_inset-inline-start,
        .set_insetBlock = &set_insetBlock,
        .set_insetBlockEnd = &set_insetBlockEnd,
        .set_insetBlockStart = &set_insetBlockStart,
        .set_insetInline = &set_insetInline,
        .set_insetInlineEnd = &set_insetInlineEnd,
        .set_insetInlineStart = &set_insetInlineStart,
        .set_justify-self = &set_justify-self,
        .set_justifySelf = &set_justifySelf,
        .set_left = &set_left,
        .set_margin = &set_margin,
        .set_margin-block = &set_margin-block,
        .set_margin-block-end = &set_margin-block-end,
        .set_margin-block-start = &set_margin-block-start,
        .set_margin-bottom = &set_margin-bottom,
        .set_margin-inline = &set_margin-inline,
        .set_margin-inline-end = &set_margin-inline-end,
        .set_margin-inline-start = &set_margin-inline-start,
        .set_margin-left = &set_margin-left,
        .set_margin-right = &set_margin-right,
        .set_margin-top = &set_margin-top,
        .set_marginBlock = &set_marginBlock,
        .set_marginBlockEnd = &set_marginBlockEnd,
        .set_marginBlockStart = &set_marginBlockStart,
        .set_marginBottom = &set_marginBottom,
        .set_marginInline = &set_marginInline,
        .set_marginInlineEnd = &set_marginInlineEnd,
        .set_marginInlineStart = &set_marginInlineStart,
        .set_marginLeft = &set_marginLeft,
        .set_marginRight = &set_marginRight,
        .set_marginTop = &set_marginTop,
        .set_max-block-size = &set_max-block-size,
        .set_max-height = &set_max-height,
        .set_max-inline-size = &set_max-inline-size,
        .set_max-width = &set_max-width,
        .set_maxBlockSize = &set_maxBlockSize,
        .set_maxHeight = &set_maxHeight,
        .set_maxInlineSize = &set_maxInlineSize,
        .set_maxWidth = &set_maxWidth,
        .set_min-block-size = &set_min-block-size,
        .set_min-height = &set_min-height,
        .set_min-inline-size = &set_min-inline-size,
        .set_min-width = &set_min-width,
        .set_minBlockSize = &set_minBlockSize,
        .set_minHeight = &set_minHeight,
        .set_minInlineSize = &set_minInlineSize,
        .set_minWidth = &set_minWidth,
        .set_place-self = &set_place-self,
        .set_placeSelf = &set_placeSelf,
        .set_position-anchor = &set_position-anchor,
        .set_position-area = &set_position-area,
        .set_positionAnchor = &set_positionAnchor,
        .set_positionArea = &set_positionArea,
        .set_right = &set_right,
        .set_top = &set_top,
        .set_width = &set_width,

        .call_getPropertyCSSValue = &call_getPropertyCSSValue,
        .call_getPropertyPriority = &call_getPropertyPriority,
        .call_getPropertyPriority = &call_getPropertyPriority,
        .call_getPropertyValue = &call_getPropertyValue,
        .call_getPropertyValue = &call_getPropertyValue,
        .call_item = &call_item,
        .call_item = &call_item,
        .call_removeProperty = &call_removeProperty,
        .call_removeProperty = &call_removeProperty,
        .call_setProperty = &call_setProperty,
        .call_setProperty = &call_setProperty,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CSSPositionTryDescriptorsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_cssText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_cssText(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        CSSPositionTryDescriptorsImpl.set_cssText(state, value);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_length(state);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_parentRule(state);
    }

    pub fn get_cssText(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_cssText(state, value);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_length(state);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_parentRule(state);
    }

    pub fn get_margin(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_margin(state);
    }

    pub fn set_margin(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_margin(state, value);
    }

    pub fn get_marginTop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_marginTop(state);
    }

    pub fn set_marginTop(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_marginTop(state, value);
    }

    pub fn get_marginRight(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_marginRight(state);
    }

    pub fn set_marginRight(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_marginRight(state, value);
    }

    pub fn get_marginBottom(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_marginBottom(state);
    }

    pub fn set_marginBottom(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_marginBottom(state, value);
    }

    pub fn get_marginLeft(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_marginLeft(state);
    }

    pub fn set_marginLeft(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_marginLeft(state, value);
    }

    pub fn get_marginBlock(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_marginBlock(state);
    }

    pub fn set_marginBlock(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_marginBlock(state, value);
    }

    pub fn get_marginBlockStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_marginBlockStart(state);
    }

    pub fn set_marginBlockStart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_marginBlockStart(state, value);
    }

    pub fn get_marginBlockEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_marginBlockEnd(state);
    }

    pub fn set_marginBlockEnd(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_marginBlockEnd(state, value);
    }

    pub fn get_marginInline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_marginInline(state);
    }

    pub fn set_marginInline(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_marginInline(state, value);
    }

    pub fn get_marginInlineStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_marginInlineStart(state);
    }

    pub fn set_marginInlineStart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_marginInlineStart(state, value);
    }

    pub fn get_marginInlineEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_marginInlineEnd(state);
    }

    pub fn set_marginInlineEnd(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_marginInlineEnd(state, value);
    }

    pub fn get_margin-top(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_margin-top(state);
    }

    pub fn set_margin-top(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_margin-top(state, value);
    }

    pub fn get_margin-right(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_margin-right(state);
    }

    pub fn set_margin-right(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_margin-right(state, value);
    }

    pub fn get_margin-bottom(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_margin-bottom(state);
    }

    pub fn set_margin-bottom(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_margin-bottom(state, value);
    }

    pub fn get_margin-left(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_margin-left(state);
    }

    pub fn set_margin-left(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_margin-left(state, value);
    }

    pub fn get_margin-block(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_margin-block(state);
    }

    pub fn set_margin-block(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_margin-block(state, value);
    }

    pub fn get_margin-block-start(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_margin-block-start(state);
    }

    pub fn set_margin-block-start(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_margin-block-start(state, value);
    }

    pub fn get_margin-block-end(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_margin-block-end(state);
    }

    pub fn set_margin-block-end(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_margin-block-end(state, value);
    }

    pub fn get_margin-inline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_margin-inline(state);
    }

    pub fn set_margin-inline(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_margin-inline(state, value);
    }

    pub fn get_margin-inline-start(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_margin-inline-start(state);
    }

    pub fn set_margin-inline-start(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_margin-inline-start(state, value);
    }

    pub fn get_margin-inline-end(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_margin-inline-end(state);
    }

    pub fn set_margin-inline-end(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_margin-inline-end(state, value);
    }

    pub fn get_inset(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_inset(state);
    }

    pub fn set_inset(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_inset(state, value);
    }

    pub fn get_insetBlock(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_insetBlock(state);
    }

    pub fn set_insetBlock(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_insetBlock(state, value);
    }

    pub fn get_insetBlockStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_insetBlockStart(state);
    }

    pub fn set_insetBlockStart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_insetBlockStart(state, value);
    }

    pub fn get_insetBlockEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_insetBlockEnd(state);
    }

    pub fn set_insetBlockEnd(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_insetBlockEnd(state, value);
    }

    pub fn get_insetInline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_insetInline(state);
    }

    pub fn set_insetInline(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_insetInline(state, value);
    }

    pub fn get_insetInlineStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_insetInlineStart(state);
    }

    pub fn set_insetInlineStart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_insetInlineStart(state, value);
    }

    pub fn get_insetInlineEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_insetInlineEnd(state);
    }

    pub fn set_insetInlineEnd(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_insetInlineEnd(state, value);
    }

    pub fn get_top(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_top(state);
    }

    pub fn set_top(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_top(state, value);
    }

    pub fn get_left(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_left(state);
    }

    pub fn set_left(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_left(state, value);
    }

    pub fn get_right(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_right(state);
    }

    pub fn set_right(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_right(state, value);
    }

    pub fn get_bottom(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_bottom(state);
    }

    pub fn set_bottom(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_bottom(state, value);
    }

    pub fn get_inset-block(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_inset-block(state);
    }

    pub fn set_inset-block(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_inset-block(state, value);
    }

    pub fn get_inset-block-start(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_inset-block-start(state);
    }

    pub fn set_inset-block-start(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_inset-block-start(state, value);
    }

    pub fn get_inset-block-end(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_inset-block-end(state);
    }

    pub fn set_inset-block-end(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_inset-block-end(state, value);
    }

    pub fn get_inset-inline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_inset-inline(state);
    }

    pub fn set_inset-inline(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_inset-inline(state, value);
    }

    pub fn get_inset-inline-start(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_inset-inline-start(state);
    }

    pub fn set_inset-inline-start(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_inset-inline-start(state, value);
    }

    pub fn get_inset-inline-end(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_inset-inline-end(state);
    }

    pub fn set_inset-inline-end(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_inset-inline-end(state, value);
    }

    pub fn get_width(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_width(state);
    }

    pub fn set_width(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_width(state, value);
    }

    pub fn get_minWidth(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_minWidth(state);
    }

    pub fn set_minWidth(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_minWidth(state, value);
    }

    pub fn get_maxWidth(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_maxWidth(state);
    }

    pub fn set_maxWidth(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_maxWidth(state, value);
    }

    pub fn get_height(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_height(state);
    }

    pub fn set_height(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_height(state, value);
    }

    pub fn get_minHeight(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_minHeight(state);
    }

    pub fn set_minHeight(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_minHeight(state, value);
    }

    pub fn get_maxHeight(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_maxHeight(state);
    }

    pub fn set_maxHeight(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_maxHeight(state, value);
    }

    pub fn get_blockSize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_blockSize(state);
    }

    pub fn set_blockSize(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_blockSize(state, value);
    }

    pub fn get_minBlockSize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_minBlockSize(state);
    }

    pub fn set_minBlockSize(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_minBlockSize(state, value);
    }

    pub fn get_maxBlockSize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_maxBlockSize(state);
    }

    pub fn set_maxBlockSize(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_maxBlockSize(state, value);
    }

    pub fn get_inlineSize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_inlineSize(state);
    }

    pub fn set_inlineSize(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_inlineSize(state, value);
    }

    pub fn get_minInlineSize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_minInlineSize(state);
    }

    pub fn set_minInlineSize(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_minInlineSize(state, value);
    }

    pub fn get_maxInlineSize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_maxInlineSize(state);
    }

    pub fn set_maxInlineSize(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_maxInlineSize(state, value);
    }

    pub fn get_min-width(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_min-width(state);
    }

    pub fn set_min-width(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_min-width(state, value);
    }

    pub fn get_max-width(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_max-width(state);
    }

    pub fn set_max-width(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_max-width(state, value);
    }

    pub fn get_min-height(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_min-height(state);
    }

    pub fn set_min-height(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_min-height(state, value);
    }

    pub fn get_max-height(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_max-height(state);
    }

    pub fn set_max-height(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_max-height(state, value);
    }

    pub fn get_block-size(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_block-size(state);
    }

    pub fn set_block-size(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_block-size(state, value);
    }

    pub fn get_min-block-size(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_min-block-size(state);
    }

    pub fn set_min-block-size(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_min-block-size(state, value);
    }

    pub fn get_max-block-size(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_max-block-size(state);
    }

    pub fn set_max-block-size(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_max-block-size(state, value);
    }

    pub fn get_inline-size(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_inline-size(state);
    }

    pub fn set_inline-size(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_inline-size(state, value);
    }

    pub fn get_min-inline-size(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_min-inline-size(state);
    }

    pub fn set_min-inline-size(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_min-inline-size(state, value);
    }

    pub fn get_max-inline-size(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_max-inline-size(state);
    }

    pub fn set_max-inline-size(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_max-inline-size(state, value);
    }

    pub fn get_placeSelf(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_placeSelf(state);
    }

    pub fn set_placeSelf(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_placeSelf(state, value);
    }

    pub fn get_alignSelf(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_alignSelf(state);
    }

    pub fn set_alignSelf(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_alignSelf(state, value);
    }

    pub fn get_justifySelf(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_justifySelf(state);
    }

    pub fn set_justifySelf(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_justifySelf(state, value);
    }

    pub fn get_place-self(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_place-self(state);
    }

    pub fn set_place-self(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_place-self(state, value);
    }

    pub fn get_align-self(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_align-self(state);
    }

    pub fn set_align-self(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_align-self(state, value);
    }

    pub fn get_justify-self(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_justify-self(state);
    }

    pub fn set_justify-self(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_justify-self(state, value);
    }

    pub fn get_positionAnchor(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_positionAnchor(state);
    }

    pub fn set_positionAnchor(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_positionAnchor(state, value);
    }

    pub fn get_position-anchor(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_position-anchor(state);
    }

    pub fn set_position-anchor(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_position-anchor(state, value);
    }

    pub fn get_positionArea(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_positionArea(state);
    }

    pub fn set_positionArea(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_positionArea(state, value);
    }

    pub fn get_position-area(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPositionTryDescriptorsImpl.get_position-area(state);
    }

    pub fn set_position-area(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPositionTryDescriptorsImpl.set_position-area(state, value);
    }

    /// Arguments for item (WebIDL overloading)
    pub const ItemArgs = union(enum) {
        /// item(index)
        long: u32,
        /// item(index)
        long: u32,
    };

    pub fn call_item(instance: *runtime.Instance, args: ItemArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .long => |arg| return CSSPositionTryDescriptorsImpl.long(state, arg),
            .long => |arg| return CSSPositionTryDescriptorsImpl.long(state, arg),
        }
    }

    /// Arguments for removeProperty (WebIDL overloading)
    pub const RemovePropertyArgs = union(enum) {
        /// removeProperty(property)
        CSSOMString: anyopaque,
        /// removeProperty(propertyName)
        string: runtime.DOMString,
    };

    pub fn call_removeProperty(instance: *runtime.Instance, args: RemovePropertyArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString => |arg| return CSSPositionTryDescriptorsImpl.CSSOMString(state, arg),
            .string => |arg| return CSSPositionTryDescriptorsImpl.string(state, arg),
        }
    }

    /// Arguments for getPropertyPriority (WebIDL overloading)
    pub const GetPropertyPriorityArgs = union(enum) {
        /// getPropertyPriority(property)
        CSSOMString: anyopaque,
        /// getPropertyPriority(propertyName)
        string: runtime.DOMString,
    };

    pub fn call_getPropertyPriority(instance: *runtime.Instance, args: GetPropertyPriorityArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString => |arg| return CSSPositionTryDescriptorsImpl.CSSOMString(state, arg),
            .string => |arg| return CSSPositionTryDescriptorsImpl.string(state, arg),
        }
    }

    /// Arguments for setProperty (WebIDL overloading)
    pub const SetPropertyArgs = union(enum) {
        /// setProperty(property, value, priority)
        CSSOMString_CSSOMString_CSSOMString: struct {
            property: anyopaque,
            value: anyopaque,
            priority: anyopaque,
        },
        /// setProperty(propertyName, value, priority)
        string_string_string: struct {
            propertyName: runtime.DOMString,
            value: runtime.DOMString,
            priority: runtime.DOMString,
        },
    };

    pub fn call_setProperty(instance: *runtime.Instance, args: SetPropertyArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString_CSSOMString_CSSOMString => |a| return CSSPositionTryDescriptorsImpl.CSSOMString_CSSOMString_CSSOMString(state, a.property, a.value, a.priority),
            .string_string_string => |a| return CSSPositionTryDescriptorsImpl.string_string_string(state, a.propertyName, a.value, a.priority),
        }
    }

    pub fn call_getPropertyCSSValue(instance: *runtime.Instance, propertyName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return CSSPositionTryDescriptorsImpl.call_getPropertyCSSValue(state, propertyName);
    }

    /// Arguments for getPropertyValue (WebIDL overloading)
    pub const GetPropertyValueArgs = union(enum) {
        /// getPropertyValue(property)
        CSSOMString: anyopaque,
        /// getPropertyValue(propertyName)
        string: runtime.DOMString,
    };

    pub fn call_getPropertyValue(instance: *runtime.Instance, args: GetPropertyValueArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString => |arg| return CSSPositionTryDescriptorsImpl.CSSOMString(state, arg),
            .string => |arg| return CSSPositionTryDescriptorsImpl.string(state, arg),
        }
    }

};
