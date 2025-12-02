//! Script Execution Module
//!
//! Implements the "prepare the script element" and "execute the script element"
//! algorithms from HTML Standard §4.12.1.1.
//!
//! Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
//!
//! This module provides the bridge between the HTML parser and the V8 JavaScript
//! engine for executing inline and external scripts.

const std = @import("std");
const runtime = @import("runtime");

// WebIDL types
const interfaces = @import("interfaces");
const impls = @import("impls");

// Script element implementation
const HTMLScriptElementImpl = impls.HTMLScriptElement;
const ScriptType = HTMLScriptElementImpl.ScriptType;
const ScriptResult = HTMLScriptElementImpl.ScriptResult;
const ClassicScript = HTMLScriptElementImpl.ClassicScript;

// Document implementation
const DocumentImpl = impls.Document;

// Node implementation for DOM traversal
const NodeImpl = impls.Node;

// Element implementation for attribute access
const ElementImpl = impls.Element;

// MIME type checking
const mimesniff = @import("mimesniff");

// Infra primitives
const infra = @import("infra");

pub const ScriptExecutionError = error{
    InvalidScriptElement,
    ScriptingDisabled,
    DocumentMismatch,
    ParseError,
    NetworkError,
    SecurityError,
    AlreadyStarted,
    NotConnected,
    OutOfMemory,
};

