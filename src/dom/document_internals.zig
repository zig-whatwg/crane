//! Document Internal Algorithms
//!
//! Contains internal helper functions for Document manipulation that are NOT
//! defined in WebIDL and should NOT be called through impls.
//!
//! ## Architecture Note
//!
//! Per Golden Rule #12 and #13:
//! - External code MUST call through interfaces, NEVER directly call impls
//! - This module provides the internal algorithm implementations that impls delegate to
//!
//! ## Migration Status
//!
//! This module is part of the migration from src/webidl/impls/Document.zig
//! (see issue whatwg-wvruv). Functions are being progressively moved here
//! from Document.zig impl.
//!
//! Spec: https://dom.spec.whatwg.org/#interface-document

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const csp = @import("csp");
const html_core = @import("html_core");
const StylesheetBlockingTracker = html_core.StylesheetBlockingTracker;

// Import the impl to access InternalState type (needed during migration)
// TODO: Eventually InternalState should be defined here, not in the impl
const impls = @import("impls");
const DocumentImpl = impls.Document;
pub const InternalState = DocumentImpl.InternalState;
pub const DocType = DocumentImpl.DocType;
pub const SpeculationEagerness = DocumentImpl.SpeculationEagerness;

// =============================================================================
// Internal State Access
// =============================================================================

/// Get the internal state from a Document instance.
/// This is the canonical way to access Document's internal state.
pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return DocumentImpl.getInternal(instance);
}

// =============================================================================
// Document Type and Content Type Management
// =============================================================================

/// Set the document type (html or xml)
/// Used during document creation and initialization.
pub fn setDocumentType(instance: *runtime.Instance, doc_type: DocType) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.doc_type = doc_type;
}

/// Set the content type (e.g., "text/html", "application/xml")
/// Used during document creation and initialization.
pub fn setContentType(instance: *runtime.Instance, content_type: []const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.content_type.deinit(internal.allocator);
    internal.content_type = try runtime.DOMString.initDupe(internal.allocator, content_type);
}

/// Get the content type.
/// Returns the MIME type of the document (e.g., "text/html", "application/xml").
pub fn getContentType(instance: *runtime.Instance) ?[]const u8 {
    const internal = getInternal(instance) orelse return null;
    return internal.content_type.asSlice();
}

/// Copy origin from another document
pub fn copyOrigin(instance: *runtime.Instance, source: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const source_internal = getInternal(source) orelse return error.InvalidStateError;
    internal.origin = source_internal.origin;
}

/// Get the document type (html or xml).
pub fn getDocumentType(instance: *runtime.Instance) ?DocType {
    const internal = getInternal(instance) orelse return null;
    return internal.doc_type;
}

/// Set the document element (the root <html> element).
pub fn setDocumentElement(instance: *runtime.Instance, element: ?*runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.document_element = element;
    }
}

/// Get the document element (the root <html> element).
pub fn getDocumentElement(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.document_element;
}

/// Set the doctype node.
pub fn setDoctype(instance: *runtime.Instance, doctype: ?*runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.doctype = doctype;
    }
}

/// Get the doctype node.
pub fn getDoctype(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.doctype;
}

// =============================================================================
// Tree Cleanup
// =============================================================================

/// Remove and deinitialize all child nodes from the document.
/// This is used when reusing an existing document for fresh parsing.
/// Each child node is properly deinitialized via deinitNodeByType, which
/// handles type-specific cleanup and recursive child cleanup.
pub fn clearChildren(instance: *runtime.Instance) void {
    const NodeImpl = impls.Node;
    const node_internal = NodeImpl.getInternalState(instance) orelse return;

    // Iterate through children and deinit each one
    var child = node_internal.first_child;
    while (child) |child_node| {
        // Get next sibling BEFORE deinit (deinit may clear sibling pointers)
        const next = if (NodeImpl.getInternalState(child_node)) |child_internal|
            child_internal.next_sibling
        else
            null;

        // Deinit the child node based on its type
        NodeImpl.deinitNodeByType(child_node);

        child = next;
    }

    // Clear tree pointers
    node_internal.first_child = null;
    node_internal.last_child = null;

    // Also clear document-specific references
    if (getInternal(instance)) |internal| {
        internal.document_element = null;
        internal.doctype = null;
    }
}

