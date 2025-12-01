//! DOM Trusted Types Integration
//!
//! W3C Trusted Types Spec: https://w3c.github.io/trusted-types/dist/spec/ § 2.3.1
//!
//! This module integrates Trusted Types enforcement with DOM injection sinks.
//! When CSP requires Trusted Types, string values passed to these sinks must
//! be wrapped in the appropriate Trusted Type.
//!
//! ## Injection Sinks
//!
//! ### Element Properties (require TrustedHTML)
//! - Element.innerHTML
//! - Element.outerHTML
//! - ShadowRoot.innerHTML
//!
//! ### Element Attributes
//! - script[src] → TrustedScriptURL
//! - iframe[srcdoc] → TrustedHTML
//! - SVGScriptElement[href] → TrustedScriptURL
//! - Event handler attributes (on*) → TrustedScript
//!
//! ### Script Element Properties (require TrustedScript)
//! - HTMLScriptElement.text
//! - HTMLScriptElement.textContent
//! - HTMLScriptElement.innerText
//!
//! ### Document Methods
//! - Document.write()
//! - Document.writeln()
//!
//! ## Usage
//!
//! ```zig
//! const dom_integration = @import("trusted_types").dom_integration;
//!
//! // In Element.set_innerHTML:
//! const validated = try dom_integration.enforceTrustedHTML(
//!     allocator,
//!     global,
//!     value,
//!     "Element innerHTML",
//! );
//! // Use validated string for actual innerHTML operation
//! ```

const std = @import("std");
const enforcement = @import("enforcement.zig");
const types = @import("types.zig");

// Re-export types for convenience
pub const TrustedHTML = types.TrustedHTML;
pub const TrustedScript = types.TrustedScript;
pub const TrustedScriptURL = types.TrustedScriptURL;
pub const ExpectedType = enforcement.ExpectedType;
pub const InputValue = enforcement.InputValue;
pub const GlobalObject = enforcement.GlobalObject;
pub const EnforcementError = enforcement.EnforcementError;
pub const CspPolicyInfo = enforcement.CspPolicyInfo;
pub const CspDisposition = enforcement.CspDisposition;

/// Error type for Trusted Types DOM integration
pub const TrustedTypesDOMError = error{
    /// The value is not a valid Trusted Type when enforcement is enabled
    TypeError,
    /// The operation is not allowed by CSP
    SecurityError,
    /// Memory allocation failed
    OutOfMemory,
    /// Invalid state
    InvalidStateError,
};

// ============================================================================
// Property Sink Enforcement
// ============================================================================

/// Enforce TrustedHTML for innerHTML/outerHTML setters
///
/// Per W3C Trusted Types spec §2.3.1:
/// - Element.innerHTML requires TrustedHTML
/// - Element.outerHTML requires TrustedHTML
/// - ShadowRoot.innerHTML requires TrustedHTML
///
/// Arguments:
/// - allocator: Allocator for any temporary allocations
/// - global: The global object with CSP/Trusted Types state
/// - value: The input value (string or TrustedHTML)
/// - sink_name: The sink name for error messages (e.g., "Element innerHTML")
///
/// Returns: The validated string value to use, or error
pub fn enforceTrustedHTML(
    allocator: std.mem.Allocator,
    global: *const GlobalObject,
    value: InputValue,
    sink_name: []const u8,
) TrustedTypesDOMError![]const u8 {
    return enforcement.getTrustedTypeCompliantString(
        allocator,
        .TrustedHTML,
        global,
        value,
        sink_name,
        "'script'", // Sink group for HTML injection sinks
    ) catch |err| switch (err) {
        EnforcementError.TypeError => TrustedTypesDOMError.TypeError,
        EnforcementError.OutOfMemory => TrustedTypesDOMError.OutOfMemory,
        EnforcementError.CallbackError => TrustedTypesDOMError.InvalidStateError,
    };
}

