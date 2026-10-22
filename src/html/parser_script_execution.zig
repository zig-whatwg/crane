//! Parser Script Execution Callback
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#script-processing-model
//! HTML Standard §13.2.6.4.7 "The rules for parsing tokens in HTML content"
//!
//! This module provides the bridge between the HTML tree builder's script execution
//! callback and actual V8 script execution during parsing.
//!
//! When the tree builder encounters a `</script>` end tag, it invokes the registered
//! callback with the script TreeNode. This module converts that TreeNode to a DOM
//! HTMLScriptElement (via the DomAdapter mapping) and executes it via V8.
//!
//! ## Architecture
//!
//! ```
//! TreeBuilder --[callback]--> ParserScriptContext --[via DomAdapter]--> DOM HTMLScriptElement
//!                                                  |
//!                                                  v
//!                                            V8 Script Execution
//! ```

const std = @import("std");

const log = std.log.scoped(.parser_script_execution);
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const parser_mutation = @import("parser_dom_mutation.zig");
const interfaces = @import("interfaces");
const infra = @import("infra");

// HTML parser types
const html_core = @import("html_core");
const TreeBuilder = html_core.parser.TreeBuilder;
const TreeNode = html_core.parser.TreeNode;
const Tokenizer = html_core.parser.Tokenizer;
const Namespace = html_core.parser.Namespace;

// Script execution
const script_execution = @import("script_execution.zig");

// DOM internals for document_element setting
const dom = @import("dom");
const node_document = @import("dom").node_document;
const document_internals = dom.document_internals;

/// Script loader function type for external scripts.
/// Takes a context pointer and URL, returns script content or null on failure.
pub const ScriptLoaderFn = *const fn (?*anyopaque, []const u8) ?[]const u8;

/// Context for parser script execution callback.
///
/// This struct holds all state needed to execute scripts during parsing.
/// It is passed as the context pointer to the tree builder's script execution callback.
pub const ParserScriptContext = struct {
    /// Memory allocator for script-related allocations.
    allocator: Allocator,

    /// Runtime context for DOM instances.
    ctx: runtime.Context,

    /// The document being parsed.
    document: *runtime.Instance,

    /// Checkpoint callbacks may destroy or replace the parser's document.
    document_generation: u64 = 0,
    had_engine: bool = false,

    /// The adapter whose generation-checked mapping (on each TreeNode) names
    /// the DOM element for a tree node.
    adapter: *const DomTreeAdapter,

    /// Reference to the tree builder for insertion point management.
    tree_builder: *TreeBuilder,

    /// Whether scripting is enabled for this document.
    scripting_enabled: bool,

    /// Base URL for resolving relative script URLs.
    base_url: []const u8 = "",

    /// Optional script loader for external scripts.
    script_loader_fn: ?ScriptLoaderFn = null,
    script_loader_ctx: ?*anyopaque = null,

    /// An owned parser driver can suspend and resume a blocking fetch.
    can_suspend: bool = false,

    /// Create a new parser script context.
    pub fn init(
        allocator: Allocator,
        ctx: runtime.Context,
        document: *runtime.Instance,
        adapter: *const DomTreeAdapter,
        tree_builder: *TreeBuilder,
        scripting_enabled: bool,
    ) ParserScriptContext {
        return .{
            .allocator = allocator,
            .ctx = ctx,
            .document = document,
            .document_generation = runtime.SlabAllocator.generationOf(document),
            .had_engine = ctx.hasEngine(),
            .adapter = adapter,
            .tree_builder = tree_builder,
            .scripting_enabled = scripting_enabled,
        };
    }

    /// Set the base URL for resolving relative script URLs.
    pub fn setBaseUrl(self: *ParserScriptContext, base_url: []const u8) void {
        self.base_url = base_url;
    }

    /// Set the script loader for external scripts.
    pub fn setScriptLoader(self: *ParserScriptContext, loader_fn: ScriptLoaderFn, loader_ctx: ?*anyopaque) void {
        self.script_loader_fn = loader_fn;
        self.script_loader_ctx = loader_ctx;
    }

    /// Get the DOM element for a TreeNode (if it has been converted).
    pub fn getDomElement(self: *const ParserScriptContext, tree_node: *TreeNode) ?*runtime.Instance {
        return self.adapter.getDomNode(tree_node);
    }
};

fn parserContextIsCurrent(ctx: *const ParserScriptContext) bool {
    if (ctx.had_engine and !ctx.ctx.hasEngine()) return false;
    if (runtime.SlabAllocator.generationOf(ctx.document) != ctx.document_generation) return false;
    const stream = ctx.tree_builder.input_stream_manager orelse return false;
    if (stream.aborted) return false;
    const internal = document_internals.getInternal(ctx.document) orelse return false;
    // A retained inactive document can receive a new script-created parser
    // (HTML open step 16). Destruction aborts the old stream and removes its
    // association; the document's activity flag does not invalidate a new one.
    return internal.input_stream_manager == stream;
}

/// HTML "text" script end-tag checkpoint, before pop or prepare. Crane has
/// no speculative parser. Check the agent's actual execution context stack,
/// since document.write can parse while script is running in another realm.
///
/// Design: WebKit HTMLScriptRunner::runScript checkpoints before preparation
/// and retains its document across callbacks:
/// https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/parser/HTMLScriptRunner.cpp
pub fn parserScriptEndCheckpoint(context: ?*anyopaque) bool {
    const ctx: *ParserScriptContext = @ptrCast(@alignCast(context orelse return true));
    if (!parserContextIsCurrent(ctx)) return false;
    const agent = ctx.ctx.agent orelse return true;
    if (!ctx.ctx.hasEngine() or engine.hasRunningScript(agent)) return true;
    const pin = engine.retainValue(ctx.ctx, .{ .instance = ctx.document }) catch return false;
    defer pin.release();
    engine.performMicrotaskCheckpoint(agent) catch {};
    // Mutation observers can open the document or remove its frame. An old
    // tree's mappings must not be used after either change.
    return parserContextIsCurrent(ctx);
}