// =============================================================================
// String Interning
// =============================================================================

/// Intern a string in the document's string pool.
/// Returns a pointer to the interned string which can be compared via pointer equality.
/// If the string is already interned, returns the existing copy.
/// Caller does NOT own the returned slice - it's managed by the Document.
pub fn internString(instance: *runtime.Instance, str: []const u8) ![]const u8 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if string is already interned
    if (internal.string_pool.getKey(str)) |existing| {
        return existing;
    }

    // Not interned yet - allocate and store
    const owned = try internal.allocator.dupe(u8, str);
    errdefer internal.allocator.free(owned);

    try internal.string_pool.put(owned, {});
    return owned;
}

// =============================================================================
// Range and NodeIterator Registration
// =============================================================================

/// Register a live range with this document.
/// Spec: https://dom.spec.whatwg.org/#concept-live-range
pub fn registerRange(instance: *runtime.Instance, range: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.ranges.append(internal.allocator, range);
}

/// Unregister a live range from this document.
pub fn unregisterRange(instance: *runtime.Instance, range: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;

    for (internal.ranges.items, 0..) |r, i| {
        if (r == range) {
            _ = internal.ranges.orderedRemove(i);
            return;
        }
    }
}

/// Register a node iterator with this document.
pub fn registerNodeIterator(instance: *runtime.Instance, iterator: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.node_iterators.append(internal.allocator, iterator);
}

/// Unregister a node iterator from this document.
pub fn unregisterNodeIterator(instance: *runtime.Instance, iterator: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;

    for (internal.node_iterators.items, 0..) |iter, i| {
        if (iter == iterator) {
            _ = internal.node_iterators.orderedRemove(i);
            return;
        }
    }
}

// =============================================================================
// Script Execution Management (HTML Standard §4.12.1.1)
// =============================================================================

/// Get pending parsing-blocking script.
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#pending-parsing-blocking-script
pub fn getPendingParsingBlockingScript(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.pending_parsing_blocking_script;
}

/// Set pending parsing-blocking script.
pub fn setPendingParsingBlockingScript(instance: *runtime.Instance, script: ?*runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.pending_parsing_blocking_script = script;
    }
}

/// Add script to "execute as soon as possible" set.
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#set-of-scripts-that-will-execute-as-soon-as-possible
pub fn addScriptToExecuteAsap(instance: *runtime.Instance, script: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.scripts_to_execute_asap.append(internal.allocator, script);
}

/// Remove script from "execute as soon as possible" set.
pub fn removeScriptFromExecuteAsap(instance: *runtime.Instance, script: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    for (internal.scripts_to_execute_asap.items, 0..) |s, i| {
        if (s == script) {
            _ = internal.scripts_to_execute_asap.orderedRemove(i);
            return;
        }
    }
}

/// Add script to "execute in order as soon as possible" list.
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#list-of-scripts-that-will-execute-in-order-as-soon-as-possible
pub fn addScriptToExecuteInOrderAsap(instance: *runtime.Instance, script: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.scripts_to_execute_in_order_asap.append(internal.allocator, script);
}

/// Get first script in "execute in order" list.
pub fn getFirstScriptToExecuteInOrder(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    if (internal.scripts_to_execute_in_order_asap.items.len > 0) {
        return internal.scripts_to_execute_in_order_asap.items[0];
    }
    return null;
}

/// Remove first script from "execute in order" list.
pub fn removeFirstScriptFromExecuteInOrder(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    if (internal.scripts_to_execute_in_order_asap.items.len > 0) {
        _ = internal.scripts_to_execute_in_order_asap.orderedRemove(0);
    }
}

/// Add script to "execute when document has finished parsing" list.
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#list-of-scripts-that-will-execute-when-the-document-has-finished-parsing
pub fn addScriptToExecuteWhenParsingFinished(instance: *runtime.Instance, script: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.scripts_to_execute_when_parsing_finished.append(internal.allocator, script);
}

/// Get scripts to execute when parsing finished.
pub fn getScriptsToExecuteWhenParsingFinished(instance: *runtime.Instance) []const *runtime.Instance {
    const internal = getInternal(instance) orelse return &.{};
    return internal.scripts_to_execute_when_parsing_finished.items;
}

