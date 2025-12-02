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

// Fetch for external scripts
const fetch = @import("fetch");

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

        // Step 33.3: If src is empty, queue error event and return
        const src = getSrcAttribute(script_element);
        if (src.len == 0) {
            // Queue error event (TODO: proper event dispatch)
            return false;
        }

        // Step 33.4-33.7: Build script URL, set request parameters
        // Resolve src against base URL
        const base_url = if (node_document) |doc|
            if (DocumentImpl.getInternal(doc)) |internal| internal.base_uri else ""
        else
            "";

        const script_url = resolveUrl(allocator, src, base_url) catch {
            return ScriptExecutionError.OutOfMemory;
        };
        defer if (script_url.ptr != src.ptr) allocator.free(script_url);

        // Step 33.8: Fetch the script
        // This is a synchronous fetch for now - in a full implementation this would be async
        const fetch_result = fetchExternalScript(allocator, script_url) catch |err| {
            std.debug.print("External script fetch error: {}\n", .{err});
            return false;
        };

        if (fetch_result.body) |body| {
            defer allocator.free(body);

            // Create a classic script from the fetched content
            const script = ClassicScript.init(body, script_url);
            HTMLScriptElementImpl.setResult(script_element, .{ .script = script });

            // Cache source text for execution
            HTMLScriptElementImpl.cacheSourceText(script_element, body) catch {
                return ScriptExecutionError.OutOfMemory;
            };

            // Mark as ready to be parser-executed
            HTMLScriptElementImpl.setReadyToBeParserExecuted(script_element, true);
        } else {
            // Network error - set result to null
            HTMLScriptElementImpl.setResult(script_element, .null);
            return false;
        }

        // Handle scheduling (will set pending-parsing-blocking, etc.)
        return handleScriptScheduling(allocator, script_element, parser_document, script_type);
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

    // Step 35-36: Handle script scheduling based on type and attributes
    // Spec: https://html.spec.whatwg.org/multipage/scripting.html#prepare-the-script-element
    return handleScriptScheduling(allocator, script_element, parser_document, script_type);
}

/// Handle script scheduling based on script type, parser insertion, and attributes
/// Spec: Steps 35-36 of "prepare the script element"
fn handleScriptScheduling(
    allocator: std.mem.Allocator,
    script_element: *runtime.Instance,
    parser_document: ?*runtime.Instance,
    script_type: ScriptType,
) ScriptExecutionError!bool {
    const has_src = hasSrcAttribute(script_element);
    const has_async = hasAsyncAttribute(script_element);
    const has_defer = hasDeferAttribute(script_element);
    const internal = HTMLScriptElementImpl.getInternal(script_element);
    const force_async = if (internal) |int| int.force_async else true;

    const node_document = getNodeDocument(script_element);

    // Determine if parser-inserted
    const is_parser_inserted = parser_document != null;

    switch (script_type) {
        .classic => {
            if (!has_src) {
                // Inline classic script
                if (is_parser_inserted) {
                    // Parser-inserted inline classic script
                    // Step 36.2: Check if document has a style sheet that is blocking scripts
                    // (not implemented - assume no blocking stylesheets)

                    // Step 36.3: Immediately execute the script element
                    _ = executeScriptElement(allocator, script_element) catch {
                        // Script errors are handled internally
                    };
                    return true;
                } else {
                    // Non-parser-inserted inline classic script - execute immediately
                    _ = executeScriptElement(allocator, script_element) catch {};
                    return true;
                }
            } else {
                // External classic script (has src)
                if (is_parser_inserted and !has_async and !has_defer) {
                    // Parser-blocking external script
                    // Step 35.1: Set document's pending parsing-blocking script to el
                    if (node_document) |doc| {
                        DocumentImpl.setPendingParsingBlockingScript(doc, script_element);
                    }
                    // Mark as ready to be parser-executed when fetch completes
                    // (actual fetching not yet implemented)
                    return true;
                } else if (has_defer and is_parser_inserted and !has_async) {
                    // Deferred external script
                    // Step 35.2: Add to list of scripts that will execute when document finishes parsing
                    if (node_document) |doc| {
                        DocumentImpl.addScriptToExecuteWhenParsingFinished(doc, script_element);
                    }
                    return true;
                } else if (has_async and has_src) {
                    // Async external script
                    if (!force_async) {
                        // Step 35.3: Add to list of scripts that will execute in order
                        if (node_document) |doc| {
                            DocumentImpl.addScriptToExecuteInOrderAsap(doc, script_element);
                        }
                    } else {
                        // Step 35.4: Add to set of scripts that will execute ASAP
                        if (node_document) |doc| {
                            DocumentImpl.addScriptToExecuteAsap(doc, script_element);
                        }
                    }
                    return true;
                }
                // External script without special handling - return true but don't execute yet
                return true;
            }
        },
        .module => {
            // Module scripts have similar scheduling logic but with async modules
            if (!has_src) {
                // Inline module script - execute when ready
                // (Module dependency resolution not yet implemented)
                return false;
            } else {
                // External module script
                if (is_parser_inserted and !has_async) {
                    // Parser-blocking module script
                    if (node_document) |doc| {
                        DocumentImpl.setPendingParsingBlockingScript(doc, script_element);
                    }
                    return true;
                } else {
                    // Async module script
                    if (node_document) |doc| {
                        DocumentImpl.addScriptToExecuteAsap(doc, script_element);
                    }
                    return true;
                }
            }
        },
        .importmap => {
            // Import maps must be processed before any module scripts
            // Not yet implemented
            return false;
        },
        .speculationrules => {
            // Speculation rules for prefetching/prerendering
            // Not yet implemented
            return false;
        },
        .null => return false,
    }
}

