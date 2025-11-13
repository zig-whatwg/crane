//! Comprehensive Shadow DOM tests
//! Spec: https://dom.spec.whatwg.org/#shadow-trees

const std = @import("std");
const dom_types = @import("dom_types");

const Element = dom_types.Element;
const ShadowRoot = dom_types.ShadowRoot;
const ShadowRootInit = dom_types.ShadowRootInit;
const Document = dom_types.Document;
const Text = dom_types.Text;

test "Shadow DOM: attachShadow creates open shadow root" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var div = try doc.call_createElement("div");
    defer {
        // Cleanup shadow root if attached
        if (div.shadow_root) |shadow| {
            shadow.deinit();
            allocator.destroy(shadow);
        }
        div.deinit();
        allocator.destroy(div);
    }

    const init = ShadowRootInit{
        .mode = .open,
        .delegatesFocus = false,
        .slotAssignment = .named,
        .clonable = false,
        .serializable = false,
        .customElementRegistry = null,
    };

    const shadow = try div.call_attachShadow(init);
    
    try std.testing.expect(shadow != null);
    try std.testing.expectEqualStrings("open", shadow.get_mode());
    try std.testing.expect(!shadow.get_delegatesFocus());
    try std.testing.expectEqualStrings("named", shadow.get_slotAssignment());
    try std.testing.expect(!shadow.get_clonable());
    try std.testing.expect(!shadow.get_serializable());
    try std.testing.expectEqual(div, shadow.get_host());
}

test "Shadow DOM: attachShadow creates closed shadow root" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var div = try doc.call_createElement("div");
    defer {
        if (div.shadow_root) |shadow| {
            shadow.deinit();
            allocator.destroy(shadow);
        }
        div.deinit();
        allocator.destroy(div);
    }

    const init = ShadowRootInit{
        .mode = .closed,
        .delegatesFocus = true,
        .slotAssignment = .manual,
        .clonable = true,
        .serializable = true,
        .customElementRegistry = null,
    };

    const shadow = try div.call_attachShadow(init);
    
    try std.testing.expectEqualStrings("closed", shadow.get_mode());
    try std.testing.expect(shadow.get_delegatesFocus());
    try std.testing.expectEqualStrings("manual", shadow.get_slotAssignment());
    try std.testing.expect(shadow.get_clonable());
    try std.testing.expect(shadow.get_serializable());
}

test "Shadow DOM: shadowRoot getter returns open shadow" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var div = try doc.call_createElement("div");
    defer {
        if (div.shadow_root) |shadow| {
            shadow.deinit();
            allocator.destroy(shadow);
        }
        div.deinit();
        allocator.destroy(div);
    }

    const init = ShadowRootInit{
        .mode = .open,
        .delegatesFocus = false,
        .slotAssignment = .named,
        .clonable = false,
        .serializable = false,
        .customElementRegistry = null,
    };

    const shadow = try div.call_attachShadow(init);
    
    // shadowRoot getter should return the shadow root for open mode
    const retrieved = div.get_shadowRoot();
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqual(shadow, retrieved.?);
}

test "Shadow DOM: shadowRoot getter returns null for closed shadow" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var div = try doc.call_createElement("div");
    defer {
        if (div.shadow_root) |shadow| {
            shadow.deinit();
            allocator.destroy(shadow);
        }
        div.deinit();
        allocator.destroy(div);
    }

    const init = ShadowRootInit{
        .mode = .closed,
        .delegatesFocus = false,
        .slotAssignment = .named,
        .clonable = false,
        .serializable = false,
        .customElementRegistry = null,
    };

    _ = try div.call_attachShadow(init);
    
    // shadowRoot getter should return null for closed mode
    const retrieved = div.get_shadowRoot();
    try std.testing.expect(retrieved == null);
}

test "Shadow DOM: attachShadow throws for invalid element" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // script is not a valid shadow host
    var script = try doc.call_createElement("script");
    defer {
        script.deinit();
        allocator.destroy(script);
    }

    const init = ShadowRootInit{
        .mode = .open,
        .delegatesFocus = false,
        .slotAssignment = .named,
        .clonable = false,
        .serializable = false,
        .customElementRegistry = null,
    };

    const result = script.call_attachShadow(init);
    try std.testing.expectError(error.NotSupportedError, result);
}

test "Shadow DOM: double attachShadow throws for non-declarative" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var div = try doc.call_createElement("div");
    defer {
        if (div.shadow_root) |shadow| {
            shadow.deinit();
            allocator.destroy(shadow);
        }
        div.deinit();
        allocator.destroy(div);
    }

    const init = ShadowRootInit{
        .mode = .open,
        .delegatesFocus = false,
        .slotAssignment = .named,
        .clonable = false,
        .serializable = false,
        .customElementRegistry = null,
    };

    // First attachment
    _ = try div.call_attachShadow(init);

    // Second attachment should fail (not declarative)
    const result = div.call_attachShadow(init);
    try std.testing.expectError(error.NotSupportedError, result);
}

test "Shadow DOM: valid shadow host names" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const valid_names = [_][]const u8{
        "article", "aside",   "blockquote", "body", "div",
        "footer",  "h1",      "h2",         "h3",   "h4",
        "h5",      "h6",      "header",     "main", "nav",
        "p",       "section", "span",
    };

    const init = ShadowRootInit{
        .mode = .open,
        .delegatesFocus = false,
        .slotAssignment = .named,
        .clonable = false,
        .serializable = false,
        .customElementRegistry = null,
    };

    for (valid_names) |name| {
        var elem = try doc.call_createElement(name);
        defer {
            if (elem.shadow_root) |shadow| {
                shadow.deinit();
                allocator.destroy(shadow);
            }
            elem.deinit();
            allocator.destroy(elem);
        }

        // Should succeed
        _ = try elem.call_attachShadow(init);
        try std.testing.expect(elem.shadow_root != null);
    }
}