/// Clear scripts to execute when parsing finished.
pub fn clearScriptsToExecuteWhenParsingFinished(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.scripts_to_execute_when_parsing_finished.clearRetainingCapacity();
    }
}

/// Get scripts from "execute as soon as possible" set.
pub fn getScriptsToExecuteAsap(instance: *runtime.Instance) []*runtime.Instance {
    const internal = getInternal(instance) orelse return &[_]*runtime.Instance{};
    return internal.scripts_to_execute_asap.items;
}

/// Pop and return the first script from "execute in order" list.
pub fn popFirstScriptToExecuteInOrderAsap(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    if (internal.scripts_to_execute_in_order_asap.items.len > 0) {
        return internal.scripts_to_execute_in_order_asap.orderedRemove(0);
    }
    return null;
}

/// Get currently executing script (for document.currentScript).
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-currentscript
pub fn getCurrentScript(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.current_script;
}

/// Set currently executing script.
pub fn setCurrentScript(instance: *runtime.Instance, script: ?*runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.current_script = script;
    }
}

// =============================================================================
// Destructive Writes Management (HTML Standard §8.4)
// =============================================================================

/// Increment ignore-destructive-writes counter.
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#ignore-destructive-writes-counter
pub fn incrementIgnoreDestructiveWritesCounter(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.ignore_destructive_writes_counter += 1;
    }
}

/// Decrement ignore-destructive-writes counter.
pub fn decrementIgnoreDestructiveWritesCounter(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        if (internal.ignore_destructive_writes_counter > 0) {
            internal.ignore_destructive_writes_counter -= 1;
        }
    }
}

/// Check if destructive writes should be ignored.
pub fn shouldIgnoreDestructiveWrites(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.ignore_destructive_writes_counter > 0;
}

// =============================================================================
// Document Write / Parsing State Management (HTML Standard §8.4)
// =============================================================================

/// Get the current insertion point.
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#insertion-point
/// Returns null if parsing has finished or not started.
pub fn getInsertionPoint(instance: *runtime.Instance) ?usize {
    const internal = getInternal(instance) orelse return null;
    return internal.insertion_point;
}

/// Set the insertion point (called when parser starts/updates position).
pub fn setInsertionPoint(instance: *runtime.Instance, position: ?usize) void {
    if (getInternal(instance)) |internal| {
        internal.insertion_point = position;
    }
}

/// Clear the insertion point (called when parsing finishes).
pub fn clearInsertionPoint(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.insertion_point = null;
    }
}

/// Check if parsing is currently active (insertion point is defined).
pub fn isParsingActive(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.insertion_point != null;
}

/// Set the InputStreamManager for document.write() during parsing.
pub fn setInputStreamManager(instance: *runtime.Instance, manager: ?*html_core.parser.document_write.InputStreamManager) void {
    if (getInternal(instance)) |internal| {
        internal.input_stream_manager = manager;
    }
}

/// Get the InputStreamManager (for document.write() during parsing).
pub fn getInputStreamManager(instance: *runtime.Instance) ?*html_core.parser.document_write.InputStreamManager {
    const internal = getInternal(instance) orelse return null;
    return internal.input_stream_manager;
}

/// Increment throw-on-dynamic-markup-insertion counter.
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#throw-on-dynamic-markup-insertion-counter
pub fn incrementThrowOnDynamicMarkupInsertionCounter(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.throw_on_dynamic_markup_insertion_counter += 1;
    }
}

/// Decrement throw-on-dynamic-markup-insertion counter.
pub fn decrementThrowOnDynamicMarkupInsertionCounter(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        if (internal.throw_on_dynamic_markup_insertion_counter > 0) {
            internal.throw_on_dynamic_markup_insertion_counter -= 1;
        }
    }
}

/// Increment unload counter.
/// Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#unload-counter
pub fn incrementUnloadCounter(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.unload_counter += 1;
    }
}

/// Decrement unload counter.
pub fn decrementUnloadCounter(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        if (internal.unload_counter > 0) {
            internal.unload_counter -= 1;
        }
    }
}