/// Enforce TrustedScript for script element text properties
///
/// Per W3C Trusted Types spec §2.3.1:
/// - HTMLScriptElement.text requires TrustedScript
/// - HTMLScriptElement.textContent requires TrustedScript
/// - HTMLScriptElement.innerText requires TrustedScript
///
/// Arguments:
/// - allocator: Allocator for any temporary allocations
/// - global: The global object with CSP/Trusted Types state
/// - value: The input value (string or TrustedScript)
/// - sink_name: The sink name for error messages
///
/// Returns: The validated string value to use, or error
pub fn enforceTrustedScript(
    allocator: std.mem.Allocator,
    global: *const GlobalObject,
    value: InputValue,
    sink_name: []const u8,
) TrustedTypesDOMError![]const u8 {
    return enforcement.getTrustedTypeCompliantString(
        allocator,
        .TrustedScript,
        global,
        value,
        sink_name,
        "'script'",
    ) catch |err| switch (err) {
        EnforcementError.TypeError => TrustedTypesDOMError.TypeError,
        EnforcementError.OutOfMemory => TrustedTypesDOMError.OutOfMemory,
        EnforcementError.CallbackError => TrustedTypesDOMError.InvalidStateError,
    };
}

/// Enforce TrustedScriptURL for script src attributes
///
/// Per W3C Trusted Types spec §2.3.1:
/// - HTMLScriptElement.src requires TrustedScriptURL
/// - SVGScriptElement.href requires TrustedScriptURL
///
/// Arguments:
/// - allocator: Allocator for any temporary allocations
/// - global: The global object with CSP/Trusted Types state
/// - value: The input value (string or TrustedScriptURL)
/// - sink_name: The sink name for error messages
///
/// Returns: The validated string value to use, or error
pub fn enforceTrustedScriptURL(
    allocator: std.mem.Allocator,
    global: *const GlobalObject,
    value: InputValue,
    sink_name: []const u8,
) TrustedTypesDOMError![]const u8 {
    return enforcement.getTrustedTypeCompliantString(
        allocator,
        .TrustedScriptURL,
        global,
        value,
        sink_name,
        "'script'",
    ) catch |err| switch (err) {
        EnforcementError.TypeError => TrustedTypesDOMError.TypeError,
        EnforcementError.OutOfMemory => TrustedTypesDOMError.OutOfMemory,
        EnforcementError.CallbackError => TrustedTypesDOMError.InvalidStateError,
    };
}

// ============================================================================
// Attribute Sink Enforcement
// ============================================================================

/// Check if an attribute requires Trusted Types enforcement
///
/// Per W3C Trusted Types spec §2.3.1:
/// - script[src] requires TrustedScriptURL
/// - iframe[srcdoc] requires TrustedHTML
/// - Event handler attributes (on*) require TrustedScript
pub fn getRequiredTypeForAttribute(
    tag_name: []const u8,
    attribute_name: []const u8,
) ?ExpectedType {
    return enforcement.getRequiredTypeForAttribute(tag_name, attribute_name);
}

/// Enforce Trusted Types for setAttribute operations
///
/// This should be called by Element.setAttribute and Element.setAttributeNS
/// when the attribute requires Trusted Types.
///
/// Arguments:
/// - allocator: Allocator for any temporary allocations
/// - global: The global object with CSP/Trusted Types state
/// - tag_name: The element's tag name
/// - attr_name: The attribute name
/// - value: The attribute value (string or Trusted Type)
///
/// Returns: The validated string value to use, or error
pub fn enforceAttributeValue(
    allocator: std.mem.Allocator,
    global: *const GlobalObject,
    tag_name: []const u8,
    attr_name: []const u8,
    value: InputValue,
) TrustedTypesDOMError![]const u8 {
    const required_type = getRequiredTypeForAttribute(tag_name, attr_name) orelse {
        // No Trusted Type required for this attribute
        return value.toStringValue();
    };

    const sink_name = getSinkNameForAttribute(tag_name, attr_name);

    return enforcement.getTrustedTypeCompliantString(
        allocator,
        required_type,
        global,
        value,
        sink_name,
        "'script'",
    ) catch |err| switch (err) {
        EnforcementError.TypeError => TrustedTypesDOMError.TypeError,
        EnforcementError.OutOfMemory => TrustedTypesDOMError.OutOfMemory,
        EnforcementError.CallbackError => TrustedTypesDOMError.InvalidStateError,
    };
}