/// Prepare the script element
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#prepare-the-script-element
///
/// This is the main entry point for script preparation. It determines the script type,
/// validates preconditions, and either immediately executes (for inline classic scripts)
/// or queues the script for later execution.
///
/// Returns true if the script was prepared successfully and may need execution,
/// false if preparation was aborted.
pub fn prepareScriptElement(
    allocator: std.mem.Allocator,
    script_element: *runtime.Instance,
) ScriptExecutionError!bool {
    // Step 1: If el's already started is true, then return
    if (HTMLScriptElementImpl.hasAlreadyStarted(script_element)) {
        return false;
    }

    // Step 2: Let parser document be el's parser document
    const parser_document = HTMLScriptElementImpl.getParserDocument(script_element);

    // Step 3: Set el's parser document to null
    HTMLScriptElementImpl.setParserDocument(script_element, null);

    // Step 4: If parser document is non-null and el does not have an async attribute,
    // then set el's force async to true
    if (parser_document != null) {
        if (!hasAsyncAttribute(script_element)) {
            // force_async is already true by default, so this step is a no-op
            // But per spec, if parser_document was null initially, force_async stays as-is
        }
    }

    // Step 5: Let source text be el's child text content
    const source_text = getChildTextContent(allocator, script_element) catch |err| {
        if (err == error.OutOfMemory) return ScriptExecutionError.OutOfMemory;
        return "";
    };
    defer if (source_text.len > 0) allocator.free(source_text);

    // Step 6: If el has no src attribute, and source text is empty, then return
    if (!hasSrcAttribute(script_element) and source_text.len == 0) {
        return false;
    }

    // Step 7: If el is not connected, then return
    if (!isConnected(script_element)) {
        return false;
    }

    // Steps 8-13: Determine script type from type attribute
    const script_type = determineScriptType(script_element);
    if (script_type == .null) {
        // Step 13: Otherwise, return (no script is executed)
        return false;
    }

    // Step 14: If parser document is non-null, set el's parser document back
    // and set force_async to false
    if (parser_document) |pd| {
        HTMLScriptElementImpl.setParserDocument(script_element, pd);
        HTMLScriptElementImpl.clearForceAsync(script_element);
    }

    // Step 15: Set el's already started to true
    HTMLScriptElementImpl.setAlreadyStarted(script_element, true);

    // Step 16: Set el's preparation-time document to its node document
    const node_document = getNodeDocument(script_element);
    HTMLScriptElementImpl.setPreparationTimeDocument(script_element, node_document);

    // Step 17: If parser document is non-null and not equal to preparation-time document, return
    if (parser_document) |pd| {
        if (pd != node_document) {
            return false;
        }
    }

    // Step 18: If scripting is disabled for el, then return
    if (node_document) |doc| {
        if (!DocumentImpl.isScriptingEnabled(doc)) {
            return false;
        }
    }

    // Step 19: If el has a nomodule attribute and type is "classic", return
    if (script_type == .classic and hasNoModuleAttribute(script_element)) {
        return false;
    }

    // Step 20: Let cspType... (CSP not implemented yet, skip)

    // Step 21: CSP check for inline scripts (not implemented yet, skip)

    // Step 22: Handle obsolete event/for attributes for classic scripts
    if (script_type == .classic) {
        if (hasEventAttribute(script_element) and hasForAttribute(script_element)) {
            const for_attr = getForAttribute(script_element);
            const event_attr = getEventAttribute(script_element);

            const trimmed_for = std.mem.trim(u8, for_attr, " \t\n\r\x0c");
            const trimmed_event = std.mem.trim(u8, event_attr, " \t\n\r\x0c");

            // If for is not "window", return
            if (!std.ascii.eqlIgnoreCase(trimmed_for, "window")) {
                return false;
            }

            // If event is not "onload" or "onload()", return
            if (!std.ascii.eqlIgnoreCase(trimmed_event, "onload") and
                !std.ascii.eqlIgnoreCase(trimmed_event, "onload()"))
            {
                return false;
            }
        }
    }

    // Steps 23-31: Build fetch options (encoding, CORS, integrity, etc.)
    // For now, we skip external script fetching

    // Set the script type
    HTMLScriptElementImpl.setScriptType(script_element, script_type);

    // Step 33: If el has a src attribute (external script)
    if (hasSrcAttribute(script_element)) {
        // External scripts - mark as from external file
        HTMLScriptElementImpl.setFromExternalFile(script_element, true);

        // TODO: Implement external script fetching
        // For now, we'll skip external scripts and handle only inline scripts

        // Step 33.3: If src is empty, queue error event and return
        const src = getSrcAttribute(script_element);
        if (src.len == 0) {
            // TODO: Queue error event
            return false;
        }

        // For external scripts, we need to fetch and then handle based on script type
        // This is complex and requires async handling - defer for now
        return false;
    }

    // Step 34: Inline script (no src attribute)
    if (node_document) |doc| {
        const base_url = DocumentImpl.getInternal(doc).?.base_uri;

        switch (script_type) {
            .classic => {
                // Step 34.2.1: Create a classic script
                const script = ClassicScript.init(source_text, base_url);

                // Step 34.2.2: Mark as ready
                HTMLScriptElementImpl.setResult(script_element, .{ .script = script });

                // Cache the source text for execution
                HTMLScriptElementImpl.cacheSourceText(script_element, source_text) catch {
                    return ScriptExecutionError.OutOfMemory;
                };
            },
            .module => {
                // Module scripts require async handling for dependency resolution
                // For now, skip module scripts
                return false;
            },
            .importmap => {
                // Import maps - not yet implemented
                return false;
            },
            .speculationrules => {
                // Speculation rules - not yet implemented
                return false;
            },
            .null => return false,
        }
    }

    // Step 35: Handle script scheduling (async, defer, parser-blocking)
    if (script_type == .classic and !hasSrcAttribute(script_element)) {
        // Inline classic script - handle based on parser insertion

        if (parser_document) |pd| {
            const internal = HTMLScriptElementImpl.getInternal(script_element);
            if (internal) |int| {
                // Step 36.2: Check if we should defer to parser-blocking
                if (int.script_type == .classic) {
                    // Check if document has style sheet that is blocking scripts
                    // (not implemented - assume no blocking stylesheets)

                    // Step 36.3: Otherwise, immediately execute the script element
                    _ = executeScriptElement(allocator, script_element) catch {
                        // Execution error - but don't propagate, script errors are handled differently
                    };
                    return true;
                }
            }
            _ = pd;
        } else {
            // Not parser-inserted, execute immediately for inline classic scripts
            _ = executeScriptElement(allocator, script_element) catch {
                // Execution error
            };
            return true;
        }
    }

    return true;
}