/// The tree builder's script callback: what the parser does at a script's
/// end tag, between the steps that raise and lower its script nesting level.
///
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#scriptEndTag
/// "An end tag whose tag name is "script"": ... "prepare the script element".
/// ... "At this stage, if the pending parsing-blocking script is not null,
/// then: if the script nesting level is not zero, set the parser pause flag to
/// true, and abort the processing of any nested invocations of the tokenizer;
/// otherwise run the pending parsing-blocking script" - see
/// `runPendingParsingBlockingScripts`.
/// And, for an SVG script (the "in foreign content" end tag): "process the SVG
/// script element".
pub fn parserScriptCallback(script_tree_node: *TreeNode, context: ?*anyopaque) void {
    const ctx: *ParserScriptContext = @ptrCast(@alignCast(context orelse return));
    if (!ctx.scripting_enabled) return;

    const script_element = ctx.getDomElement(script_tree_node) orelse return;

    // Trusted Types 4.1.2.6: "Set script's script text value to its child
    // text content" - before preparing it, for an HTML script and (as the
    // spec asks of implementations) an SVG one.
    dom.script_elements.setScriptTextToChildTextContent(ctx.allocator, script_element) catch {};

    if (isSvgScript(script_tree_node)) {
        script_execution.processSvgScriptElement(ctx.allocator, script_element);
        return;
    }

    // The embedder's loader, when it has one, is what "prepare the script
    // element" fetches a parser-inserted classic script's src with (the WPT
    // runner has one, to keep testharness.js from loading twice) - at its
    // fetch step, so only a script it would fetch anyway is loaded. What the
    // loader returns is used as-is, EMPTY included (an empty script still
    // runs and fires load); null is a network error, which executing the
    // element turns into the error event.
    const loader: ?script_execution.ParserScriptLoader = if (ctx.script_loader_fn != null or ctx.can_suspend) .{
        .context = ctx,
        .load = &loadForPrepare,
        .allocator = ctx.allocator,
        .can_suspend = ctx.can_suspend,
    } else null;
    _ = script_execution.prepareScriptElementWithLoader(ctx.allocator, script_element, loader) catch {};

    runPendingParsingBlockingScripts(ctx);
}

/// `ParserScriptLoader.load` for a ParserScriptContext: its embedder's
/// loader. Null - the loader has no answer - leaves the fetch to "fetch a
/// classic script", which builds the request the spec's way.
fn loadForPrepare(context: ?*anyopaque, src: []const u8) ?[]const u8 {
    const ctx: *ParserScriptContext = @ptrCast(@alignCast(context orelse return null));
    const loader_fn = ctx.script_loader_fn orelse return null;
    return loader_fn(ctx.script_loader_ctx, src);
}

/// The script end-tag steps' pending parsing-blocking script handling.
///
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#scriptEndTag
/// "If the script nesting level is not zero: Set the parser pause flag to
///  true, and abort the processing of any nested invocations of the tokenizer,
///  yielding control back to the caller." - a script document.write()
///  inserted waits for the script that wrote it to finish. "Otherwise: While
///  the pending parsing-blocking script is not null: ... Let the insertion
///  point be just before the next input character. Increment the parser's
///  script nesting level by one. ... Execute the script element the script.
///  Decrement the parser's script nesting level by one. If the parser's script
///  nesting level is zero (which it always should be at this point), then set
///  the parser pause flag to false. Let the insertion point be undefined
///  again."
///
/// This runs inside the end-tag steps, before they lower the nesting level
/// they raised - so the spec's "not zero" is more than one here, and the level
/// the loop sets (one) is the one already in effect. The insertion point is
/// set again for each script: the pending script may be one a nested write
/// inserted, whose end tag the tokenizer has passed, and the characters
/// written after it wait just after the tokenizer - where the script's own
/// document.write() must insert (document-write/script_013). The end-tag
/// steps restore the old insertion point after this returns.
fn runPendingParsingBlockingScripts(ctx: *ParserScriptContext) void {
    if (!parserContextIsCurrent(ctx)) return;
    if (script_execution.pendingParsingBlockingScript(ctx.document) == null) {
        ctx.tree_builder.waiting_for_parser_blocking_script = false;
        return;
    }
    ctx.tree_builder.waiting_for_parser_blocking_script = true;
    if (ctx.tree_builder.script_nesting_level > 1) {
        ctx.tree_builder.parser_pause_flag = true;
        return;
    }
    while (true) {
        if (!script_execution.pendingParserBlockingScriptReady(ctx.document)) break;
        if (ctx.tree_builder.input_stream_manager) |stream| stream.setInsertionPointAtNextInputCharacter();
        // The response ended the pause BEFORE executing the script, so its
        // own document.write can invoke the tokenizer at the insertion point.
        ctx.tree_builder.waiting_for_parser_blocking_script = false;
        ctx.tree_builder.parser_pause_flag = false;
        const executed = script_execution.executePendingParserBlockingScript(ctx.allocator, ctx.document);
        // A resumed script can open its document, stop navigation, or remove
        // its frame. Never consult the old document again after cancellation.
        if (!parserContextIsCurrent(ctx)) return;
        if (!executed) break;
        ctx.tree_builder.parser_pause_flag = false;
    }
    ctx.tree_builder.waiting_for_parser_blocking_script = script_execution.pendingParsingBlockingScript(ctx.document) != null;
    if (ctx.tree_builder.waiting_for_parser_blocking_script)
        ctx.tree_builder.parser_pause_flag = true;
}

/// Resume the script end-tag loop after an asynchronous parser-blocking
/// response arrives. The owning parser calls this before reading more input.
/// The insertion point and script nesting level are scoped across execution,
/// including nested document.write calls and abrupt script completion.
pub fn resumeAfterBlockingScript(ctx: *ParserScriptContext) void {
    if (!parserContextIsCurrent(ctx)) return;
    if (script_execution.pendingParsingBlockingScript(ctx.document) == null) return;
    if (ctx.tree_builder.script_nesting_level != 0) return;
    const stream = ctx.tree_builder.input_stream_manager;
    if (stream) |input| input.pushInsertionPoint();
    defer if (stream) |input| input.popInsertionPoint();
    ctx.tree_builder.script_nesting_level += 1;
    defer ctx.tree_builder.script_nesting_level -= 1;
    runPendingParsingBlockingScripts(ctx);
}

// =============================================================================
// Attributes from the parser
// =============================================================================

/// "Create an element for the token" step: "Append each attribute in the
/// given token to element" - DOM "append an attribute", with the namespace
/// and prefix "adjust foreign attributes" gave it, and no validation: an
/// attribute name the tokenizer produced is one the element holds, whether or
/// not setAttribute() would accept it (`<div a"b>`), and an `xlink:href` on
/// SVG is the attribute `href` in the XLink namespace, which setAttribute()
/// could not make.
///
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#create-an-element-for-the-token
/// Record where an HTML script element the parser just created starts in
/// `document`: the parser's position after its start tag (Blink's
/// HTMLTreeBuilder script start position). Read when the parser prepares
/// it, for its errors' lines and its CSP violation's location.
pub fn recordStartPosition(element: *runtime.Instance, document: *runtime.Instance) void {
    const state = @import("script_element.zig").of(element) orelse return;
    state.start = @import("script_element.zig").parserPosition(document);
}

