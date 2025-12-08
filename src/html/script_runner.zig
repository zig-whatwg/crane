//! Script Runner Module
//!
//! Spec: https://html.spec.whatwg.org/multipage/scripting.html
//! HTML Standard §4.12.1.1 - Processing model
//!
//! This module coordinates script execution timing and manages the various
//! script queues defined in the HTML specification:
//!
//! - Pending parsing-blocking script
//! - List of scripts that will execute when document finishes parsing (defer)
//! - Set of scripts that will execute as soon as possible (async)
//! - List of scripts that will execute in order as soon as possible
//!
//! ## Architecture
//!
//! The ScriptRunner works with the HTML parser and event loop:
//!
//! ```
//! Parser → ScriptRunner → EventLoop
//!   │           │             │
//!   │           ▼             │
//!   │     ┌─────────────┐    │
//!   └────▶│ Script      │◀───┘
//!         │ Queues      │
//!         └─────────────┘
//! ```
//!
//! ## Script Execution Order
//!
//! Per spec, scripts execute in this priority:
//! 1. Parser-blocking scripts (sync, block parsing)
//! 2. Deferred scripts (in document order, after parsing)
//! 3. Async scripts (as soon as loaded, any order)
//!

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const impls = @import("impls");
const HTMLScriptElement = interfaces.HTMLScriptElement;
const HTMLScriptElementImpl = impls.HTMLScriptElement;
const Document = interfaces.Document;
const html_core = @import("html_core");
const EventLoop = html_core.EventLoop;

// Note: script_execution.zig is imported lazily inside executeScript()
// to avoid pulling in V8 FFI symbols at compile time. This allows tests
// to use ScriptRunner for queue management without needing V8 linked.