/// Execute the script element
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#execute-the-script-element
///
/// Executes the prepared script using V8.
pub fn executeScriptElement(
    allocator: std.mem.Allocator,
    script_element: *runtime.Instance,
) ScriptExecutionError!void {
    _ = allocator;

    // Step 1: Let document be el's node document
    const node_document = getNodeDocument(script_element) orelse {
        return ScriptExecutionError.InvalidScriptElement;
    };

    // Step 2: If el's preparation-time document is not equal to document, return
    const prep_time_doc = HTMLScriptElementImpl.getPreparationTimeDocument(script_element);
    if (prep_time_doc != node_document) {
        return;
    }

    // Step 3: Unblock rendering (not implemented - no rendering engine)

    // Step 4: If el's result is null, fire error event and return
    const result = HTMLScriptElementImpl.getResult(script_element);
    switch (result) {
        .null => {
            // TODO: Fire error event
            return;
        },
        .uninitialized => {
            return ScriptExecutionError.InvalidScriptElement;
        },
        else => {},
    }

    // Step 5: If el's from an external file is true or type is "module",
    // increment ignore-destructive-writes counter
    const from_external = HTMLScriptElementImpl.isFromExternalFile(script_element);
    const script_type = HTMLScriptElementImpl.getScriptType(script_element);
    const should_increment_counter = from_external or script_type == .module;

    if (should_increment_counter) {
        DocumentImpl.incrementIgnoreDestructiveWritesCounter(node_document);
    }
    defer if (should_increment_counter) {
        DocumentImpl.decrementIgnoreDestructiveWritesCounter(node_document);
    };

    // Step 6: Execute based on script type
    switch (script_type) {
        .classic => {
            // Step 6.1: Let oldCurrentScript be document's currentScript
            const old_current_script = DocumentImpl.getCurrentScript(node_document);

            // Step 6.2: If el's root is not a shadow root, set currentScript to el
            // (We'll assume no shadow roots for now)
            DocumentImpl.setCurrentScript(node_document, script_element);

            // Step 6.3: Run the classic script
            runClassicScript(script_element) catch |err| {
                // Script execution error - log but don't propagate
                std.debug.print("Script execution error: {}\n", .{err});
            };

            // Step 6.4: Set currentScript back to oldCurrentScript
            DocumentImpl.setCurrentScript(node_document, old_current_script);
        },
        .module => {
            // Step 6.2: Run the module script
            // Not yet implemented
        },
        .importmap => {
            // Step 6.3: Register an import map
            // Not yet implemented
        },
        .speculationrules => {
            // Step 6.4: Register speculation rules
            // Not yet implemented
        },
        .null => {},
    }

    // Step 7: Decrement counter was handled with defer above

    // Step 8: If el's from an external file is true, fire load event
    if (from_external) {
        // TODO: Fire load event
    }
}

/// Run a classic script
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#run-a-classic-script
fn runClassicScript(script_element: *runtime.Instance) !void {
    const result = HTMLScriptElementImpl.getResult(script_element);
    const source = switch (result) {
        .script => |s| s.source_text,
        else => HTMLScriptElementImpl.getCachedSourceText(script_element) orelse return,
    };

    // Get V8 context from document/global
    // For now, we'll use a simplified execution path

    // Import V8 FFI
    const v8 = @import("v8");
    const ffi = v8.ffi;

    // Get current isolate
    const isolate = ffi.v8_Isolate_GetCurrent() orelse {
        std.debug.print("No V8 isolate available for script execution\n", .{});
        return;
    };

    // Get current context
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        std.debug.print("No V8 context available for script execution\n", .{});
        return;
    };

    // Create V8 string from source
    const source_str = ffi.v8_String_NewFromUtf8(
        isolate,
        source.ptr,
        @intCast(source.len),
    ) orelse {
        std.debug.print("Failed to create V8 string from script source\n", .{});
        return;
    };
    defer ffi.v8_String_Dispose(source_str);

    // Compile the script
    const script = ffi.v8_Script_Compile(context, source_str) orelse {
        std.debug.print("Failed to compile script\n", .{});
        // TODO: Fire error event with parse error details
        return;
    };
    defer ffi.v8_Script_Dispose(script);

    // Run the script
    _ = ffi.v8_Script_Run(context, script) orelse {
        std.debug.print("Script execution threw an exception\n", .{});
        // TODO: Handle script exceptions properly
        return;
    };
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Check if element has async attribute
fn hasAsyncAttribute(element: *runtime.Instance) bool {
    return hasAttribute(element, "async");
}

