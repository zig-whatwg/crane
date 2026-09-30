//! A Document's scripts, as HTML's script processing model reaches them.
//!
//! "Prepare the script element" puts a script element on one of its
//! document's lists - the set of scripts that will execute as soon as
//! possible, the list of scripts that will execute in order as soon as
//! possible, the list of scripts that will execute when the document has
//! finished parsing - or makes it the document's pending parsing-blocking
//! script; "execute the script element" raises the document's
//! ignore-destructive-writes counter and sets its currentScript. It also asks
//! the document whether scripting is enabled, whether a style sheet is
//! blocking scripts, whether its Content Security Policy allows a script, and
//! hands it a speculation rule set's prefetch hints.
//!
//! All of that is the Document's state, and no IDL member reaches it
//! (currentScript is read-only to script). So Document keeps a `Scripts` -
//! the object Blink calls ScriptRunner (core/script/script_runner.h) and
//! WebKit ScriptRunner (Source/WebCore/dom/ScriptRunner.h), both owned by
//! their Document - and installs this hook from its `init`, before any
//! document exists; html's script_execution asks it. The shape of
//! `document_lifecycle.zig`.
//!
//! The lists hold bare element pointers: the element's pending activity
//! (engine.keepPlatformObjectAlive while its "mark as ready" task waits) is
//! what keeps a listed element alive, never this state.
//!
//! Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
//! Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#ignore-destructive-writes-counter
//!
//! lint-impls: hook for Document

const std = @import("std");
const runtime = @import("runtime");

/// A speculation rule's eagerness. More eager first: `@intFromEnum` orders
/// them.
/// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html#speculation-rule-eagerness
pub const SpeculationEagerness = enum {
    immediate,
    eager,
    moderate,
    conservative,
};

/// The script processing model's state on one Document.
pub const Scripts = struct {
    allocator: std.mem.Allocator,

    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#pending-parsing-blocking-script
    pending_parsing_blocking_script: ?*runtime.Instance = null,

    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#set-of-scripts-that-will-execute-as-soon-as-possible
    scripts_to_execute_asap: std.ArrayList(*runtime.Instance) = .empty,

    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#list-of-scripts-that-will-execute-in-order-as-soon-as-possible
    scripts_to_execute_in_order_asap: std.ArrayList(*runtime.Instance) = .empty,

    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#list-of-scripts-that-will-execute-when-the-document-has-finished-parsing
    scripts_to_execute_when_parsing_finished: std.ArrayList(*runtime.Instance) = .empty,

    /// The script element whose classic script is running, for
    /// document.currentScript.
    /// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-currentscript
    current_script: ?*runtime.Instance = null,

    /// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#ignore-destructive-writes-counter
    ignore_destructive_writes_counter: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) Scripts {
        return .{ .allocator = allocator };
    }

    /// Frees the lists, not the elements on them.
    pub fn deinit(self: *Scripts) void {
        self.scripts_to_execute_asap.deinit(self.allocator);
        self.scripts_to_execute_in_order_asap.deinit(self.allocator);
        self.scripts_to_execute_when_parsing_finished.deinit(self.allocator);
    }

    /// Add `script` to the set of scripts that will execute as soon as
    /// possible.
    pub fn addAsap(self: *Scripts, script: *runtime.Instance) error{OutOfMemory}!void {
        try self.scripts_to_execute_asap.append(self.allocator, script);
    }

    /// Remove `script` from the set of scripts that will execute as soon as
    /// possible, keeping the others in their order.
    pub fn removeAsap(self: *Scripts, script: *runtime.Instance) void {
        for (self.scripts_to_execute_asap.items, 0..) |s, i| {
            if (s == script) {
                _ = self.scripts_to_execute_asap.orderedRemove(i);
                return;
            }
        }
    }

    /// Append `script` to the list of scripts that will execute in order as
    /// soon as possible.
    pub fn appendInOrder(self: *Scripts, script: *runtime.Instance) error{OutOfMemory}!void {
        try self.scripts_to_execute_in_order_asap.append(self.allocator, script);
    }

    /// The head of the list of scripts that will execute in order as soon as
    /// possible, left where it is.
    pub fn firstInOrder(self: *const Scripts) ?*runtime.Instance {
        if (self.scripts_to_execute_in_order_asap.items.len == 0) return null;
        return self.scripts_to_execute_in_order_asap.items[0];
    }

    /// Remove the head of the list of scripts that will execute in order as
    /// soon as possible and return it.
    pub fn removeFirstInOrder(self: *Scripts) ?*runtime.Instance {
        if (self.scripts_to_execute_in_order_asap.items.len == 0) return null;
        return self.scripts_to_execute_in_order_asap.orderedRemove(0);
    }

    /// Append `script` to the list of scripts that will execute when the
    /// document has finished parsing.
    pub fn addWhenParsingFinished(self: *Scripts, script: *runtime.Instance) error{OutOfMemory}!void {
        try self.scripts_to_execute_when_parsing_finished.append(self.allocator, script);
    }

    /// Empty the list of scripts that will execute when the document has
    /// finished parsing.
    pub fn clearWhenParsingFinished(self: *Scripts) void {
        self.scripts_to_execute_when_parsing_finished.clearRetainingCapacity();
    }

    /// "Increment document's ignore-destructive-writes counter."
    pub fn incrementIgnoreDestructiveWrites(self: *Scripts) void {
        self.ignore_destructive_writes_counter += 1;
    }

    /// "Decrement the ignore-destructive-writes counter of document", never
    /// below zero.
    pub fn decrementIgnoreDestructiveWrites(self: *Scripts) void {
        if (self.ignore_destructive_writes_counter > 0) self.ignore_destructive_writes_counter -= 1;
    }
};

