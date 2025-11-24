//! Generated from: css-anchor-position.idl
//! Generated at: 2025-11-24T18:47:08Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSPositionTryDescriptorsImpl = @import("impls").CSSPositionTryDescriptors;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const CSSOMString = @import("typedefs").CSSOMString;
const CSSRule = @import("interfaces").CSSRule;
const DOMString = @import("typedefs").DOMString;
const CSSValue = @import("interfaces").CSSValue;

pub const CSSPositionTryDescriptors = struct {
    pub const Meta = struct {
        pub const name = "CSSPositionTryDescriptors";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSStyleDeclaration;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "margin", "get_margin", "set_margin" },
            .{ "marginTop", "get_marginTop", "set_marginTop" },
            .{ "marginRight", "get_marginRight", "set_marginRight" },
            .{ "marginBottom", "get_marginBottom", "set_marginBottom" },
            .{ "marginLeft", "get_marginLeft", "set_marginLeft" },
            .{ "marginBlock", "get_marginBlock", "set_marginBlock" },
            .{ "marginBlockStart", "get_marginBlockStart", "set_marginBlockStart" },
            .{ "marginBlockEnd", "get_marginBlockEnd", "set_marginBlockEnd" },
            .{ "marginInline", "get_marginInline", "set_marginInline" },
            .{ "marginInlineStart", "get_marginInlineStart", "set_marginInlineStart" },
            .{ "marginInlineEnd", "get_marginInlineEnd", "set_marginInlineEnd" },
            .{ "margin-top", "get_margin_top", "set_margin_top" },
            .{ "margin-right", "get_margin_right", "set_margin_right" },
            .{ "margin-bottom", "get_margin_bottom", "set_margin_bottom" },
            .{ "margin-left", "get_margin_left", "set_margin_left" },
            .{ "margin-block", "get_margin_block", "set_margin_block" },
            .{ "margin-block-start", "get_margin_block_start", "set_margin_block_start" },
            .{ "margin-block-end", "get_margin_block_end", "set_margin_block_end" },
            .{ "margin-inline", "get_margin_inline", "set_margin_inline" },
            .{ "margin-inline-start", "get_margin_inline_start", "set_margin_inline_start" },
            .{ "margin-inline-end", "get_margin_inline_end", "set_margin_inline_end" },
            .{ "inset", "get_inset", "set_inset" },
            .{ "insetBlock", "get_insetBlock", "set_insetBlock" },
            .{ "insetBlockStart", "get_insetBlockStart", "set_insetBlockStart" },
            .{ "insetBlockEnd", "get_insetBlockEnd", "set_insetBlockEnd" },
            .{ "insetInline", "get_insetInline", "set_insetInline" },
            .{ "insetInlineStart", "get_insetInlineStart", "set_insetInlineStart" },
            .{ "insetInlineEnd", "get_insetInlineEnd", "set_insetInlineEnd" },
            .{ "top", "get_top", "set_top" },
            .{ "left", "get_left", "set_left" },
            .{ "right", "get_right", "set_right" },
            .{ "bottom", "get_bottom", "set_bottom" },
            .{ "inset-block", "get_inset_block", "set_inset_block" },
            .{ "inset-block-start", "get_inset_block_start", "set_inset_block_start" },
            .{ "inset-block-end", "get_inset_block_end", "set_inset_block_end" },
            .{ "inset-inline", "get_inset_inline", "set_inset_inline" },
            .{ "inset-inline-start", "get_inset_inline_start", "set_inset_inline_start" },
            .{ "inset-inline-end", "get_inset_inline_end", "set_inset_inline_end" },
            .{ "width", "get_width", "set_width" },
            .{ "minWidth", "get_minWidth", "set_minWidth" },
            .{ "maxWidth", "get_maxWidth", "set_maxWidth" },
            .{ "height", "get_height", "set_height" },
            .{ "minHeight", "get_minHeight", "set_minHeight" },
            .{ "maxHeight", "get_maxHeight", "set_maxHeight" },
            .{ "blockSize", "get_blockSize", "set_blockSize" },
            .{ "minBlockSize", "get_minBlockSize", "set_minBlockSize" },
            .{ "maxBlockSize", "get_maxBlockSize", "set_maxBlockSize" },
            .{ "inlineSize", "get_inlineSize", "set_inlineSize" },
            .{ "minInlineSize", "get_minInlineSize", "set_minInlineSize" },
            .{ "maxInlineSize", "get_maxInlineSize", "set_maxInlineSize" },
            .{ "min-width", "get_min_width", "set_min_width" },
            .{ "max-width", "get_max_width", "set_max_width" },
            .{ "min-height", "get_min_height", "set_min_height" },
            .{ "max-height", "get_max_height", "set_max_height" },
            .{ "block-size", "get_block_size", "set_block_size" },
            .{ "min-block-size", "get_min_block_size", "set_min_block_size" },
            .{ "max-block-size", "get_max_block_size", "set_max_block_size" },
            .{ "inline-size", "get_inline_size", "set_inline_size" },
            .{ "min-inline-size", "get_min_inline_size", "set_min_inline_size" },
            .{ "max-inline-size", "get_max_inline_size", "set_max_inline_size" },
            .{ "placeSelf", "get_placeSelf", "set_placeSelf" },
            .{ "alignSelf", "get_alignSelf", "set_alignSelf" },
            .{ "justifySelf", "get_justifySelf", "set_justifySelf" },
            .{ "place-self", "get_place_self", "set_place_self" },
            .{ "align-self", "get_align_self", "set_align_self" },
            .{ "justify-self", "get_justify_self", "set_justify_self" },
            .{ "positionAnchor", "get_positionAnchor", "set_positionAnchor" },
            .{ "position-anchor", "get_position_anchor", "set_position_anchor" },
            .{ "positionArea", "get_positionArea", "set_positionArea" },
            .{ "position-area", "get_position_area", "set_position_area" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "item",
            "getPropertyValue",
            "getPropertyPriority",
            "setProperty",
            "removeProperty",
            "getPropertyValue",
            "getPropertyCSSValue",
            "removeProperty",
            "getPropertyPriority",
            "setProperty",
            "item",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "margin", "get_margin", "set_margin" },
            .{ "marginTop", "get_marginTop", "set_marginTop" },
            .{ "marginRight", "get_marginRight", "set_marginRight" },
            .{ "marginBottom", "get_marginBottom", "set_marginBottom" },
            .{ "marginLeft", "get_marginLeft", "set_marginLeft" },
            .{ "marginBlock", "get_marginBlock", "set_marginBlock" },
            .{ "marginBlockStart", "get_marginBlockStart", "set_marginBlockStart" },
            .{ "marginBlockEnd", "get_marginBlockEnd", "set_marginBlockEnd" },
            .{ "marginInline", "get_marginInline", "set_marginInline" },
            .{ "marginInlineStart", "get_marginInlineStart", "set_marginInlineStart" },
            .{ "marginInlineEnd", "get_marginInlineEnd", "set_marginInlineEnd" },
            .{ "margin-top", "get_margin_top", "set_margin_top" },
            .{ "margin-right", "get_margin_right", "set_margin_right" },
            .{ "margin-bottom", "get_margin_bottom", "set_margin_bottom" },
            .{ "margin-left", "get_margin_left", "set_margin_left" },
            .{ "margin-block", "get_margin_block", "set_margin_block" },
            .{ "margin-block-start", "get_margin_block_start", "set_margin_block_start" },
            .{ "margin-block-end", "get_margin_block_end", "set_margin_block_end" },
            .{ "margin-inline", "get_margin_inline", "set_margin_inline" },
            .{ "margin-inline-start", "get_margin_inline_start", "set_margin_inline_start" },
            .{ "margin-inline-end", "get_margin_inline_end", "set_margin_inline_end" },
            .{ "inset", "get_inset", "set_inset" },
            .{ "insetBlock", "get_insetBlock", "set_insetBlock" },
            .{ "insetBlockStart", "get_insetBlockStart", "set_insetBlockStart" },
            .{ "insetBlockEnd", "get_insetBlockEnd", "set_insetBlockEnd" },
            .{ "insetInline", "get_insetInline", "set_insetInline" },
            .{ "insetInlineStart", "get_insetInlineStart", "set_insetInlineStart" },
            .{ "insetInlineEnd", "get_insetInlineEnd", "set_insetInlineEnd" },
            .{ "top", "get_top", "set_top" },
            .{ "left", "get_left", "set_left" },
            .{ "right", "get_right", "set_right" },
            .{ "bottom", "get_bottom", "set_bottom" },
            .{ "inset-block", "get_inset_block", "set_inset_block" },
            .{ "inset-block-start", "get_inset_block_start", "set_inset_block_start" },
            .{ "inset-block-end", "get_inset_block_end", "set_inset_block_end" },
            .{ "inset-inline", "get_inset_inline", "set_inset_inline" },
            .{ "inset-inline-start", "get_inset_inline_start", "set_inset_inline_start" },
            .{ "inset-inline-end", "get_inset_inline_end", "set_inset_inline_end" },
            .{ "width", "get_width", "set_width" },
            .{ "minWidth", "get_minWidth", "set_minWidth" },
            .{ "maxWidth", "get_maxWidth", "set_maxWidth" },
            .{ "height", "get_height", "set_height" },
            .{ "minHeight", "get_minHeight", "set_minHeight" },
            .{ "maxHeight", "get_maxHeight", "set_maxHeight" },
            .{ "blockSize", "get_blockSize", "set_blockSize" },
            .{ "minBlockSize", "get_minBlockSize", "set_minBlockSize" },
            .{ "maxBlockSize", "get_maxBlockSize", "set_maxBlockSize" },
            .{ "inlineSize", "get_inlineSize", "set_inlineSize" },
            .{ "minInlineSize", "get_minInlineSize", "set_minInlineSize" },
            .{ "maxInlineSize", "get_maxInlineSize", "set_maxInlineSize" },
            .{ "min-width", "get_min_width", "set_min_width" },
            .{ "max-width", "get_max_width", "set_max_width" },
            .{ "min-height", "get_min_height", "set_min_height" },
            .{ "max-height", "get_max_height", "set_max_height" },
            .{ "block-size", "get_block_size", "set_block_size" },
            .{ "min-block-size", "get_min_block_size", "set_min_block_size" },
            .{ "max-block-size", "get_max_block_size", "set_max_block_size" },
            .{ "inline-size", "get_inline_size", "set_inline_size" },
            .{ "min-inline-size", "get_min_inline_size", "set_min_inline_size" },
            .{ "max-inline-size", "get_max_inline_size", "set_max_inline_size" },
            .{ "placeSelf", "get_placeSelf", "set_placeSelf" },
            .{ "alignSelf", "get_alignSelf", "set_alignSelf" },
            .{ "justifySelf", "get_justifySelf", "set_justifySelf" },
            .{ "place-self", "get_place_self", "set_place_self" },
            .{ "align-self", "get_align_self", "set_align_self" },
            .{ "justify-self", "get_justify_self", "set_justify_self" },
            .{ "positionAnchor", "get_positionAnchor", "set_positionAnchor" },
            .{ "position-anchor", "get_position_anchor", "set_position_anchor" },
            .{ "positionArea", "get_positionArea", "set_positionArea" },
            .{ "position-area", "get_position_area", "set_position_area" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
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
            @"margin-top": CSSOMString = undefined,
            @"margin-right": CSSOMString = undefined,
            @"margin-bottom": CSSOMString = undefined,
            @"margin-left": CSSOMString = undefined,
            @"margin-block": CSSOMString = undefined,
            @"margin-block-start": CSSOMString = undefined,
            @"margin-block-end": CSSOMString = undefined,
            @"margin-inline": CSSOMString = undefined,
            @"margin-inline-start": CSSOMString = undefined,
            @"margin-inline-end": CSSOMString = undefined,
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
            @"inset-block": CSSOMString = undefined,
            @"inset-block-start": CSSOMString = undefined,
            @"inset-block-end": CSSOMString = undefined,
            @"inset-inline": CSSOMString = undefined,
            @"inset-inline-start": CSSOMString = undefined,
            @"inset-inline-end": CSSOMString = undefined,
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
            @"min-width": CSSOMString = undefined,
            @"max-width": CSSOMString = undefined,
            @"min-height": CSSOMString = undefined,
            @"max-height": CSSOMString = undefined,
            @"block-size": CSSOMString = undefined,
            @"min-block-size": CSSOMString = undefined,
            @"max-block-size": CSSOMString = undefined,
            @"inline-size": CSSOMString = undefined,
            @"min-inline-size": CSSOMString = undefined,
            @"max-inline-size": CSSOMString = undefined,
            placeSelf: CSSOMString = undefined,
            alignSelf: CSSOMString = undefined,
            justifySelf: CSSOMString = undefined,
            @"place-self": CSSOMString = undefined,
            @"align-self": CSSOMString = undefined,
            @"justify-self": CSSOMString = undefined,
            positionAnchor: CSSOMString = undefined,
            @"position-anchor": CSSOMString = undefined,
            positionArea: CSSOMString = undefined,
            @"position-area": CSSOMString = undefined,
            _internal: ?*CSSPositionTryDescriptorsImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_alignSelf = &get_alignSelf,
        .get_align_self = &get_align_self,
        .get_blockSize = &get_blockSize,
        .get_block_size = &get_block_size,
        .get_bottom = &get_bottom,
        .get_height = &get_height,
        .get_inlineSize = &get_inlineSize,
        .get_inline_size = &get_inline_size,
        .get_inset = &get_inset,
        .get_insetBlock = &get_insetBlock,
        .get_insetBlockEnd = &get_insetBlockEnd,
        .get_insetBlockStart = &get_insetBlockStart,
        .get_insetInline = &get_insetInline,
        .get_insetInlineEnd = &get_insetInlineEnd,
        .get_insetInlineStart = &get_insetInlineStart,
        .get_inset_block = &get_inset_block,
        .get_inset_block_end = &get_inset_block_end,
        .get_inset_block_start = &get_inset_block_start,
        .get_inset_inline = &get_inset_inline,
        .get_inset_inline_end = &get_inset_inline_end,
        .get_inset_inline_start = &get_inset_inline_start,
        .get_justifySelf = &get_justifySelf,
        .get_justify_self = &get_justify_self,
        .get_left = &get_left,
        .get_margin = &get_margin,
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
        .get_margin_block = &get_margin_block,
        .get_margin_block_end = &get_margin_block_end,
        .get_margin_block_start = &get_margin_block_start,
        .get_margin_bottom = &get_margin_bottom,
        .get_margin_inline = &get_margin_inline,
        .get_margin_inline_end = &get_margin_inline_end,
        .get_margin_inline_start = &get_margin_inline_start,
        .get_margin_left = &get_margin_left,
        .get_margin_right = &get_margin_right,
        .get_margin_top = &get_margin_top,
        .get_maxBlockSize = &get_maxBlockSize,
        .get_maxHeight = &get_maxHeight,
        .get_maxInlineSize = &get_maxInlineSize,
        .get_maxWidth = &get_maxWidth,
        .get_max_block_size = &get_max_block_size,
        .get_max_height = &get_max_height,
        .get_max_inline_size = &get_max_inline_size,
        .get_max_width = &get_max_width,
        .get_minBlockSize = &get_minBlockSize,
        .get_minHeight = &get_minHeight,
        .get_minInlineSize = &get_minInlineSize,
        .get_minWidth = &get_minWidth,
        .get_min_block_size = &get_min_block_size,
        .get_min_height = &get_min_height,
        .get_min_inline_size = &get_min_inline_size,
        .get_min_width = &get_min_width,
        .get_placeSelf = &get_placeSelf,
        .get_place_self = &get_place_self,
        .get_positionAnchor = &get_positionAnchor,
        .get_positionArea = &get_positionArea,
        .get_position_anchor = &get_position_anchor,
        .get_position_area = &get_position_area,
        .get_right = &get_right,
        .get_top = &get_top,
        .get_width = &get_width,

        .set_alignSelf = &set_alignSelf,
        .set_align_self = &set_align_self,
        .set_blockSize = &set_blockSize,
        .set_block_size = &set_block_size,
        .set_bottom = &set_bottom,
        .set_height = &set_height,
        .set_inlineSize = &set_inlineSize,
        .set_inline_size = &set_inline_size,
        .set_inset = &set_inset,
        .set_insetBlock = &set_insetBlock,
        .set_insetBlockEnd = &set_insetBlockEnd,
        .set_insetBlockStart = &set_insetBlockStart,
        .set_insetInline = &set_insetInline,
        .set_insetInlineEnd = &set_insetInlineEnd,
        .set_insetInlineStart = &set_insetInlineStart,
        .set_inset_block = &set_inset_block,
        .set_inset_block_end = &set_inset_block_end,
        .set_inset_block_start = &set_inset_block_start,
        .set_inset_inline = &set_inset_inline,
        .set_inset_inline_end = &set_inset_inline_end,
        .set_inset_inline_start = &set_inset_inline_start,
        .set_justifySelf = &set_justifySelf,
        .set_justify_self = &set_justify_self,
        .set_left = &set_left,
        .set_margin = &set_margin,
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
        .set_margin_block = &set_margin_block,
        .set_margin_block_end = &set_margin_block_end,
        .set_margin_block_start = &set_margin_block_start,
        .set_margin_bottom = &set_margin_bottom,
        .set_margin_inline = &set_margin_inline,
        .set_margin_inline_end = &set_margin_inline_end,
        .set_margin_inline_start = &set_margin_inline_start,
        .set_margin_left = &set_margin_left,
        .set_margin_right = &set_margin_right,
        .set_margin_top = &set_margin_top,
        .set_maxBlockSize = &set_maxBlockSize,
        .set_maxHeight = &set_maxHeight,
        .set_maxInlineSize = &set_maxInlineSize,
        .set_maxWidth = &set_maxWidth,
        .set_max_block_size = &set_max_block_size,
        .set_max_height = &set_max_height,
        .set_max_inline_size = &set_max_inline_size,
        .set_max_width = &set_max_width,
        .set_minBlockSize = &set_minBlockSize,
        .set_minHeight = &set_minHeight,
        .set_minInlineSize = &set_minInlineSize,
        .set_minWidth = &set_minWidth,
        .set_min_block_size = &set_min_block_size,
        .set_min_height = &set_min_height,
        .set_min_inline_size = &set_min_inline_size,
        .set_min_width = &set_min_width,
        .set_placeSelf = &set_placeSelf,
        .set_place_self = &set_place_self,
        .set_positionAnchor = &set_positionAnchor,
        .set_positionArea = &set_positionArea,
        .set_position_anchor = &set_position_anchor,
        .set_position_area = &set_position_area,
        .set_right = &set_right,
        .set_top = &set_top,
        .set_width = &set_width,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSPositionTryDescriptorsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSPositionTryDescriptorsImpl.deinit(instance);
    }

    pub fn get_margin(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_margin(instance);
    }

    pub fn set_margin(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin(instance, value);
    }

    pub fn get_marginTop(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_marginTop(instance);
    }

    pub fn set_marginTop(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginTop(instance, value);
    }

    pub fn get_marginRight(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_marginRight(instance);
    }

    pub fn set_marginRight(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginRight(instance, value);
    }

    pub fn get_marginBottom(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_marginBottom(instance);
    }

    pub fn set_marginBottom(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginBottom(instance, value);
    }

    pub fn get_marginLeft(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_marginLeft(instance);
    }

    pub fn set_marginLeft(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginLeft(instance, value);
    }

    pub fn get_marginBlock(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_marginBlock(instance);
    }

    pub fn set_marginBlock(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginBlock(instance, value);
    }

    pub fn get_marginBlockStart(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_marginBlockStart(instance);
    }

    pub fn set_marginBlockStart(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginBlockStart(instance, value);
    }

    pub fn get_marginBlockEnd(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_marginBlockEnd(instance);
    }

    pub fn set_marginBlockEnd(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginBlockEnd(instance, value);
    }

    pub fn get_marginInline(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_marginInline(instance);
    }

    pub fn set_marginInline(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginInline(instance, value);
    }

    pub fn get_marginInlineStart(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_marginInlineStart(instance);
    }

    pub fn set_marginInlineStart(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginInlineStart(instance, value);
    }

    pub fn get_marginInlineEnd(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_marginInlineEnd(instance);
    }

    pub fn set_marginInlineEnd(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_marginInlineEnd(instance, value);
    }

    pub fn get_margin_top(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_margin_top(instance);
    }

    pub fn set_margin_top(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin_top(instance, value);
    }

    pub fn get_margin_right(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_margin_right(instance);
    }

    pub fn set_margin_right(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin_right(instance, value);
    }

    pub fn get_margin_bottom(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_margin_bottom(instance);
    }

    pub fn set_margin_bottom(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin_bottom(instance, value);
    }

    pub fn get_margin_left(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_margin_left(instance);
    }

    pub fn set_margin_left(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin_left(instance, value);
    }

    pub fn get_margin_block(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_margin_block(instance);
    }

    pub fn set_margin_block(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin_block(instance, value);
    }

    pub fn get_margin_block_start(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_margin_block_start(instance);
    }

    pub fn set_margin_block_start(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin_block_start(instance, value);
    }

    pub fn get_margin_block_end(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_margin_block_end(instance);
    }

    pub fn set_margin_block_end(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin_block_end(instance, value);
    }

    pub fn get_margin_inline(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_margin_inline(instance);
    }

    pub fn set_margin_inline(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin_inline(instance, value);
    }

    pub fn get_margin_inline_start(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_margin_inline_start(instance);
    }

    pub fn set_margin_inline_start(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin_inline_start(instance, value);
    }

    pub fn get_margin_inline_end(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_margin_inline_end(instance);
    }

    pub fn set_margin_inline_end(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_margin_inline_end(instance, value);
    }

    pub fn get_inset(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_inset(instance);
    }

    pub fn set_inset(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inset(instance, value);
    }

    pub fn get_insetBlock(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_insetBlock(instance);
    }

    pub fn set_insetBlock(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_insetBlock(instance, value);
    }

    pub fn get_insetBlockStart(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_insetBlockStart(instance);
    }

    pub fn set_insetBlockStart(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_insetBlockStart(instance, value);
    }

    pub fn get_insetBlockEnd(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_insetBlockEnd(instance);
    }

    pub fn set_insetBlockEnd(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_insetBlockEnd(instance, value);
    }

    pub fn get_insetInline(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_insetInline(instance);
    }

    pub fn set_insetInline(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_insetInline(instance, value);
    }

    pub fn get_insetInlineStart(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_insetInlineStart(instance);
    }

    pub fn set_insetInlineStart(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_insetInlineStart(instance, value);
    }

    pub fn get_insetInlineEnd(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_insetInlineEnd(instance);
    }

    pub fn set_insetInlineEnd(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_insetInlineEnd(instance, value);
    }

    pub fn get_top(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_top(instance);
    }

    pub fn set_top(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_top(instance, value);
    }

    pub fn get_left(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_left(instance);
    }

    pub fn set_left(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_left(instance, value);
    }

    pub fn get_right(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_right(instance);
    }

    pub fn set_right(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_right(instance, value);
    }

    pub fn get_bottom(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_bottom(instance);
    }

    pub fn set_bottom(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_bottom(instance, value);
    }

    pub fn get_inset_block(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_inset_block(instance);
    }

    pub fn set_inset_block(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inset_block(instance, value);
    }

    pub fn get_inset_block_start(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_inset_block_start(instance);
    }

    pub fn set_inset_block_start(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inset_block_start(instance, value);
    }

    pub fn get_inset_block_end(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_inset_block_end(instance);
    }

    pub fn set_inset_block_end(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inset_block_end(instance, value);
    }

    pub fn get_inset_inline(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_inset_inline(instance);
    }

    pub fn set_inset_inline(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inset_inline(instance, value);
    }

    pub fn get_inset_inline_start(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_inset_inline_start(instance);
    }

    pub fn set_inset_inline_start(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inset_inline_start(instance, value);
    }

    pub fn get_inset_inline_end(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_inset_inline_end(instance);
    }

    pub fn set_inset_inline_end(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inset_inline_end(instance, value);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_width(instance);
    }

    pub fn set_width(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_width(instance, value);
    }

    pub fn get_minWidth(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_minWidth(instance);
    }

    pub fn set_minWidth(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_minWidth(instance, value);
    }

    pub fn get_maxWidth(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_maxWidth(instance);
    }

    pub fn set_maxWidth(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_maxWidth(instance, value);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_height(instance);
    }

    pub fn set_height(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_height(instance, value);
    }

    pub fn get_minHeight(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_minHeight(instance);
    }

    pub fn set_minHeight(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_minHeight(instance, value);
    }

    pub fn get_maxHeight(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_maxHeight(instance);
    }

    pub fn set_maxHeight(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_maxHeight(instance, value);
    }

    pub fn get_blockSize(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_blockSize(instance);
    }

    pub fn set_blockSize(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_blockSize(instance, value);
    }

    pub fn get_minBlockSize(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_minBlockSize(instance);
    }

    pub fn set_minBlockSize(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_minBlockSize(instance, value);
    }

    pub fn get_maxBlockSize(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_maxBlockSize(instance);
    }

    pub fn set_maxBlockSize(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_maxBlockSize(instance, value);
    }

    pub fn get_inlineSize(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_inlineSize(instance);
    }

    pub fn set_inlineSize(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inlineSize(instance, value);
    }

    pub fn get_minInlineSize(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_minInlineSize(instance);
    }

    pub fn set_minInlineSize(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_minInlineSize(instance, value);
    }

    pub fn get_maxInlineSize(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_maxInlineSize(instance);
    }

    pub fn set_maxInlineSize(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_maxInlineSize(instance, value);
    }

    pub fn get_min_width(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_min_width(instance);
    }

    pub fn set_min_width(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_min_width(instance, value);
    }

    pub fn get_max_width(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_max_width(instance);
    }

    pub fn set_max_width(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_max_width(instance, value);
    }

    pub fn get_min_height(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_min_height(instance);
    }

    pub fn set_min_height(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_min_height(instance, value);
    }

    pub fn get_max_height(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_max_height(instance);
    }

    pub fn set_max_height(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_max_height(instance, value);
    }

    pub fn get_block_size(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_block_size(instance);
    }

    pub fn set_block_size(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_block_size(instance, value);
    }

    pub fn get_min_block_size(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_min_block_size(instance);
    }

    pub fn set_min_block_size(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_min_block_size(instance, value);
    }

    pub fn get_max_block_size(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_max_block_size(instance);
    }

    pub fn set_max_block_size(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_max_block_size(instance, value);
    }

    pub fn get_inline_size(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_inline_size(instance);
    }

    pub fn set_inline_size(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_inline_size(instance, value);
    }

    pub fn get_min_inline_size(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_min_inline_size(instance);
    }

    pub fn set_min_inline_size(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_min_inline_size(instance, value);
    }

    pub fn get_max_inline_size(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_max_inline_size(instance);
    }

    pub fn set_max_inline_size(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_max_inline_size(instance, value);
    }

    pub fn get_placeSelf(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_placeSelf(instance);
    }

    pub fn set_placeSelf(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_placeSelf(instance, value);
    }

    pub fn get_alignSelf(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_alignSelf(instance);
    }

    pub fn set_alignSelf(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_alignSelf(instance, value);
    }

    pub fn get_justifySelf(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_justifySelf(instance);
    }

    pub fn set_justifySelf(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_justifySelf(instance, value);
    }

    pub fn get_place_self(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_place_self(instance);
    }

    pub fn set_place_self(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_place_self(instance, value);
    }

    pub fn get_align_self(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_align_self(instance);
    }

    pub fn set_align_self(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_align_self(instance, value);
    }

    pub fn get_justify_self(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_justify_self(instance);
    }

    pub fn set_justify_self(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_justify_self(instance, value);
    }

    pub fn get_positionAnchor(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_positionAnchor(instance);
    }

    pub fn set_positionAnchor(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_positionAnchor(instance, value);
    }

    pub fn get_position_anchor(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_position_anchor(instance);
    }

    pub fn set_position_anchor(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_position_anchor(instance, value);
    }

    pub fn get_positionArea(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_positionArea(instance);
    }

    pub fn set_positionArea(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_positionArea(instance, value);
    }

    pub fn get_position_area(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPositionTryDescriptorsImpl.get_position_area(instance);
    }

    pub fn set_position_area(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPositionTryDescriptorsImpl.set_position_area(instance, value);
    }

};