/// Where a `<style>` the parser just created starts in `document` - the
/// parser's position after its start tag - for its CSP violation; null for
/// a link, or when no parser position is known.
pub fn styleStart(local_name: []const u8, document: *runtime.Instance) ?dom.style_sheet_owners.Position {
    if (!std.mem.eql(u8, local_name, "style")) return null;
    const at = @import("script_element.zig").parserPosition(document) orelse return null;
    return .{ .line = at.line, .column = at.column };
}

pub fn appendParsedAttribute(element: *runtime.Instance, attr: html_core.parser.TreeNode.Attribute) void {
    dom.element_attributes.append(element, .{
        .namespace = if (attr.namespace) |ns| ns.uri() else null,
        .prefix = attr.prefix,
        .local_name = attr.name,
        .value = attr.value,
    }) catch |err| log.debug("parser attribute {s} not appended: {}", .{ attr.name, err });
}

/// The SVG script end-tag step's "process the SVG script element", or the
/// HTML script callback: which one `tree_node` is.
pub fn isSvgScript(tree_node: *const TreeNode) bool {
    return tree_node.namespace == .svg and tree_node.hasTagName("script");
}

// =============================================================================
// Static Callback Wrappers for Tree Builder Integration
// =============================================================================

/// Static callback wrapper for onNodeCreated.
/// This is passed to tree_builder.setDomAdapterCallbacks().
pub fn domAdapterOnNodeCreated(tree_node: *TreeNode, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    adapter.onNodeCreated(tree_node) catch {};
}

/// Static callback wrapper for onChildAppended.
/// This is passed to tree_builder.setDomAdapterCallbacks().
pub fn domAdapterOnChildAppended(parent: *TreeNode, child: *TreeNode, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    adapter.onChildAppended(parent, child) catch {};
}

pub fn domAdapterOnInserted(location: TreeBuilder.InsertionLocation, child: *TreeNode, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    // The element the tree builder pushes next is "on the stack" while its
    // insertion steps run (DocumentParser.isOnStackOfOpenElements).
    const outer = adapter.inserting;
    adapter.inserting = if (child.node_type == .element) child else null;
    defer adapter.inserting = outer;
    const inserted = parser_mutation.insert(adapter, location, child) catch false;
    if (inserted) adapter.removeOrphan(child) else adapter.keepFailedInsertion(child);
    adapter.endPendingHold(child);
}

pub fn domAdapterOnRemoved(node: *TreeNode, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    const instance = adapter.getDomNode(node) orelse return;
    parser_mutation.remove(instance) catch return;
    if (adapter.getDomNode(node) == null) return;
    if (!engine.hasWrapper(instance)) adapter.addOrphan(node) catch {};
}

pub fn domAdapterOnChildrenMoved(source: *TreeNode, destination: *TreeNode, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    parser_mutation.moveChildren(adapter, source, destination) catch {};
}

/// The tree builder's "insert a character" step 4 for the live parser: the
/// LIVE DOM's previous sibling of the adjusted insertion location `location`
/// (parser_dom_mutation.resolve: the fostered table's live parent, template
/// contents). Reads node fields only - no wrapper, no copy. Passed to
/// tree_builder.setDomAdapterTextBeforeCallback().
pub fn domAdapterTextBefore(location: TreeBuilder.InsertionLocation, context: ?*anyopaque) html_core.parser.LiveTextBefore {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return .unknown));
    const target = parser_mutation.resolve(adapter, location) catch return .unknown;
    const parent = dom.instance_bridge.getNodeBase(target.parent) orelse return .unknown;
    const previous_sibling = if (target.before) |before| blk: {
        const reference = dom.instance_bridge.getNodeBase(before) orelse return .unknown;
        // Script moved the reference child elsewhere: the insertion itself
        // will not take place there (parser_mutation.insert drops it).
        if (reference.parent_node != parent) return .unknown;
        break :blk reference.previous_sibling;
    } else parent.last_child;
    const previous = previous_sibling orelse return .none;
    // Step 5: "If previousSibling is a Text node" - a CDATASection is one too.
    if (previous.node_type != interfaces.Node.get_TEXT_NODE() and previous.node_type != interfaces.Node.get_CDATA_SECTION_NODE()) return .none;
    const instance = dom.instance_bridge.getInstanceTyped(runtime.Instance, previous) orelse return .unknown;
    const data = dom.character_data.dataOf(instance) orelse return .unknown;
    return .{ .text = .{ .node = instance, .generation = runtime.SlabAllocator.generationOf(instance), .data = data } };
}

/// The tree builder's "Keep" steps 2.1-2.3 for a `<template for>` and HTML
/// "prepare content patching" steps 4-14, against the LIVE DOM: scope is the
/// live target parent of the adjusted insertion location (the body element's
/// parent for the body), the markers are its live descendants', and the
/// nodes between them are removed with DOM "remove" - which can run script
/// (an iframe's pagehide), so the nodes are collected first and each is
/// generation-checked before its removal. Passed to
/// tree_builder.setDomAdapterContentPatchingCallbacks().
pub fn domAdapterPrepareContentPatching(patch: *html_core.parser.ContentPatch, location: TreeBuilder.InsertionLocation, marker_name: []const u8, context: ?*anyopaque) bool {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return false));
    if (!adapter.isAlive()) return false;
    // Step 2.1.
    var scope = (parser_mutation.resolve(adapter, location) catch return false).parent;
    // Step 2.2: "If scope is the body element of its node document, then set
    // scope to its parent" - patching head from a template in body.
    if (isTheBodyElement(scope)) scope = (interfaces.Node.get_parentNode(scope) catch return false) orelse return false;
    // Steps 4-5.
    const markers = findMarkers(adapter.allocator, scope, marker_name) catch return false;
    const start = markers.start orelse return false;
    const start_base = dom.instance_bridge.getNodeBase(start) orelse return false;
    const target_base = start_base.parent_node orelse return false;
    const target = dom.instance_bridge.getInstanceTyped(runtime.Instance, target_base) orelse return false;
    // Steps 6-8.
    patch.target = target;
    patch.target_generation = runtime.SlabAllocator.generationOf(target);
    patch.start = start;
    patch.start_generation = runtime.SlabAllocator.generationOf(start);
    if (markers.end) |end| {
        patch.end = end;
        patch.end_generation = runtime.SlabAllocator.generationOf(end);
    }
    // Step 9.
    if (markers.end == start) return true;
    // Steps 10-12: removedNodes, start's following siblings up to end.
    var removed: std.ArrayListUnmanaged(struct { node: *runtime.Instance, generation: u64 }) = .empty;
    defer removed.deinit(adapter.allocator);
    var current = start_base.next_sibling;
    while (current) |base| : (current = base.next_sibling) {
        const node = dom.instance_bridge.getInstanceTyped(runtime.Instance, base) orelse continue;
        if (markers.end == node) break;
        removed.append(adapter.allocator, .{ .node = node, .generation = runtime.SlabAllocator.generationOf(node) }) catch return true;
    }
    // Step 13: "If node's parent is not null, then remove node" - whatever
    // parent an event handler gave it meanwhile.
    for (removed.items) |entry| {
        if (!adapter.isAlive()) break;
        if (runtime.SlabAllocator.generationOf(entry.node) != entry.generation) continue;
        parser_mutation.remove(entry.node) catch continue;
    }
    // Step 14.
    return true;
}

