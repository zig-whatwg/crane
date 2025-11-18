//! Generated from: css-anchor-position.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSPositionTryDescriptorsImpl = @import("impls").CSSPositionTryDescriptors;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const CSSOMString = @import("interfaces").CSSOMString;

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
        .call_getPropertyValue = &call_getPropertyValue,
        .call_item = &call_item,
        .call_removeProperty = &call_removeProperty,
        .call_setProperty = &call_setProperty,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSSPositionTryDescriptorsImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSPositionTryDescriptorsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_cssText(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_cssText(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try CSSPositionTryDescriptorsImpl.set_cssText(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSPositionTryDescriptorsImpl.get_length(instance);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_parentRule(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSPositionTryDescriptorsImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_cssText(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSPositionTryDescriptorsImpl.get_length(instance);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!CSSRule {
        return try CSSPositionTryDescriptorsImpl.get_parentRule(instance);
    }

    pub fn get_margin(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_margin(instance);
    }

    pub fn set_margin(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin(instance, value);
    }

    pub fn get_marginTop(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_marginTop(instance);
    }

    pub fn set_marginTop(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginTop(instance, value);
    }

    pub fn get_marginRight(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_marginRight(instance);
    }

    pub fn set_marginRight(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginRight(instance, value);
    }

    pub fn get_marginBottom(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_marginBottom(instance);
    }

    pub fn set_marginBottom(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginBottom(instance, value);
    }

    pub fn get_marginLeft(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_marginLeft(instance);
    }

    pub fn set_marginLeft(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginLeft(instance, value);
    }

    pub fn get_marginBlock(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_marginBlock(instance);
    }

    pub fn set_marginBlock(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginBlock(instance, value);
    }

    pub fn get_marginBlockStart(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_marginBlockStart(instance);
    }

    pub fn set_marginBlockStart(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginBlockStart(instance, value);
    }

    pub fn get_marginBlockEnd(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_marginBlockEnd(instance);
    }

    pub fn set_marginBlockEnd(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginBlockEnd(instance, value);
    }

    pub fn get_marginInline(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_marginInline(instance);
    }

    pub fn set_marginInline(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginInline(instance, value);
    }

    pub fn get_marginInlineStart(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_marginInlineStart(instance);
    }

    pub fn set_marginInlineStart(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginInlineStart(instance, value);
    }

    pub fn get_marginInlineEnd(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_marginInlineEnd(instance);
    }

    pub fn set_marginInlineEnd(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginInlineEnd(instance, value);
    }

    pub fn get_margin-top(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_margin-top(instance);
    }

    pub fn set_margin-top(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin-top(instance, value);
    }

    pub fn get_margin-right(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_margin-right(instance);
    }

    pub fn set_margin-right(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin-right(instance, value);
    }

    pub fn get_margin-bottom(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_margin-bottom(instance);
    }

    pub fn set_margin-bottom(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin-bottom(instance, value);
    }

    pub fn get_margin-left(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_margin-left(instance);
    }

    pub fn set_margin-left(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin-left(instance, value);
    }

    pub fn get_margin-block(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_margin-block(instance);
    }

    pub fn set_margin-block(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin-block(instance, value);
    }

    pub fn get_margin-block-start(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_margin-block-start(instance);
    }

    pub fn set_margin-block-start(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin-block-start(instance, value);
    }

    pub fn get_margin-block-end(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_margin-block-end(instance);
    }

    pub fn set_margin-block-end(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin-block-end(instance, value);
    }

    pub fn get_margin-inline(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_margin-inline(instance);
    }

    pub fn set_margin-inline(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin-inline(instance, value);
    }

    pub fn get_margin-inline-start(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_margin-inline-start(instance);
    }

    pub fn set_margin-inline-start(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin-inline-start(instance, value);
    }

    pub fn get_margin-inline-end(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_margin-inline-end(instance);
    }

    pub fn set_margin-inline-end(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin-inline-end(instance, value);
    }

    pub fn get_inset(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_inset(instance);
    }

    pub fn set_inset(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inset(instance, value);
    }

    pub fn get_insetBlock(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_insetBlock(instance);
    }

    pub fn set_insetBlock(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_insetBlock(instance, value);
    }

    pub fn get_insetBlockStart(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_insetBlockStart(instance);
    }

    pub fn set_insetBlockStart(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_insetBlockStart(instance, value);
    }

    pub fn get_insetBlockEnd(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_insetBlockEnd(instance);
    }

    pub fn set_insetBlockEnd(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_insetBlockEnd(instance, value);
    }

    pub fn get_insetInline(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_insetInline(instance);
    }

    pub fn set_insetInline(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_insetInline(instance, value);
    }

    pub fn get_insetInlineStart(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_insetInlineStart(instance);
    }

    pub fn set_insetInlineStart(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_insetInlineStart(instance, value);
    }

    pub fn get_insetInlineEnd(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_insetInlineEnd(instance);
    }

    pub fn set_insetInlineEnd(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_insetInlineEnd(instance, value);
    }

    pub fn get_top(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_top(instance);
    }

    pub fn set_top(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_top(instance, value);
    }

    pub fn get_left(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_left(instance);
    }

    pub fn set_left(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_left(instance, value);
    }

    pub fn get_right(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_right(instance);
    }

    pub fn set_right(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_right(instance, value);
    }

    pub fn get_bottom(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_bottom(instance);
    }

    pub fn set_bottom(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_bottom(instance, value);
    }

    pub fn get_inset-block(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_inset-block(instance);
    }

    pub fn set_inset-block(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inset-block(instance, value);
    }

    pub fn get_inset-block-start(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_inset-block-start(instance);
    }

    pub fn set_inset-block-start(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inset-block-start(instance, value);
    }

    pub fn get_inset-block-end(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_inset-block-end(instance);
    }

    pub fn set_inset-block-end(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inset-block-end(instance, value);
    }

    pub fn get_inset-inline(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_inset-inline(instance);
    }

    pub fn set_inset-inline(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inset-inline(instance, value);
    }

    pub fn get_inset-inline-start(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_inset-inline-start(instance);
    }

    pub fn set_inset-inline-start(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inset-inline-start(instance, value);
    }

    pub fn get_inset-inline-end(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_inset-inline-end(instance);
    }

    pub fn set_inset-inline-end(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inset-inline-end(instance, value);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_width(instance);
    }

    pub fn set_width(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_width(instance, value);
    }

    pub fn get_minWidth(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_minWidth(instance);
    }

    pub fn set_minWidth(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_minWidth(instance, value);
    }

    pub fn get_maxWidth(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_maxWidth(instance);
    }

    pub fn set_maxWidth(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_maxWidth(instance, value);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_height(instance);
    }

    pub fn set_height(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_height(instance, value);
    }

    pub fn get_minHeight(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_minHeight(instance);
    }

    pub fn set_minHeight(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_minHeight(instance, value);
    }

    pub fn get_maxHeight(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_maxHeight(instance);
    }

    pub fn set_maxHeight(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_maxHeight(instance, value);
    }

    pub fn get_blockSize(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_blockSize(instance);
    }

    pub fn set_blockSize(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_blockSize(instance, value);
    }

    pub fn get_minBlockSize(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_minBlockSize(instance);
    }

    pub fn set_minBlockSize(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_minBlockSize(instance, value);
    }

    pub fn get_maxBlockSize(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_maxBlockSize(instance);
    }

    pub fn set_maxBlockSize(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_maxBlockSize(instance, value);
    }

    pub fn get_inlineSize(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_inlineSize(instance);
    }

    pub fn set_inlineSize(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inlineSize(instance, value);
    }

    pub fn get_minInlineSize(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_minInlineSize(instance);
    }

    pub fn set_minInlineSize(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_minInlineSize(instance, value);
    }

    pub fn get_maxInlineSize(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_maxInlineSize(instance);
    }

    pub fn set_maxInlineSize(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_maxInlineSize(instance, value);
    }

    pub fn get_min-width(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_min-width(instance);
    }

    pub fn set_min-width(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_min-width(instance, value);
    }

    pub fn get_max-width(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_max-width(instance);
    }

    pub fn set_max-width(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_max-width(instance, value);
    }

    pub fn get_min-height(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_min-height(instance);
    }

    pub fn set_min-height(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_min-height(instance, value);
    }

    pub fn get_max-height(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_max-height(instance);
    }

    pub fn set_max-height(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_max-height(instance, value);
    }

    pub fn get_block-size(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_block-size(instance);
    }

    pub fn set_block-size(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_block-size(instance, value);
    }

    pub fn get_min-block-size(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_min-block-size(instance);
    }

    pub fn set_min-block-size(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_min-block-size(instance, value);
    }

    pub fn get_max-block-size(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_max-block-size(instance);
    }

    pub fn set_max-block-size(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_max-block-size(instance, value);
    }

    pub fn get_inline-size(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_inline-size(instance);
    }

    pub fn set_inline-size(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inline-size(instance, value);
    }

    pub fn get_min-inline-size(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_min-inline-size(instance);
    }

    pub fn set_min-inline-size(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_min-inline-size(instance, value);
    }

    pub fn get_max-inline-size(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_max-inline-size(instance);
    }

    pub fn set_max-inline-size(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_max-inline-size(instance, value);
    }

    pub fn get_placeSelf(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_placeSelf(instance);
    }

    pub fn set_placeSelf(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_placeSelf(instance, value);
    }

    pub fn get_alignSelf(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_alignSelf(instance);
    }

    pub fn set_alignSelf(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_alignSelf(instance, value);
    }

    pub fn get_justifySelf(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_justifySelf(instance);
    }

    pub fn set_justifySelf(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_justifySelf(instance, value);
    }

    pub fn get_place-self(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_place-self(instance);
    }

    pub fn set_place-self(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_place-self(instance, value);
    }

    pub fn get_align-self(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_align-self(instance);
    }

    pub fn set_align-self(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_align-self(instance, value);
    }

    pub fn get_justify-self(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_justify-self(instance);
    }

    pub fn set_justify-self(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_justify-self(instance, value);
    }

    pub fn get_positionAnchor(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_positionAnchor(instance);
    }

    pub fn set_positionAnchor(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_positionAnchor(instance, value);
    }

    pub fn get_position-anchor(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_position-anchor(instance);
    }

    pub fn set_position-anchor(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_position-anchor(instance, value);
    }

    pub fn get_positionArea(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_positionArea(instance);
    }

    pub fn set_positionArea(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_positionArea(instance, value);
    }

    pub fn get_position-area(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPositionTryDescriptorsImpl.get_position-area(instance);
    }

    pub fn set_position-area(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_position-area(instance, value);
    }

    /// Arguments for item (WebIDL overloading)
    pub const ItemArgs = union(enum) {
        /// item(index)
        long: u32,
        /// item(index)
        long: u32,
    };

    pub fn call_item(instance: *runtime.Instance, args: ItemArgs) anyerror!anyopaque {
        switch (args) {
            .long => |arg| return try CSSPositionTryDescriptorsImpl.long(instance, arg),
            .long => |arg| return try CSSPositionTryDescriptorsImpl.long(instance, arg),
        }
    }

    /// Arguments for removeProperty (WebIDL overloading)
    pub const RemovePropertyArgs = union(enum) {
        /// removeProperty(property)
        CSSOMString: anyopaque,
        /// removeProperty(propertyName)
        string: DOMString,
    };

    pub fn call_removeProperty(instance: *runtime.Instance, args: RemovePropertyArgs) anyerror!anyopaque {
        switch (args) {
            .CSSOMString => |arg| return try CSSPositionTryDescriptorsImpl.CSSOMString(instance, arg),
            .string => |arg| return try CSSPositionTryDescriptorsImpl.string(instance, arg),
        }
    }

    /// Arguments for getPropertyPriority (WebIDL overloading)
    pub const GetPropertyPriorityArgs = union(enum) {
        /// getPropertyPriority(property)
        CSSOMString: anyopaque,
        /// getPropertyPriority(propertyName)
        string: DOMString,
    };

    pub fn call_getPropertyPriority(instance: *runtime.Instance, args: GetPropertyPriorityArgs) anyerror!anyopaque {
        switch (args) {
            .CSSOMString => |arg| return try CSSPositionTryDescriptorsImpl.CSSOMString(instance, arg),
            .string => |arg| return try CSSPositionTryDescriptorsImpl.string(instance, arg),
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
            propertyName: DOMString,
            value: DOMString,
            priority: DOMString,
        },
    };

    pub fn call_setProperty(instance: *runtime.Instance, args: SetPropertyArgs) anyerror!void {
        switch (args) {
            .CSSOMString_CSSOMString_CSSOMString => |a| return try CSSPositionTryDescriptorsImpl.CSSOMString_CSSOMString_CSSOMString(instance, a.property, a.value, a.priority),
            .string_string_string => |a| return try CSSPositionTryDescriptorsImpl.string_string_string(instance, a.propertyName, a.value, a.priority),
        }
    }

    pub fn call_getPropertyCSSValue(instance: *runtime.Instance, propertyName: DOMString) anyerror!CSSValue {
        
        return try CSSPositionTryDescriptorsImpl.call_getPropertyCSSValue(instance, propertyName);
    }

    /// Arguments for getPropertyValue (WebIDL overloading)
    pub const GetPropertyValueArgs = union(enum) {
        /// getPropertyValue(property)
        CSSOMString: anyopaque,
        /// getPropertyValue(propertyName)
        string: DOMString,
    };

    pub fn call_getPropertyValue(instance: *runtime.Instance, args: GetPropertyValueArgs) anyerror!anyopaque {
        switch (args) {
            .CSSOMString => |arg| return try CSSPositionTryDescriptorsImpl.CSSOMString(instance, arg),
            .string => |arg| return try CSSPositionTryDescriptorsImpl.string(instance, arg),
        }
    }

};