/// Check if element has defer attribute
fn hasDeferAttribute(element: *runtime.Instance) bool {
    return hasAttribute(element, "defer");
}

/// Check if element has src attribute
fn hasSrcAttribute(element: *runtime.Instance) bool {
    return hasAttribute(element, "src");
}

/// Get src attribute value
fn getSrcAttribute(element: *runtime.Instance) []const u8 {
    return getAttribute(element, "src") orelse "";
}

/// Check if element has nomodule attribute
fn hasNoModuleAttribute(element: *runtime.Instance) bool {
    return hasAttribute(element, "nomodule");
}

/// Check if element has event attribute (obsolete)
fn hasEventAttribute(element: *runtime.Instance) bool {
    return hasAttribute(element, "event");
}

/// Get event attribute value
fn getEventAttribute(element: *runtime.Instance) []const u8 {
    return getAttribute(element, "event") orelse "";
}

/// Check if element has for attribute (obsolete)
fn hasForAttribute(element: *runtime.Instance) bool {
    return hasAttribute(element, "for");
}

/// Get for attribute value
fn getForAttribute(element: *runtime.Instance) []const u8 {
    return getAttribute(element, "for") orelse "";
}

/// Generic attribute check
fn hasAttribute(element: *runtime.Instance, name: []const u8) bool {
    if (ElementImpl.getInternal(element)) |internal| {
        for (internal.attributes.items) |attr| {
            if (std.mem.eql(u8, attr.local_name.asSlice(), name)) {
                return true;
            }
        }
    }
    return false;
}

/// Generic attribute getter
fn getAttribute(element: *runtime.Instance, name: []const u8) ?[]const u8 {
    if (ElementImpl.getInternal(element)) |internal| {
        for (internal.attributes.items) |attr| {
            if (std.mem.eql(u8, attr.local_name.asSlice(), name)) {
                return attr.value.asSlice();
            }
        }
    }
    return null;
}

/// Get the type attribute value
fn getTypeAttribute(element: *runtime.Instance) []const u8 {
    return getAttribute(element, "type") orelse "";
}

/// Get the language attribute value (obsolete)
fn getLanguageAttribute(element: *runtime.Instance) []const u8 {
    return getAttribute(element, "language") orelse "";
}

/// Determine script type from type attribute
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#prepare-the-script-element (steps 8-13)
fn determineScriptType(element: *runtime.Instance) ScriptType {
    const type_attr = getTypeAttribute(element);
    const lang_attr = getLanguageAttribute(element);

    // Step 8: Determine the script block's type string
    var type_string: []const u8 = undefined;

    if (type_attr.len == 0) {
        // type attribute is empty or missing
        if (lang_attr.len == 0) {
            // No type, no language -> default to text/javascript
            type_string = "text/javascript";
        } else {
            // Has language attribute -> "text/" + language
            // For simplicity, we'll handle common cases
            if (std.ascii.eqlIgnoreCase(lang_attr, "javascript")) {
                type_string = "text/javascript";
            } else {
                // Unknown language type
                return .null;
            }
        }
    } else {
        // Use type attribute value, stripped of whitespace
        type_string = std.mem.trim(u8, type_attr, " \t\n\r\x0c");
    }

    // Step 9: If type string is a JavaScript MIME type essence match -> classic
    if (isJavaScriptMimeType(type_string)) {
        return .classic;
    }

    // Step 10: If type string is "module" (case-insensitive) -> module
    if (std.ascii.eqlIgnoreCase(type_string, "module")) {
        return .module;
    }

    // Step 11: If type string is "importmap" (case-insensitive) -> importmap
    if (std.ascii.eqlIgnoreCase(type_string, "importmap")) {
        return .importmap;
    }

    // Step 12: If type string is "speculationrules" (case-insensitive) -> speculationrules
    if (std.ascii.eqlIgnoreCase(type_string, "speculationrules")) {
        return .speculationrules;
    }

    // Step 13: Otherwise, no script is executed
    return .null;
}

