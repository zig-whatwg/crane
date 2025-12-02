//! Implementation for HTMLScriptElement interface
//!
//! Spec: https://html.spec.whatwg.org/multipage/scripting.html#the-script-element
//! HTML Standard §4.12.1
//!
//! The script element allows authors to include dynamic script and data blocks
//! in their documents. This implementation handles the internal state required
//! for script preparation and execution per the HTML specification.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLScriptElement = interfaces.HTMLScriptElement;

pub const State = HTMLScriptElement.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// Script type enumeration
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

/// Script result type
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#concept-script-result
pub const ScriptResult = union(enum) {
    /// Initial state before preparation
    uninitialized,
    /// Error state (failed to load/parse)
    null,
    /// Successfully prepared classic script
    script: ClassicScript,
    /// Successfully prepared module script
    module_script: ModuleScript,
    /// Import map parse result
    import_map_result: void, // TODO: Implement import map result type
    /// Speculation rules parse result
    speculation_rules_result: void, // TODO: Implement speculation rules result type
};

/// Classic script representation
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

/// Module script representation
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#module-script
pub const ModuleScript = struct {
    /// The script source text
    source_text: []const u8,
    /// Base URL for the script
    base_url: []const u8,
    /// Settings object (document's origin, etc.)
    settings_object: ?*runtime.Instance,
    /// The module record (V8 compiled module)
    module_record: ?*anyopaque,
    /// Whether script had a parse error
    parse_error: bool,
    /// Parse error details
    parse_error_message: ?[]const u8,
    /// Muted errors flag (for cross-origin scripts)
    muted_errors: bool,
    /// Credentials mode for fetching imports
    credentials_mode: CredentialsMode,

    pub const CredentialsMode = enum {
        same_origin,
        include,
        omit,
    };

    pub fn init(source: []const u8, base: []const u8) ModuleScript {
        return .{
            .source_text = source,
            .base_url = base,
            .settings_object = null,
            .module_record = null,
            .parse_error = false,
            .parse_error_message = null,
            .muted_errors = false,
            .credentials_mode = .same_origin,
        };
    }
};

/// Internal state for HTMLScriptElement
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
pub const InternalState = struct {
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

    /// Cached script source text (for inline scripts)
    cached_source_text: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator) InternalState {
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
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Free cached source text if allocated
        if (self.cached_source_text) |text| {
            self.allocator.free(text);
        }
    }
};

/// Global registry for HTMLScriptElement internal state
var script_registry: std.AutoHashMap(usize, *InternalState) = undefined;
var script_registry_initialized: bool = false;

fn ensureScriptRegistry() void {
    if (!script_registry_initialized) {
        script_registry = std.AutoHashMap(usize, *InternalState).init(std.heap.page_allocator);
        script_registry_initialized = true;
    }
}

fn setInternalInRegistry(instance: *runtime.Instance, internal: *InternalState) !void {
    ensureScriptRegistry();
    try script_registry.put(@intFromPtr(instance), internal);
}

fn getInternalFromRegistry(instance: *runtime.Instance) ?*InternalState {
    ensureScriptRegistry();
    return script_registry.get(@intFromPtr(instance));
}

/// Get the internal state from an instance
/// Made public for use by script execution module
pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return getInternalFromRegistry(instance);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize HTMLScriptElement's internal state in registry
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    try setInternalInRegistry(instance, internal);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up from registry
    ensureScriptRegistry();
    if (script_registry.get(@intFromPtr(instance))) |internal| {
        internal.deinit();
    }
    _ = script_registry.remove(@intFromPtr(instance));
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &HTMLScriptElement.vtable, ctx);
    errdefer deinit(instance);

    return instance;
}

// =============================================================================
// Script Element Helpers (for parser integration)
// =============================================================================

/// Set the parser document for this script element
/// Called by the HTML parser when inserting the script
pub fn setParserDocument(instance: *runtime.Instance, document: ?*runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.parser_document = document;
    }
}

/// Get the parser document for this script element
pub fn getParserDocument(instance: *runtime.Instance) ?*runtime.Instance {
    if (getInternal(instance)) |internal| {
        return internal.parser_document;
    }
    return null;
}

/// Set force_async to false (called by parser)
pub fn clearForceAsync(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.force_async = false;
    }
}

/// Check if script is parser-inserted
pub fn isParserInserted(instance: *runtime.Instance) bool {
    if (getInternal(instance)) |internal| {
        return internal.parser_document != null;
    }
    return false;
}

/// Check if script has already started
pub fn hasAlreadyStarted(instance: *runtime.Instance) bool {
    if (getInternal(instance)) |internal| {
        return internal.already_started;
    }
    return false;
}

/// Set already_started flag
pub fn setAlreadyStarted(instance: *runtime.Instance, value: bool) void {
    if (getInternal(instance)) |internal| {
        internal.already_started = value;
    }
}

