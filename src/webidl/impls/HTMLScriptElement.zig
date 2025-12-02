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

// =============================================================================
// Content Attribute Reflection Helpers
// Spec: https://html.spec.whatwg.org/multipage/dom.html#reflecting-content-attributes-in-idl-attributes
// =============================================================================

const ElementImpl = @import("Element.zig");

/// Get a content attribute value from this element
fn getContentAttribute(instance: *runtime.Instance, name: []const u8) ?runtime.DOMString {
    const elem_internal = ElementImpl.getInternalState(instance) orelse return null;

    // Search attributes for matching name
    for (elem_internal.attributes.items) |attr| {
        if (std.mem.eql(u8, attr.local_name, name)) {
            return runtime.DOMString.initInterned(attr.value);
        }
    }
    return null;
}

/// Set a content attribute value on this element
fn setContentAttribute(instance: *runtime.Instance, name: []const u8, value: runtime.DOMString) !void {
    const elem_internal = ElementImpl.getInternalState(instance) orelse return error.InvalidStateError;

    // Search for existing attribute
    for (elem_internal.attributes.items) |*attr| {
        if (std.mem.eql(u8, attr.local_name, name)) {
            // Update existing
            elem_internal.allocator.free(attr.value);
            attr.value = try elem_internal.allocator.dupe(u8, value.asSlice());
            return;
        }
    }

    // Add new attribute
    try elem_internal.attributes.append(elem_internal.allocator, .{
        .namespace_uri = null,
        .prefix = null,
        .local_name = try elem_internal.allocator.dupe(u8, name),
        .value = try elem_internal.allocator.dupe(u8, value.asSlice()),
    });
}

/// Check if a boolean content attribute exists (presence = true)
fn hasBooleanAttribute(instance: *runtime.Instance, name: []const u8) bool {
    const elem_internal = ElementImpl.getInternalState(instance) orelse return false;

    for (elem_internal.attributes.items) |attr| {
        if (std.mem.eql(u8, attr.local_name, name)) {
            return true;
        }
    }
    return false;
}

/// Set or remove a boolean attribute (presence = true, absence = false)
fn setBooleanAttribute(instance: *runtime.Instance, name: []const u8, value: bool) !void {
    const elem_internal = ElementImpl.getInternalState(instance) orelse return error.InvalidStateError;

    if (value) {
        // Set the attribute with empty value (presence means true)
        try setContentAttribute(instance, name, runtime.DOMString.initEmpty());
    } else {
        // Remove the attribute
        var i: usize = 0;
        while (i < elem_internal.attributes.items.len) {
            if (std.mem.eql(u8, elem_internal.attributes.items[i].local_name, name)) {
                const entry = elem_internal.attributes.orderedRemove(i);
                elem_internal.allocator.free(entry.local_name);
                elem_internal.allocator.free(entry.value);
                if (entry.namespace_uri) |ns| elem_internal.allocator.free(ns);
                if (entry.prefix) |p| elem_internal.allocator.free(p);
                return;
            }
            i += 1;
        }
    }
}

// =============================================================================
// IDL Attribute Implementations - Content Attribute Reflection
// =============================================================================

/// Getter for type
/// Spec: [CEReactions, Reflect] attribute DOMString type;
/// Reflects the type content attribute.
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "type") orelse runtime.DOMString.initEmpty();
}

/// Getter for src
/// Spec: [CEReactions, ReflectURL] attribute USVString src;
/// Reflects the src content attribute (URL-valued).
pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString {
    // For ReflectURL, we should return the resolved URL, but for now return raw value
    if (getContentAttribute(instance, "src")) |attr| {
        return attr.asSlice();
    }
    return "";
}

/// Getter for noModule
/// Spec: [CEReactions, Reflect] attribute boolean noModule;
/// True if the nomodule attribute is present.
pub fn get_noModule(instance: *runtime.Instance) anyerror!bool {
    return hasBooleanAttribute(instance, "nomodule");
}