/// Abort the active parser (e.g., due to navigation).
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#abort-a-parser
pub fn abortParser(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.active_parser_was_aborted = true;
        internal.insertion_point = null;
        internal.input_stream_manager = null;
    }
}

/// Check if the active parser was aborted.
pub fn wasParserAborted(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.active_parser_was_aborted;
}

/// Get the write buffer content (for document.write() in after-parsing mode).
pub fn getWriteBuffer(instance: *runtime.Instance) []const u8 {
    const internal = getInternal(instance) orelse return "";
    return internal.write_buffer.items;
}

/// Check if scripting is enabled.
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#concept-n-noscript
pub fn isScriptingEnabled(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.scripting_enabled;
}

/// Set scripting enabled flag.
pub fn setScriptingEnabled(instance: *runtime.Instance, enabled: bool) void {
    if (getInternal(instance)) |internal| {
        internal.scripting_enabled = enabled;
    }
}

// =============================================================================
// Module Map Management (HTML Standard §8.1.3.10)
// =============================================================================

/// Get a module from the module map by URL.
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#module-map
pub fn getModule(instance: *runtime.Instance, url: []const u8) ?*anyopaque {
    const internal = getInternal(instance) orelse return null;
    return internal.module_map.get(url);
}

/// Store a module in the module map.
pub fn setModule(instance: *runtime.Instance, url: []const u8, module: *anyopaque) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    if (internal.module_map.get(url)) |old_module| {
        if (internal.dispose_module_fn) |dispose_fn| {
            dispose_fn(old_module);
        }
        _ = internal.module_map.remove(url);
    }

    const owned_url = try internal.allocator.dupe(u8, url);
    errdefer internal.allocator.free(owned_url);

    try internal.module_map.put(owned_url, module);
}

/// Check if a module exists in the module map.
pub fn hasModule(instance: *runtime.Instance, url: []const u8) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.module_map.contains(url);
}

/// Set the module disposal function for this document.
pub fn setModuleDisposeFunction(instance: *runtime.Instance, dispose_fn: ?*const fn (*anyopaque) void) void {
    if (getInternal(instance)) |internal| {
        internal.dispose_module_fn = dispose_fn;
    }
}

// =============================================================================
// Import Map Management (HTML Standard §8.1.6)
// =============================================================================

/// Check if import map has been acquired.
pub fn hasImportMapAcquired(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.import_map_acquired;
}

/// Mark import map as acquired.
pub fn setImportMapAcquired(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.import_map_acquired = true;
    }
}

/// Add an import mapping.
pub fn addImportMapping(instance: *runtime.Instance, specifier: []const u8, resolved_url: []const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    const owned_specifier = try internal.allocator.dupe(u8, specifier);
    errdefer internal.allocator.free(owned_specifier);

    const owned_url = try internal.allocator.dupe(u8, resolved_url);
    errdefer internal.allocator.free(owned_url);

    if (internal.import_map_imports.getKey(specifier)) |old_key| {
        if (internal.import_map_imports.get(old_key)) |old_value| {
            internal.allocator.free(old_value);
        }
        _ = internal.import_map_imports.remove(old_key);
        internal.allocator.free(old_key);
    }

    try internal.import_map_imports.put(owned_specifier, owned_url);
}

/// Resolve an import specifier using the import map.
pub fn resolveImportSpecifier(instance: *runtime.Instance, specifier: []const u8, referrer_url: []const u8) ?[]const u8 {
    const internal = getInternal(instance) orelse return null;

    var best_scope: ?[]const u8 = null;
    var best_scope_len: usize = 0;

    var scope_it = internal.import_map_scopes.keyIterator();
    while (scope_it.next()) |scope_key| {
        if (std.mem.startsWith(u8, referrer_url, scope_key.*)) {
            if (scope_key.len > best_scope_len) {
                best_scope = scope_key.*;
                best_scope_len = scope_key.len;
            }
        }
    }

    if (best_scope) |scope| {
        if (internal.import_map_scopes.get(scope)) |scope_map| {
            if (scope_map.get(specifier)) |resolved| {
                return resolved;
            }
        }
    }

    return internal.import_map_imports.get(specifier);
}

// =============================================================================
// Content Security Policy Management (CSP Level 3)
// =============================================================================