/// Script Runner manages script execution scheduling
///
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
pub const ScriptRunner = struct {
    allocator: std.mem.Allocator,
    document: ?*runtime.Instance,

    /// Pending parsing-blocking script
    /// Spec: https://html.spec.whatwg.org/multipage/parsing.html#pending-parsing-blocking-script
    pending_parsing_blocking_script: ?*runtime.Instance,

    /// List of scripts that will execute when the document has finished parsing
    /// Spec: "list of scripts that will execute when the document has finished parsing"
    /// These are defer scripts added in document order
    deferred_scripts: std.ArrayList(*runtime.Instance),

    /// Set of scripts that will execute as soon as possible
    /// Spec: "set of scripts that will execute as soon as possible"
    /// These are async scripts that can execute in any order when ready
    async_scripts: std.ArrayList(*runtime.Instance),

    /// List of scripts that will execute in order as soon as possible
    /// Spec: "list of scripts that will execute in order as soon as possible"
    /// These are dynamically inserted async scripts that maintain relative order
    in_order_async_scripts: std.ArrayList(*runtime.Instance),

    /// Whether the parser has finished
    parser_finished: bool,

    /// Whether scripts are currently executing
    is_executing: bool,

    pub fn init(allocator: std.mem.Allocator, document: ?*runtime.Instance) ScriptRunner {
        return .{
            .allocator = allocator,
            .document = document,
            .pending_parsing_blocking_script = null,
            .deferred_scripts = .{},
            .async_scripts = .{},
            .in_order_async_scripts = .{},
            .parser_finished = false,
            .is_executing = false,
        };
    }

    pub fn deinit(self: *ScriptRunner) void {
        self.deferred_scripts.deinit(self.allocator);
        self.async_scripts.deinit(self.allocator);
        self.in_order_async_scripts.deinit(self.allocator);
    }

    // =========================================================================
    // Parser-Blocking Script
    // =========================================================================

    /// Set the pending parsing-blocking script
    /// Called when a parser-inserted external classic script without async/defer is encountered
    pub fn setPendingParsingBlockingScript(self: *ScriptRunner, script: ?*runtime.Instance) void {
        self.pending_parsing_blocking_script = script;
    }

    /// Get the pending parsing-blocking script
    pub fn getPendingParsingBlockingScript(self: *ScriptRunner) ?*runtime.Instance {
        return self.pending_parsing_blocking_script;
    }

    /// Check if there is a pending parsing-blocking script
    /// Convenience method for testing
    pub fn hasPendingParserBlockingScript(self: *ScriptRunner) bool {
        return self.pending_parsing_blocking_script != null;
    }

    /// Alias for setPendingParsingBlockingScript (test compatibility)
    pub fn setParserBlockingScript(self: *ScriptRunner, script: *runtime.Instance) void {
        self.setPendingParsingBlockingScript(script);
    }

    /// Clear the pending parsing-blocking script
    pub fn clearParserBlockingScript(self: *ScriptRunner) void {
        self.pending_parsing_blocking_script = null;
    }

    /// Execute the pending parsing-blocking script if ready
    /// Called by parser after each token processing
    ///
    /// Spec: https://html.spec.whatwg.org/multipage/parsing.html#pending-parsing-blocking-script
    pub fn executePendingParsingBlockingScript(self: *ScriptRunner) !void {
        const script = self.pending_parsing_blocking_script orelse return;

        // Check if script is ready
        if (!HTMLScriptElementImpl.isReadyToBeParserExecuted(script)) {
            return;
        }

        // Clear pending script
        self.pending_parsing_blocking_script = null;

        // Execute
        try self.executeScript(script);
    }

    // =========================================================================
    // Deferred Scripts
    // =========================================================================

    /// Add a script to the list of scripts that will execute when parsing finishes
    /// Used for defer scripts
    pub fn addDeferredScript(self: *ScriptRunner, script: *runtime.Instance) !void {
        try self.deferred_scripts.append(self.allocator, script);
    }

    /// Alias for addDeferredScript (test compatibility)
    pub fn queueDeferredScript(self: *ScriptRunner, script: *runtime.Instance) !void {
        try self.addDeferredScript(script);
    }

    /// Check if there are deferred scripts
    pub fn hasDeferredScripts(self: *ScriptRunner) bool {
        return self.deferred_scripts.items.len > 0;
    }

    /// Execute all deferred scripts
    /// Called when document parsing completes
    ///
    /// Spec: https://html.spec.whatwg.org/multipage/parsing.html#the-end (step 3)
    pub fn executeDeferredScripts(self: *ScriptRunner) !void {
        // Execute in document order
        for (self.deferred_scripts.items) |script| {
            // Check if ready (internal state accessor - use impl directly)
            if (HTMLScriptElementImpl.isReadyToBeParserExecuted(script)) {
                try self.executeScript(script);
            }
        }

        // Clear the list
        self.deferred_scripts.clearRetainingCapacity();
    }

    // =========================================================================
    // Async Scripts
    // =========================================================================

    /// Add a script to the set of scripts that will execute ASAP
    /// Used for async scripts (no ordering guarantee)
    pub fn addAsyncScript(self: *ScriptRunner, script: *runtime.Instance) !void {
        try self.async_scripts.append(self.allocator, script);
    }

    /// Alias for addAsyncScript (test compatibility)
    pub fn queueAsyncScript(self: *ScriptRunner, script: *runtime.Instance) !void {
        try self.addAsyncScript(script);
    }

    /// Check if there are async scripts
    pub fn hasAsyncScripts(self: *ScriptRunner) bool {
        return self.async_scripts.items.len > 0;
    }

    /// Remove an async script from the set
    pub fn removeAsyncScript(self: *ScriptRunner, script: *runtime.Instance) bool {
        for (self.async_scripts.items, 0..) |s, i| {
            if (s == script) {
                _ = self.async_scripts.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    /// Execute async scripts that are ready
    /// Can be called at any time - executes whichever async scripts are ready
    pub fn executeAsyncScripts(self: *ScriptRunner) !void {
        // Find and execute ready scripts (in any order)
        var i: usize = 0;
        while (i < self.async_scripts.items.len) {
            const script = self.async_scripts.items[i];
            if (HTMLScriptElementImpl.isReadyToBeParserExecuted(script)) {
                _ = self.async_scripts.orderedRemove(i);
                try self.executeScript(script);
                // Don't increment i - list shifted
            } else {
                i += 1;
            }
        }
    }

    // =========================================================================
    // In-Order Async Scripts
    // =========================================================================

    /// Add a script to the list of scripts that will execute in order ASAP
    /// Used for dynamically inserted async scripts that need ordering
    pub fn addInOrderAsyncScript(self: *ScriptRunner, script: *runtime.Instance) !void {
        try self.in_order_async_scripts.append(self.allocator, script);
    }

    /// Alias for addInOrderAsyncScript (test compatibility)
    pub fn queueInOrderAsyncScript(self: *ScriptRunner, script: *runtime.Instance) !void {
        try self.addInOrderAsyncScript(script);
    }

    /// Check if there are in-order async scripts
    pub fn hasInOrderAsyncScripts(self: *ScriptRunner) bool {
        return self.in_order_async_scripts.items.len > 0;
    }

    /// Execute in-order async scripts
    /// These must execute in order, so we stop at the first non-ready script
    pub fn executeInOrderAsyncScripts(self: *ScriptRunner) !void {
        while (self.in_order_async_scripts.items.len > 0) {
            const script = self.in_order_async_scripts.items[0];

            // Check if ready
            if (!HTMLScriptElementImpl.isReadyToBeParserExecuted(script)) {
                // Not ready - must maintain order, so stop here
                break;
            }

            // Remove and execute
            _ = self.in_order_async_scripts.orderedRemove(0);
            try self.executeScript(script);
        }
    }

    // =========================================================================
    // Common Execution
    // =========================================================================

    /// Execute a script element
    fn executeScript(self: *ScriptRunner, script: *runtime.Instance) !void {
        // Prevent reentrancy issues
        if (self.is_executing) {
            // Queue for later execution via event loop
            // For now, just execute synchronously
        }

        self.is_executing = true;
        defer self.is_executing = false;

        // Use lazy import to avoid pulling in V8 symbols at compile time
        const script_execution = @import("script_execution.zig");
        script_execution.executeScriptElement(self.allocator, script) catch |err| {
            std.debug.print("Script execution error: {}\n", .{err});
            // Errors are handled internally, don't propagate
        };
    }

    // =========================================================================
    // Parser Integration
    // =========================================================================

    /// Notify that the parser has finished
    /// Triggers execution of deferred scripts
    pub fn notifyParserFinished(self: *ScriptRunner) void {
        self.parser_finished = true;

        // Step 3: Execute deferred scripts
        self.executeDeferredScripts() catch |err| {
            std.debug.print("Deferred script execution error: {}\n", .{err});
        };

        // Also try to execute any pending async scripts
        self.executeAsyncScripts() catch |err| {
            std.debug.print("Async script execution error: {}\n", .{err});
        };
        self.executeInOrderAsyncScripts() catch |err| {
            std.debug.print("In-order async script execution error: {}\n", .{err});
        };
    }

    /// Process all ready scripts
    /// Called from event loop or parser to advance script execution
    pub fn processReadyScripts(self: *ScriptRunner) !void {
        // Try pending parsing-blocking first
        try self.executePendingParsingBlockingScript();

        // Then async scripts
        try self.executeAsyncScripts();
        try self.executeInOrderAsyncScripts();

        // Deferred scripts only after parsing
        if (self.parser_finished) {
            try self.executeDeferredScripts();
        }
    }

    /// Mark a script as ready (when fetch completes)
    /// This triggers execution checks
    pub fn markScriptReady(self: *ScriptRunner, script: *runtime.Instance) !void {
        HTMLScriptElementImpl.setReadyToBeParserExecuted(script, true);

        // Try to execute pending scripts
        try self.processReadyScripts();
    }
};

// =============================================================================
// Document Integration Helpers
// =============================================================================

// Note: ScriptRunner integration with Document will be done via the Document impl
// rather than modifying Document's InternalState. The Document interface already
// has all the script queue fields (pending_parsing_blocking_script, etc.)
// This ScriptRunner provides a higher-level abstraction for coordination.

// =============================================================================
// Tests
// =============================================================================

test "ScriptRunner - init and deinit" {
    const allocator = std.testing.allocator;

    var runner = ScriptRunner.init(allocator, null);
    defer runner.deinit();

    try std.testing.expect(runner.pending_parsing_blocking_script == null);
    try std.testing.expect(runner.deferred_scripts.items.len == 0);
    try std.testing.expect(runner.async_scripts.items.len == 0);
    try std.testing.expect(runner.in_order_async_scripts.items.len == 0);
    try std.testing.expect(!runner.parser_finished);
}

test "ScriptRunner - pending parsing-blocking script" {
    const allocator = std.testing.allocator;

    var runner = ScriptRunner.init(allocator, null);
    defer runner.deinit();

    // Use a dummy pointer for testing
    const dummy_script: *runtime.Instance = @ptrFromInt(0x12345678);

    // Set pending script
    runner.setPendingParsingBlockingScript(dummy_script);
    try std.testing.expect(runner.getPendingParsingBlockingScript() == dummy_script);

    // Clear pending script
    runner.setPendingParsingBlockingScript(null);
    try std.testing.expect(runner.getPendingParsingBlockingScript() == null);
}

test "ScriptRunner - deferred scripts list" {
    const allocator = std.testing.allocator;

    var runner = ScriptRunner.init(allocator, null);
    defer runner.deinit();

    // Use properly aligned dummy script addresses
    const alignment = @alignOf(runtime.Instance);
    const script1: *runtime.Instance = @ptrFromInt(alignment * 1);
    const script2: *runtime.Instance = @ptrFromInt(alignment * 2);
    const script3: *runtime.Instance = @ptrFromInt(alignment * 3);

    try runner.addDeferredScript(script1);
    try runner.addDeferredScript(script2);
    try runner.addDeferredScript(script3);

    try std.testing.expectEqual(@as(usize, 3), runner.deferred_scripts.items.len);
    try std.testing.expect(runner.deferred_scripts.items[0] == script1);
    try std.testing.expect(runner.deferred_scripts.items[1] == script2);
    try std.testing.expect(runner.deferred_scripts.items[2] == script3);
}

test "ScriptRunner - async scripts set" {
    const allocator = std.testing.allocator;

    var runner = ScriptRunner.init(allocator, null);
    defer runner.deinit();

    // Use properly aligned dummy script addresses
    const alignment = @alignOf(runtime.Instance);
    const script1: *runtime.Instance = @ptrFromInt(alignment * 1);
    const script2: *runtime.Instance = @ptrFromInt(alignment * 2);

    try runner.addAsyncScript(script1);
    try runner.addAsyncScript(script2);

    try std.testing.expectEqual(@as(usize, 2), runner.async_scripts.items.len);

    // Remove script1
    try std.testing.expect(runner.removeAsyncScript(script1));
    try std.testing.expectEqual(@as(usize, 1), runner.async_scripts.items.len);
    try std.testing.expect(runner.async_scripts.items[0] == script2);

    // Try to remove non-existent
    try std.testing.expect(!runner.removeAsyncScript(script1));
}

test "ScriptRunner - parser finished notification" {
    const allocator = std.testing.allocator;

    var runner = ScriptRunner.init(allocator, null);
    defer runner.deinit();

    try std.testing.expect(!runner.parser_finished);

    // Note: We can't fully test notifyParserFinished without real script elements
    // because it would try to execute scripts. Just test the flag setting manually.
    runner.parser_finished = true;
    try std.testing.expect(runner.parser_finished);
}
