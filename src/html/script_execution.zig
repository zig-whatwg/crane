//! Script Execution Module
//!
//! Implements the "prepare the script element" and "execute the script element"
//! algorithms from HTML Standard §4.12.1.1.
//!
//! Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
//!
//! This module provides the bridge between the HTML parser and the V8 JavaScript
//! engine for executing inline and external scripts.
//!
//! ## Architecture Note
//!
//! This module uses interfaces for all public API access per Golden Rule #12.
//! Internal state access is provided through interface delegate methods that
//! expose impl internal state in a controlled manner.

const std = @import("std");
const runtime = @import("runtime");

// WebIDL interfaces - used for all public API access per Golden Rule #12
const interfaces = @import("interfaces");

// Interface types used in this module
const HTMLScriptElement = interfaces.HTMLScriptElement;
const Document = interfaces.Document;
const Node = interfaces.Node;
const Element = interfaces.Element;
const Text = interfaces.Text;
const CharacterData = interfaces.CharacterData;

// Script element types re-exported from interface
const ScriptType = HTMLScriptElement.ScriptType;
const ScriptResult = HTMLScriptElement.ScriptResult;
const ClassicScript = HTMLScriptElement.ClassicScript;
const ModuleScript = HTMLScriptElement.ModuleScript;

// Infra primitives
const infra = @import("infra");

// Fetch for external scripts
const fetch = @import("fetch");