/// Get the CSP list for this document.
pub fn getCSPList(instance: *runtime.Instance) ?*csp.CSPList {
    const internal = getInternal(instance) orelse return null;
    return internal.csp_list;
}

/// Set the CSP list for this document.
pub fn setCSPList(instance: *runtime.Instance, csp_list: *csp.CSPList) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    if (internal.csp_list) |old_list| {
        old_list.deinit();
        internal.allocator.destroy(old_list);
    }

    internal.csp_list = csp_list;
}

/// Add a policy to the document's CSP list.
pub fn addCSPPolicy(instance: *runtime.Instance, policy: csp.Policy) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    if (internal.csp_list == null) {
        const new_list = try internal.allocator.create(csp.CSPList);
        new_list.* = csp.CSPList.init(internal.allocator);
        internal.csp_list = new_list;
    }

    try internal.csp_list.?.append(policy);
}

/// Get the document's CSP self-origin.
pub fn getCSPSelfOrigin(instance: *runtime.Instance) ?*const csp.Origin {
    const internal = getInternal(instance) orelse return null;
    if (internal.csp_self_origin) |*origin| {
        return origin;
    }
    return null;
}

/// Set the document's CSP self-origin.
pub fn setCSPSelfOrigin(instance: *runtime.Instance, scheme: []const u8, host: []const u8, port: ?u16) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    if (internal.csp_self_origin) |*origin| {
        origin.deinit();
    }

    internal.csp_self_origin = try csp.Origin.create(internal.allocator, scheme, host, port);
}

/// Check if an inline script is allowed by CSP.
pub fn isInlineScriptAllowedByCSP(
    instance: *runtime.Instance,
    nonce: ?[]const u8,
    hash_algorithm: ?[]const u8,
    hash_value: ?[]const u8,
) bool {
    const internal = getInternal(instance) orelse return true;
    const csp_list = internal.csp_list orelse return true;

    for (csp_list.policies.items) |*policy| {
        if (policy.disposition != .enforce) continue;

        const directive = csp.fallback.getEffectiveScriptSrcElem(policy) orelse continue;
        const has_strict_dynamic = csp.matching.hasStrictDynamic(&directive.value);

        if (nonce) |n| {
            if (csp.matching.doesNonceMatch(n, &directive.value)) {
                continue;
            }
        }

        if (hash_algorithm) |algo| {
            if (hash_value) |hash| {
                if (csp.matching.doesHashMatch(algo, hash, &directive.value)) {
                    continue;
                }
            }
        }

        if (!has_strict_dynamic and csp.matching.allowsUnsafeInline(&directive.value)) {
            var has_nonce_or_hash = false;
            for (directive.value.expressions.items) |expr| {
                if (expr.type == .nonce or expr.type == .hash) {
                    has_nonce_or_hash = true;
                    break;
                }
            }

            if (!has_nonce_or_hash) {
                continue;
            }
        }

        return false;
    }

    return true;
}

/// Check if an external script URL is allowed by CSP.
pub fn isExternalScriptAllowedByCSP(
    instance: *runtime.Instance,
    url_scheme: []const u8,
    url_host: []const u8,
    url_port: ?u16,
    url_path: []const u8,
    nonce: ?[]const u8,
) bool {
    const internal = getInternal(instance) orelse return true;
    const csp_list = internal.csp_list orelse return true;
    const self_origin = if (internal.csp_self_origin) |*o| o else null;

    for (csp_list.policies.items) |*policy| {
        if (policy.disposition != .enforce) continue;

        const directive = csp.fallback.getEffectiveScriptSrcElem(policy) orelse continue;
        const has_strict_dynamic = csp.matching.hasStrictDynamic(&directive.value);

        if (has_strict_dynamic) {
            if (nonce) |n| {
                if (csp.matching.doesNonceMatch(n, &directive.value)) {
                    continue;
                }
            }
            return false;
        }

        if (nonce) |n| {
            if (csp.matching.doesNonceMatch(n, &directive.value)) {
                continue;
            }
        }

        if (csp.matching.doesUrlMatchSourceList(
            url_scheme,
            url_host,
            url_port,
            url_path,
            &directive.value,
            self_origin,
            0,
        )) {
            continue;
        }

        return false;
    }

    return true;
}

