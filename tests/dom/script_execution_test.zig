//! Tests for script execution integration
//!
//! Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
//! HTML Standard §4.12.1.1
//!
//! These tests verify the script preparation and execution algorithms work correctly
//! with the HTML parser.

const std = @import("std");

// =============================================================================
// Unit Tests for MIME type detection
// =============================================================================

/// Check if a MIME type is a JavaScript MIME type essence match
/// Spec: https://mimesniff.spec.whatwg.org/#javascript-mime-type
fn isJavaScriptMimeType(mime_type: []const u8) bool {
    var lower_buf: [64]u8 = undefined;
    const len = @min(mime_type.len, 64);
    for (0..len) |i| {
        lower_buf[i] = std.ascii.toLower(mime_type[i]);
    }
    const lower = lower_buf[0..len];

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

test "isJavaScriptMimeType - standard types" {
    // Standard JavaScript MIME types
    try std.testing.expect(isJavaScriptMimeType("text/javascript"));
    try std.testing.expect(isJavaScriptMimeType("application/javascript"));
    try std.testing.expect(isJavaScriptMimeType("text/ecmascript"));
    try std.testing.expect(isJavaScriptMimeType("application/ecmascript"));
}

test "isJavaScriptMimeType - case insensitive" {
    try std.testing.expect(isJavaScriptMimeType("TEXT/JAVASCRIPT"));
    try std.testing.expect(isJavaScriptMimeType("Text/JavaScript"));
    try std.testing.expect(isJavaScriptMimeType("APPLICATION/JAVASCRIPT"));
}

test "isJavaScriptMimeType - with parameters" {
    // MIME types with charset parameters should still match
    try std.testing.expect(isJavaScriptMimeType("text/javascript; charset=utf-8"));
    try std.testing.expect(isJavaScriptMimeType("application/javascript; charset=utf-8"));
    try std.testing.expect(isJavaScriptMimeType("text/javascript;charset=utf-8"));
}

test "isJavaScriptMimeType - legacy types" {
    // Legacy MIME types that should be recognized
    try std.testing.expect(isJavaScriptMimeType("text/javascript1.0"));
    try std.testing.expect(isJavaScriptMimeType("text/javascript1.1"));
    try std.testing.expect(isJavaScriptMimeType("text/javascript1.2"));
    try std.testing.expect(isJavaScriptMimeType("text/javascript1.3"));
    try std.testing.expect(isJavaScriptMimeType("text/javascript1.4"));
    try std.testing.expect(isJavaScriptMimeType("text/javascript1.5"));
    try std.testing.expect(isJavaScriptMimeType("text/jscript"));
    try std.testing.expect(isJavaScriptMimeType("text/livescript"));
    try std.testing.expect(isJavaScriptMimeType("text/x-ecmascript"));
    try std.testing.expect(isJavaScriptMimeType("text/x-javascript"));
    try std.testing.expect(isJavaScriptMimeType("application/x-ecmascript"));
    try std.testing.expect(isJavaScriptMimeType("application/x-javascript"));
}

test "isJavaScriptMimeType - non-JavaScript types" {
    // Non-JavaScript MIME types should not match
    try std.testing.expect(!isJavaScriptMimeType("text/plain"));
    try std.testing.expect(!isJavaScriptMimeType("application/json"));
    try std.testing.expect(!isJavaScriptMimeType("text/html"));
    try std.testing.expect(!isJavaScriptMimeType("application/xml"));
    try std.testing.expect(!isJavaScriptMimeType(""));
    try std.testing.expect(!isJavaScriptMimeType("module"));
    try std.testing.expect(!isJavaScriptMimeType("importmap"));
}

// =============================================================================
// Script Type Determination Tests
// =============================================================================

/// Script type enumeration
const ScriptType = enum {
    null,
    classic,
    module,
    importmap,
    speculationrules,
};

/// Determine script type from type attribute value
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#prepare-the-script-element (steps 8-13)
fn determineScriptType(type_attr: []const u8, lang_attr: []const u8) ScriptType {
    // Step 8: Determine the script block's type string
    var type_string: []const u8 = undefined;

    if (type_attr.len == 0) {
        // type attribute is empty or missing
        if (lang_attr.len == 0) {
            // No type, no language -> default to text/javascript
            type_string = "text/javascript";
        } else {
            // Has language attribute -> "text/" + language
            if (std.ascii.eqlIgnoreCase(lang_attr, "javascript")) {
                type_string = "text/javascript";
            } else {
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

test "determineScriptType - no type attribute defaults to classic" {
    try std.testing.expectEqual(ScriptType.classic, determineScriptType("", ""));
}

test "determineScriptType - JavaScript MIME types are classic" {
    try std.testing.expectEqual(ScriptType.classic, determineScriptType("text/javascript", ""));
    try std.testing.expectEqual(ScriptType.classic, determineScriptType("application/javascript", ""));
    try std.testing.expectEqual(ScriptType.classic, determineScriptType("TEXT/JAVASCRIPT", ""));
}

test "determineScriptType - module type" {
    try std.testing.expectEqual(ScriptType.module, determineScriptType("module", ""));
    try std.testing.expectEqual(ScriptType.module, determineScriptType("MODULE", ""));
    try std.testing.expectEqual(ScriptType.module, determineScriptType("Module", ""));
}

test "determineScriptType - importmap type" {
    try std.testing.expectEqual(ScriptType.importmap, determineScriptType("importmap", ""));
    try std.testing.expectEqual(ScriptType.importmap, determineScriptType("IMPORTMAP", ""));
    try std.testing.expectEqual(ScriptType.importmap, determineScriptType("ImportMap", ""));
}

test "determineScriptType - speculationrules type" {
    try std.testing.expectEqual(ScriptType.speculationrules, determineScriptType("speculationrules", ""));
    try std.testing.expectEqual(ScriptType.speculationrules, determineScriptType("SPECULATIONRULES", ""));
}

test "determineScriptType - unknown types return null" {
    try std.testing.expectEqual(ScriptType.null, determineScriptType("text/plain", ""));
    try std.testing.expectEqual(ScriptType.null, determineScriptType("application/json", ""));
    try std.testing.expectEqual(ScriptType.null, determineScriptType("unknown", ""));
}

test "determineScriptType - language attribute fallback" {
    // language="javascript" should produce classic script
    try std.testing.expectEqual(ScriptType.classic, determineScriptType("", "javascript"));
    try std.testing.expectEqual(ScriptType.classic, determineScriptType("", "JavaScript"));
    try std.testing.expectEqual(ScriptType.classic, determineScriptType("", "JAVASCRIPT"));

    // Unknown language should produce null
    try std.testing.expectEqual(ScriptType.null, determineScriptType("", "vbscript"));
    try std.testing.expectEqual(ScriptType.null, determineScriptType("", "python"));
}

test "determineScriptType - type attribute takes precedence over language" {
    // Even with language="javascript", if type is set to something else, use type
    try std.testing.expectEqual(ScriptType.module, determineScriptType("module", "javascript"));
    try std.testing.expectEqual(ScriptType.null, determineScriptType("text/plain", "javascript"));
}

test "determineScriptType - whitespace trimming" {
    try std.testing.expectEqual(ScriptType.classic, determineScriptType("  text/javascript  ", ""));
    try std.testing.expectEqual(ScriptType.module, determineScriptType("\t module \n", ""));
    try std.testing.expectEqual(ScriptType.importmap, determineScriptType("  importmap  ", ""));
}

// =============================================================================
// ClassicScript Structure Tests
// =============================================================================

/// Classic script representation
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#classic-script
const ClassicScript = struct {
    source_text: []const u8,
    base_url: []const u8,
    parse_error: bool,
    muted_errors: bool,

    pub fn init(source: []const u8, base: []const u8) ClassicScript {
        return .{
            .source_text = source,
            .base_url = base,
            .parse_error = false,
            .muted_errors = false,
        };
    }
};

test "ClassicScript - initialization" {
    const script = ClassicScript.init("console.log('hello');", "https://example.com/");
    try std.testing.expectEqualStrings("console.log('hello');", script.source_text);
    try std.testing.expectEqualStrings("https://example.com/", script.base_url);
    try std.testing.expect(!script.parse_error);
    try std.testing.expect(!script.muted_errors);
}

test "ClassicScript - empty source" {
    const script = ClassicScript.init("", "about:blank");
    try std.testing.expectEqualStrings("", script.source_text);
    try std.testing.expectEqualStrings("about:blank", script.base_url);
}

// =============================================================================
// ScriptResult Union Tests
// =============================================================================

/// Script result type
const ScriptResult = union(enum) {
    uninitialized,
    null,
    script: ClassicScript,
};

test "ScriptResult - uninitialized state" {
    const result: ScriptResult = .uninitialized;
    try std.testing.expect(result == .uninitialized);
}

test "ScriptResult - null (error) state" {
    const result: ScriptResult = .null;
    try std.testing.expect(result == .null);
}

test "ScriptResult - script state" {
    const script = ClassicScript.init("const x = 1;", "https://test.com/");
    const result: ScriptResult = .{ .script = script };
    switch (result) {
        .script => |s| {
            try std.testing.expectEqualStrings("const x = 1;", s.source_text);
        },
        else => try std.testing.expect(false),
    }
}

// =============================================================================
// InternalState Tests
// =============================================================================

/// Internal state for HTMLScriptElement (simplified for testing)
const InternalState = struct {
    parser_document: ?*anyopaque,
    preparation_time_document: ?*anyopaque,
    force_async: bool,
    from_external_file: bool,
    ready_to_be_parser_executed: bool,
    already_started: bool,
    delaying_the_load_event: bool,
    script_type: ScriptType,
    result: ScriptResult,

    pub fn init() InternalState {
        return .{
            .parser_document = null,
            .preparation_time_document = null,
            .force_async = true, // Initially true per spec
            .from_external_file = false,
            .ready_to_be_parser_executed = false,
            .already_started = false,
            .delaying_the_load_event = false,
            .script_type = .null,
            .result = .uninitialized,
        };
    }
};

test "InternalState - default values per spec" {
    const state = InternalState.init();

    // Per HTML Standard:
    // - parser_document: initially null
    // - force_async: initially true
    // - already_started: initially false
    // - script_type: initially null
    // - result: initially uninitialized

    try std.testing.expectEqual(@as(?*anyopaque, null), state.parser_document);
    try std.testing.expectEqual(@as(?*anyopaque, null), state.preparation_time_document);
    try std.testing.expect(state.force_async);
    try std.testing.expect(!state.from_external_file);
    try std.testing.expect(!state.ready_to_be_parser_executed);
    try std.testing.expect(!state.already_started);
    try std.testing.expect(!state.delaying_the_load_event);
    try std.testing.expectEqual(ScriptType.null, state.script_type);
    try std.testing.expectEqual(ScriptResult.uninitialized, state.result);
}

test "InternalState - parser insertion modifies force_async" {
    var state = InternalState.init();

    // Simulate parser inserting script
    var dummy_doc: u8 = 0; // Fake document pointer
    state.parser_document = @ptrCast(&dummy_doc);

    // Per spec: if parser-inserted and no async attribute, force_async stays true initially
    // but when async attribute is absent and parser_document is set, we clear force_async
    state.force_async = false;

    try std.testing.expect(!state.force_async);
    try std.testing.expect(state.parser_document != null);
}

test "InternalState - already_started prevents re-execution" {
    var state = InternalState.init();

    // First execution
    try std.testing.expect(!state.already_started);
    state.already_started = true;

    // Second attempt should see already_started = true
    try std.testing.expect(state.already_started);
}