// Content Security Policy
const csp = @import("csp");

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
    if (HTMLScriptElement.hasAlreadyStarted(script_element)) {
        return false;
    }

    // Step 2: Let parser document be el's parser document
    const parser_document = HTMLScriptElement.getParserDocument(script_element);

    // Step 3: Set el's parser document to null
    HTMLScriptElement.setParserDocument(script_element, null);

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
        return false; // Abort on other errors
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
        HTMLScriptElement.setParserDocument(script_element, pd);
        HTMLScriptElement.clearForceAsync(script_element);
    }

    // Step 15: Set el's already started to true
    HTMLScriptElement.setAlreadyStarted(script_element, true);

    // Step 16: Set el's preparation-time document to its node document
    const node_document = getNodeDocument(script_element);
    HTMLScriptElement.setPreparationTimeDocument(script_element, node_document);

    // Step 17: If parser document is non-null and not equal to preparation-time document, return
    if (parser_document) |pd| {
        if (pd != node_document) {
            return false;
        }
    }

    // Step 18: If scripting is disabled for el, then return
    if (node_document) |doc| {
        if (!Document.isScriptingEnabled(doc)) {
            return false;
        }
    }

    // Step 19: If el has a nomodule attribute and type is "classic", return
    if (script_type == .classic and hasNoModuleAttribute(script_element)) {
        return false;
    }

    // Step 20: Let cspType be "script" if type is classic/module, "import map" if importmap
    // Step 21: CSP check for inline scripts
    // Spec: https://www.w3.org/TR/CSP3/ §6.7.3
    //
    // For inline scripts, we need to check:
    // - 'unsafe-inline' keyword (only if no nonce/hash in directive)
    // - Nonce matching (nonce attribute)
    // - Hash matching (computed from source text)
    if (!hasSrcAttribute(script_element)) {
        // This is an inline script
        if (node_document) |doc| {
            // Get nonce attribute if present
            const nonce = getNonceAttribute(script_element);

            // TODO: Compute hash of source text for hash-based CSP
            // For now, we only check nonce and 'unsafe-inline'

            // Check if inline script is allowed by CSP
            if (!Document.isInlineScriptAllowedByCSP(
                doc,
                if (nonce.len > 0) nonce else null,
                null, // hash_algorithm (TODO: compute from source)
                null, // hash_value (TODO: compute from source)
            )) {
                // CSP blocked inline script
                std.debug.print("CSP blocked inline script\n", .{});
                return false;
            }
        }
    }

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
    HTMLScriptElement.setScriptType(script_element, script_type);

    // Step 33: If el has a src attribute (external script)
    if (hasSrcAttribute(script_element)) {
        // External scripts - mark as from external file
        HTMLScriptElement.setFromExternalFile(script_element, true);

        // Step 33.3: If src is empty, queue error event and return
        const src = getSrcAttribute(script_element);
        if (src.len == 0) {
            // Queue error event (TODO: proper event dispatch)
            return false;
        }

        // Step 33.4-33.7: Build script URL, set request parameters
        // Resolve src against base URL
        const base_url = if (node_document) |doc|
            if (Document.getInternal(doc)) |internal| internal.base_uri else ""
        else
            "";

        const script_url = resolveUrl(allocator, src, base_url) catch {
            return ScriptExecutionError.OutOfMemory;
        };
        defer if (script_url.ptr != src.ptr) allocator.free(script_url);

        // CSP check for external script URL
        // Spec: https://www.w3.org/TR/CSP3/ §6.7.2
        if (node_document) |doc| {
            // Parse URL components for CSP check
            const url_parts = parseUrlForCSP(script_url);
            const nonce = getNonceAttribute(script_element);

            if (!Document.isExternalScriptAllowedByCSP(
                doc,
                url_parts.scheme,
                url_parts.host,
                url_parts.port,
                url_parts.path,
                if (nonce.len > 0) nonce else null,
            )) {
                // CSP blocked external script
                std.debug.print("CSP blocked external script: {s}\n", .{script_url});
                return false;
            }
        }

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
            HTMLScriptElement.setResult(script_element, .{ .script = script });

            // Cache source text for execution
            HTMLScriptElement.cacheSourceText(script_element, body) catch {
                return ScriptExecutionError.OutOfMemory;
            };

            // Mark as ready to be parser-executed
            HTMLScriptElement.setReadyToBeParserExecuted(script_element, true);
        } else {
            // Network error - set result to null
            HTMLScriptElement.setResult(script_element, .null);
            return false;
        }

        // Handle scheduling (will set pending-parsing-blocking, etc.)
        return handleScriptScheduling(allocator, script_element, parser_document, script_type);
    }

    // Step 34: Inline script (no src attribute)
    if (node_document) |doc| {
        const base_url = Document.getInternal(doc).?.base_uri;

        switch (script_type) {
            .classic => {
                // Step 34.2.1: Create a classic script
                const script = ClassicScript.init(source_text, base_url);

                // Step 34.2.2: Mark as ready
                HTMLScriptElement.setResult(script_element, .{ .script = script });

                // Cache the source text for execution
                HTMLScriptElement.cacheSourceText(script_element, source_text) catch {
                    return ScriptExecutionError.OutOfMemory;
                };
            },
            .module => {
                // Step 34.1: Create a module script
                const module = ModuleScript.init(source_text, base_url);

                // Set result
                HTMLScriptElement.setResult(script_element, .{ .module_script = module });

                // Cache source text for execution
                HTMLScriptElement.cacheSourceText(script_element, source_text) catch {
                    return ScriptExecutionError.OutOfMemory;
                };

                // Note: Module scripts still need dependency resolution before execution
                // For inline modules with no imports, we can execute directly
                // Full implementation would parse imports and fetch dependencies
            },
            .importmap => {
                // Parse and register import map
                // Spec: https://html.spec.whatwg.org/multipage/webappapis.html#import-map-parse-result

                // Step 1: Check if import map has already been acquired
                if (Document.hasImportMapAcquired(doc)) {
                    // Only one import map per document is allowed
                    // Subsequent import maps are ignored with a console warning
                    std.debug.print("Import map ignored: document already has an import map\n", .{});
                    return false;
                }

                // Step 2: Parse the import map JSON
                const import_map_result = parseImportMap(allocator, source_text, base_url);
                defer {
                    if (import_map_result.allocator) |alloc| {
                        if (import_map_result.error_message) |msg| {
                            alloc.free(msg);
                        }
                    }
                }

                if (import_map_result.error_message) |err_msg| {
                    std.debug.print("Import map parse error: {s}\n", .{err_msg});
                    return false;
                }

                // Step 3: Register the import map
                registerImportMap(doc, import_map_result) catch |err| {
                    std.debug.print("Failed to register import map: {}\n", .{err});
                    return false;
                };

                // Step 4: Mark import map as acquired
                Document.setImportMapAcquired(doc);

                return true;
            },
            .speculationrules => {
                // Parse and process speculation rules
                // Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html#speculation-rules

                // Step 1: Parse the speculation rules JSON
                const speculation_result = parseSpeculationRules(allocator, source_text, base_url);
                defer {
                    if (speculation_result.allocator) |alloc| {
                        if (speculation_result.error_message) |msg| {
                            alloc.free(msg);
                        }
                    }
                }

                if (speculation_result.error_message) |err_msg| {
                    std.debug.print("Speculation rules parse error: {s}\n", .{err_msg});
                    return false;
                }

                // Step 2: Register speculation rules with the document
                registerSpeculationRules(doc, speculation_result) catch |err| {
                    std.debug.print("Failed to register speculation rules: {}\n", .{err});
                    return false;
                };

                return true;
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
    const internal = HTMLScriptElement.getInternal(script_element);
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
                        Document.setPendingParsingBlockingScript(doc, script_element);
                    }
                    // Mark as ready to be parser-executed when fetch completes
                    // (actual fetching not yet implemented)
                    return true;
                } else if (has_defer and is_parser_inserted and !has_async) {
                    // Deferred external script
                    // Step 35.2: Add to list of scripts that will execute when document finishes parsing
                    if (node_document) |doc| {
                        Document.addScriptToExecuteWhenParsingFinished(doc, script_element) catch {};
                    }
                    return true;
                } else if (has_async and has_src) {
                    // Async external script
                    if (!force_async) {
                        // Step 35.3: Add to list of scripts that will execute in order
                        if (node_document) |doc| {
                            Document.addScriptToExecuteInOrderAsap(doc, script_element) catch {};
                        }
                    } else {
                        // Step 35.4: Add to set of scripts that will execute ASAP
                        if (node_document) |doc| {
                            Document.addScriptToExecuteAsap(doc, script_element) catch {};
                        }
                    }
                    return true;
                }
                // External script without special handling - return true but don't execute yet
                return true;
            }
        },
        .module => {
            // Module scripts are always deferred by default
            // Spec: https://html.spec.whatwg.org/multipage/scripting.html#attr-script-async
            if (!has_src) {
                // Inline module script
                if (is_parser_inserted and !has_async) {
                    // Parser-inserted inline module without async - defer until parsing finishes
                    if (node_document) |doc| {
                        Document.addScriptToExecuteWhenParsingFinished(doc, script_element) catch {};
                    }
                    return true;
                } else {
                    // Not parser-inserted or has async - execute immediately
                    // For inline modules with no imports, we can execute now
                    _ = executeScriptElement(allocator, script_element) catch {};
                    return true;
                }
            } else {
                // External module script
                if (is_parser_inserted and !has_async) {
                    // Parser-inserted external module - deferred by default
                    // Step 35.2: Add to list of scripts that will execute when document finishes parsing
                    if (node_document) |doc| {
                        Document.addScriptToExecuteWhenParsingFinished(doc, script_element) catch {};
                    }
                    return true;
                } else {
                    // Async external module script
                    if (node_document) |doc| {
                        Document.addScriptToExecuteAsap(doc, script_element) catch {};
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
    const pending_script = Document.getPendingParsingBlockingScript(document) orelse return;

    // Check if the script is ready to execute
    if (!HTMLScriptElement.isReadyToBeParserExecuted(pending_script)) {
        // Script is not ready yet (still fetching or waiting for dependencies)
        return;
    }

    // Clear pending parsing-blocking script
    Document.setPendingParsingBlockingScript(document, null);

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
    const scripts = Document.getScriptsToExecuteWhenParsingFinished(document);

    for (scripts) |script| {
        // Execute each deferred script in order
        _ = executeScriptElement(allocator, script) catch |err| {
            std.debug.print("Deferred script execution error: {}\n", .{err});
        };
    }

    // Clear the list
    Document.clearScriptsToExecuteWhenParsingFinished(document);
}

/// Execute scripts in the "execute in order ASAP" list
/// These are async scripts that were added with the async attribute
/// but need to maintain relative order
pub fn executeScriptsInOrderAsap(
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
) void {
    while (true) {
        const script = Document.popFirstScriptToExecuteInOrderAsap(document) orelse break;

        // Check if ready
        if (!HTMLScriptElement.isReadyToBeParserExecuted(script)) {
            // Re-add to list and stop - must maintain order
            Document.addScriptToExecuteInOrderAsap(document, script) catch {};
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
    const scripts = Document.getScriptsToExecuteAsap(document);

    // Find all ready scripts and execute them
    var i: usize = 0;
    while (i < scripts.len) {
        const script = scripts[i];
        if (HTMLScriptElement.isReadyToBeParserExecuted(script)) {
            _ = Document.removeScriptFromExecuteAsap(document, script);
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
    // Step 1: Let document be el's node document
    const node_document = getNodeDocument(script_element) orelse {
        return ScriptExecutionError.InvalidScriptElement;
    };

    // Step 2: If el's preparation-time document is not equal to document, return
    const prep_time_doc = HTMLScriptElement.getPreparationTimeDocument(script_element);
    if (prep_time_doc != node_document) {
        return;
    }

    // Step 3: Unblock rendering (not implemented - no rendering engine)

    // Step 4: If el's result is null, fire error event and return
    const result = HTMLScriptElement.getResult(script_element);
    switch (result) {
        .null => {
            // Fire error event per spec
            fireErrorEvent(allocator, script_element);
            return;
        },
        .uninitialized => {
            return ScriptExecutionError.InvalidScriptElement;
        },
        else => {},
    }

    // Step 5: If el's from an external file is true or type is "module",
    // increment ignore-destructive-writes counter
    const from_external = HTMLScriptElement.isFromExternalFile(script_element);
    const script_type = HTMLScriptElement.getScriptType(script_element);
    const should_increment_counter = from_external or script_type == .module;

    if (should_increment_counter) {
        Document.incrementIgnoreDestructiveWritesCounter(node_document);
    }
    defer if (should_increment_counter) {
        Document.decrementIgnoreDestructiveWritesCounter(node_document);
    };

    // Step 6: Execute based on script type
    switch (script_type) {
        .classic => {
            // Step 6.1: Let oldCurrentScript be document's currentScript
            const old_current_script = Document.getCurrentScript(node_document);

            // Step 6.2: If el's root is not a shadow root, set currentScript to el
            // (We'll assume no shadow roots for now)
            Document.setCurrentScript(node_document, script_element);

            // Step 6.3: Run the classic script
            runClassicScript(script_element) catch |err| {
                // Script execution error - log but don't propagate
                std.debug.print("Script execution error: {}\n", .{err});
            };

            // Step 6.4: Set currentScript back to oldCurrentScript
            Document.setCurrentScript(node_document, old_current_script);
        },
        .module => {
            // Step 6.2: Run the module script
            // Note: For module scripts, currentScript is always null (per spec)
            // Modules execute in strict mode and have their own scope

            runModuleScript(script_element) catch |err| {
                // Module execution error - log but don't propagate
                std.debug.print("Module script execution error: {}\n", .{err});
            };
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
        fireLoadEvent(allocator, script_element);
    }
}

/// Run a classic script
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#run-a-classic-script
fn runClassicScript(script_element: *runtime.Instance) !void {
    const result = HTMLScriptElement.getResult(script_element);
    const source = switch (result) {
        .script => |s| s.source_text,
        else => HTMLScriptElement.getCachedSourceText(script_element) orelse return,
    };

    // Get source URL for error messages
    const source_url: ?[]const u8 = switch (result) {
        .script => |s| if (s.base_url.len > 0) s.base_url else null,
        else => null,
    };

    // Get engine interface from the script element's context
    const ctx = script_element.ctx;
    const engine = ctx.getEngine() orelse {
        // No engine available (testing mode) - silently skip execution
        // This allows tests to run without V8 linked
        std.debug.print("No JS engine available for script execution (testing mode)\n", .{});
        return;
    };

    // Get engine context (V8 Context, JSC VM, etc.)
    const engine_ctx = ctx.getEngineContext() orelse {
        std.debug.print("No engine context available for script execution\n", .{});
        return;
    };

    // Compile the script using the engine interface
    const compileScript = engine.compileScript orelse {
        std.debug.print("Engine does not support script compilation\n", .{});
        return;
    };

    const script = compileScript(engine_ctx, source, source_url) catch |err| {
        std.debug.print("Script compilation error: {}\n", .{err});
        return;
    } orelse {
        // Compilation failed - fire error event at script element
        // Spec: https://html.spec.whatwg.org/multipage/scripting.html#execute-the-script-element
        // When compilation fails, fire error event with syntax error details
        const node_document = getNodeDocument(script_element);
        if (node_document) |doc| {
            if (Document.getInternal(doc)) |internal| {
                _ = event_utils.fireErrorEvent(
                    internal.allocator,
                    null,
                    script_element,
                    .{
                        .message = "Script compilation failed: syntax error",
                        .filename = source_url orelse "",
                        .lineno = 1, // Line number from engine if available
                        .colno = 0,
                        .@"error" = null,
                    },
                ) catch false;
            }
        }
        return;
    };

    // Dispose script when done
    defer {
        if (engine.disposeScript) |dispose| {
            dispose(script);
        }
    }

    // Run the script using the engine interface
    const runScript = engine.runScript orelse {
        std.debug.print("Engine does not support script execution\n", .{});
        return;
    };

    _ = runScript(engine_ctx, script) catch |err| {
        std.debug.print("Script execution error: {}\n", .{err});
        return;
    } orelse {
        // Script threw an uncaught exception
        // Spec: https://html.spec.whatwg.org/multipage/webappapis.html#report-an-exception
        //
        // Per spec, we should:
        // 1. Get the global object (Window)
        // 2. Fire an error event at the global
        // 3. Log to console if error wasn't handled
        //
        // For cross-origin scripts without CORS, error details should be muted per spec
        // ("Script error." message, no line/col info)
        const is_external = HTMLScriptElement.isFromExternalFile(script_element);
        const has_crossorigin = hasAttribute(script_element, "crossorigin");
        const is_muted = is_external and !has_crossorigin;

        if (is_muted) {
            // Cross-origin script without CORS - sanitize error per spec
            std.debug.print("Script error.\n", .{});
        } else {
            // Same-origin or CORS-enabled script - show full error
            std.debug.print("Uncaught error in script: {s}\n", .{source_url orelse "(inline)"});
        }

        // Fire error event at the script element itself (for load-time errors)
        // Runtime errors would go to window.onerror, but that requires Window integration
        const node_document = getNodeDocument(script_element);
        if (node_document) |doc| {
            if (Document.getInternal(doc)) |internal| {
                _ = event_utils.fireErrorEvent(
                    internal.allocator,
                    null,
                    script_element,
                    .{
                        .message = if (is_muted) "Script error." else "Uncaught exception",
                        .filename = if (is_muted) "" else source_url orelse "",
                        .lineno = 0, // Would be from engine exception info
                        .colno = 0,
                        .@"error" = null,
                    },
                ) catch false;
            }
        }
        return;
    };
}

/// Run a module script
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#run-a-module-script
fn runModuleScript(script_element: *runtime.Instance) !void {
    const result = HTMLScriptElement.getResult(script_element);
    const module_script = switch (result) {
        .module_script => |m| m,
        else => {
            // Try to get cached source and create inline module
            const source = HTMLScriptElement.getCachedSourceText(script_element) orelse return;
            return runModuleFromSource(script_element, source, "inline");
        },
    };

    return runModuleFromSource(script_element, module_script.source_text, module_script.base_url);
}

/// Run a module from source text using the engine-agnostic EngineInterface
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#run-a-module-script
///
/// This function supports top-level await (TLA) per TC39 proposal:
/// - For modules with TLA, uses runModuleAsync to get the evaluation Promise
/// - The Promise resolves when all TLA expressions complete
/// - Parent modules wait for async children before their own evaluation
///
/// See: https://tc39.es/proposal-top-level-await/
fn runModuleFromSource(
    script_element: *runtime.Instance,
    source: []const u8,
    base_url: []const u8,
) !void {
    // Get document for module map caching
    const node_document = getNodeDocument(script_element);

    // Check if this module is already compiled and cached
    if (node_document) |doc| {
        if (Document.hasModule(doc, base_url)) {
            // Module already compiled and executed - skip
            // Per spec, modules are only executed once
            return;
        }
    }

    // Get engine interface from the script element's context
    const ctx = script_element.ctx;
    const engine = ctx.getEngine() orelse {
        // No engine available (testing mode) - silently skip execution
        std.debug.print("No JS engine available for module execution (testing mode)\n", .{});
        return;
    };

    // Get engine context
    const engine_ctx = ctx.getEngineContext() orelse {
        std.debug.print("No engine context available for module execution\n", .{});
        return;
    };

    // Compile the module using the engine interface
    const compileModule = engine.compileModule orelse {
        std.debug.print("Engine does not support module compilation\n", .{});
        return;
    };

    const module = compileModule(engine_ctx, source, base_url) catch |err| {
        std.debug.print("Module compilation error: {}\n", .{err});
        return;
    } orelse {
        std.debug.print("Failed to compile ES module: {s}\n", .{base_url});
        return;
    };

    // Store in document's module map for caching and dependency resolution
    if (node_document) |doc| {
        Document.setModule(doc, base_url, module) catch |err| {
            std.debug.print("Failed to cache module: {}\n", .{err});
            // Continue execution even if caching fails
        };
    }

    // Check if module has top-level await (TLA)
    // Per TC39 spec, we need to use async evaluation for TLA modules
    const has_tla = if (engine.hasTopLevelAwait) |hasTLA|
        hasTLA(module)
    else
        false;

    if (has_tla) {
        // Module has TLA - use async evaluation
        // Per HTML spec "run a module script" step 7:
        // "If script's record is a Cyclic Module Record whose [[HasTLA]] is true,
        //  then the result of evaluating script's record is a promise."
        const runModuleAsync = engine.runModuleAsync orelse {
            // Fallback to sync execution if async not available
            std.debug.print("Engine does not support async module execution, falling back to sync\n", .{});
            return runModuleSync(engine, engine_ctx, module);
        };

        // Start async evaluation - returns a Promise
        const evaluation_promise = runModuleAsync(engine_ctx, module) catch |err| {
            std.debug.print("Module async evaluation error: {}\n", .{err});
            return;
        } orelse {
            std.debug.print("Failed to start async module evaluation: {s}\n", .{base_url});
            return;
        };

        // Chain handlers to the evaluation Promise
        // Per spec, we need to wait for TLA completion before the module is considered "evaluated"
        if (engine.chainPromiseHandlers) |chainHandlers| {
            // For now, we just log completion/rejection
            // A full implementation would:
            // 1. Update module status when Promise resolves
            // 2. Fire load/error events appropriately
            // 3. Unblock dependent modules waiting for this one
            chainHandlers(
                engine_ctx,
                evaluation_promise,
                tlaFulfillHandler,
                @ptrCast(@constCast(base_url.ptr)), // Pass URL for logging
                tlaRejectHandler,
                @ptrCast(@constCast(base_url.ptr)),
            ) catch |err| {
                std.debug.print("Failed to chain TLA handlers: {}\n", .{err});
            };
        }

        // Note: For parser-inserted modules, we may need to block further parsing
        // until TLA completes. This is handled by the module graph system.
    } else {
        // No TLA - use synchronous evaluation
        return runModuleSync(engine, engine_ctx, module);
    }
}

/// Synchronous module execution (for modules without TLA)
fn runModuleSync(
    engine: *const runtime.EngineInterface,
    engine_ctx: *anyopaque,
    module: *anyopaque,
) void {
    const runModule = engine.runModule orelse {
        std.debug.print("Engine does not support module execution\n", .{});
        return;
    };

    runModule(engine_ctx, module) catch |err| {
        std.debug.print("Module execution error: {}\n", .{err});
        return;
    };
}

/// Handler called when TLA module evaluation Promise fulfills
fn tlaFulfillHandler(context: ?*anyopaque, value: ?*anyopaque) callconv(.c) void {
    _ = value;
    // context contains the module URL for logging
    if (context) |ctx| {
        const url_ptr: [*]const u8 = @ptrCast(ctx);
        // We don't know the length, so just log that it completed
        _ = url_ptr;
        std.debug.print("TLA module evaluation completed successfully\n", .{});
    }
}

/// Handler called when TLA module evaluation Promise rejects
fn tlaRejectHandler(context: ?*anyopaque, reason: ?*anyopaque) callconv(.c) void {
    _ = reason;
    // context contains the module URL for logging
    if (context) |ctx| {
        const url_ptr: [*]const u8 = @ptrCast(ctx);
        _ = url_ptr;
        std.debug.print("TLA module evaluation failed\n", .{});
    }
}

/// Module resolution callback for V8
/// Called when V8 encounters an import statement and needs to resolve the specifier
///
/// NOTE: This callback is V8-specific and uses the V8 callconv. It is invoked by the
/// V8 engine during module instantiation. The callback mechanism is engine-specific,
/// but we use the EngineInterface for module compilation when available.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#resolve-a-module-specifier
fn moduleResolveCallback(
    user_data: ?*anyopaque,
    specifier: [*]const u8,
    specifier_len: c_int,
    referrer_module: ?*anyopaque,
) callconv(.c) ?*anyopaque {
    _ = referrer_module;

    // Get script element from user data (passed when setting up the callback)
    const script_element: *runtime.Instance = @ptrCast(@alignCast(user_data orelse return null));

    // Get the specifier as a Zig slice
    const specifier_slice = specifier[0..@intCast(specifier_len)];

    // Get document for import map resolution
    const node_document = getNodeDocument(script_element) orelse return null;

    // Get base URL for resolution
    const doc_internal = Document.getInternal(node_document) orelse return null;
    const base_url = doc_internal.base_uri;

    // Step 1: Try to resolve via import map
    var resolved_url: ?[]const u8 = Document.resolveImportSpecifier(
        node_document,
        specifier_slice,
        base_url,
    );

    // Step 2: If not found in import map, try URL resolution
    if (resolved_url == null) {
        // Check if it's a URL-like specifier (starts with /, ./, ../, or is absolute)
        if (isUrlLikeSpecifier(specifier_slice)) {
            // Resolve relative to base URL
            // For simplicity, just use the specifier as-is for absolute URLs
            // A full implementation would use proper URL resolution
            resolved_url = specifier_slice;
        } else {
            // Bare specifier without import map entry - error
            std.debug.print("Module specifier '{s}' could not be resolved\n", .{specifier_slice});
            return null;
        }
    }

    const final_url = resolved_url orelse return null;

    // Step 3: Check module map for cached module
    if (Document.getModule(node_document, final_url)) |cached_module| {
        return cached_module;
    }

    // Step 4: Module not in cache - need to fetch and compile
    // Get allocator for fetch
    const allocator = doc_internal.allocator;

    // Try to fetch the module (synchronous for now - ideally would be async)
    const fetch_result = fetchExternalScript(allocator, final_url) catch {
        std.debug.print("Failed to fetch module: {s}\n", .{final_url});
        return null;
    };

    if (fetch_result.body) |body| {
        defer allocator.free(body);

        // Use engine interface to compile the module
        const ctx = script_element.ctx;
        const engine = ctx.getEngine() orelse {
            std.debug.print("No JS engine available for module compilation\n", .{});
            return null;
        };

        const engine_ctx = ctx.getEngineContext() orelse {
            std.debug.print("No engine context available for module compilation\n", .{});
            return null;
        };

        const compileModule = engine.compileModule orelse {
            std.debug.print("Engine does not support module compilation\n", .{});
            return null;
        };

        const module = compileModule(engine_ctx, body, final_url) catch {
            std.debug.print("Failed to compile fetched module: {s}\n", .{final_url});
            return null;
        } orelse {
            std.debug.print("Failed to compile fetched module: {s}\n", .{final_url});
            return null;
        };

        // Cache in module map
        Document.setModule(node_document, final_url, module) catch {
            // Continue even if caching fails
        };

        return module;
    }

    std.debug.print("Module fetch returned no body: {s}\n", .{final_url});
    return null;
}

/// Check if a specifier looks like a URL (starts with /, ./, ../, or has a scheme)
fn isUrlLikeSpecifier(specifier: []const u8) bool {
    if (specifier.len == 0) return false;

    // Starts with /
    if (specifier[0] == '/') return true;

    // Starts with ./ or ../
    if (specifier.len >= 2 and specifier[0] == '.') {
        if (specifier[1] == '/') return true;
        if (specifier.len >= 3 and specifier[1] == '.' and specifier[2] == '/') return true;
    }

    // Has a scheme (e.g., https://, http://)
    if (std.mem.indexOf(u8, specifier, "://") != null) return true;

    return false;
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

/// Get nonce attribute value
/// Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#attr-nonce
fn getNonceAttribute(element: *runtime.Instance) []const u8 {
    return getAttribute(element, "nonce") orelse "";
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
    if (Element.getInternal(element)) |internal| {
        for (internal.attributes.items) |attr| {
            if (std.mem.eql(u8, attr.local_name, name)) {
                return true;
            }
        }
    }
    return false;
}

/// Generic attribute getter
fn getAttribute(element: *runtime.Instance, name: []const u8) ?[]const u8 {
    if (Element.getInternal(element)) |internal| {
        for (internal.attributes.items) |attr| {
            if (std.mem.eql(u8, attr.local_name, name)) {
                return attr.value;
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
    // Lowercase the input into a stack buffer
    var buffer: [64]u8 = undefined;
    const len = @min(mime_type.len, 64);
    const lower = std.ascii.lowerString(buffer[0..len], mime_type[0..len]);

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
    if (Node.getInternalState(node)) |internal| {
        return internal.owner_document;
    }
    return null;
}

/// Get child text content of an element
fn getChildTextContent(allocator: std.mem.Allocator, element: *runtime.Instance) ![]const u8 {
    var result = infra.List(u8).init(allocator);
    errdefer result.deinit();

    try collectTextContent(element, &result);

    if (result.size() == 0) {
        result.deinit();
        return "";
    }

    return try result.toOwnedSlice();
}

/// Recursively collect text content from a node and its descendants
fn collectTextContent(node: *runtime.Instance, result: *infra.List(u8)) !void {
    const node_type = Node.getNodeType(node) orelse return;

    if (node_type == Node.NodeType.TEXT_NODE or
        node_type == Node.NodeType.CDATA_SECTION_NODE)
    {
        // Get text content from Text/CDATASection node via CharacterData interface
        // Text and CDATASection inherit from CharacterData which stores the data
        const data = CharacterData.get_data(node) catch return;
        try result.appendSlice(data.asSlice());
    } else {
        // Recurse into children
        var child = Node.getFirstChild(node);
        while (child) |c| {
            try collectTextContent(c, result);
            child = Node.getNextSibling(c);
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
    // Check for "://" (http, https, etc.) or single-colon schemes (javascript:, data:, blob:, etc.)
    if (std.mem.indexOf(u8, url, "://") != null) {
        return url; // Return the original slice, don't allocate
    }

    // Check for single-colon schemes like javascript:, data:, blob:, mailto:, tel:, etc.
    // These are absolute URLs that should not be resolved relative to base
    if (std.mem.indexOf(u8, url, ":")) |colon_pos| {
        // Only treat as absolute if the scheme part contains only valid scheme characters (letters, digits, +, -, .)
        // and the colon is not at position 0
        if (colon_pos > 0) {
            const potential_scheme = url[0..colon_pos];
            var is_valid_scheme = true;
            for (potential_scheme) |c| {
                if (!std.ascii.isAlphanumeric(c) and c != '+' and c != '-' and c != '.') {
                    is_valid_scheme = false;
                    break;
                }
            }
            if (is_valid_scheme and std.ascii.isAlphabetic(potential_scheme[0])) {
                return url; // It's an absolute URL with a single-colon scheme
            }
        }
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

/// URL parts for CSP checking
const UrlPartsForCSP = struct {
    scheme: []const u8,
    host: []const u8,
    port: ?u16,
    path: []const u8,
};

/// Parse a URL into components for CSP checking
/// This is a simplified URL parser for CSP purposes.
fn parseUrlForCSP(url: []const u8) UrlPartsForCSP {
    var result = UrlPartsForCSP{
        .scheme = "",
        .host = "",
        .port = null,
        .path = "/",
    };

    // Find scheme (before ://)
    if (std.mem.indexOf(u8, url, "://")) |scheme_end| {
        result.scheme = url[0..scheme_end];

        // Find host (after :// and before / or : or end)
        const after_scheme = url[scheme_end + 3 ..];

        // Find end of authority (first / or end of string)
        var authority_end = after_scheme.len;
        if (std.mem.indexOf(u8, after_scheme, "/")) |slash| {
            authority_end = slash;
            result.path = after_scheme[slash..];
        }

        const authority = after_scheme[0..authority_end];

        // Check for port (: in authority)
        if (std.mem.lastIndexOf(u8, authority, ":")) |colon| {
            result.host = authority[0..colon];
            const port_str = authority[colon + 1 ..];
            result.port = std.fmt.parseInt(u16, port_str, 10) catch null;
        } else {
            result.host = authority;
        }
    }

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
    {
        const headers = &response.header_list;
        if (headers.getFirstValue("content-type")) |ct| {
            content_type = try allocator.dupe(u8, ct);
        }
    }

    // Extract body
    var body: ?[]const u8 = null;
    if (response.body) |resp_body| {
        if (resp_body.data.items.len > 0) {
            body = try allocator.dupe(u8, resp_body.data.items);
        }
    }

    return ExternalScriptFetchResult{
        .body = body,
        .content_type = content_type,
        .status = response.status,
    };
}

// =============================================================================
// Import Map Support (HTML Standard §8.1.6)
// =============================================================================

/// Result of parsing an import map
const ImportMapParseResult = struct {
    /// Imports mapping: bare specifier -> resolved URL
    imports: std.StringHashMap([]const u8),

    /// Scopes mapping: scope prefix -> (specifier -> URL)
    scopes: std.StringHashMap(std.StringHashMap([]const u8)),

    /// Error message if parsing failed
    error_message: ?[]const u8,

    /// Allocator used for error message (for cleanup)
    allocator: ?std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) ImportMapParseResult {
        return .{
            .imports = std.StringHashMap([]const u8).init(alloc),
            .scopes = std.StringHashMap(std.StringHashMap([]const u8)).init(alloc),
            .error_message = null,
            .allocator = null,
        };
    }

    pub fn deinit(self: *ImportMapParseResult, alloc: std.mem.Allocator) void {
        // Free imports
        var imp_it = self.imports.iterator();
        while (imp_it.next()) |entry| {
            alloc.free(entry.key_ptr.*);
            alloc.free(entry.value_ptr.*);
        }
        self.imports.deinit();

        // Free scopes
        var scope_it = self.scopes.iterator();
        while (scope_it.next()) |entry| {
            alloc.free(entry.key_ptr.*);
            var nested_it = entry.value_ptr.iterator();
            while (nested_it.next()) |nested_entry| {
                alloc.free(nested_entry.key_ptr.*);
                alloc.free(nested_entry.value_ptr.*);
            }
            entry.value_ptr.deinit();
        }
        self.scopes.deinit();
    }
};

/// Parse an import map JSON
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#parse-an-import-map-string
fn parseImportMap(
    allocator: std.mem.Allocator,
    json_text: []const u8,
    base_url: []const u8,
) ImportMapParseResult {
    var result = ImportMapParseResult.init(allocator);

    // Parse JSON
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_text, .{}) catch {
        result.error_message = allocator.dupe(u8, "Invalid JSON in import map") catch null;
        result.allocator = allocator;
        return result;
    };
    defer parsed.deinit();

    const root = parsed.value;

    // Import map must be an object
    if (root != .object) {
        result.error_message = allocator.dupe(u8, "Import map must be a JSON object") catch null;
        result.allocator = allocator;
        return result;
    }

    const root_obj = root.object;

    // Process "imports" if present
    if (root_obj.get("imports")) |imports_value| {
        if (imports_value == .object) {
            var imp_it = imports_value.object.iterator();
            while (imp_it.next()) |entry| {
                const specifier = entry.key_ptr.*;
                if (entry.value_ptr.* == .string) {
                    const target = entry.value_ptr.string;

                    // Resolve target URL relative to base URL
                    const resolved = resolveUrl(allocator, target, base_url) catch continue;

                    // Store owned copies
                    const owned_specifier = allocator.dupe(u8, specifier) catch continue;
                    const owned_url = if (resolved.ptr != target.ptr)
                        resolved
                    else
                        allocator.dupe(u8, resolved) catch continue;

                    result.imports.put(owned_specifier, owned_url) catch {
                        allocator.free(owned_specifier);
                        if (resolved.ptr != target.ptr) allocator.free(resolved);
                        continue;
                    };
                }
            }
        }
    }

    // Process "scopes" if present
    if (root_obj.get("scopes")) |scopes_value| {
        if (scopes_value == .object) {
            var scope_it = scopes_value.object.iterator();
            while (scope_it.next()) |scope_entry| {
                const scope_prefix = scope_entry.key_ptr.*;
                if (scope_entry.value_ptr.* == .object) {
                    // Resolve scope prefix URL
                    const resolved_scope = resolveUrl(allocator, scope_prefix, base_url) catch continue;
                    const owned_scope = if (resolved_scope.ptr != scope_prefix.ptr)
                        resolved_scope
                    else
                        allocator.dupe(u8, resolved_scope) catch continue;

                    var scope_imports = std.StringHashMap([]const u8).init(allocator);

                    var inner_it = scope_entry.value_ptr.object.iterator();
                    while (inner_it.next()) |inner_entry| {
                        const specifier = inner_entry.key_ptr.*;
                        if (inner_entry.value_ptr.* == .string) {
                            const target = inner_entry.value_ptr.string;

                            // Resolve target URL relative to base URL
                            const resolved = resolveUrl(allocator, target, base_url) catch continue;

                            const owned_specifier = allocator.dupe(u8, specifier) catch continue;
                            const owned_url = if (resolved.ptr != target.ptr)
                                resolved
                            else
                                allocator.dupe(u8, resolved) catch continue;

                            scope_imports.put(owned_specifier, owned_url) catch {
                                allocator.free(owned_specifier);
                                if (resolved.ptr != target.ptr) allocator.free(resolved);
                                continue;
                            };
                        }
                    }

                    result.scopes.put(owned_scope, scope_imports) catch {
                        allocator.free(owned_scope);
                        // Free scope_imports contents
                        var cleanup_it = scope_imports.iterator();
                        while (cleanup_it.next()) |cleanup_entry| {
                            allocator.free(cleanup_entry.key_ptr.*);
                            allocator.free(cleanup_entry.value_ptr.*);
                        }
                        scope_imports.deinit();
                        continue;
                    };
                }
            }
        }
    }

    return result;
}

/// Register an import map with the document
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#register-an-import-map
fn registerImportMap(
    doc: *runtime.Instance,
    import_map: ImportMapParseResult,
) !void {
    // Register all top-level imports
    var imp_it = import_map.imports.iterator();
    while (imp_it.next()) |entry| {
        try Document.addImportMapping(doc, entry.key_ptr.*, entry.value_ptr.*);
    }

    // Register all scoped imports
    var scope_it = import_map.scopes.iterator();
    while (scope_it.next()) |scope_entry| {
        var inner_it = scope_entry.value_ptr.iterator();
        while (inner_it.next()) |inner_entry| {
            try Document.addScopedImportMapping(
                doc,
                scope_entry.key_ptr.*,
                inner_entry.key_ptr.*,
                inner_entry.value_ptr.*,
            );
        }
    }
}

// =============================================================================
// Speculation Rules Support (HTML Standard §7.6.1)
// =============================================================================

/// Speculation rule eagerness levels
/// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html#speculation-rule-eagerness
pub const SpeculationEagerness = enum {
    immediate,
    eager,
    moderate,
    conservative,
};

/// A single speculation rule
/// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html#speculation-rule
pub const SpeculationRule = struct {
    /// URLs to prefetch/prerender (for list-based rules)
    urls: infra.List([]const u8),

    /// Eagerness level
    eagerness: SpeculationEagerness,

    /// Referrer policy override (empty string means use default)
    referrer_policy: []const u8,

    /// Tags for this rule
    tags: infra.List([]const u8),

    /// Whether anonymous client IP is required for cross-origin
    requires_anonymous_client_ip: bool,

    pub fn init(allocator: std.mem.Allocator) SpeculationRule {
        return .{
            .urls = infra.List([]const u8).init(allocator),
            .eagerness = .immediate,
            .referrer_policy = "",
            .tags = infra.List([]const u8).init(allocator),
            .requires_anonymous_client_ip = false,
        };
    }

    pub fn deinit(self: *SpeculationRule, allocator: std.mem.Allocator) void {
        for (0..self.urls.len) |i| {
            if (self.urls.get(i)) |url| {
                allocator.free(url);
            }
        }
        self.urls.deinit();
        for (0..self.tags.len) |i| {
            if (self.tags.get(i)) |tag| {
                allocator.free(tag);
            }
        }
        self.tags.deinit();
        if (self.referrer_policy.len > 0) {
            allocator.free(self.referrer_policy);
        }
    }
};

/// Result of parsing speculation rules
const SpeculationRulesParseResult = struct {
    /// Prefetch rules
    prefetch_rules: infra.List(SpeculationRule),

    /// Prerender rules (treated same as prefetch for now)
    prerender_rules: infra.List(SpeculationRule),

    /// Top-level tag (optional)
    tag: ?[]const u8,

    /// Error message if parsing failed
    error_message: ?[]const u8,

    /// Allocator used for error message (for cleanup)
    allocator: ?std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) SpeculationRulesParseResult {
        return .{
            .prefetch_rules = infra.List(SpeculationRule).init(alloc),
            .prerender_rules = infra.List(SpeculationRule).init(alloc),
            .tag = null,
            .error_message = null,
            .allocator = null,
        };
    }

    pub fn deinit(self: *SpeculationRulesParseResult, alloc: std.mem.Allocator) void {
        for (0..self.prefetch_rules.len) |i| {
            if (self.prefetch_rules.get(i)) |*rule| {
                @constCast(rule).deinit(alloc);
            }
        }
        self.prefetch_rules.deinit();
        for (0..self.prerender_rules.len) |i| {
            if (self.prerender_rules.get(i)) |*rule| {
                @constCast(rule).deinit(alloc);
            }
        }
        self.prerender_rules.deinit();
        if (self.tag) |tag| {
            alloc.free(tag);
        }
    }
};

/// Parse speculation rules JSON
/// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html#parse-a-speculation-rule-set-string
fn parseSpeculationRules(
    allocator: std.mem.Allocator,
    json_text: []const u8,
    base_url: []const u8,
) SpeculationRulesParseResult {
    var result = SpeculationRulesParseResult.init(allocator);

    // Step 1: Parse JSON
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_text, .{}) catch {
        result.error_message = allocator.dupe(u8, "Invalid JSON in speculation rules") catch null;
        result.allocator = allocator;
        return result;
    };
    defer parsed.deinit();

    const root = parsed.value;

    // Step 2: Must be an object
    if (root != .object) {
        result.error_message = allocator.dupe(u8, "Speculation rules must be a JSON object") catch null;
        result.allocator = allocator;
        return result;
    }

    const root_obj = root.object;

    // Step 4-5: Get top-level tag if present
    if (root_obj.get("tag")) |tag_value| {
        if (tag_value == .string) {
            result.tag = allocator.dupe(u8, tag_value.string) catch null;
        }
    }

    // Step 7-8: Process "prefetch" and "prerender" arrays
    const rule_types = [_][]const u8{ "prefetch", "prerender" };

    for (rule_types) |rule_type| {
        if (root_obj.get(rule_type)) |rules_value| {
            if (rules_value == .array) {
                for (rules_value.array.items) |rule_value| {
                    const rule = parseSpeculationRule(allocator, rule_value, result.tag, base_url) orelse continue;
                    if (std.mem.eql(u8, rule_type, "prefetch")) {
                        result.prefetch_rules.append(rule) catch continue;
                    } else {
                        result.prerender_rules.append(rule) catch continue;
                    }
                }
            }
        }
    }

    return result;
}

/// Parse a single speculation rule
/// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html#parse-a-speculation-rule
fn parseSpeculationRule(
    allocator: std.mem.Allocator,
    input: std.json.Value,
    ruleset_tag: ?[]const u8,
    base_url: []const u8,
) ?SpeculationRule {
    // Step 1: Must be an object
    if (input != .object) {
        return null;
    }

    const obj = input.object;

    var rule = SpeculationRule.init(allocator);
    errdefer rule.deinit(allocator);

    // Step 3-7: Determine source (list or document)
    var source: ?[]const u8 = null;
    if (obj.get("source")) |source_value| {
        if (source_value == .string) {
            source = source_value.string;
        }
    }

    // Infer source if not provided
    if (source == null) {
        if (obj.get("urls") != null and obj.get("where") == null) {
            source = "list";
        } else if (obj.get("where") != null and obj.get("urls") == null) {
            source = "document";
        }
    }

    // Step 8-10: Parse URLs for list-based rules
    if (source != null and std.mem.eql(u8, source.?, "list")) {
        if (obj.get("urls")) |urls_value| {
            if (urls_value == .array) {
                for (urls_value.array.items) |url_value| {
                    if (url_value == .string) {
                        // Resolve URL relative to base
                        const resolved = resolveUrl(allocator, url_value.string, base_url) catch continue;
                        const owned_url = if (resolved.ptr != url_value.string.ptr)
                            resolved
                        else
                            allocator.dupe(u8, resolved) catch continue;

                        // Validate it's HTTP(S)
                        if (std.mem.startsWith(u8, owned_url, "http://") or
                            std.mem.startsWith(u8, owned_url, "https://"))
                        {
                            rule.urls.append(owned_url) catch {
                                allocator.free(owned_url);
                                continue;
                            };
                        } else {
                            allocator.free(owned_url);
                        }
                    }
                }
            }
        }
    }

    // Step 12-13: Parse eagerness
    if (obj.get("eagerness")) |eagerness_value| {
        if (eagerness_value == .string) {
            const eagerness_str = eagerness_value.string;
            if (std.mem.eql(u8, eagerness_str, "immediate")) {
                rule.eagerness = .immediate;
            } else if (std.mem.eql(u8, eagerness_str, "eager")) {
                rule.eagerness = .eager;
            } else if (std.mem.eql(u8, eagerness_str, "moderate")) {
                rule.eagerness = .moderate;
            } else if (std.mem.eql(u8, eagerness_str, "conservative")) {
                rule.eagerness = .conservative;
            } else {
                // Invalid eagerness
                return null;
            }
        }
    } else {
        // Default: immediate for list, conservative for document
        if (source != null and std.mem.eql(u8, source.?, "list")) {
            rule.eagerness = .immediate;
        } else {
            rule.eagerness = .conservative;
        }
    }

    // Step 14-15: Parse referrer policy
    if (obj.get("referrer_policy")) |rp_value| {
        if (rp_value == .string) {
            rule.referrer_policy = allocator.dupe(u8, rp_value.string) catch "";
        }
    }

    // Step 16-20: Parse tags
    if (ruleset_tag) |tag| {
        const owned_tag = allocator.dupe(u8, tag) catch null;
        if (owned_tag) |t| {
            rule.tags.append(t) catch {};
        }
    }
    if (obj.get("tag")) |tag_value| {
        if (tag_value == .string) {
            const owned_tag = allocator.dupe(u8, tag_value.string) catch null;
            if (owned_tag) |t| {
                rule.tags.append(t) catch {};
            }
        }
    }

    // Step 21-22: Parse requirements
    if (obj.get("requires")) |req_value| {
        if (req_value == .array) {
            for (req_value.array.items) |req| {
                if (req == .string) {
                    if (std.mem.eql(u8, req.string, "anonymous-client-ip-when-cross-origin")) {
                        rule.requires_anonymous_client_ip = true;
                    }
                }
            }
        }
    }

    return rule;
}

/// Convert local SpeculationEagerness to Document.SpeculationEagerness
fn toDocumentEagerness(eagerness: SpeculationEagerness) Document.SpeculationEagerness {
    return switch (eagerness) {
        .immediate => .immediate,
        .eager => .eager,
        .moderate => .moderate,
        .conservative => .conservative,
    };
}

/// Register speculation rules with the document
/// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html#consider-speculative-loads
fn registerSpeculationRules(
    doc: *runtime.Instance,
    rules: SpeculationRulesParseResult,
) !void {
    // For now, we just store the prefetch URLs in the document
    // A full implementation would:
    // 1. Add to document's speculation rule sets
    // 2. Consider speculative loads (queue microtask)
    // 3. Match against links in the document for document rules
    // 4. Actually initiate prefetch requests

    // Store prefetch URLs for potential use
    for (0..rules.prefetch_rules.len) |i| {
        const rule = rules.prefetch_rules.get(i) orelse continue;
        for (0..rule.urls.len) |j| {
            const url = rule.urls.get(j) orelse continue;
            // Add to document's prefetch hints
            // Convert local eagerness type to Document's eagerness type
            Document.addPrefetchHint(doc, url, toDocumentEagerness(rule.eagerness)) catch continue;
        }
    }

    // Prerender rules are treated similarly (prefetch for now)
    for (0..rules.prerender_rules.len) |i| {
        const rule = rules.prerender_rules.get(i) orelse continue;
        for (0..rule.urls.len) |j| {
            const url = rule.urls.get(j) orelse continue;
            Document.addPrefetchHint(doc, url, toDocumentEagerness(rule.eagerness)) catch continue;
        }
    }

    std.debug.print("Registered {d} prefetch rules and {d} prerender rules\n", .{
        rules.prefetch_rules.len,
        rules.prerender_rules.len,
    });
}

// =============================================================================
// Event Firing for Script Elements
// =============================================================================

// Event utilities for proper event creation and dispatch
const event_utils = @import("event_utils.zig");

/// Fire a load event on a script element
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#execute-the-script-element (step 8)
///
/// The load event is fired after successful script execution to indicate
/// the script has loaded and executed successfully.
pub fn fireLoadEvent(allocator: std.mem.Allocator, script_element: *runtime.Instance) void {
    // Fire a simple "load" event - not cancelable, doesn't bubble
    event_utils.fireSimpleEvent(allocator, null, script_element, "load") catch |err| {
        std.debug.print("Failed to fire load event: {any}\n", .{err});
    };
}

/// Fire an error event on a script element
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#prepare-the-script-element
///
/// The error event is fired when:
/// - Script source cannot be loaded (network error, 404, etc.)
/// - Script type is not supported
/// - URL parsing fails
/// - CSP blocks the script
///
/// Note: This is different from reportScriptError which handles runtime errors.
/// This function handles load-time errors.
pub fn fireErrorEvent(allocator: std.mem.Allocator, script_element: *runtime.Instance) void {
    // Fire a simple "error" event - not cancelable by default for load errors
    event_utils.fireSimpleEvent(allocator, null, script_element, "error") catch |err| {
        std.debug.print("Failed to fire error event: {any}\n", .{err});
    };
}

/// Report a script execution error
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#report-an-exception
///
/// This is called when a script throws an exception during execution.
/// The error event is fired at the global object, not the script element.
///
/// Parameters:
/// - allocator: Memory allocator
/// - global: The global object (Window or WorkerGlobalScope)
/// - message: The error message
/// - filename: URL of the script where the error occurred
/// - lineno: Line number where the error occurred
/// - colno: Column number where the error occurred
/// - error_value: The JavaScript error object (may be null for muted errors)
/// - muted_errors: Whether this script has muted errors (cross-origin without CORS)
pub fn reportScriptError(
    allocator: std.mem.Allocator,
    global: *runtime.Instance,
    message: ?[]const u8,
    filename: ?[]const u8,
    lineno: ?u32,
    colno: ?u32,
    error_value: ?*const anyopaque,
    muted_errors: bool,
) void {
    _ = event_utils.reportException(
        allocator,
        null,
        global,
        error_value,
        message,
        filename,
        lineno,
        colno,
        muted_errors,
        false, // omit_error = false
    ) catch |err| {
        std.debug.print("Failed to report script error: {any}\n", .{err});
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

// =============================================================================
// Import Map Tests
// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#import-maps
// =============================================================================

test "parseImportMap - basic bare specifier mapping" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "imports": {
        \\    "lodash": "https://cdn.example.com/lodash/v4.17.21/lodash.min.js",
        \\    "react": "https://cdn.example.com/react/v18.2.0/react.min.js"
        \\  }
        \\}
    ;

    var result = parseImportMap(allocator, json, "https://example.com/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 2), result.imports.count());
    try std.testing.expectEqualStrings(
        "https://cdn.example.com/lodash/v4.17.21/lodash.min.js",
        result.imports.get("lodash").?,
    );
    try std.testing.expectEqualStrings(
        "https://cdn.example.com/react/v18.2.0/react.min.js",
        result.imports.get("react").?,
    );
}

test "parseImportMap - relative URL resolution" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "imports": {
        \\    "utils": "lib/utils.js",
        \\    "helpers": "/scripts/helpers.js"
        \\  }
        \\}
    ;

    var result = parseImportMap(allocator, json, "https://example.com/app/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 2), result.imports.count());

    // Relative URL should be resolved against base URL
    try std.testing.expectEqualStrings(
        "https://example.com/app/lib/utils.js",
        result.imports.get("utils").?,
    );

    // Root-relative URL
    try std.testing.expectEqualStrings(
        "https://example.com/scripts/helpers.js",
        result.imports.get("helpers").?,
    );
}

test "parseImportMap - scoped imports" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "imports": {
        \\    "lodash": "https://cdn.example.com/lodash/v4.js"
        \\  },
        \\  "scopes": {
        \\    "/app/": {
        \\      "lodash": "https://cdn.example.com/lodash/v5.js"
        \\    }
        \\  }
        \\}
    ;

    var result = parseImportMap(allocator, json, "https://example.com/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 1), result.imports.count());
    try std.testing.expectEqual(@as(usize, 1), result.scopes.count());

    // Top-level import
    try std.testing.expectEqualStrings(
        "https://cdn.example.com/lodash/v4.js",
        result.imports.get("lodash").?,
    );

    // Scoped import - different version for /app/ paths
    const app_scope = result.scopes.get("https://example.com/app/");
    try std.testing.expect(app_scope != null);
    try std.testing.expectEqualStrings(
        "https://cdn.example.com/lodash/v5.js",
        app_scope.?.get("lodash").?,
    );
}

test "parseImportMap - empty imports object" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "imports": {}
        \\}
    ;

    var result = parseImportMap(allocator, json, "https://example.com/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 0), result.imports.count());
}

test "parseImportMap - invalid JSON" {
    const allocator = std.testing.allocator;

    const json = "{ invalid json }";

    const result = parseImportMap(allocator, json, "https://example.com/");
    defer {
        if (result.allocator) |alloc| {
            if (result.error_message) |msg| {
                alloc.free(msg);
            }
        }
    }

    try std.testing.expect(result.error_message != null);
    try std.testing.expectEqualStrings("Invalid JSON in import map", result.error_message.?);
}

test "parseImportMap - non-object root" {
    const allocator = std.testing.allocator;

    const json = "[\"array\", \"not\", \"object\"]";

    const result = parseImportMap(allocator, json, "https://example.com/");
    defer {
        if (result.allocator) |alloc| {
            if (result.error_message) |msg| {
                alloc.free(msg);
            }
        }
    }

    try std.testing.expect(result.error_message != null);
    try std.testing.expectEqualStrings("Import map must be a JSON object", result.error_message.?);
}

test "parseImportMap - package subpath imports" {
    const allocator = std.testing.allocator;

    // Common pattern: package name with trailing slash for subpath imports
    const json =
        \\{
        \\  "imports": {
        \\    "lodash/": "https://cdn.example.com/lodash/",
        \\    "lodash": "https://cdn.example.com/lodash/index.js"
        \\  }
        \\}
    ;

    var result = parseImportMap(allocator, json, "https://example.com/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 2), result.imports.count());

    // Base import
    try std.testing.expectEqualStrings(
        "https://cdn.example.com/lodash/index.js",
        result.imports.get("lodash").?,
    );

    // Subpath prefix (trailing slash allows lodash/debounce -> cdn.example.com/lodash/debounce)
    try std.testing.expectEqualStrings(
        "https://cdn.example.com/lodash/",
        result.imports.get("lodash/").?,
    );
}

test "parseImportMap - multiple scopes" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "imports": {
        \\    "react": "https://cdn.example.com/react/v17.js"
        \\  },
        \\  "scopes": {
        \\    "/new-app/": {
        \\      "react": "https://cdn.example.com/react/v18.js"
        \\    },
        \\    "/legacy/": {
        \\      "react": "https://cdn.example.com/react/v16.js"
        \\    }
        \\  }
        \\}
    ;

    var result = parseImportMap(allocator, json, "https://example.com/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 2), result.scopes.count());

    // New app gets React 18
    const new_app_scope = result.scopes.get("https://example.com/new-app/");
    try std.testing.expect(new_app_scope != null);
    try std.testing.expectEqualStrings(
        "https://cdn.example.com/react/v18.js",
        new_app_scope.?.get("react").?,
    );

    // Legacy app gets React 16
    const legacy_scope = result.scopes.get("https://example.com/legacy/");
    try std.testing.expect(legacy_scope != null);
    try std.testing.expectEqualStrings(
        "https://cdn.example.com/react/v16.js",
        legacy_scope.?.get("react").?,
    );
}

test "isUrlLikeSpecifier - URL-like specifiers" {
    // Absolute URLs with schemes
    try std.testing.expect(isUrlLikeSpecifier("https://example.com/module.js"));
    try std.testing.expect(isUrlLikeSpecifier("http://example.com/module.js"));

    // Root-relative
    try std.testing.expect(isUrlLikeSpecifier("/scripts/module.js"));

    // Relative
    try std.testing.expect(isUrlLikeSpecifier("./module.js"));
    try std.testing.expect(isUrlLikeSpecifier("../module.js"));
    try std.testing.expect(isUrlLikeSpecifier("./path/to/module.js"));

    // Bare specifiers (should NOT be URL-like)
    try std.testing.expect(!isUrlLikeSpecifier("lodash"));
    try std.testing.expect(!isUrlLikeSpecifier("react"));
    try std.testing.expect(!isUrlLikeSpecifier("@scoped/package"));
    try std.testing.expect(!isUrlLikeSpecifier("module-name"));
}

// =============================================================================
// Speculation Rules Tests
// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html
// =============================================================================

test "parseSpeculationRules - basic prefetch rule" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "prefetch": [
        \\    {
        \\      "source": "list",
        \\      "urls": ["https://example.com/page1", "https://example.com/page2"]
        \\    }
        \\  ]
        \\}
    ;

    const result = parseSpeculationRules(allocator, json, "https://example.com/");
    defer @constCast(&result).deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 1), result.prefetch_rules.len);

    const rule = result.prefetch_rules.get(0).?;
    try std.testing.expectEqual(@as(usize, 2), rule.urls.len);
    try std.testing.expectEqualStrings("https://example.com/page1", rule.urls.get(0).?);
    try std.testing.expectEqualStrings("https://example.com/page2", rule.urls.get(1).?);
    try std.testing.expectEqual(SpeculationEagerness.immediate, rule.eagerness);
}

test "parseSpeculationRules - eagerness levels" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "prefetch": [
        \\    {
        \\      "urls": ["https://example.com/eager"],
        \\      "eagerness": "eager"
        \\    },
        \\    {
        \\      "urls": ["https://example.com/moderate"],
        \\      "eagerness": "moderate"
        \\    },
        \\    {
        \\      "urls": ["https://example.com/conservative"],
        \\      "eagerness": "conservative"
        \\    }
        \\  ]
        \\}
    ;

    var result = parseSpeculationRules(allocator, json, "https://example.com/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 3), result.prefetch_rules.len);
    try std.testing.expectEqual(SpeculationEagerness.eager, result.prefetch_rules.get(0).?.eagerness);
    try std.testing.expectEqual(SpeculationEagerness.moderate, result.prefetch_rules.get(1).?.eagerness);
    try std.testing.expectEqual(SpeculationEagerness.conservative, result.prefetch_rules.get(2).?.eagerness);
}

test "parseSpeculationRules - with tag" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "tag": "navigation-hints",
        \\  "prefetch": [
        \\    {
        \\      "urls": ["https://example.com/page"],
        \\      "tag": "primary"
        \\    }
        \\  ]
        \\}
    ;

    var result = parseSpeculationRules(allocator, json, "https://example.com/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 1), result.prefetch_rules.len);

    // Should have both ruleset tag and rule tag
    try std.testing.expectEqual(@as(usize, 2), result.prefetch_rules.get(0).?.tags.len);
}

test "parseSpeculationRules - invalid JSON" {
    const allocator = std.testing.allocator;

    const json = "{ invalid json }";

    const result = parseSpeculationRules(allocator, json, "https://example.com/");
    defer {
        if (result.allocator) |alloc| {
            if (result.error_message) |msg| {
                alloc.free(msg);
            }
        }
    }

    try std.testing.expect(result.error_message != null);
}

test "parseSpeculationRules - non-HTTP URLs filtered" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "prefetch": [
        \\    {
        \\      "urls": ["https://example.com/valid", "javascript:alert(1)", "data:text/html,test"]
        \\    }
        \\  ]
        \\}
    ;

    var result = parseSpeculationRules(allocator, json, "https://example.com/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 1), result.prefetch_rules.len);
    // Only the HTTPS URL should be kept
    try std.testing.expectEqual(@as(usize, 1), result.prefetch_rules.get(0).?.urls.len);
}