/// Execute pending parser-blocking script if ready
/// Called by the parser after processing tokens
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#pending-parsing-blocking-script
pub fn executePendingParserBlockingScript(
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
) void {
    const pending_script = DocumentImpl.getPendingParsingBlockingScript(document) orelse return;

    // Check if the script is ready to execute
    if (!HTMLScriptElementImpl.isReadyToBeParserExecuted(pending_script)) {
        // Script is not ready yet (still fetching or waiting for dependencies)
        return;
    }

    // Clear pending parsing-blocking script
    DocumentImpl.setPendingParsingBlockingScript(document, null);

    // Execute the script
    _ = executeScriptElement(allocator, pending_script) catch |err| {
        std.debug.print("Parser-blocking script execution error: {}\n", .{err});
    };
}

/// Execute all scripts that should run when document finishes parsing
/// Called when the parser reaches the end of the document
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#the-end (step 3)
pub fn executeScriptsWhenParsingFinished(
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
) void {
    const scripts = DocumentImpl.getScriptsToExecuteWhenParsingFinished(document);

    for (scripts) |script| {
        // Execute each deferred script in order
        _ = executeScriptElement(allocator, script) catch |err| {
            std.debug.print("Deferred script execution error: {}\n", .{err});
        };
    }

    // Clear the list
    DocumentImpl.clearScriptsToExecuteWhenParsingFinished(document);
}

/// Execute scripts in the "execute in order ASAP" list
/// These are async scripts that were added with the async attribute
/// but need to maintain relative order
pub fn executeScriptsInOrderAsap(
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
) void {
    while (true) {
        const script = DocumentImpl.popFirstScriptToExecuteInOrderAsap(document) orelse break;

        // Check if ready
        if (!HTMLScriptElementImpl.isReadyToBeParserExecuted(script)) {
            // Re-add to list and stop - must maintain order
            DocumentImpl.addScriptToExecuteInOrderAsap(document, script);
            break;
        }

        _ = executeScriptElement(allocator, script) catch |err| {
            std.debug.print("In-order async script execution error: {}\n", .{err});
        };
    }
}