/// The template end tag's step 4 against the live DOM: remove the start
/// marker, then the end marker, each if it still has a parent. Passed to
/// tree_builder.setDomAdapterContentPatchingCallbacks().
pub fn domAdapterFinishContentPatching(patch: *html_core.parser.ContentPatch, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    // Steps 4.4-4.5.
    const end_generation = patch.end_generation;
    const end = patch.end;
    if (parser_mutation.liveNode(patch.start, patch.start_generation)) |start| if (adapter.isAlive())
        parser_mutation.remove(start) catch {};
    if (parser_mutation.liveNode(end, end_generation)) |marker| if (adapter.isAlive())
        parser_mutation.remove(marker) catch {};
}

const Markers = struct { start: ?*runtime.Instance = null, end: ?*runtime.Instance = null };

/// HTML "find markers" given `scope` and `name` over the live DOM: scope's
/// descendants in tree order (not template contents or shadow trees, which
/// are no descendants).
fn findMarkers(allocator: Allocator, scope: *runtime.Instance, name: []const u8) !Markers {
    const scope_base = dom.instance_bridge.getNodeBase(scope) orelse return .{};
    var node = scope_base.first_child;
    while (node) |descendant| : (node = nextDescendant(descendant, scope_base)) {
        // Step 1.1.
        if (descendant.node_type != interfaces.Node.get_PROCESSING_INSTRUCTION_NODE()) continue;
        const instance = dom.instance_bridge.getInstanceTyped(runtime.Instance, descendant) orelse continue;
        const target = processingInstructionTarget(allocator, instance) orelse continue;
        defer allocator.free(target);
        const marker = std.mem.eql(u8, target, "marker");
        if (!marker and !std.mem.eql(u8, target, "start")) continue;
        // Step 1.2.
        if (!try piNameIs(allocator, instance, name)) continue;
        // Step 1.3.
        if (marker) return .{ .start = instance, .end = instance };
        // Step 1.4.
        var nesting: usize = 0;
        var sibling = descendant.next_sibling;
        while (sibling) |candidate| : (sibling = candidate.next_sibling) {
            if (candidate.node_type != interfaces.Node.get_PROCESSING_INSTRUCTION_NODE()) continue;
            const candidate_instance = dom.instance_bridge.getInstanceTyped(runtime.Instance, candidate) orelse continue;
            const candidate_target = processingInstructionTarget(allocator, candidate_instance) orelse continue;
            defer allocator.free(candidate_target);
            if (std.mem.eql(u8, candidate_target, "start")) nesting += 1;
            if (std.mem.eql(u8, candidate_target, "end")) {
                if (nesting == 0) return .{ .start = instance, .end = candidate_instance };
                nesting -= 1;
            }
        }
        return .{ .start = instance };
    }
    // Step 2.
    return .{};
}

/// A processing instruction's target, as a copy the caller frees.
fn processingInstructionTarget(allocator: Allocator, pi: *runtime.Instance) ?[]u8 {
    var target = interfaces.ProcessingInstruction.get_target(pi) catch return null;
    defer target.deinit(pi.ctx.allocator);
    return allocator.dupe(u8, target.asSlice()) catch null;
}

/// DOM "get a processing instruction attribute" given `pi` and "name" is
/// `name`, from the pseudo-attributes of its current data (DOM 4.13 "update
/// attributes from data"; a parse error is an empty attribute map).
fn piNameIs(allocator: Allocator, pi: *runtime.Instance, name: []const u8) !bool {
    var attributes = dom.pi_attributes.Attributes.init(allocator);
    defer attributes.deinit();
    attributes.parse(dom.character_data.dataOf(pi) orelse "") catch |err| switch (err) {
        error.InvalidPseudoAttributes => return false,
        error.OutOfMemory => return error.OutOfMemory,
    };
    const value = attributes.get("name") orelse return false;
    return std.mem.eql(u8, value, name);
}

/// The node after `node` in tree order within `scope`.
fn nextDescendant(node: *dom.NodeBase, scope: *dom.NodeBase) ?*dom.NodeBase {
    if (node.first_child) |child| return child;
    var current = node;
    while (current != scope) {
        if (current.next_sibling) |sibling| return sibling;
        current = current.parent_node orelse return null;
    }
    return null;
}

/// Whether `node` is the body element of its node document.
fn isTheBodyElement(node: *runtime.Instance) bool {
    const document = (interfaces.Node.get_ownerDocument(node) catch return false) orelse return false;
    const body = (interfaces.Document.get_body(document) catch return false) orelse return false;
    return body == node;
}

/// Static callback wrapper for onTextContentChanged.
/// This is passed to tree_builder.setDomAdapterCallbacks().
pub fn domAdapterOnTextContentChanged(tree_node: *TreeNode, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    adapter.onTextContentChanged(tree_node) catch {};
}

/// Static callback wrapper for an attribute added to an element the adapter
/// already made. Passed to tree_builder.setDomAdapterAttributeCallback().
pub fn domAdapterOnAttributeAdded(tree_node: *TreeNode, attr: *const TreeNode.Attribute, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    const element = adapter.getDomNode(tree_node) orelse return;
    appendParsedAttribute(element, attr.*);
}

/// Static callback wrapper for the document mode the parser set: the Document
/// takes it. Passed to tree_builder.setDomAdapterModeCallback().
pub fn domAdapterOnModeSet(mode: html_core.parser.QuirksMode, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    if (!adapter.isAlive()) return;
    document_internals.setMode(adapter.document, documentMode(mode)) catch {};
}

