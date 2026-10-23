//! CSS Anchor Position 1 §8.1: restricted position-try descriptors.
//! State and mutation belong to the generated CSSStyleDeclaration parent
//! chain. Accessors use its public interface; the block enforces §6.4.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");

pub const State = interfaces.CSSPositionTryDescriptors.State;
pub const InternalState = struct {};
pub const ImplError = error{InvalidStateError};

pub fn get_margin(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin"));
}

pub fn set_margin(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_marginTop(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-top"));
}

pub fn set_marginTop(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-top"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_marginRight(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-right"));
}

pub fn set_marginRight(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-right"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_marginBottom(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-bottom"));
}

pub fn set_marginBottom(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-bottom"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_marginLeft(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-left"));
}

pub fn set_marginLeft(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-left"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_marginBlock(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-block"));
}

pub fn set_marginBlock(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-block"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_marginBlockStart(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-block-start"));
}

pub fn set_marginBlockStart(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-block-start"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_marginBlockEnd(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-block-end"));
}

pub fn set_marginBlockEnd(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-block-end"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_marginInline(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-inline"));
}

pub fn set_marginInline(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-inline"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_marginInlineStart(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-inline-start"));
}

pub fn set_marginInlineStart(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-inline-start"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_marginInlineEnd(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-inline-end"));
}

pub fn set_marginInlineEnd(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-inline-end"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_margin_top(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-top"));
}

pub fn set_margin_top(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-top"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_margin_right(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-right"));
}

pub fn set_margin_right(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-right"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_margin_bottom(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-bottom"));
}

pub fn set_margin_bottom(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-bottom"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_margin_left(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-left"));
}

pub fn set_margin_left(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-left"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_margin_block(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-block"));
}

pub fn set_margin_block(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-block"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_margin_block_start(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-block-start"));
}

pub fn set_margin_block_start(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-block-start"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_margin_block_end(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-block-end"));
}

pub fn set_margin_block_end(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-block-end"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_margin_inline(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-inline"));
}

pub fn set_margin_inline(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-inline"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_margin_inline_start(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-inline-start"));
}

pub fn set_margin_inline_start(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-inline-start"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_margin_inline_end(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-inline-end"));
}

pub fn set_margin_inline_end(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-inline-end"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_inset(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("inset"));
}

pub fn set_inset(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("inset"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_insetBlock(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("inset-block"));
}

pub fn set_insetBlock(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("inset-block"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_insetBlockStart(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("inset-block-start"));
}

pub fn set_insetBlockStart(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("inset-block-start"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_insetBlockEnd(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("inset-block-end"));
}

pub fn set_insetBlockEnd(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("inset-block-end"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_insetInline(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("inset-inline"));
}

pub fn set_insetInline(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("inset-inline"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_insetInlineStart(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("inset-inline-start"));
}

pub fn set_insetInlineStart(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("inset-inline-start"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_insetInlineEnd(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("inset-inline-end"));
}

pub fn set_insetInlineEnd(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("inset-inline-end"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_top(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("top"));
}

pub fn set_top(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("top"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_left(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("left"));
}

pub fn set_left(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("left"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_right(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("right"));
}

pub fn set_right(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("right"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_bottom(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("bottom"));
}

pub fn set_bottom(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("bottom"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_inset_block(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("inset-block"));
}

pub fn set_inset_block(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("inset-block"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_inset_block_start(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("inset-block-start"));
}

pub fn set_inset_block_start(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("inset-block-start"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_inset_block_end(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("inset-block-end"));
}

pub fn set_inset_block_end(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("inset-block-end"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_inset_inline(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("inset-inline"));
}

pub fn set_inset_inline(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("inset-inline"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_inset_inline_start(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("inset-inline-start"));
}

pub fn set_inset_inline_start(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("inset-inline-start"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_inset_inline_end(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("inset-inline-end"));
}

pub fn set_inset_inline_end(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("inset-inline-end"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_width(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("width"));
}

pub fn set_width(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("width"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_minWidth(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("min-width"));
}

pub fn set_minWidth(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("min-width"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_maxWidth(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("max-width"));
}

pub fn set_maxWidth(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("max-width"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_height(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("height"));
}

pub fn set_height(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("height"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_minHeight(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("min-height"));
}

pub fn set_minHeight(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("min-height"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_maxHeight(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("max-height"));
}

pub fn set_maxHeight(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("max-height"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_blockSize(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("block-size"));
}

pub fn set_blockSize(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("block-size"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_minBlockSize(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("min-block-size"));
}

pub fn set_minBlockSize(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("min-block-size"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_maxBlockSize(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("max-block-size"));
}

pub fn set_maxBlockSize(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("max-block-size"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_inlineSize(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("inline-size"));
}

pub fn set_inlineSize(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("inline-size"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_minInlineSize(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("min-inline-size"));
}

pub fn set_minInlineSize(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("min-inline-size"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_maxInlineSize(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("max-inline-size"));
}

pub fn set_maxInlineSize(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("max-inline-size"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_min_width(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("min-width"));
}

pub fn set_min_width(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("min-width"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_max_width(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("max-width"));
}

pub fn set_max_width(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("max-width"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_min_height(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("min-height"));
}

pub fn set_min_height(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("min-height"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_max_height(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("max-height"));
}

pub fn set_max_height(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("max-height"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_block_size(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("block-size"));
}

pub fn set_block_size(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("block-size"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_min_block_size(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("min-block-size"));
}

pub fn set_min_block_size(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("min-block-size"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_max_block_size(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("max-block-size"));
}

pub fn set_max_block_size(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("max-block-size"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_inline_size(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("inline-size"));
}

pub fn set_inline_size(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("inline-size"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_min_inline_size(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("min-inline-size"));
}

pub fn set_min_inline_size(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("min-inline-size"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_max_inline_size(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("max-inline-size"));
}

pub fn set_max_inline_size(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("max-inline-size"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_placeSelf(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("place-self"));
}

pub fn set_placeSelf(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("place-self"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_alignSelf(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("align-self"));
}

pub fn set_alignSelf(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("align-self"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_justifySelf(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("justify-self"));
}

pub fn set_justifySelf(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("justify-self"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_place_self(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("place-self"));
}

pub fn set_place_self(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("place-self"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_align_self(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("align-self"));
}

pub fn set_align_self(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("align-self"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_justify_self(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("justify-self"));
}

pub fn set_justify_self(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("justify-self"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_positionAnchor(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("position-anchor"));
}

pub fn set_positionAnchor(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("position-anchor"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_position_anchor(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("position-anchor"));
}

pub fn set_position_anchor(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("position-anchor"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_positionArea(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("position-area"));
}

pub fn set_positionArea(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("position-area"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_position_area(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("position-area"));
}

pub fn set_position_area(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("position-area"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}
