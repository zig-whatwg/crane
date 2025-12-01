//! Tests for DOM Trusted Types Integration
//!
//! Validates that DOM injection sinks properly enforce Trusted Types
//! when CSP requires it.

const std = @import("std");
const trusted_types = @import("trusted_types");
const dom_integration = trusted_types.dom_integration;

test "enforceTrustedHTML - no CSP allows string" {
    const allocator = std.testing.allocator;

    var global = dom_integration.createGlobalNoCsp(allocator);
    _ = &global;

    const input = dom_integration.inputFromString("<div>test</div>");
    const result = try dom_integration.enforceTrustedHTML(allocator, &global, input, "Element innerHTML");

    try std.testing.expectEqualStrings("<div>test</div>", result);
}

test "enforceTrustedHTML - CSP blocks untrusted string" {
    const allocator = std.testing.allocator;

    // Create enforcing CSP
    const sink_groups = [_][]const u8{"'script'"};
    const policies = [_]dom_integration.CspPolicyInfo{
        dom_integration.createCspPolicyInfo(.enforce, &sink_groups),
    };

    var global = dom_integration.createGlobalWithTrustedTypes(allocator, &policies);
    _ = &global;

    const input = dom_integration.inputFromString("<script>evil()</script>");
    const result = dom_integration.enforceTrustedHTML(allocator, &global, input, "Element innerHTML");

    try std.testing.expectError(dom_integration.TrustedTypesDOMError.TypeError, result);
}

test "enforceTrustedHTML - CSP allows TrustedHTML" {
    const allocator = std.testing.allocator;

    // Create enforcing CSP
    const sink_groups = [_][]const u8{"'script'"};
    const policies = [_]dom_integration.CspPolicyInfo{
        dom_integration.createCspPolicyInfo(.enforce, &sink_groups),
    };

    var global = dom_integration.createGlobalWithTrustedTypes(allocator, &policies);
    _ = &global;

    // Create TrustedHTML
    var html = try dom_integration.TrustedHTML.create(allocator, "<div>safe</div>");
    defer html.deinit();

    const input = dom_integration.inputFromTrustedHTML(html);
    const result = try dom_integration.enforceTrustedHTML(allocator, &global, input, "Element innerHTML");

    try std.testing.expectEqualStrings("<div>safe</div>", result);
}

test "enforceTrustedScript - CSP blocks untrusted string" {
    const allocator = std.testing.allocator;

    // Create enforcing CSP
    const sink_groups = [_][]const u8{"'script'"};
    const policies = [_]dom_integration.CspPolicyInfo{
        dom_integration.createCspPolicyInfo(.enforce, &sink_groups),
    };

    var global = dom_integration.createGlobalWithTrustedTypes(allocator, &policies);
    _ = &global;

    const input = dom_integration.inputFromString("alert('xss')");
    const result = dom_integration.enforceTrustedScript(allocator, &global, input, "HTMLScriptElement text");

    try std.testing.expectError(dom_integration.TrustedTypesDOMError.TypeError, result);
}

test "enforceTrustedScript - CSP allows TrustedScript" {
    const allocator = std.testing.allocator;

    // Create enforcing CSP
    const sink_groups = [_][]const u8{"'script'"};
    const policies = [_]dom_integration.CspPolicyInfo{
        dom_integration.createCspPolicyInfo(.enforce, &sink_groups),
    };

    var global = dom_integration.createGlobalWithTrustedTypes(allocator, &policies);
    _ = &global;

    // Create TrustedScript
    var script = try dom_integration.TrustedScript.create(allocator, "console.log('safe')");
    defer script.deinit();

    const input = dom_integration.inputFromTrustedScript(script);
    const result = try dom_integration.enforceTrustedScript(allocator, &global, input, "HTMLScriptElement text");

    try std.testing.expectEqualStrings("console.log('safe')", result);
}

test "enforceTrustedScriptURL - CSP blocks untrusted string" {
    const allocator = std.testing.allocator;

    // Create enforcing CSP
    const sink_groups = [_][]const u8{"'script'"};
    const policies = [_]dom_integration.CspPolicyInfo{
        dom_integration.createCspPolicyInfo(.enforce, &sink_groups),
    };

    var global = dom_integration.createGlobalWithTrustedTypes(allocator, &policies);
    _ = &global;

    const input = dom_integration.inputFromString("https://evil.com/script.js");
    const result = dom_integration.enforceTrustedScriptURL(allocator, &global, input, "HTMLScriptElement src");

    try std.testing.expectError(dom_integration.TrustedTypesDOMError.TypeError, result);
}

test "enforceTrustedScriptURL - CSP allows TrustedScriptURL" {
    const allocator = std.testing.allocator;

    // Create enforcing CSP
    const sink_groups = [_][]const u8{"'script'"};
    const policies = [_]dom_integration.CspPolicyInfo{
        dom_integration.createCspPolicyInfo(.enforce, &sink_groups),
    };

    var global = dom_integration.createGlobalWithTrustedTypes(allocator, &policies);
    _ = &global;

    // Create TrustedScriptURL
    var url = try dom_integration.TrustedScriptURL.create(allocator, "https://trusted.com/script.js");
    defer url.deinit();

    const input = dom_integration.inputFromTrustedScriptURL(url);
    const result = try dom_integration.enforceTrustedScriptURL(allocator, &global, input, "HTMLScriptElement src");

    try std.testing.expectEqualStrings("https://trusted.com/script.js", result);
}