/// Get the script type
pub fn getScriptType(instance: *runtime.Instance) ScriptType {
    if (getInternal(instance)) |internal| {
        return internal.script_type;
    }
    return .null;
}

/// Set the script type
pub fn setScriptType(instance: *runtime.Instance, script_type: ScriptType) void {
    if (getInternal(instance)) |internal| {
        internal.script_type = script_type;
    }
}

/// Get the script result
pub fn getResult(instance: *runtime.Instance) ScriptResult {
    if (getInternal(instance)) |internal| {
        return internal.result;
    }
    return .uninitialized;
}

/// Set the script result
pub fn setResult(instance: *runtime.Instance, result: ScriptResult) void {
    if (getInternal(instance)) |internal| {
        internal.result = result;
    }
}

/// Check if script is ready to be parser-executed
pub fn isReadyToBeParserExecuted(instance: *runtime.Instance) bool {
    if (getInternal(instance)) |internal| {
        return internal.ready_to_be_parser_executed;
    }
    return false;
}

/// Set ready_to_be_parser_executed flag
pub fn setReadyToBeParserExecuted(instance: *runtime.Instance, value: bool) void {
    if (getInternal(instance)) |internal| {
        internal.ready_to_be_parser_executed = value;
    }
}

/// Get force_async flag
pub fn getForceAsync(instance: *runtime.Instance) bool {
    if (getInternal(instance)) |internal| {
        return internal.force_async;
    }
    return true;
}

/// Set preparation-time document
pub fn setPreparationTimeDocument(instance: *runtime.Instance, document: ?*runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.preparation_time_document = document;
    }
}

/// Get preparation-time document
pub fn getPreparationTimeDocument(instance: *runtime.Instance) ?*runtime.Instance {
    if (getInternal(instance)) |internal| {
        return internal.preparation_time_document;
    }
    return null;
}

/// Set from_external_file flag
pub fn setFromExternalFile(instance: *runtime.Instance, value: bool) void {
    if (getInternal(instance)) |internal| {
        internal.from_external_file = value;
    }
}

/// Get from_external_file flag
pub fn isFromExternalFile(instance: *runtime.Instance) bool {
    if (getInternal(instance)) |internal| {
        return internal.from_external_file;
    }
    return false;
}

/// Cache the source text for inline scripts
pub fn cacheSourceText(instance: *runtime.Instance, text: []const u8) !void {
    if (getInternal(instance)) |internal| {
        // Free old cached text if any
        if (internal.cached_source_text) |old| {
            internal.allocator.free(old);
        }
        internal.cached_source_text = try internal.allocator.dupe(u8, text);
    }
}

/// Get cached source text
pub fn getCachedSourceText(instance: *runtime.Instance) ?[]const u8 {
    if (getInternal(instance)) |internal| {
        return internal.cached_source_text;
    }
    return null;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for src
pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for noModule
pub fn get_noModule(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for async
pub fn get_async(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for defer
pub fn get_defer(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for blocking
pub fn get_blocking(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crossOrigin
pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for referrerPolicy
pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for integrity
pub fn get_integrity(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fetchPriority
pub fn get_fetchPriority(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for text
pub fn get_text(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for charset
pub fn get_charset(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for event
pub fn get_event(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for htmlFor
pub fn get_htmlFor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for attributionSrc
pub fn get_attributionSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for type
pub fn set_type(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for src
pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for noModule
pub fn set_noModule(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for async
pub fn set_async(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for defer
pub fn set_defer(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for crossOrigin
pub fn set_crossOrigin(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for referrerPolicy
pub fn set_referrerPolicy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for integrity
pub fn set_integrity(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for fetchPriority
pub fn set_fetchPriority(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for text
pub fn set_text(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for charset
pub fn set_charset(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for event
pub fn set_event(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for htmlFor
pub fn set_htmlFor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for attributionSrc
pub fn set_attributionSrc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: supports
pub fn call_supports(instance: *runtime.Instance, @"type": runtime.DOMString) anyerror!bool {
    _ = instance;
    _ = @"type";
    return error.NotImplemented;
}

// =============================================================================
// Script Preparation and Execution Algorithms
// HTML Standard §4.12.1.1
// =============================================================================

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
    // Import the script_execution module which contains the algorithm implementation
    // This is a transitional pattern - eventually all logic will move here
    const script_execution = @import("html").script_execution;
    return script_execution.prepareScriptElement(allocator, script_element);
}

/// Execute the script element
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#execute-the-script-element
///
/// Executes the prepared script using V8.
pub fn executeScriptElement(
    allocator: std.mem.Allocator,
    script_element: *runtime.Instance,
) ScriptExecutionError!void {
    const script_execution = @import("html").script_execution;
    return script_execution.executeScriptElement(allocator, script_element);
}

/// Script execution error type
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