/// Static callback wrapper for an element the "text" insertion mode popped:
/// a style element's style block updates now ("The element is popped off
/// the stack of open elements of an HTML parser"). Passed to
/// tree_builder.setDomAdapterPoppedCallback().
pub fn domAdapterOnElementPopped(tree_node: *TreeNode, context: ?*anyopaque) void {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    if (!tree_node.hasTagName("style")) return;
    const element = adapter.getDomNode(tree_node) orelse return;
    dom.style_sheet_owners.poppedByParser(element);
}

/// Static callback wrapper for an element the tree builder removed from its
/// stack of open elements, however it left it: an element type with steps in
/// dom.finish_parsing_children hears that the element's children are parsed.
/// Passed to tree_builder.setDomAdapterFinishedCallback().
pub fn domAdapterOnChildrenFinished(tree_node: *TreeNode, context: ?*anyopaque) void {
    if (tree_node.node_type != .element) return;
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
    // HTML 13.2.4.3: "When the current node is removed from the stack of
    // open elements, process internal resource links given the current
    // node's node document" - for an element of any namespace, which an
    // expect link can indicate by its ID. Nothing to do, at the cost of one
    // check, while no expect link blocks the parser's document.
    if (dom.document_rendering.hasExpectLinks(adapter.document)) {
        if (adapter.getDomNode(tree_node)) |element| {
            if (interfaces.Node.get_ownerDocument(element) catch null) |document| {
                dom.document_rendering.processInternalResourceLinks(document, element);
            }
        }
    }
    if (tree_node.namespace != .html) return;
    const local_name = tree_node.local_name orelse return;
    if (!dom.finish_parsing_children.hasSteps(local_name)) return;
    const element = adapter.getDomNode(tree_node) orelse return;
    dom.finish_parsing_children.finishedParsingChildren(element, local_name);
}

/// The tree builder's declarative shadow root step for the live parser
/// ("in head", a start tag whose tag name is "template", steps 7.10-7.11):
/// attach a shadow root to the request's host, mark it declarative, and
/// record it, so the template's contents insert into it. False - the template
/// is inserted as an ordinary one - when the host is already a shadow host
/// (7.10) or attaching threw (7.11.2). The attach draws the same host and
/// shadow root edges attachShadow does, so it wraps the host and the root:
/// two wrappers per declarative host, none for a page without one.
/// Passed to tree_builder.setDomAdapterDeclarativeShadowCallback().
pub fn domAdapterAttachDeclarativeShadow(request: *html_core.parser.DeclarativeShadow, context: ?*anyopaque) bool {
    const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return false));
    const host = adapter.getDomNode(request.host) orelse return false;
    // Step 7.10: "If declarativeShadowHostElement is a shadow host".
    if (dom.shadow_hosts.rootForHost(host) != null) return false;
    // Step 7.11.1: "Let registry be null if templateStartTag has a
    // shadowrootcustomelementregistry attribute; otherwise
    // declarativeShadowHostElement's node document's custom element
    // registry."
    const registry: ?*runtime.Instance = if (request.keep_registry_null) null else blk: {
        const document = (interfaces.Node.get_ownerDocument(host) catch return false) orelse return false;
        break :blk interfaces.Document.get_customElementRegistry(document) catch return false;
    };
    // Steps 7.11.2-7.11.7.
    const shadow = dom.declarative_shadow.attach(host, declarativeRequest(request.*), registry) catch return false;
    request.shadow_root = shadow;
    request.shadow_generation = runtime.SlabAllocator.generationOf(shadow);
    return true;
}

/// The DOM request for a tree builder's declarative shadow root.
pub fn declarativeRequest(request: html_core.parser.DeclarativeShadow) dom.declarative_shadow.Request {
    return .{
        .mode = switch (request.mode) {
            .open => ._open_,
            .closed => ._closed_,
        },
        .delegates_focus = request.delegates_focus,
        .serializable = request.serializable,
        .slot_assignment = switch (request.slot_assignment) {
            .named => ._named_,
            .manual => ._manual_,
        },
        .clonable = request.clonable,
        .keep_registry_null = request.keep_registry_null,
    };
}

/// The DOM document mode for the parser's.
pub fn documentMode(mode: html_core.parser.QuirksMode) document_internals.Mode {
    return switch (mode) {
        .no_quirks => .no_quirks,
        .quirks => .quirks,
        .limited_quirks => .limited_quirks,
    };
}

// =============================================================================
// DomTreeAdapter Integration
// =============================================================================