/// Check if eval() is allowed by CSP.
pub fn isEvalAllowedByCSP(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return true;
    const csp_list = internal.csp_list orelse return true;

    for (csp_list.policies.items) |*policy| {
        if (policy.disposition != .enforce) continue;

        const directive = csp.fallback.getEffectiveScriptSrc(&policy.directive_set) orelse continue;

        if (!csp.matching.allowsUnsafeEval(&directive.value)) {
            return false;
        }
    }

    return true;
}

// =============================================================================
// Stylesheet Blocking (HTML Standard §14.3.3)
// =============================================================================

/// Check if document has a style sheet that is blocking scripts.
pub fn hasStyleSheetBlockingScripts(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.stylesheet_tracker.hasBlockingStylesheet();
}

/// Get the stylesheet blocking tracker.
pub fn getStylesheetTracker(instance: *runtime.Instance) ?*StylesheetBlockingTracker {
    const internal = getInternal(instance) orelse return null;
    return &internal.stylesheet_tracker;
}

/// Add a stylesheet to the blocking tracker.
pub fn addBlockingStylesheet(
    instance: *runtime.Instance,
    id: []const u8,
    url: []const u8,
    is_blocking: bool,
) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.stylesheet_tracker.addStylesheet(id, url, is_blocking);
}

/// Mark a stylesheet as loaded.
pub fn markStylesheetLoaded(instance: *runtime.Instance, id: []const u8) void {
    const internal = getInternal(instance) orelse return;
    internal.stylesheet_tracker.markLoaded(id);
}

/// Mark a stylesheet as failed.
pub fn markStylesheetFailed(instance: *runtime.Instance, id: []const u8) void {
    const internal = getInternal(instance) orelse return;
    internal.stylesheet_tracker.markFailed(id);
}

/// Remove a stylesheet from tracking.
pub fn removeBlockingStylesheet(instance: *runtime.Instance, id: []const u8) void {
    const internal = getInternal(instance) orelse return;
    internal.stylesheet_tracker.removeStylesheet(id);
}

/// Get the count of blocking stylesheets.
pub fn getBlockingStylesheetCount(instance: *runtime.Instance) usize {
    const internal = getInternal(instance) orelse return 0;
    return internal.stylesheet_tracker.getBlockingCount();
}

/// Set callback for when all blocking stylesheets are resolved.
pub fn setStylesheetBlockingResolvedCallback(
    instance: *runtime.Instance,
    callback: StylesheetBlockingTracker.BlockingResolvedCallback,
    context: ?*anyopaque,
) void {
    const internal = getInternal(instance) orelse return;
    internal.stylesheet_tracker.setBlockingResolvedCallback(callback, context);
}

// =============================================================================
// Speculation Rules Support (HTML Standard §7.6)
// =============================================================================

/// Add a prefetch hint from speculation rules.
pub fn addPrefetchHint(
    instance: *runtime.Instance,
    url: []const u8,
    eagerness: SpeculationEagerness,
) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    if (internal.prefetch_hints.get(url)) |existing_eagerness| {
        if (@intFromEnum(eagerness) < @intFromEnum(existing_eagerness)) {
            internal.prefetch_hints.put(url, eagerness) catch return error.OutOfMemory;
        }
        return;
    }

    const owned_url = try internal.allocator.dupe(u8, url);
    errdefer internal.allocator.free(owned_url);

    try internal.prefetch_hints.put(owned_url, eagerness);
}

/// Get all prefetch hints for this document.
pub fn getPrefetchHints(instance: *runtime.Instance) []const []const u8 {
    const internal = getInternal(instance) orelse return &.{};
    return internal.prefetch_hints.keys();
}

/// Check if a URL is in the prefetch hints.
pub fn hasPrefetchHint(instance: *runtime.Instance, url: []const u8) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.prefetch_hints.contains(url);
}

/// Get the eagerness for a prefetch hint.
pub fn getPrefetchHintEagerness(instance: *runtime.Instance, url: []const u8) ?SpeculationEagerness {
    const internal = getInternal(instance) orelse return null;
    return internal.prefetch_hints.get(url);
}