/// Execute scripts in the "execute ASAP" set
/// These can execute in any order as soon as they're ready
pub fn executeScriptsAsap(
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
) void {
    const scripts = DocumentImpl.getScriptsToExecuteAsap(document);

    // Find all ready scripts and execute them
    var i: usize = 0;
    while (i < scripts.len) {
        const script = scripts[i];
        if (HTMLScriptElementImpl.isReadyToBeParserExecuted(script)) {
            _ = DocumentImpl.removeScriptFromExecuteAsap(document, script);
            _ = executeScriptElement(allocator, script) catch |err| {
                std.debug.print("ASAP script execution error: {}\n", .{err});
            };
            // Don't increment i - list shifted
        } else {
            i += 1;
        }
    }
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
// External Script Loading
// =============================================================================

/// Result of fetching an external script
const ExternalScriptFetchResult = struct {
    body: ?[]const u8,
    content_type: ?[]const u8,
    status: u16,

    pub fn deinit(self: *ExternalScriptFetchResult, allocator: std.mem.Allocator) void {
        if (self.body) |b| allocator.free(b);
        if (self.content_type) |ct| allocator.free(ct);
    }
};

/// Resolve a URL relative to a base URL
/// For now, this is a simple implementation that handles absolute URLs
/// and simple relative paths
fn resolveUrl(allocator: std.mem.Allocator, url: []const u8, base_url: []const u8) ![]const u8 {
    // If URL starts with a scheme, it's absolute
    if (std.mem.indexOf(u8, url, "://") != null) {
        return url; // Return the original slice, don't allocate
    }

    // If URL starts with //, it's protocol-relative
    if (std.mem.startsWith(u8, url, "//")) {
        // Extract scheme from base URL
        if (std.mem.indexOf(u8, base_url, "://")) |scheme_end| {
            const scheme = base_url[0..scheme_end];
            const result = try allocator.alloc(u8, scheme.len + 1 + url.len);
            @memcpy(result[0..scheme.len], scheme);
            result[scheme.len] = ':';
            @memcpy(result[scheme.len + 1 ..], url);
            return result;
        }
        // Fallback to https
        const result = try allocator.alloc(u8, 6 + url.len);
        @memcpy(result[0..6], "https:");
        @memcpy(result[6..], url);
        return result;
    }

    // Relative URL - resolve against base
    if (base_url.len == 0) {
        return url; // Can't resolve without base
    }

    // Find the base path (everything up to and including the last /)
    var base_path_end: usize = 0;
    if (std.mem.lastIndexOf(u8, base_url, "/")) |last_slash| {
        base_path_end = last_slash + 1;
    }

    // If URL starts with /, it's root-relative
    if (std.mem.startsWith(u8, url, "/")) {
        // Find the origin (scheme + authority)
        if (std.mem.indexOf(u8, base_url, "://")) |scheme_end| {
            const after_scheme = scheme_end + 3; // Skip "://"
            const origin_end = if (std.mem.indexOfPos(u8, base_url, after_scheme, "/")) |slash|
                slash
            else
                base_url.len;

            const result = try allocator.alloc(u8, origin_end + url.len);
            @memcpy(result[0..origin_end], base_url[0..origin_end]);
            @memcpy(result[origin_end..], url);
            return result;
        }
        return url;
    }

    // Regular relative URL - append to base path
    const result = try allocator.alloc(u8, base_path_end + url.len);
    @memcpy(result[0..base_path_end], base_url[0..base_path_end]);
    @memcpy(result[base_path_end..], url);
    return result;
}

/// Fetch an external script using the Fetch API
/// This is a synchronous fetch for parser-blocking scripts
fn fetchExternalScript(allocator: std.mem.Allocator, url: []const u8) !ExternalScriptFetchResult {
    // Use the fetch module to retrieve the script
    const response = fetch.fetchSimple(allocator, url) catch |err| {
        std.debug.print("Fetch error for script {s}: {}\n", .{ url, err });
        return ExternalScriptFetchResult{
            .body = null,
            .content_type = null,
            .status = 0,
        };
    };
    defer response.deinit();

    // Check for successful response
    if (response.status < 200 or response.status >= 300) {
        return ExternalScriptFetchResult{
            .body = null,
            .content_type = null,
            .status = response.status,
        };
    }

    // Get Content-Type header
    var content_type: ?[]const u8 = null;
    if (response.header_list) |headers| {
        const ct_values = headers.getValues(allocator, "content-type") catch null;
        if (ct_values) |values| {
            if (values.len > 0) {
                content_type = try allocator.dupe(u8, values[0]);
            }
            for (values) |v| {
                allocator.free(v);
            }
            allocator.free(values);
        }
    }

    // Extract body
    var body: ?[]const u8 = null;
    if (response.body) |resp_body| {
        if (resp_body.bytes) |bytes| {
            body = try allocator.dupe(u8, bytes);
        }
    }

    return ExternalScriptFetchResult{
        .body = body,
        .content_type = content_type,
        .status = response.status,
    };
}

// =============================================================================
// Tests
// =============================================================================

test "resolveUrl - absolute URLs" {
    const allocator = std.testing.allocator;

    // Absolute URLs should be returned as-is (same pointer)
    const abs_url = "https://example.com/script.js";
    const resolved = try resolveUrl(allocator, abs_url, "https://other.com/page.html");
    try std.testing.expectEqual(abs_url.ptr, resolved.ptr);
}

test "resolveUrl - protocol-relative URLs" {
    const allocator = std.testing.allocator;

    const result = try resolveUrl(allocator, "//cdn.example.com/script.js", "https://example.com/page.html");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("https://cdn.example.com/script.js", result);
}

test "resolveUrl - root-relative URLs" {
    const allocator = std.testing.allocator;

    const result = try resolveUrl(allocator, "/scripts/app.js", "https://example.com/path/to/page.html");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("https://example.com/scripts/app.js", result);
}

test "resolveUrl - relative URLs" {
    const allocator = std.testing.allocator;

    const result = try resolveUrl(allocator, "lib.js", "https://example.com/scripts/");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("https://example.com/scripts/lib.js", result);
}

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