/// DomTreeAdapter provides incremental TreeNode to DOM conversion during parsing.
///
/// This adapter is called by the tree builder as nodes are created and modified,
/// allowing scripts to access DOM elements that have already been parsed.
pub const DomTreeAdapter = struct {
    /// An element created wrapped - a custom element or a customized
    /// built-in, constructed synchronously - held from its creation until its
    /// first insertion attempt ends (design 5.4, H2).
    pub const PendingHold = struct {
        tree_node: *TreeNode,
        owned: engine.Owned,
    };

    /// The owning parser's rescue (design 5.3, trigger 2), for an element
    /// whose insertion failed: it is parentless, or in a tree its Document
    /// does not keep, and may be or become held.
    pub const Rescuer = struct {
        context: ?*anyopaque,
        rescue: *const fn (?*anyopaque, *runtime.Instance) void,
    };

    /// What a node's creation can have done before the adapter asks whether
    /// it has a wrapper.
    pub const Creation = enum {
        /// A custom element definition matched the element's token (HTML
        /// "create an element for a token": "will execute script"): its
        /// constructor, and the reactions to its attributes, ran script that
        /// can have wrapped it.
        may_have_run_script,
        /// No definition matched, or the node is a text, comment or doctype
        /// node: no script ran between the creation and the check.
        ran_no_script,
    };

    /// Whether the adapter must ask the engine if a node it just made has a
    /// wrapper. An ownership predicate, so an allowlist whose default is the
    /// safe answer (AGENTS.md "Memory"): only a creation KNOWN to have run no
    /// script is skipped - nothing can have made a wrapper for a node no
    /// script has seen - and an unknown creation is asked.
    pub fn mustCheckWrapper(creation: ?Creation) bool {
        const known = creation orelse return true;
        return switch (known) {
            .ran_no_script => false,
            .may_have_run_script => true,
        };
    }

    pub const Orphan = struct {
        node: *runtime.Instance,
        generation: u64,
        tree_node: *TreeNode,
    };

    allocator: Allocator,
    ctx: runtime.Context,
    document: *runtime.Instance,

    /// The DOM nodes this adapter made, or the parser removed, that are
    /// unwrapped and no insertion has taken: a successful insertion transfers
    /// ownership to the DOM tree, and at teardown only live, unwrapped
    /// orphans are ours to destroy (wrapped ones belong to the engine's
    /// collector). Each entry's tree node records its index
    /// (TreeNode.dom_orphan_index) for O(1) removal; teardown reads only the
    /// entries, never a tree node, which may already be freed. The mapping
    /// itself lives on each TreeNode (design 7.3): one copy, generation-
    /// checked on every read.
    orphans: std.ArrayListUnmanaged(Orphan) = .empty,
    /// No hold per node: the parser's own structures are its holds. Only an
    /// element wrapped at its creation is held, until its first insertion
    /// attempt (usually empty).
    pending: std.ArrayListUnmanaged(PendingHold) = .empty,
    rescuer: ?Rescuer = null,
    /// What the node being created can have done (`mustCheckWrapper`); set by
    /// the create step, consumed by onNodeCreated.
    last_creation: ?Creation = null,
    document_generation: u64,
    had_engine: bool,

    /// The element the tree builder is inserting (`domAdapterOnInserted`),
    /// which it pushes onto its stack of open elements next; null outside
    /// an insertion.
    inserting: ?*TreeNode = null,

    /// The tree builder tells this adapter when an element leaves its stack
    /// of open elements (`domAdapterOnChildrenFinished`, wired by the
    /// scripted parser): only then may an element type hear that the parser
    /// created one of its elements, since only then will it hear that the
    /// parser is done with it (dom.finish_parsing_children).
    notifies_children_finished: bool = false,

    pub fn init(
        allocator: Allocator,
        ctx: runtime.Context,
        document: *runtime.Instance,
    ) DomTreeAdapter {
        return .{
            .allocator = allocator,
            .ctx = ctx,
            .document = document,
            .document_generation = runtime.SlabAllocator.generationOf(document),
            .had_engine = ctx.hasEngine(),
        };
    }

    pub fn deinit(self: *DomTreeAdapter) void {
        // A realm can be torn down by script while parsing. Check the slab
        // generation before dereferencing any saved pointer, including orphans.
        // Release the parser's roots only after finishing native cleanup.
        for (self.orphans.items) |orphan| {
            const dom_node = orphan.node;
            if (runtime.SlabAllocator.generationOf(dom_node) != orphan.generation) continue;

            // The document is created and freed by the caller, never by us.
            if (dom_node == self.document or engine.hasWrapper(dom_node)) continue;

            // Belt: a node that somehow acquired a parent without going through
            // onChildAppended is attached, whatever the list says.
            const parent = interfaces.Node.get_parentNode(dom_node) catch null;
            if (parent == null) dom.node_creation.destroyUninserted(dom_node);
        }
        self.orphans.deinit(self.allocator);
        for (self.pending.items) |held| held.owned.release();
        self.pending.deinit(self.allocator);
    }

    /// The tree builder's document node names this adapter's Document.
    pub fn mapDocument(self: *DomTreeAdapter, tree_node: *TreeNode) void {
        tree_node.dom_node = self.document;
        tree_node.dom_generation = runtime.SlabAllocator.generationOf(self.document);
        tree_node.dom_revoked = false;
    }

    /// `tree_node`'s DOM node is the adapter's to free unless an insertion
    /// takes it.
    pub fn addOrphan(self: *DomTreeAdapter, tree_node: *TreeNode) Allocator.Error!void {
        if (tree_node.dom_orphan_index != TreeNode.not_an_orphan) return;
        const node: *runtime.Instance = @ptrCast(@alignCast(tree_node.dom_node orelse return));
        const index: u32 = @intCast(self.orphans.items.len);
        try self.orphans.append(self.allocator, .{ .node = node, .generation = tree_node.dom_generation, .tree_node = tree_node });
        tree_node.dom_orphan_index = index;
    }

    /// An insertion took `tree_node`'s DOM node (or a wrapper owns it now).
    pub fn removeOrphan(self: *DomTreeAdapter, tree_node: *TreeNode) void {
        const index = tree_node.dom_orphan_index;
        if (index == TreeNode.not_an_orphan) return;
        tree_node.dom_orphan_index = TreeNode.not_an_orphan;
        const last = self.orphans.pop() orelse return;
        if (index < self.orphans.items.len) {
            self.orphans.items[index] = last;
            last.tree_node.dom_orphan_index = index;
        }
    }

    /// Called when a new node is created during parsing.
    /// Creates the corresponding DOM node and adds it to the map.
    pub fn onNodeCreated(self: *DomTreeAdapter, tree_node: *TreeNode) !void {
        if (!self.isAlive()) return error.InvalidStateError;
        self.last_creation = null;
        const dom_node = try self.createDomNode(tree_node);
        const creation = self.last_creation;
        self.last_creation = null;
        // A tree node is mapped once; should it be made again, an unwrapped
        // orphan of the first creation is still the adapter's to free.
        if (tree_node.dom_orphan_index != TreeNode.not_an_orphan) {
            self.removeOrphan(tree_node);
            if (tree_node.dom_node) |previous_opaque| {
                const previous: *runtime.Instance = @ptrCast(@alignCast(previous_opaque));
                if (previous != dom_node and runtime.SlabAllocator.generationOf(previous) == tree_node.dom_generation and
                    !engine.hasWrapper(previous) and (interfaces.Node.get_parentNode(previous) catch null) == null)
                    dom.node_creation.destroyUninserted(previous);
            }
        }
        tree_node.dom_node = dom_node;
        tree_node.dom_generation = runtime.SlabAllocator.generationOf(dom_node);
        tree_node.dom_revoked = false;
        // Wrapped nodes belong to engine cleanup (a pending hold, a rescue,
        // or script that wrapped them); an unwrapped one is the adapter's
        // until an insertion takes it.
        if (dom_node != self.document and !(mustCheckWrapper(creation) and engine.hasWrapper(dom_node)))
            try self.addOrphan(tree_node);
    }

    /// Called when a child is appended to a parent during parsing.
    /// Updates the DOM tree structure.
    /// When appending <html> to document, also sets document.documentElement.
    pub fn onChildAppended(self: *DomTreeAdapter, parent: *TreeNode, child: *TreeNode) !void {
        const child_dom = self.getDomNode(child) orelse return;

        // Hand the child over to V8 only if it really was attached: a failed
        // append leaves it orphaned and still ours to free.
        const inserted = parser_mutation.insert(self, .{ .parent = parent, .before = child.next_sibling, .move = true }, child) catch |err| {
            self.keepFailedInsertion(child);
            self.endPendingHold(child);
            return err;
        };
        if (!inserted) self.keepFailedInsertion(child);
        self.endPendingHold(child);
        if (inserted) self.removeOrphan(child) else return;
        if (!self.isAlive() or self.getDomNode(child) == null) return;

        // CRITICAL: If appending <html> to document, set documentElement
        // Per DOM spec, documentElement is the first Element child of the Document
        if (parent.node_type == .document and child.node_type == .element) {
            if (child.local_name) |name| {
                if (std.mem.eql(u8, name, "html") and child.namespace == .html) {
                    document_internals.setDocumentElement(self.document, child_dom);
                }
            }
        }
    }

    /// Called when a node's text content changes during parsing.
    pub fn onTextContentChanged(self: *DomTreeAdapter, tree_node: *TreeNode) !void {
        const dom_node = self.getDomNode(tree_node) orelse return;

        // Update the DOM node's text content
        const text_content = tree_node.text_content.toSlice();
        const dom_string = runtime.DOMString.initInterned(text_content);

        // For Text nodes, update via CharacterData interface
        interfaces.CharacterData.set_data(dom_node, dom_string) catch {};
    }

    /// After a failed parser insertion of an element (design 5.3, trigger 2):
    /// rescue the root of the tree it is in, unless that is the Document -
    /// a pre-insert error leaves it parentless, and a reaction may have put
    /// it in a tree nothing else keeps. Rare and script-induced: one wrapper
    /// until the parser ends.
    pub fn keepFailedInsertion(self: *DomTreeAdapter, tree_node: *TreeNode) void {
        if (tree_node.node_type != .element) return;
        const rescuer = self.rescuer orelse return;
        const node = self.getDomNode(tree_node) orelse return;
        const base = dom.instance_bridge.getNodeBase(node) orelse return;
        const root_base = @import("parser_holds.zig").hostIncludingRoot(base);
        const document_base = dom.instance_bridge.getNodeBase(self.document);
        if (document_base != null and root_base == document_base.?) return;
        const root_opaque = dom.instance_bridge.getInstance(root_base) orelse return;
        rescuer.rescue(rescuer.context, @ptrCast(@alignCast(root_opaque)));
    }

    /// The first insertion attempt of `tree_node` has ended: its pending
    /// hold, if it has one, goes. A failed attempt was rescued first.
    pub fn endPendingHold(self: *DomTreeAdapter, tree_node: *TreeNode) void {
        if (self.pending.items.len == 0) return;
        for (self.pending.items, 0..) |held, i| {
            if (held.tree_node != tree_node) continue;
            const owned = self.pending.swapRemove(i).owned;
            owned.release();
            return;
        }
    }

    /// Get the DOM element for a TreeNode.
    pub fn getDomNode(self: *const DomTreeAdapter, tree_node: *TreeNode) ?*runtime.Instance {
        if (!self.isAlive() or tree_node.dom_revoked) return null;
        const node: *runtime.Instance = @ptrCast(@alignCast(tree_node.dom_node orelse return null));
        if (node == self.document) return node;
        return if (runtime.SlabAllocator.generationOf(node) == tree_node.dom_generation) node else null;
    }

    pub fn isAlive(self: *const DomTreeAdapter) bool {
        return (!self.had_engine or self.ctx.hasEngine()) and runtime.SlabAllocator.generationOf(self.document) == self.document_generation;
    }

    /// Create a DOM node from a TreeNode.
    fn createDomNode(self: *DomTreeAdapter, tree_node: *TreeNode) !*runtime.Instance {
        return switch (tree_node.node_type) {
            .element => try self.createElementNode(tree_node),
            .text => try self.createTextNode(tree_node),
            .comment => try self.createCommentNode(tree_node),
            .processing_instruction => try self.createProcessingInstructionNode(tree_node),
            .doctype => try self.createDoctypeNode(tree_node),
            .document => self.document, // Document already exists
        };
    }

    fn createElementNode(self: *DomTreeAdapter, tree_node: *TreeNode) !*runtime.Instance {
        const local_name = tree_node.local_name orelse return error.InvalidStateError;

        // Create an element for the token, step 3: determine the intended
        // parent's document BEFORE creating an element or invoking its hooks.
        const intended: ?*runtime.Instance = if (tree_node.creation_location) |location| (try parser_mutation.resolve(self, location)).parent else null;
        const owner = if (intended) |parent| blk: {
            break :blk if ((try interfaces.Node.get_nodeType(parent)) == interfaces.Node.get_DOCUMENT_NODE())
                parent
            else
                (try interfaces.Node.get_ownerDocument(parent)) orelse self.document;
        } else self.document;

        // Check if this is an HTML element (most common case)
        const is_html = tree_node.namespace == .html;
        const ns_uri: []const u8 = switch (tree_node.namespace) {
            .html => "http://www.w3.org/1999/xhtml",
            .mathml => "http://www.w3.org/1998/Math/MathML",
            .svg => "http://www.w3.org/2000/svg",
        };
        const parser_ce = @import("custom_elements/parser.zig");
        const is_value = parser_ce.isValue(tree_node);
        // Step 6: "Let registry be the result of looking up a custom element
        // registry given intendedParent" - an element's own, so a descendant
        // of a null-registry element is null too (Chrome does so; Safari does
        // not: a tie between the browsers that ship scoped registries, which
        // goes to the spec text). A token with a customelementregistry
        // attribute gets null instead (Chrome and Safari; browsers-first
        // audit R3 - the spec text has no such attribute).
        const registry: dom.custom_elements.RegistrySelection = if (parser_ce.hasRegistryAttribute(tree_node))
            .{ .explicit = null }
        else if (intended) |parent|
            .{ .explicit = try parser_ce.lookUpRegistry(parent) }
        else
            .default;
        // This adapter is the incremental full-document parser, including
        // document.write. Fragment conversion uses HTMLParser's explicit bit.
        const scope = try parser_ce.Scope.beginWithRegistry(owner, local_name, ns_uri, is_value, false, registry);
        // Scope.begin found a definition exactly when this creation will
        // execute script.
        const creation: Creation = if (scope.synchronous) .may_have_run_script else .ran_no_script;
        defer scope.end();
        const element = try @import("custom_elements/creation.zig").create(.{
            .document = owner,
            .local_name = local_name,
            .namespace = ns_uri,
            .is_value = is_value,
            .synchronous = scope.synchronous,
            .registry = registry,
        });

        errdefer if (!engine.hasWrapper(element)) dom.node_creation.destroyUninserted(element);

        // Design 5.4: an element its creation wrapped (a synchronously
        // constructed custom element or customized built-in) is parentless
        // and collectible until it is inserted. Hold it BEFORE its attributes
        // are appended and `scope.end()` runs its reactions - which, or the
        // checkpoint after them, can drop `this` and collect. retainValue
        // returns the existing wrapper; an unwrapped element needs no hold
        // (the collector never frees an unwrapped root).
        if (mustCheckWrapper(creation) and self.ctx.hasEngine() and engine.hasWrapper(element)) {
            try self.pending.ensureUnusedCapacity(self.allocator, 1);
            const owned = try engine.retainValue(self.ctx, .{ .instance = element });
            self.pending.appendAssumeCapacity(.{ .tree_node = tree_node, .owned = owned });
        }

        // A script element - HTML's, or an SVG script, whose insertion and
        // children-changed steps wait for its end tag too - is
        // parser-inserted.
        if (std.mem.eql(u8, local_name, "script")) {
            dom.script_elements.markParserInserted(element, self.document);
            // Where its text starts: the parser's position after its start
            // tag, for its errors and a CSP violation to report.
            recordStartPosition(element, self.document);
        }
        // An element type that acts when the parser pops its elements
        // (dom.finish_parsing_children) hears that this one is on the stack
        // of open elements - before its attributes are appended, so their
        // change steps already know.
        if (is_html and self.notifies_children_finished and dom.finish_parsing_children.hasSteps(local_name)) {
            dom.finish_parsing_children.createdByParser(element, local_name);
        }

        for (tree_node.attributes.toSlice()) |attr| appendParsedAttribute(element, attr);

        // HTML 4.2.7 records the token's stylesheet relationship and enabled
        // state at creation, before its post-connection steps start a fetch.
        if (is_html and (std.mem.eql(u8, local_name, "style") or std.mem.eql(u8, local_name, "link"))) dom.style_sheet_owners.createdByParser(element, styleStart(local_name, self.document));

        // Step 15: the tree builder found its parser conditions held; the
        // intended parent must share the form's tree, and a form-associated
        // custom element is never associated.
        if (tree_node.parser_form) |form_node| {
            if (intended) |parent| if (self.getDomNode(form_node)) |form|
                try @import("form_associated.zig").parserAssociate(element, form, parent);
        }

        self.last_creation = creation;
        return element;
    }

    fn createTextNode(self: *DomTreeAdapter, tree_node: *TreeNode) !*runtime.Instance {
        const text_data = tree_node.text_content.toSlice();
        const text = try interfaces.Text.initWith(
            self.ctx.allocator,
            self.ctx,
            .{ .data = text_data },
        );

        node_document.set(text, self.document) catch {};

        self.last_creation = .ran_no_script;
        return text;
    }

    fn createCommentNode(self: *DomTreeAdapter, tree_node: *TreeNode) !*runtime.Instance {
        const comment_data = tree_node.text_content.toSlice();
        const comment = try interfaces.Comment.initWith(
            self.ctx.allocator,
            self.ctx,
            .{ .data = comment_data },
        );

        node_document.set(comment, self.document) catch {};

        self.last_creation = .ran_no_script;
        return comment;
    }

    /// HTML "insert a processing instruction" step 4, through Document's
    /// createProcessingInstruction (DOM 4.5: "creating a processing
    /// instruction node" given the document, target and data). Made in the
    /// adapter's document, as its comments are; inserting it into a
    /// template's contents adopts it there.
    fn createProcessingInstructionNode(self: *DomTreeAdapter, tree_node: *TreeNode) !*runtime.Instance {
        const pi = try interfaces.Document.call_createProcessingInstruction(
            self.document,
            runtime.DOMString.initInterned(tree_node.pi_target orelse ""),
            runtime.DOMString.initInterned(tree_node.text_content.toSlice()),
        );
        self.last_creation = .ran_no_script;
        return pi;
    }

    fn createDoctypeNode(self: *DomTreeAdapter, tree_node: *TreeNode) !*runtime.Instance {
        // Its node type is DocumentType.init's; its name, public ID and
        // system ID are the token's, which no IDL member sets.
        const doctype = try interfaces.DocumentType.init(self.allocator, self.ctx);
        dom.node_creation.setDoctypeIds(doctype, tree_node.doctype_name, tree_node.doctype_public_id, tree_node.doctype_system_id);

        node_document.set(doctype, self.document) catch {};

        self.last_creation = .ran_no_script;
        return doctype;
    }
};