/// Getter for async
/// Spec: [CEReactions] attribute boolean async;
/// Special behavior: returns the "force async" flag OR the async attribute.
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-script-async
pub fn get_async(instance: *runtime.Instance) anyerror!bool {
    // Per spec: The async IDL attribute controls whether the element will execute
    // asynchronously or not. If the element's "force async" flag is set, then,
    // on getting, the async IDL attribute must return true, and on setting,
    // the "force async" flag must first be unset...
    if (getInternal(instance)) |internal| {
        if (internal.force_async) {
            return true;
        }
    }
    return hasBooleanAttribute(instance, "async");
}

/// Getter for defer
/// Spec: [CEReactions, Reflect] attribute boolean defer;
/// True if the defer attribute is present.
pub fn get_defer(instance: *runtime.Instance) anyerror!bool {
    return hasBooleanAttribute(instance, "defer");
}

/// Getter for blocking
/// Spec: [SameObject, PutForwards=value, Reflect] readonly attribute DOMTokenList blocking;
/// Returns the DOMTokenList for the blocking attribute.
/// TODO: Implement DOMTokenList support
pub fn get_blocking(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented; // Requires DOMTokenList implementation
}

/// Getter for crossOrigin
/// Spec: [CEReactions] attribute DOMString? crossOrigin;
/// Reflects the crossorigin content attribute (limited to known values).
pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    // Per spec, crossOrigin returns null if attribute is absent
    return getContentAttribute(instance, "crossorigin");
}

/// Getter for referrerPolicy
/// Spec: [CEReactions] attribute DOMString referrerPolicy;
/// Reflects the referrerpolicy content attribute.
pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "referrerpolicy") orelse runtime.DOMString.initEmpty();
}

/// Getter for integrity
/// Spec: [CEReactions, Reflect] attribute DOMString integrity;
/// Reflects the integrity content attribute.
pub fn get_integrity(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "integrity") orelse runtime.DOMString.initEmpty();
}

/// Getter for fetchPriority
/// Spec: [CEReactions] attribute DOMString fetchPriority;
/// Reflects the fetchpriority content attribute.
pub fn get_fetchPriority(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "fetchpriority") orelse runtime.DOMString.initEmpty();
}

/// Getter for text
/// Spec: [CEReactions] attribute DOMString text;
/// Returns the child text content (concatenation of all Text node descendants).
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-script-text
pub fn get_text(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Per spec: "On getting, it must return this element's child text content."
    // For now, return cached source text if available
    if (getInternal(instance)) |internal| {
        if (internal.cached_source_text) |text| {
            return runtime.DOMString.initInterned(text);
        }
    }
    // TODO: Implement proper child text content collection
    return runtime.DOMString.initEmpty();
}

/// Getter for charset (obsolete)
/// Spec: [CEReactions, Reflect] attribute DOMString charset;
/// Reflects the charset content attribute.
pub fn get_charset(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "charset") orelse runtime.DOMString.initEmpty();
}

/// Getter for event (obsolete)
/// Spec: [CEReactions, Reflect] attribute DOMString event;
/// Reflects the event content attribute.
pub fn get_event(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "event") orelse runtime.DOMString.initEmpty();
}

/// Getter for htmlFor (obsolete)
/// Spec: [CEReactions, Reflect=for] attribute DOMString htmlFor;
/// Reflects the "for" content attribute.
pub fn get_htmlFor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "for") orelse runtime.DOMString.initEmpty();
}

/// Getter for attributionSrc
/// Spec: [CEReactions, Reflect] attribute USVString attributionSrc;
/// Reflects the attributionsrc content attribute.
pub fn get_attributionSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    if (getContentAttribute(instance, "attributionsrc")) |attr| {
        return attr.asSlice();
    }
    return "";
}

/// Setter for type
/// Spec: [CEReactions, Reflect] attribute DOMString type;
pub fn set_type(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "type", value);
}

/// Setter for src
/// Spec: [CEReactions, ReflectURL] attribute USVString src;
pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    try setContentAttribute(instance, "src", runtime.DOMString.initInterned(value));
}