/// What Document supplies.
pub const Implementation = struct {
    /// `document`'s scripts, or null for an object that is no Document.
    scripts: *const fn (document: *runtime.Instance) ?*Scripts,
    /// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#concept-n-script
    scripting_enabled: *const fn (document: *runtime.Instance) bool,
    /// Spec: https://html.spec.whatwg.org/multipage/semantics.html#has-a-style-sheet-that-is-blocking-scripts
    has_style_sheet_blocking_scripts: *const fn (document: *runtime.Instance) bool,
    /// CSP "should element's inline type behavior be blocked", for a script.
    inline_script_allowed_by_csp: *const fn (document: *runtime.Instance, nonce: ?[]const u8, hash_algorithm: ?[]const u8, hash_value: ?[]const u8) bool,
    /// CSP's script-src check of an external script's URL.
    external_script_allowed_by_csp: *const fn (document: *runtime.Instance, scheme: []const u8, host: []const u8, port: ?u16, path: []const u8, nonce: ?[]const u8) bool,
    /// Record a speculation rule set's prefetch candidate.
    add_prefetch_hint: *const fn (document: *runtime.Instance, url: []const u8, eagerness: SpeculationEagerness) error{ InvalidStateError, OutOfMemory }!void,
    /// The document's URL as its state records it: "" when none was set.
    url: *const fn (document: *runtime.Instance) []const u8,
};

/// Per thread, like the documents it serves.
threadlocal var implementation: ?Implementation = null;

/// Called by Document. Idempotent: every call installs the same functions.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// `document`'s scripts; null for an object that is no Document.
pub fn of(document: *runtime.Instance) ?*Scripts {
    const impl = implementation orelse return null;
    return impl.scripts(document);
}

/// Whether scripting is enabled for `document`.
pub fn scriptingEnabled(document: *runtime.Instance) bool {
    const impl = implementation orelse return false;
    return impl.scripting_enabled(document);
}

/// Whether `document` has a style sheet that is blocking scripts.
pub fn hasStyleSheetBlockingScripts(document: *runtime.Instance) bool {
    const impl = implementation orelse return false;
    return impl.has_style_sheet_blocking_scripts(document);
}

/// Whether `document`'s CSP allows an inline script with this nonce and
/// hash. Allowed with no document state to ask.
pub fn inlineScriptAllowedByCsp(document: *runtime.Instance, nonce: ?[]const u8, hash_algorithm: ?[]const u8, hash_value: ?[]const u8) bool {
    const impl = implementation orelse return true;
    return impl.inline_script_allowed_by_csp(document, nonce, hash_algorithm, hash_value);
}

/// Whether `document`'s CSP allows an external script from this URL, with
/// this nonce. Allowed with no document state to ask.
pub fn externalScriptAllowedByCsp(document: *runtime.Instance, scheme: []const u8, host: []const u8, port: ?u16, path: []const u8, nonce: ?[]const u8) bool {
    const impl = implementation orelse return true;
    return impl.external_script_allowed_by_csp(document, scheme, host, port, path, nonce);
}

/// Record a prefetch hint for `url` on `document`, the more eager one
/// winning.
pub fn addPrefetchHint(document: *runtime.Instance, url: []const u8, eagerness: SpeculationEagerness) error{ InvalidStateError, OutOfMemory }!void {
    const impl = implementation orelse return error.InvalidStateError;
    return impl.add_prefetch_hint(document, url, eagerness);
}

/// `document`'s URL as its state records it; "" when none was set.
pub fn urlOf(document: *runtime.Instance) []const u8 {
    const impl = implementation orelse return "";
    return impl.url(document);
}

test "without an installed implementation a document has no scripts and allows every script" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads it.
    var document: runtime.Instance = undefined;
    try std.testing.expect(of(&document) == null);
    try std.testing.expect(!scriptingEnabled(&document));
    try std.testing.expect(!hasStyleSheetBlockingScripts(&document));
    try std.testing.expect(inlineScriptAllowedByCsp(&document, null, null, null));
    try std.testing.expect(externalScriptAllowedByCsp(&document, "https", "example.test", null, "/", null));
    try std.testing.expectEqualStrings("", urlOf(&document));
}