/// Get the sink name for an attribute (for error messages)
fn getSinkNameForAttribute(tag_name: []const u8, attr_name: []const u8) []const u8 {
    // Build sink name like "HTMLScriptElement src" or "Element onclick"
    // For simplicity, return a static string based on common patterns
    if (std.mem.eql(u8, tag_name, "script")) {
        if (std.mem.eql(u8, attr_name, "src")) {
            return "HTMLScriptElement src";
        }
    } else if (std.mem.eql(u8, tag_name, "iframe")) {
        if (std.mem.eql(u8, attr_name, "srcdoc")) {
            return "HTMLIFrameElement srcdoc";
        }
    }

    // Event handlers
    if (std.mem.startsWith(u8, attr_name, "on")) {
        return "Element event handler attribute";
    }

    return "Element attribute";
}

// ============================================================================
// Property Sink Type Checking
// ============================================================================

/// Check if a property requires Trusted Types enforcement
///
/// Per W3C Trusted Types spec §2.3.1:
/// - innerHTML requires TrustedHTML
/// - outerHTML requires TrustedHTML
/// - script.src requires TrustedScriptURL
/// - script.text/textContent/innerText require TrustedScript
pub fn getRequiredTypeForProperty(
    tag_name: []const u8,
    property_name: []const u8,
) ?ExpectedType {
    return enforcement.getRequiredTypeForProperty(tag_name, property_name);
}

// ============================================================================
// Document Method Enforcement
// ============================================================================

/// Enforce TrustedHTML for Document.write() and Document.writeln()
///
/// Per HTML spec integrated with Trusted Types:
/// - Document.write() requires TrustedHTML when CSP enforces Trusted Types
/// - Document.writeln() requires TrustedHTML when CSP enforces Trusted Types
///
/// Arguments:
/// - allocator: Allocator for any temporary allocations
/// - global: The global object with CSP/Trusted Types state
/// - value: The input value (string or TrustedHTML)
/// - method_name: "write" or "writeln"
///
/// Returns: The validated string value to use, or error
pub fn enforceDocumentWrite(
    allocator: std.mem.Allocator,
    global: *const GlobalObject,
    value: InputValue,
    method_name: []const u8,
) TrustedTypesDOMError![]const u8 {
    const sink_name = if (std.mem.eql(u8, method_name, "write"))
        "Document write"
    else
        "Document writeln";

    return enforceTrustedHTML(allocator, global, value, sink_name);
}

// ============================================================================
// insertAdjacentHTML Enforcement
// ============================================================================

/// Enforce TrustedHTML for Element.insertAdjacentHTML()
///
/// Per W3C Trusted Types spec §2.3.1:
/// - Element.insertAdjacentHTML() requires TrustedHTML
///
/// Arguments:
/// - allocator: Allocator for any temporary allocations
/// - global: The global object with CSP/Trusted Types state
/// - value: The input value (string or TrustedHTML)
///
/// Returns: The validated string value to use, or error
pub fn enforceInsertAdjacentHTML(
    allocator: std.mem.Allocator,
    global: *const GlobalObject,
    value: InputValue,
) TrustedTypesDOMError![]const u8 {
    return enforceTrustedHTML(allocator, global, value, "Element insertAdjacentHTML");
}

// ============================================================================
// DOMParser Enforcement
// ============================================================================

