//! Auto-generated mixin: NonDocumentTypeChildNode
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NonDocumentTypeChildNodeImpl = @import("impls").NonDocumentTypeChildNode;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;
const SetHTMLOptions = @import("dictionaries").SetHTMLOptions;
const TrustedHTMLOrDOMString = @import("typedefs").TrustedHTMLOrDOMString;
const SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions = @import("typedefs").SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions;
const WritableStream = @import("interfaces").WritableStream;
const DOMString = @import("typedefs").DOMString;

const impl = @import("impls").NonDocumentTypeChildNode;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "NonDocumentTypeChildNode")) {
        if (comptime @hasDecl(impls.NonDocumentTypeChildNode, "installHooks")) impls.NonDocumentTypeChildNode.installHooks();
    }
}

pub fn get_previousElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try NonDocumentTypeChildNodeImpl.get_previousElementSibling(instance);
}

pub fn get_nextElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try NonDocumentTypeChildNodeImpl.get_nextElementSibling(instance);
}

/// Extended attributes: [CEReactions]
pub fn call_replaceWithHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(SetHTMLOptions)) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    const ce_scope = runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(ce_scope);

    return try NonDocumentTypeChildNodeImpl.call_replaceWithHTML(instance, html, options);
}

/// Extended attributes: [CEReactions]
pub fn call_afterHTMLUnsafe(instance: *runtime.Instance, html: TrustedHTMLOrDOMString, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    const ce_scope = runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(ce_scope);

    return try NonDocumentTypeChildNodeImpl.call_afterHTMLUnsafe(instance, html, options);
}

/// Extended attributes: [NewObject]
pub fn call_streamBeforeHTML(instance: *runtime.Instance, options: webidl.Opt(SetHTMLOptions)) anyerror!*runtime.Instance {
    // [NewObject] - Caller owns the returned object

    return try NonDocumentTypeChildNodeImpl.call_streamBeforeHTML(instance, options);
}

/// Extended attributes: [CEReactions], [NewObject]
pub fn call_streamReplaceWithHTML(instance: *runtime.Instance, options: webidl.Opt(SetHTMLOptions)) anyerror!*runtime.Instance {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    const ce_scope = runtime.CEReactions.begin(instance);
    // [NewObject] - Caller owns the returned object

    const result = NonDocumentTypeChildNodeImpl.call_streamReplaceWithHTML(instance, options) catch |err| {
        runtime.CEReactions.end(ce_scope);
        return err;
    };
    // A result the reactions freed (its realm ended) is not returned.
    const result_generation = runtime.SlabAllocator.generationOf(result);
    runtime.CEReactions.end(ce_scope);
    if (runtime.SlabAllocator.generationOf(result) != result_generation) return error.InvalidStateError;
    return result;
}

/// Extended attributes: [CEReactions]
pub fn call_replaceWithHTMLUnsafe(instance: *runtime.Instance, html: TrustedHTMLOrDOMString, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    const ce_scope = runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(ce_scope);

    return try NonDocumentTypeChildNodeImpl.call_replaceWithHTMLUnsafe(instance, html, options);
}

/// Extended attributes: [CEReactions]
pub fn call_afterHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(SetHTMLOptions)) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    const ce_scope = runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(ce_scope);

    return try NonDocumentTypeChildNodeImpl.call_afterHTML(instance, html, options);
}

/// Extended attributes: [NewObject]
pub fn call_streamAfterHTML(instance: *runtime.Instance, options: webidl.Opt(SetHTMLOptions)) anyerror!*runtime.Instance {
    // [NewObject] - Caller owns the returned object

    return try NonDocumentTypeChildNodeImpl.call_streamAfterHTML(instance, options);
}

/// Extended attributes: [CEReactions]
pub fn call_beforeHTMLUnsafe(instance: *runtime.Instance, html: TrustedHTMLOrDOMString, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    const ce_scope = runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(ce_scope);

    return try NonDocumentTypeChildNodeImpl.call_beforeHTMLUnsafe(instance, html, options);
}

/// Extended attributes: [NewObject]
pub fn call_streamAfterHTMLUnsafe(instance: *runtime.Instance, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!*runtime.Instance {
    // [NewObject] - Caller owns the returned object

    return try NonDocumentTypeChildNodeImpl.call_streamAfterHTMLUnsafe(instance, options);
}

/// Extended attributes: [CEReactions]
pub fn call_beforeHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(SetHTMLOptions)) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    const ce_scope = runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(ce_scope);

    return try NonDocumentTypeChildNodeImpl.call_beforeHTML(instance, html, options);
}

/// Extended attributes: [NewObject]
pub fn call_streamBeforeHTMLUnsafe(instance: *runtime.Instance, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!*runtime.Instance {
    // [NewObject] - Caller owns the returned object

    return try NonDocumentTypeChildNodeImpl.call_streamBeforeHTMLUnsafe(instance, options);
}

/// Extended attributes: [CEReactions], [NewObject]
pub fn call_streamReplaceWithHTMLUnsafe(instance: *runtime.Instance, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!*runtime.Instance {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    const ce_scope = runtime.CEReactions.begin(instance);
    // [NewObject] - Caller owns the returned object

    const result = NonDocumentTypeChildNodeImpl.call_streamReplaceWithHTMLUnsafe(instance, options) catch |err| {
        runtime.CEReactions.end(ce_scope);
        return err;
    };
    // A result the reactions freed (its realm ended) is not returned.
    const result_generation = runtime.SlabAllocator.generationOf(result);
    runtime.CEReactions.end(ce_scope);
    if (runtime.SlabAllocator.generationOf(result) != result_generation) return error.InvalidStateError;
    return result;
}

/// HTML [CEReactions]: the functions that run a custom element reactions
/// bracket - the binding dispatches each in a catch scope, where
/// engine.withPendingExceptionSetAside sets aside what the member leaves
/// pending.
pub const ce_reactions = .{
    "call_replaceWithHTML",
    "call_afterHTMLUnsafe",
    "call_streamReplaceWithHTML",
    "call_replaceWithHTMLUnsafe",
    "call_afterHTML",
    "call_beforeHTMLUnsafe",
    "call_beforeHTML",
    "call_streamReplaceWithHTMLUnsafe",
};