/// Check if a MIME type is a JavaScript MIME type essence match
/// Spec: https://mimesniff.spec.whatwg.org/#javascript-mime-type
fn isJavaScriptMimeType(mime_type: []const u8) bool {
    const normalized = std.ascii.lowerString(mime_type[0..@min(mime_type.len, 64)]);
    const lower = normalized[0..@min(mime_type.len, 64)];

    // JavaScript MIME type essence matches
    const js_types = [_][]const u8{
        "application/ecmascript",
        "application/javascript",
        "application/x-ecmascript",
        "application/x-javascript",
        "text/ecmascript",
        "text/javascript",
        "text/javascript1.0",
        "text/javascript1.1",
        "text/javascript1.2",
        "text/javascript1.3",
        "text/javascript1.4",
        "text/javascript1.5",
        "text/jscript",
        "text/livescript",
        "text/x-ecmascript",
        "text/x-javascript",
    };

    for (js_types) |js_type| {
        if (std.mem.startsWith(u8, lower, js_type)) {
            // Check for exact match or parameters (;)
            if (lower.len == js_type.len or
                (lower.len > js_type.len and lower[js_type.len] == ';'))
            {
                return true;
            }
        }
    }

    return false;
}

/// Check if element is connected to a document
fn isConnected(element: *runtime.Instance) bool {
    // An element is connected if it has an owner document
    return getNodeDocument(element) != null;
}

/// Get the node's owner document
fn getNodeDocument(node: *runtime.Instance) ?*runtime.Instance {
    if (NodeImpl.getInternalState(node)) |internal| {
        return internal.owner_document;
    }
    return null;
}

/// Get child text content of an element
fn getChildTextContent(allocator: std.mem.Allocator, element: *runtime.Instance) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    try collectTextContent(element, &result);

    if (result.items.len == 0) {
        result.deinit();
        return "";
    }

    return try result.toOwnedSlice();
}

/// Recursively collect text content from a node and its descendants
fn collectTextContent(node: *runtime.Instance, result: *std.ArrayList(u8)) !void {
    const node_type = NodeImpl.getNodeType(node) orelse return;

    if (node_type == NodeImpl.NodeType.TEXT_NODE or
        node_type == NodeImpl.NodeType.CDATA_SECTION_NODE)
    {
        // Get text content from Text/CDATASection node
        const TextImpl = impls.Text;
        if (TextImpl.getInternal(node)) |internal| {
            try result.appendSlice(internal.data.asSlice());
        }
    } else {
        // Recurse into children
        var child = NodeImpl.getFirstChild(node);
        while (child) |c| {
            try collectTextContent(c, result);
            child = NodeImpl.getNextSibling(c);
        }
    }
}

// =============================================================================
// Tests
// =============================================================================

test "isJavaScriptMimeType" {
    try std.testing.expect(isJavaScriptMimeType("text/javascript"));
    try std.testing.expect(isJavaScriptMimeType("TEXT/JAVASCRIPT"));
    try std.testing.expect(isJavaScriptMimeType("text/javascript; charset=utf-8"));
    try std.testing.expect(isJavaScriptMimeType("application/javascript"));
    try std.testing.expect(isJavaScriptMimeType("application/ecmascript"));

    try std.testing.expect(!isJavaScriptMimeType("text/plain"));
    try std.testing.expect(!isJavaScriptMimeType("application/json"));
    try std.testing.expect(!isJavaScriptMimeType(""));
}