test "getRequiredTypeForAttribute - script src" {
    const result = dom_integration.getRequiredTypeForAttribute("script", "src");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(dom_integration.ExpectedType.TrustedScriptURL, result.?);
}

test "getRequiredTypeForAttribute - iframe srcdoc" {
    const result = dom_integration.getRequiredTypeForAttribute("iframe", "srcdoc");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(dom_integration.ExpectedType.TrustedHTML, result.?);
}

test "getRequiredTypeForAttribute - event handler" {
    const result = dom_integration.getRequiredTypeForAttribute("button", "onclick");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(dom_integration.ExpectedType.TrustedScript, result.?);
}

test "getRequiredTypeForAttribute - non-sensitive attribute" {
    const result = dom_integration.getRequiredTypeForAttribute("div", "class");
    try std.testing.expect(result == null);
}

test "getRequiredTypeForProperty - innerHTML" {
    const result = dom_integration.getRequiredTypeForProperty("div", "innerHTML");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(dom_integration.ExpectedType.TrustedHTML, result.?);
}

test "getRequiredTypeForProperty - outerHTML" {
    const result = dom_integration.getRequiredTypeForProperty("span", "outerHTML");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(dom_integration.ExpectedType.TrustedHTML, result.?);
}

test "getRequiredTypeForProperty - script.text" {
    const result = dom_integration.getRequiredTypeForProperty("script", "text");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(dom_integration.ExpectedType.TrustedScript, result.?);
}

test "getRequiredTypeForProperty - script.src" {
    const result = dom_integration.getRequiredTypeForProperty("script", "src");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(dom_integration.ExpectedType.TrustedScriptURL, result.?);
}

test "getRequiredTypeForProperty - non-sensitive property" {
    const result = dom_integration.getRequiredTypeForProperty("div", "className");
    try std.testing.expect(result == null);
}

test "enforceDocumentWrite - CSP blocks untrusted" {
    const allocator = std.testing.allocator;

    // Create enforcing CSP
    const sink_groups = [_][]const u8{"'script'"};
    const policies = [_]dom_integration.CspPolicyInfo{
        dom_integration.createCspPolicyInfo(.enforce, &sink_groups),
    };

    var global = dom_integration.createGlobalWithTrustedTypes(allocator, &policies);
    _ = &global;

    const input = dom_integration.inputFromString("<script>evil()</script>");
    const result = dom_integration.enforceDocumentWrite(allocator, &global, input, "write");

    try std.testing.expectError(dom_integration.TrustedTypesDOMError.TypeError, result);
}

test "enforceInsertAdjacentHTML - CSP blocks untrusted" {
    const allocator = std.testing.allocator;

    // Create enforcing CSP
    const sink_groups = [_][]const u8{"'script'"};
    const policies = [_]dom_integration.CspPolicyInfo{
        dom_integration.createCspPolicyInfo(.enforce, &sink_groups),
    };

    var global = dom_integration.createGlobalWithTrustedTypes(allocator, &policies);
    _ = &global;

    const input = dom_integration.inputFromString("<div onclick='evil()'>click me</div>");
    const result = dom_integration.enforceInsertAdjacentHTML(allocator, &global, input);

    try std.testing.expectError(dom_integration.TrustedTypesDOMError.TypeError, result);
}

test "enforceDOMParserParseFromString - HTML type requires TrustedHTML" {
    const allocator = std.testing.allocator;

    // Create enforcing CSP
    const sink_groups = [_][]const u8{"'script'"};
    const policies = [_]dom_integration.CspPolicyInfo{
        dom_integration.createCspPolicyInfo(.enforce, &sink_groups),
    };

    var global = dom_integration.createGlobalWithTrustedTypes(allocator, &policies);
    _ = &global;

    const input = dom_integration.inputFromString("<html><body>test</body></html>");

    // text/html requires TrustedHTML
    const html_result = dom_integration.enforceDOMParserParseFromString(allocator, &global, input, "text/html");
    try std.testing.expectError(dom_integration.TrustedTypesDOMError.TypeError, html_result);

    // text/xml does not require TrustedHTML
    const xml_result = try dom_integration.enforceDOMParserParseFromString(allocator, &global, input, "text/xml");
    try std.testing.expectEqualStrings("<html><body>test</body></html>", xml_result);
}

test "report-only CSP allows string but would report" {
    const allocator = std.testing.allocator;

    // Create report-only CSP
    const sink_groups = [_][]const u8{"'script'"};
    const policies = [_]dom_integration.CspPolicyInfo{
        dom_integration.createCspPolicyInfo(.report, &sink_groups),
    };

    var global = dom_integration.createGlobalWithTrustedTypes(allocator, &policies);
    _ = &global;

    // String should pass through in report-only mode
    const input = dom_integration.inputFromString("<div>test</div>");
    const result = try dom_integration.enforceTrustedHTML(allocator, &global, input, "Element innerHTML");

    try std.testing.expectEqualStrings("<div>test</div>", result);
}
