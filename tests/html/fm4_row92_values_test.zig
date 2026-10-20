//! Forms remainder regressions through generated interfaces, with leak checking.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

const support = @import("fm4_row92_support.zig");
const attribute = support.attribute;
const create = support.create;
const expectValue = support.expectValue;
const withDocument = support.withDocument;

fn emailMultiple(document: *runtime.Instance) !void {
    const input = try create(document, "input");
    defer dom.node_creation.destroyUninserted(input);
    try attribute(input, "type", "email");
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("first@example.com , second@example.com"));
    try attribute(input, "multiple", "");
    try expectValue(input, "first@example.com,second@example.com");
    try interfaces.Element.call_removeAttribute(input, runtime.DOMString.initInterned("multiple"));
    try expectValue(input, "first@example.com,second@example.com");
}

fn rangeDecimals(document: *runtime.Instance) !void {
    const input = try create(document, "input");
    defer dom.node_creation.destroyUninserted(input);
    try attribute(input, "type", "range");
    try attribute(input, "min", "0");
    try attribute(input, "max", "1");
    try attribute(input, "step", "0.1");
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("0.6"));
    try expectValue(input, "0.6");
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("0.65"));
    try expectValue(input, "0.7");
    try attribute(input, "min", "-0.95");
    try attribute(input, "max", "0.95");
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("-0.6"));
    try expectValue(input, "-0.55");
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("-0.6000000000000001"));
    try expectValue(input, "-0.65");
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("-0.5999999999999999"));
    try expectValue(input, "-0.55");
    try attribute(input, "step", "any");
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("0.333"));
    try expectValue(input, "0.333");
    try attribute(input, "min", "9999999999.95");
    try attribute(input, "max", "10000000001");
    try attribute(input, "step", "0.1");
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("10000000000.3"));
    try expectValue(input, "10000000000.35");
    try attribute(input, "min", "");
    try attribute(input, "max", "100");
    try attribute(input, "step", "1000");
    try attribute(input, "value", "200");
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("100"));
    try expectValue(input, "100");
}

fn emptyStep(document: *runtime.Instance) !void {
    const input = try create(document, "input");
    defer dom.node_creation.destroyUninserted(input);
    try attribute(input, "type", "number");
    try attribute(input, "min", "7");
    try interfaces.HTMLInputElement.call_stepDown(input, .notPassed());
    try expectValue(input, "7");
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("3"));
    try interfaces.HTMLInputElement.call_stepDown(input, .notPassed());
    try expectValue(input, "3");
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("3.5"));
    try interfaces.HTMLInputElement.call_stepDown(input, .notPassed());
    try expectValue(input, "3.5");
    try interfaces.Element.call_removeAttribute(input, runtime.DOMString.initInterned("min"));
    try attribute(input, "max", "-7");
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initEmpty());
    try interfaces.HTMLInputElement.call_stepUp(input, .notPassed());
    try expectValue(input, "-7");
}

fn detachedRadios(document: *runtime.Instance) !void {
    const form = try create(document, "form");
    defer dom.node_creation.destroyUninserted(form);
    const first = try create(document, "input");
    const second = try create(document, "input");
    for ([_]*runtime.Instance{ first, second }) |input| {
        try attribute(input, "type", "radio");
        try attribute(input, "name", "group");
        try interfaces.HTMLInputElement.set_checked(input, true);
        _ = try interfaces.Node.call_appendChild(form, input);
    }
    try testing.expect(!try interfaces.HTMLInputElement.get_checked(first));
    try testing.expect(try interfaces.HTMLInputElement.get_checked(second));
}

test "email multiple attribute sanitizes the existing value" {
    try withDocument(emailMultiple);
}

test "range sanitization preserves decimal steps and positive ties" {
    try withDocument(rangeDecimals);
}

test "empty numeric stepping clamps but valid wrong-direction values stay" {
    try withDocument(emptyStep);
}

test "joining a detached form normalizes checked radio groups" {
    try withDocument(detachedRadios);
}
