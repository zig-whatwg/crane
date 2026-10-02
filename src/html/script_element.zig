//! A script element's processing-model state, and the hook that reaches it.
//!
//! HTML gives every script element state that no IDL member exposes: its
//! parser document, preparation-time document, force async, from an external
//! file, ready to be parser-executed, already started, delaying the load
//! event, type and result. Two parties read and write it: the processing
//! model - "prepare the script element", "execute the script element", the
//! parser's script end-tag steps - in html/script_execution.zig, and the
//! element's IDL members (async, text) and DOM steps (cloning, insertion,
//! attribute changes) in the HTMLScriptElement impl. Neither may reach into
//! the other, so the state's type is defined here, where both can see it.
//! The impl keeps each element's `State` - created with the element, freed by
//! the element's deinit - and installs `of`, from its installHooks, before any
//! script element exists; the processing model calls `of`.
//!
//! Blink draws the same line: an HTMLScriptElement owns a ScriptLoader
//! (core/script/script_loader.h), which holds this state (already_started_,
//! parser_inserted_, will_be_parser_executed_, ready_to_be_parser_executed_,
//! force_async_, resource_keep_alive_) and runs PrepareScript. WebKit's
//! ScriptElement (Source/WebCore/dom/ScriptElement.h) is the same object.
//!
//! What the state owns: the cached source text and the script URL, which it
//! frees. What it does not: a module script result points at html's
//! module_script.ModuleScript, which the node document's module map owns and
//! disposes of with the Document; the preparation-time and parser documents
//! are the documents' own.
//!
//! Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
//!
//! lint-impls: hook for HTMLScriptElement

const std = @import("std");
const runtime = @import("runtime");
const module_script = @import("module_script.zig");

/// A script element's type.
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#concept-script-type
pub const ScriptType = enum {
    /// Not yet determined or unsupported type
    null,
    /// Classic JavaScript script
    classic,
    /// JavaScript module script
    module,
    /// Import map
    importmap,
    /// Speculation rules
    speculationrules,
};

/// A script element's result.
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#concept-script-result
pub const ScriptResult = union(enum) {
    /// "uninitialized": before preparation delivers one
    uninitialized,
    /// null: the script failed to load or parse
    null,
    /// A classic script
    script: ClassicScript,
    /// A module script, owned by the node document's module map
    module_script: *module_script.ModuleScript,
    /// Import map parse result
    import_map_result: void, // TODO: Implement import map result type
    /// Speculation rules parse result
    speculation_rules_result: void, // TODO: Implement speculation rules result type
};

/// A classic script, as a script element's result keeps it.
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#classic-script
pub const ClassicScript = struct {
    /// The script source text
    source_text: []const u8,
    /// Base URL for the script
    base_url: []const u8,
    /// Settings object (document's origin, etc.)
    settings_object: ?*runtime.Instance,
    /// Whether script had a parse error
    parse_error: bool,
    /// Muted errors flag (for cross-origin scripts)
    muted_errors: bool,

    pub fn init(source: []const u8, base: []const u8) ClassicScript {
        return .{
            .source_text = source,
            .base_url = base,
            .settings_object = null,
            .parse_error = false,
            .muted_errors = false,
        };
    }
};

/// One script element's processing-model state.
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
pub const State = struct {
    allocator: std.mem.Allocator,

    /// The parser document - set by HTML/XML parser on inserted scripts
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#parser-document
    /// Scripts with non-null parser_document are "parser-inserted"
    parser_document: ?*runtime.Instance,

    /// The preparation-time document - prevents cross-document execution
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#preparation-time-document
    preparation_time_document: ?*runtime.Instance,

    /// Force async flag - initially true, set false by parser
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-force-async
    force_async: bool,

    /// From external file flag - has src attribute
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#concept-script-external
    from_external_file: bool,

    /// Ready to be parser-executed flag - used for parser-inserted scripts
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#ready-to-be-parser-executed
    ready_to_be_parser_executed: bool,

    /// Already started flag - prevents re-execution
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#already-started
    already_started: bool,

    /// Delaying the load event flag
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#concept-script-delay-load
    delaying_the_load_event: bool,

    /// Script type (classic, module, importmap, speculationrules, or null)
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#concept-script-type
    script_type: ScriptType,

    /// Script result
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#concept-script-result
    result: ScriptResult,

    /// Steps to run when the result is ready (for async/deferred scripts)
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#steps-to-run-when-the-result-is-ready
    steps_to_run_when_ready: ?*const fn (*runtime.Instance) void,

    /// Cached script source text (for inline scripts), owned here.
    cached_source_text: ?[]const u8,

    /// The URL an external script was fetched from, owned here.
    ///
    /// The script's base URL has to outlive "prepare the script element": a
    /// deferred, async or parser-blocking script executes long after the
    /// preparation that resolved its `src` has returned, and the resolved URL
    /// used to be freed on that return, leaving `ClassicScript.base_url`
    /// pointing into freed memory by the time the script ran.
    script_url: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator) State {
        return .{
            .allocator = allocator,
            .parser_document = null,
            .preparation_time_document = null,
            .force_async = true, // Initially true per spec
            .from_external_file = false,
            .ready_to_be_parser_executed = false,
            .already_started = false,
            .delaying_the_load_event = false,
            .script_type = .null,
            .result = .uninitialized,
            .steps_to_run_when_ready = null,
            .cached_source_text = null,
            .script_url = null,
        };
    }

    pub fn deinit(self: *State) void {
        if (self.cached_source_text) |text| self.allocator.free(text);
        if (self.script_url) |url| self.allocator.free(url);
        self.cached_source_text = null;
        self.script_url = null;
    }

    /// Keep a copy of `text` as the element's cached source text, freeing the
    /// one it replaces.
    pub fn cacheSourceText(self: *State, text: []const u8) !void {
        const owned = try self.allocator.dupe(u8, text);
        if (self.cached_source_text) |old| self.allocator.free(old);
        self.cached_source_text = owned;
    }

    /// Record the URL an external script comes from, taking a copy the
    /// element owns. Returns the element's copy - the one a script result may
    /// point at.
    pub fn setScriptUrl(self: *State, url: []const u8) ![]const u8 {
        const owned = try self.allocator.dupe(u8, url);
        if (self.script_url) |old| self.allocator.free(old);
        self.script_url = owned;
        return owned;
    }
};

/// What HTMLScriptElement supplies: an HTML script element's state, or null
/// for any other object.
pub const Implementation = struct {
    state: *const fn (element: *runtime.Instance) ?*State,
};

/// Process-wide, written once at start-up (dom.process_start).
var implementation: ?Implementation = null;

/// Called by HTMLScriptElement's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    @import("dom").process_start.assertInstalling();
    implementation = impl;
}

/// `element`'s script element state if it is an HTML script element, else
/// null - also before any script element exists to install the hook.
pub fn of(element: *runtime.Instance) ?*State {
    const impl = implementation orelse return null;
    return impl.state(element);
}

test "without an installed implementation no element has script element state" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads it.
    var element: runtime.Instance = undefined;
    try std.testing.expect(of(&element) == null);
}