/// Enforce TrustedHTML for DOMParser.parseFromString() with HTML types
///
/// Per W3C Trusted Types spec §2.3.1:
/// - DOMParser.parseFromString() with type "text/html" requires TrustedHTML
///
/// Arguments:
/// - allocator: Allocator for any temporary allocations
/// - global: The global object with CSP/Trusted Types state
/// - value: The input value (string or TrustedHTML)
/// - mime_type: The MIME type being parsed
///
/// Returns: The validated string value to use, or error
pub fn enforceDOMParserParseFromString(
    allocator: std.mem.Allocator,
    global: *const GlobalObject,
    value: InputValue,
    mime_type: []const u8,
) TrustedTypesDOMError![]const u8 {
    // Only HTML types require TrustedHTML
    if (std.mem.eql(u8, mime_type, "text/html")) {
        return enforceTrustedHTML(allocator, global, value, "DOMParser parseFromString");
    }

    // Other types (XML, SVG) don't require Trusted Types
    return value.toStringValue();
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Create an InputValue from a string
pub fn inputFromString(value: []const u8) InputValue {
    return InputValue{ .string = value };
}

/// Create an InputValue from a TrustedHTML
pub fn inputFromTrustedHTML(value: TrustedHTML) InputValue {
    return InputValue{ .trusted_html = value };
}

/// Create an InputValue from a TrustedScript
pub fn inputFromTrustedScript(value: TrustedScript) InputValue {
    return InputValue{ .trusted_script = value };
}

/// Create an InputValue from a TrustedScriptURL
pub fn inputFromTrustedScriptURL(value: TrustedScriptURL) InputValue {
    return InputValue{ .trusted_script_url = value };
}

/// Create a GlobalObject with no CSP (for testing or when CSP is disabled)
pub fn createGlobalNoCsp(allocator: std.mem.Allocator) GlobalObject {
    return GlobalObject.initNoCsp(allocator);
}

/// Create a GlobalObject with CSP requiring Trusted Types
pub fn createGlobalWithTrustedTypes(
    allocator: std.mem.Allocator,
    csp_policies: []const CspPolicyInfo,
) GlobalObject {
    return GlobalObject.init(allocator, csp_policies);
}

/// Create a CspPolicyInfo with require-trusted-types-for directive
pub fn createCspPolicyInfo(
    disposition: CspDisposition,
    required_sink_groups: []const []const u8,
) CspPolicyInfo {
    return enforcement.createCspPolicyInfo(disposition, required_sink_groups);
}

// ============================================================================
// Tests
// ============================================================================

test "enforceTrustedHTML - no CSP enforcement" {
    const allocator = std.testing.allocator;

    // Create global with no CSP
    var global = createGlobalNoCsp(allocator);
    _ = &global;

    // String should pass through when enforcement is disabled
    const input = inputFromString("<div>test</div>");
    const result = try enforceTrustedHTML(allocator, &global, input, "Element innerHTML");

    try std.testing.expectEqualStrings("<div>test</div>", result);
}

test "enforceTrustedHTML - TrustedHTML passes" {
    const allocator = std.testing.allocator;

    // Create CSP policy requiring Trusted Types
    const sink_groups = [_][]const u8{"'script'"};
    const policies = [_]CspPolicyInfo{
        createCspPolicyInfo(.enforce, &sink_groups),
    };

    var global = createGlobalWithTrustedTypes(allocator, &policies);
    _ = &global;

    // Create TrustedHTML value
    var trusted_html = try TrustedHTML.create(allocator, "<div>trusted</div>");
    defer trusted_html.deinit();

    const input = inputFromTrustedHTML(trusted_html);
    const result = try enforceTrustedHTML(allocator, &global, input, "Element innerHTML");

    try std.testing.expectEqualStrings("<div>trusted</div>", result);
}

test "enforceTrustedHTML - string blocked with CSP" {
    const allocator = std.testing.allocator;

    // Create CSP policy requiring Trusted Types
    const sink_groups = [_][]const u8{"'script'"};
    const policies = [_]CspPolicyInfo{
        createCspPolicyInfo(.enforce, &sink_groups),
    };

    var global = createGlobalWithTrustedTypes(allocator, &policies);
    _ = &global;

    // String should be blocked when enforcement is enabled
    const input = inputFromString("<div>untrusted</div>");
    const result = enforceTrustedHTML(allocator, &global, input, "Element innerHTML");

    try std.testing.expectError(TrustedTypesDOMError.TypeError, result);
}

test "getRequiredTypeForAttribute - script src" {
    const result = getRequiredTypeForAttribute("script", "src");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(ExpectedType.TrustedScriptURL, result.?);
}

test "getRequiredTypeForAttribute - onclick" {
    const result = getRequiredTypeForAttribute("button", "onclick");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(ExpectedType.TrustedScript, result.?);
}

test "getRequiredTypeForAttribute - regular attribute" {
    const result = getRequiredTypeForAttribute("div", "class");
    try std.testing.expect(result == null);
}

test "getRequiredTypeForProperty - innerHTML" {
    const result = getRequiredTypeForProperty("div", "innerHTML");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(ExpectedType.TrustedHTML, result.?);
}

test "getRequiredTypeForProperty - script text" {
    const result = getRequiredTypeForProperty("script", "text");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(ExpectedType.TrustedScript, result.?);
}