/// Create an element in the HTML namespace: it implements the interface HTML's
/// "element interface" algorithm names for `local_name`, matched exactly.
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#htmlelement
pub fn createHTMLElement(
    allocator: Allocator,
    ctx: runtime.Context,
    local_name: []const u8,
) !*runtime.Instance {
    return switch (html_core.element_interface.forLocalName(local_name)) {
        inline else => |which| @field(interfaces, @tagName(which)).init(allocator, ctx),
    };
}

/// Create an element the parser met in foreign content - in the SVG or MathML
/// namespace - with the interface its local name and namespace call for.
///
/// MathML Core 2.2.3 and 3.2.5 select MathMLElement and MathMLAnchorElement.
/// Deviation, stated: SVG interfaces other than script and a still use
/// plain Element (TODO: the rest of SVG and SVGElement for unknown ones).
pub fn createForeignElement(
    allocator: Allocator,
    ctx: runtime.Context,
    namespace: Namespace,
    local_name: []const u8,
) !*runtime.Instance {
    if (namespace == .svg and std.mem.eql(u8, local_name, "script")) {
        return interfaces.SVGScriptElement.init(allocator, ctx);
    }
    // An SVG a is an SVGAElement, whose activation behaviour follows its
    // hyperlink - as Document.createElementNS makes it. Other SVG elements
    // are still plain Elements (stated: their impls do not chain yet).
    if (namespace == .svg and std.mem.eql(u8, local_name, "a")) {
        return interfaces.SVGAElement.init(allocator, ctx);
    }
    if (namespace == .mathml) {
        return if (std.mem.eql(u8, local_name, "a"))
            interfaces.MathMLAnchorElement.init(allocator, ctx)
        else
            interfaces.MathMLElement.init(allocator, ctx);
    }
    return interfaces.Element.init(allocator, ctx);
}

// =============================================================================
// Tests
// =============================================================================

test "ParserScriptContext - init" {
    const allocator = std.testing.allocator;

    // Create runtime context data for testing
    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    // Create minimal context (without actual document/tree_builder for unit test)
    const script_ctx = ParserScriptContext{
        .allocator = allocator,
        .ctx = ctx,
        .document = undefined,
        .adapter = undefined,
        .tree_builder = undefined,
        .scripting_enabled = true,
    };

    try std.testing.expect(script_ctx.scripting_enabled);
}