/// Setter for noModule
/// Spec: [CEReactions, Reflect] attribute boolean noModule;
pub fn set_noModule(instance: *runtime.Instance, value: bool) anyerror!void {
    try setBooleanAttribute(instance, "nomodule", value);
}

/// Setter for async
/// Spec: [CEReactions] attribute boolean async;
/// Special behavior: first unsets the "force async" flag.
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-script-async
pub fn set_async(instance: *runtime.Instance, value: bool) anyerror!void {
    // Per spec: On setting, the "force async" flag must first be unset...
    if (getInternal(instance)) |internal| {
        internal.force_async = false;
    }
    try setBooleanAttribute(instance, "async", value);
}

/// Setter for defer
/// Spec: [CEReactions, Reflect] attribute boolean defer;
pub fn set_defer(instance: *runtime.Instance, value: bool) anyerror!void {
    try setBooleanAttribute(instance, "defer", value);
}

/// Setter for crossOrigin
/// Spec: [CEReactions] attribute DOMString? crossOrigin;
pub fn set_crossOrigin(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "crossorigin", value);
}

/// Setter for referrerPolicy
/// Spec: [CEReactions] attribute DOMString referrerPolicy;
pub fn set_referrerPolicy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "referrerpolicy", value);
}

/// Setter for integrity
/// Spec: [CEReactions, Reflect] attribute DOMString integrity;
pub fn set_integrity(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "integrity", value);
}

/// Setter for fetchPriority
/// Spec: [CEReactions] attribute DOMString fetchPriority;
pub fn set_fetchPriority(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "fetchpriority", value);
}

/// Setter for text
/// Spec: [CEReactions] attribute DOMString text;
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-script-text
pub fn set_text(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Per spec: "On setting, it must string replace all with the given value within this element."
    // For now, just cache the text (full implementation needs DOM tree manipulation)
    try cacheSourceText(instance, value.asSlice());
}

/// Setter for charset (obsolete)
/// Spec: [CEReactions, Reflect] attribute DOMString charset;
pub fn set_charset(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "charset", value);
}

/// Setter for event (obsolete)
/// Spec: [CEReactions, Reflect] attribute DOMString event;
pub fn set_event(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "event", value);
}

/// Setter for htmlFor (obsolete)
/// Spec: [CEReactions, Reflect=for] attribute DOMString htmlFor;
pub fn set_htmlFor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "for", value);
}

/// Setter for attributionSrc
/// Setter for attributionSrc
/// Spec: [CEReactions, Reflect] attribute USVString attributionSrc;
pub fn set_attributionSrc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    try setContentAttribute(instance, "attributionsrc", runtime.DOMString.initInterned(value));
}

/// Operation: supports (static method)
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-script-supports
///
/// The static supports(type) method steps are:
/// 1. If type is "classic", then return true.
/// 2. If type is "module", then return true.
/// 3. If type is "importmap", then return true.
/// 4. If type is "speculationrules", then return true.
/// 5. Return false.
///
/// Note: The type argument has to exactly match these values; we do not perform
/// an ASCII case-insensitive match.
pub fn call_supports(instance: *runtime.Instance, @"type": runtime.DOMString) anyerror!bool {
    _ = instance; // Static method - instance not used

    const type_str = @"type".asSlice();

    // Step 1: If type is "classic", return true
    if (std.mem.eql(u8, type_str, "classic")) {
        return true;
    }

    // Step 2: If type is "module", return true
    if (std.mem.eql(u8, type_str, "module")) {
        return true;
    }

    // Step 3: If type is "importmap", return true
    if (std.mem.eql(u8, type_str, "importmap")) {
        return true;
    }

    // Step 4: If type is "speculationrules", return true
    if (std.mem.eql(u8, type_str, "speculationrules")) {
        return true;
    }

    // Step 5: Return false
    return false;
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
    // Import the script_execution module - now a local import in impls/
    const script_execution = @import("script_execution.zig");
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
    const script_execution = @import("script_execution.zig");
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
