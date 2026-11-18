//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

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

pub const NonDocumentTypeChildNode = struct {
    pub const Meta = struct {
        pub const name = "NonDocumentTypeChildNode";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "previousElementSibling", "get_previousElementSibling", null },
            .{ "nextElementSibling", "get_nextElementSibling", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "beforeHTML", "call_beforeHTML", 1 },
            .{ "afterHTML", "call_afterHTML", 1 },
            .{ "replaceWithHTML", "call_replaceWithHTML", 1 },
            .{ "streamBeforeHTML", "call_streamBeforeHTML", 0 },
            .{ "streamAfterHTML", "call_streamAfterHTML", 0 },
            .{ "streamReplaceWithHTML", "call_streamReplaceWithHTML", 0 },
            .{ "beforeHTMLUnsafe", "call_beforeHTMLUnsafe", 1 },
            .{ "afterHTMLUnsafe", "call_afterHTMLUnsafe", 1 },
            .{ "replaceWithHTMLUnsafe", "call_replaceWithHTMLUnsafe", 1 },
            .{ "streamBeforeHTMLUnsafe", "call_streamBeforeHTMLUnsafe", 0 },
            .{ "streamAfterHTMLUnsafe", "call_streamAfterHTMLUnsafe", 0 },
            .{ "streamReplaceWithHTMLUnsafe", "call_streamReplaceWithHTMLUnsafe", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "beforeHTML",
            "afterHTML",
            "replaceWithHTML",
            "streamBeforeHTML",
            "streamAfterHTML",
            "streamReplaceWithHTML",
            "beforeHTMLUnsafe",
            "afterHTMLUnsafe",
            "replaceWithHTMLUnsafe",
            "streamBeforeHTMLUnsafe",
            "streamAfterHTMLUnsafe",
            "streamReplaceWithHTMLUnsafe",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "previousElementSibling", "get_previousElementSibling", null },
            .{ "nextElementSibling", "get_nextElementSibling", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*NonDocumentTypeChildNodeImpl.InternalState = null,
        },
    );

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
};
