//! Implementation for NonDocumentTypeChildNode mixin
//!
//! Spec: https://dom.spec.whatwg.org/#interface-nondocumenttypechildnode
//!
//! This impl contains the actual logic for NonDocumentTypeChildNode methods.
//! The mixin file delegates to these functions.
//!
//! The NonDocumentTypeChildNode mixin defines:
//! - previousElementSibling - Returns the previous sibling that is an element
//! - nextElementSibling - Returns the next sibling that is an element

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");

pub const State = interfaces.NonDocumentTypeChildNode.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// Internal state for implementation-specific data
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

// =============================================================================
// NonDocumentTypeChildNode Attributes
// =============================================================================

/// previousElementSibling - Returns the previous sibling that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-previouselementsibling
///
/// Returns the first preceding sibling that is an element, or null if none exists.
pub fn get_previousElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    var sibling = interfaces.Node.get_previousSibling(instance) catch null;
    while (sibling) |s| {
        const node_type = interfaces.Node.get_nodeType(s) catch 0;
        if (node_type == interfaces.Node.get_ELEMENT_NODE()) {
            return s;
        }
        sibling = interfaces.Node.get_previousSibling(s) catch null;
    }
    return null;
}

/// nextElementSibling - Returns the next sibling that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-nextelementsibling
///
/// Returns the first following sibling that is an element, or null if none exists.
pub fn get_nextElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    var sibling = interfaces.Node.get_nextSibling(instance) catch null;
    while (sibling) |s| {
        const node_type = interfaces.Node.get_nodeType(s) catch 0;
        if (node_type == interfaces.Node.get_ELEMENT_NODE()) {
            return s;
        }
        sibling = interfaces.Node.get_nextSibling(s) catch null;
    }
    return null;
}

// ============================================================================
// HTML 8.5.2 / 8.5.3: the child-node HTML insertion and streaming methods.
// Their Unsafe counterparts' Trusted Types sink names use "Node" as the
// interface name: mixin names are not observable.
// ============================================================================

const webidl = @import("webidl");
const insertion = @import("html").html_insertion;
const streaming = @import("html").stream_html;

fn safeOptions(instance: *runtime.Instance, options: webidl.Opt(dictionaries.SetHTMLOptions)) !insertion.ParserOptions {
    return insertion.ParserOptions.fromDictionary(instance.ctx, options.getOrDefault(.{}).sanitizer, null);
}

fn unsafeOptions(instance: *runtime.Instance, options: webidl.Opt(typedefs.SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) !insertion.ParserOptions {
    return insertion.ParserOptions.fromUnion(instance.ctx, if (options.wasPassed()) options.getValue() else null);
}

/// beforeHTML(html, options): the parent for HTML insertion given this (null:
/// return), then filter and pre-insert HTML before this, Safe.
pub fn call_beforeHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(dictionaries.SetHTMLOptions)) anyerror!void {
    var parsed = try safeOptions(instance, options);
    defer parsed.deinit();
    try insertion.childSafe(instance, .before, html.asSlice(), &parsed);
}

/// afterHTML(html, options): before this's next sibling.
pub fn call_afterHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(dictionaries.SetHTMLOptions)) anyerror!void {
    var parsed = try safeOptions(instance, options);
    defer parsed.deinit();
    try insertion.childSafe(instance, .after, html.asSlice(), &parsed);
}

/// replaceWithHTML(html, options): filter and replace this with HTML.
pub fn call_replaceWithHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(dictionaries.SetHTMLOptions)) anyerror!void {
    var parsed = try safeOptions(instance, options);
    defer parsed.deinit();
    try insertion.childSafe(instance, .replace_with, html.asSlice(), &parsed);
}

/// beforeHTMLUnsafe(html, options): get trusted type compliant input ("Node
/// beforeHTMLUnsafe") first.
pub fn call_beforeHTMLUnsafe(instance: *runtime.Instance, html: typedefs.TrustedHTMLOrDOMString, options: webidl.Opt(typedefs.SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!void {
    try insertion.childUnsafe(instance, .before, @import("dom").trusted_types.inputFrom(html), try unsafeOptions(instance, options), "Node beforeHTMLUnsafe");
}

/// afterHTMLUnsafe(html, options).
pub fn call_afterHTMLUnsafe(instance: *runtime.Instance, html: typedefs.TrustedHTMLOrDOMString, options: webidl.Opt(typedefs.SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!void {
    try insertion.childUnsafe(instance, .after, @import("dom").trusted_types.inputFrom(html), try unsafeOptions(instance, options), "Node afterHTMLUnsafe");
}

/// replaceWithHTMLUnsafe(html, options).
pub fn call_replaceWithHTMLUnsafe(instance: *runtime.Instance, html: typedefs.TrustedHTMLOrDOMString, options: webidl.Opt(typedefs.SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!void {
    try insertion.childUnsafe(instance, .replace_with, @import("dom").trusted_types.inputFrom(html), try unsafeOptions(instance, options), "Node replaceWithHTMLUnsafe");
}

/// HTML 8.5.3 streamBeforeHTML(options).
pub fn call_streamBeforeHTML(instance: *runtime.Instance, options: webidl.Opt(dictionaries.SetHTMLOptions)) anyerror!*runtime.Instance {
    return streaming.childSafe(instance, .before, options.getOrDefault(.{}).sanitizer);
}

/// HTML 8.5.3 streamAfterHTML(options).
pub fn call_streamAfterHTML(instance: *runtime.Instance, options: webidl.Opt(dictionaries.SetHTMLOptions)) anyerror!*runtime.Instance {
    return streaming.childSafe(instance, .after, options.getOrDefault(.{}).sanitizer);
}

/// HTML 8.5.3 streamReplaceWithHTML(options).
pub fn call_streamReplaceWithHTML(instance: *runtime.Instance, options: webidl.Opt(dictionaries.SetHTMLOptions)) anyerror!*runtime.Instance {
    return streaming.childSafe(instance, .replace_with, options.getOrDefault(.{}).sanitizer);
}

/// HTML 8.5.3 streamBeforeHTMLUnsafe(options).
pub fn call_streamBeforeHTMLUnsafe(instance: *runtime.Instance, options: webidl.Opt(typedefs.SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!*runtime.Instance {
    return streaming.childUnsafe(instance, .before, try unsafeOptions(instance, options), "Node streamBeforeHTMLUnsafe");
}

/// HTML 8.5.3 streamAfterHTMLUnsafe(options).
pub fn call_streamAfterHTMLUnsafe(instance: *runtime.Instance, options: webidl.Opt(typedefs.SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!*runtime.Instance {
    return streaming.childUnsafe(instance, .after, try unsafeOptions(instance, options), "Node streamAfterHTMLUnsafe");
}

/// HTML 8.5.3 streamReplaceWithHTMLUnsafe(options).
pub fn call_streamReplaceWithHTMLUnsafe(instance: *runtime.Instance, options: webidl.Opt(typedefs.SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!*runtime.Instance {
    return streaming.childUnsafe(instance, .replace_with, try unsafeOptions(instance, options), "Node streamReplaceWithHTMLUnsafe");
}
