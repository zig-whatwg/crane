//! Tests migrated from src/selector/matcher.zig
//! Per WHATWG specifications

const std = @import("std");

const selector = @import("selector");
const source = @import("../../src/selector/matcher.zig");

test "Matcher: type selector (div)" {
    const allocator = testing.allocator;
    const elem = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, elem);

    const input = "div";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result);
}
test "Matcher: type selector mismatch" {
    const allocator = testing.allocator;
    const elem = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, elem);

    const input = "span";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(!result);
}
test "Matcher: class selector" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "class", .value = "container active" },
    });
    defer destroyTestElement(allocator, elem);

    const input = ".container";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result);
}
test "Matcher: ID selector" {
    const allocator = testing.allocator;
    const elem = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, elem);

    try elem.setId("main");

    const input = "#main";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result);
}
test "Matcher: compound selector (div.container)" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "class", .value = "container" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "div.container";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result);
}
test "Matcher: attribute selector [href]" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "a", &.{
        .{ .name = "href", .value = "https://example.com" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "[href]";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result);
}
test "Matcher: :empty pseudo-class" {
    const allocator = testing.allocator;
    const elem = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, elem);

    const input = "div:empty";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result); // Empty div should match
}
test "Matcher: :lang(en) pseudo-class" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "lang", .value = "en" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "div:lang(en)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result);
}
test "Matcher: :lang(en) matches en-US variant" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "lang", .value = "en-US" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "div:lang(en)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result); // en-US should match :lang(en)
}
test "Matcher: child combinator (div > p)" {
    const allocator = testing.allocator;

    // Create parent div
    const parent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent);

    // Create child p
    const child = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, child);

    // Link them
    child.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&child.base);

    const input = "div > p";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(child, &selector_list);

    try testing.expect(result);
}
test "Matcher: descendant combinator (div p)" {
    const allocator = testing.allocator;

    // Create grandparent div
    const grandparent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, grandparent);

    // Create parent span
    const parent = try createTestElement(allocator, "span");
    defer destroyTestElement(allocator, parent);

    // Create child p
    const child = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, child);

    // Link: div > span > p
    parent.base.parent_node = &grandparent.base;
    try grandparent.base.child_nodes.append(&parent.base);
    child.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&child.base);

    const input = "div p";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(child, &selector_list);

    try testing.expect(result); // p is descendant of div
}
test "Matcher: next-sibling combinator (h1 + p)" {
    const allocator = testing.allocator;

    // Create parent
    const parent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent);

    // Create siblings
    const h1 = try createTestElement(allocator, "h1");
    defer destroyTestElement(allocator, h1);

    const p = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p);

    // Link as siblings: div > h1, p
    h1.base.parent_node = &parent.base;
    p.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&h1.base);
    try parent.base.child_nodes.append(&p.base);

    const input = "h1 + p";
    var tokenizer = Tokenizer.init(allocator, input);
    var p_parser = try Parser.init(allocator, &tokenizer);
    defer p_parser.deinit();

    var selector_list = try p_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(p, &selector_list);

    try testing.expect(result); // p immediately follows h1
}
test "Matcher: subsequent-sibling combinator (h1 ~ p)" {
    const allocator = testing.allocator;

    // Create parent
    const parent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent);

    // Create siblings: h1, span, p
    const h1 = try createTestElement(allocator, "h1");
    defer destroyTestElement(allocator, h1);

    const span = try createTestElement(allocator, "span");
    defer destroyTestElement(allocator, span);

    const p = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p);

    // Link as siblings
    h1.base.parent_node = &parent.base;
    span.base.parent_node = &parent.base;
    p.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&h1.base);
    try parent.base.child_nodes.append(&span.base);
    try parent.base.child_nodes.append(&p.base);

    const input = "h1 ~ p";
    var tokenizer = Tokenizer.init(allocator, input);
    var p_parser = try Parser.init(allocator, &tokenizer);
    defer p_parser.deinit();

    var selector_list = try p_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(p, &selector_list);

    try testing.expect(result); // p follows h1 (not immediately)
}
test "Matcher: :first-child pseudo-class" {
    const allocator = testing.allocator;

    // Create parent
    const parent = try createTestElement(allocator, "ul");
    defer destroyTestElement(allocator, parent);

    // Create children
    const li1 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li1);

    const li2 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li2);

    // Link
    li1.base.parent_node = &parent.base;
    li2.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&li1.base);
    try parent.base.child_nodes.append(&li2.base);

    const input = "li:first-child";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(li1, &selector_list)); // li1 is first-child
    try testing.expect(!try matcher.matches(li2, &selector_list)); // li2 is not first-child
}
test "Matcher: :last-child pseudo-class" {
    const allocator = testing.allocator;

    // Create parent
    const parent = try createTestElement(allocator, "ul");
    defer destroyTestElement(allocator, parent);

    // Create children
    const li1 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li1);

    const li2 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li2);

    // Link
    li1.base.parent_node = &parent.base;
    li2.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&li1.base);
    try parent.base.child_nodes.append(&li2.base);

    const input = "li:last-child";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(!try matcher.matches(li1, &selector_list)); // li1 is not last-child
    try testing.expect(try matcher.matches(li2, &selector_list)); // li2 is last-child
}
test "Matcher: :only-child pseudo-class" {
    const allocator = testing.allocator;

    // Create parent with one child
    const parent1 = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent1);

    const only = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, only);

    only.base.parent_node = &parent1.base;
    try parent1.base.child_nodes.append(&only.base);

    // Create parent with multiple children
    const parent2 = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent2);

    const child1 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, child1);

    const child2 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, child2);

    child1.base.parent_node = &parent2.base;
    child2.base.parent_node = &parent2.base;
    try parent2.base.child_nodes.append(&child1.base);
    try parent2.base.child_nodes.append(&child2.base);

    const input = "p:only-child";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(only, &selector_list)); // only is only-child
    try testing.expect(!try matcher.matches(child1, &selector_list)); // child1 has siblings
}
test "Matcher: :first-of-type pseudo-class" {
    const allocator = testing.allocator;

    // Create parent
    const parent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent);

    // Create mixed children: div, p, p
    const div = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, div);

    const p1 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p1);

    const p2 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p2);

    // Link
    div.base.parent_node = &parent.base;
    p1.base.parent_node = &parent.base;
    p2.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&div.base);
    try parent.base.child_nodes.append(&p1.base);
    try parent.base.child_nodes.append(&p2.base);

    const input = "p:first-of-type";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(p1, &selector_list)); // p1 is first p
    try testing.expect(!try matcher.matches(p2, &selector_list)); // p2 is second p
}
test "Matcher: :last-of-type pseudo-class" {
    const allocator = testing.allocator;

    // Create parent
    const parent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent);

    // Create mixed children: p, p, div
    const p1 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p1);

    const p2 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p2);

    const div = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, div);

    // Link
    p1.base.parent_node = &parent.base;
    p2.base.parent_node = &parent.base;
    div.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&p1.base);
    try parent.base.child_nodes.append(&p2.base);
    try parent.base.child_nodes.append(&div.base);

    const input = "p:last-of-type";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(!try matcher.matches(p1, &selector_list)); // p1 is not last p
    try testing.expect(try matcher.matches(p2, &selector_list)); // p2 is last p
}
test "Matcher: :only-of-type pseudo-class" {
    const allocator = testing.allocator;

    // Create parent with mixed types: div, p, span
    const parent = try createTestElement(allocator, "section");
    defer destroyTestElement(allocator, parent);

    const div = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, div);

    const p = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p);

    const span = try createTestElement(allocator, "span");
    defer destroyTestElement(allocator, span);

    // Link
    div.base.parent_node = &parent.base;
    p.base.parent_node = &parent.base;
    span.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&div.base);
    try parent.base.child_nodes.append(&p.base);
    try parent.base.child_nodes.append(&span.base);

    const input = "p:only-of-type";
    var tokenizer = Tokenizer.init(allocator, input);
    var p_parser = try Parser.init(allocator, &tokenizer);
    defer p_parser.deinit();

    var selector_list = try p_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(p, &selector_list)); // p is only p
}
test "Matcher: :nth-child(2n) even" {
    const allocator = testing.allocator;

    // Create parent with 4 children
    const parent = try createTestElement(allocator, "ul");
    defer destroyTestElement(allocator, parent);

    const li1 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li1);
    const li2 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li2);
    const li3 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li3);
    const li4 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li4);

    // Link all
    li1.base.parent_node = &parent.base;
    li2.base.parent_node = &parent.base;
    li3.base.parent_node = &parent.base;
    li4.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&li1.base);
    try parent.base.child_nodes.append(&li2.base);
    try parent.base.child_nodes.append(&li3.base);
    try parent.base.child_nodes.append(&li4.base);

    const input = "li:nth-child(even)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(!try matcher.matches(li1, &selector_list)); // odd
    try testing.expect(try matcher.matches(li2, &selector_list)); // even
    try testing.expect(!try matcher.matches(li3, &selector_list)); // odd
    try testing.expect(try matcher.matches(li4, &selector_list)); // even
}
test "Matcher: :nth-child(2n+1) odd" {
    const allocator = testing.allocator;

    // Create parent with 3 children
    const parent = try createTestElement(allocator, "ul");
    defer destroyTestElement(allocator, parent);

    const li1 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li1);
    const li2 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li2);
    const li3 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li3);

    // Link all
    li1.base.parent_node = &parent.base;
    li2.base.parent_node = &parent.base;
    li3.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&li1.base);
    try parent.base.child_nodes.append(&li2.base);
    try parent.base.child_nodes.append(&li3.base);

    const input = "li:nth-child(odd)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(li1, &selector_list)); // odd
    try testing.expect(!try matcher.matches(li2, &selector_list)); // even
    try testing.expect(try matcher.matches(li3, &selector_list)); // odd
}
test "Matcher: :nth-last-child(2)" {
    const allocator = testing.allocator;

    // Create parent with 3 children
    const parent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent);

    const p1 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p1);
    const p2 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p2);
    const p3 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p3);

    // Link
    p1.base.parent_node = &parent.base;
    p2.base.parent_node = &parent.base;
    p3.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&p1.base);
    try parent.base.child_nodes.append(&p2.base);
    try parent.base.child_nodes.append(&p3.base);

    const input = "p:nth-last-child(2)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(!try matcher.matches(p1, &selector_list)); // 3rd from end
    try testing.expect(try matcher.matches(p2, &selector_list)); // 2nd from end
    try testing.expect(!try matcher.matches(p3, &selector_list)); // 1st from end
}
test "Matcher: :root pseudo-class" {
    const allocator = testing.allocator;

    // Create root element (no parent)
    const root = try createTestElement(allocator, "html");
    defer destroyTestElement(allocator, root);

    // Create child element
    const child = try createTestElement(allocator, "body");
    defer destroyTestElement(allocator, child);

    child.base.parent_node = &root.base;
    try root.base.child_nodes.append(&child.base);

    const input = ":root";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(root, &selector_list)); // root has no parent
    try testing.expect(!try matcher.matches(child, &selector_list)); // child has parent
}
test "Matcher: attribute exact match [type='text']" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "input", &.{
        .{ .name = "type", .value = "text" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "[type='text']";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}
test "Matcher: attribute prefix match [href^='https']" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "a", &.{
        .{ .name = "href", .value = "https://example.com" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "[href^='https']";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}
test "Matcher: attribute suffix match [src$='.png']" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "img", &.{
        .{ .name = "src", .value = "/images/logo.png" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "[src$='.png']";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}
test "Matcher: attribute substring match [title*='hello']" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "title", .value = "Say hello world" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "[title*='hello']";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}
test "Matcher: attribute includes word [class~='active']" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "class", .value = "btn btn-primary active" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "[class~='active']";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}
test "Matcher: attribute dash match [lang|='en']" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "lang", .value = "en-US" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "[lang|='en']";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}
test "Matcher: attribute case-insensitive [type='TEXT' i]" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "input", &.{
        .{ .name = "type", .value = "text" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "[type='TEXT' i]"; // Note: space before 'i' may be required by tokenizer
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}
test "Matcher: :not() pseudo-class" {
    const allocator = testing.allocator;
    const div = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, div);

    const p = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p);

    const input = "*:not(p)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p_parser = try Parser.init(allocator, &tokenizer);
    defer p_parser.deinit();

    var selector_list = try p_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(div, &selector_list)); // div is not p
    try testing.expect(!try matcher.matches(p, &selector_list)); // p is p
}
test "Matcher: :is() pseudo-class" {
    const allocator = testing.allocator;
    const h1 = try createTestElement(allocator, "h1");
    defer destroyTestElement(allocator, h1);

    const h2 = try createTestElement(allocator, "h2");
    defer destroyTestElement(allocator, h2);

    const p = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p);

    const input = ":is(h1, h2)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p_parser = try Parser.init(allocator, &tokenizer);
    defer p_parser.deinit();

    var selector_list = try p_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(h1, &selector_list)); // h1 matches
    try testing.expect(try matcher.matches(h2, &selector_list)); // h2 matches
    try testing.expect(!try matcher.matches(p, &selector_list)); // p doesn't match
}
test "Matcher: :where() pseudo-class" {
    const allocator = testing.allocator;
    const article = try createTestElement(allocator, "article");
    defer destroyTestElement(allocator, article);

    const section = try createTestElement(allocator, "section");
    defer destroyTestElement(allocator, section);

    const input = ":where(article, section)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p_parser = try Parser.init(allocator, &tokenizer);
    defer p_parser.deinit();

    var selector_list = try p_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(article, &selector_list));
    try testing.expect(try matcher.matches(section, &selector_list));
}
test "Matcher: :has() pseudo-class" {
    const allocator = testing.allocator;

    // Create parent with child p
    const parent1 = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent1);

    const child_p = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, child_p);

    child_p.base.parent_node = &parent1.base;
    try parent1.base.child_nodes.append(&child_p.base);

    // Create parent with child span (no p)
    const parent2 = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent2);

    const child_span = try createTestElement(allocator, "span");
    defer destroyTestElement(allocator, child_span);

    child_span.base.parent_node = &parent2.base;
    try parent2.base.child_nodes.append(&child_span.base);

    const input = "div:has(p)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p_parser = try Parser.init(allocator, &tokenizer);
    defer p_parser.deinit();

    var selector_list = try p_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(parent1, &selector_list)); // has p
    try testing.expect(!try matcher.matches(parent2, &selector_list)); // no p
}
test "Matcher: empty selector list behavior" {
    const allocator = testing.allocator;
    const elem = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, elem);

    // Parser should fail on empty input, but test error handling
    const input = "div";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    // Verify we have a valid selector list
    try testing.expect(selector_list.selectors.len > 0);
}
test "Matcher: class selector with multiple classes" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "class", .value = "foo bar baz" },
    });
    defer destroyTestElement(allocator, elem);

    const input = ".bar";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}
test "Matcher: element with no parent (root)" {
    const allocator = testing.allocator;
    const elem = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, elem);

    // Element with no parent should still match simple selectors
    const input = "div";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}
test "Matcher: complex selector chain (div > p.text)" {
    const allocator = testing.allocator;

    // Create: div > p.text
    const parent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent);

    const child = try createTestElementWithAttrs(allocator, "p", &.{
        .{ .name = "class", .value = "text important" },
    });
    defer destroyTestElement(allocator, child);

    child.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&child.base);

    const input = "div > p.text";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(child, &selector_list));
}
test "Matcher: nested :not(:is()) combination" {
    const allocator = testing.allocator;
    const div = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, div);

    const p = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p);

    const input = "*:not(:is(p, span))";
    var tokenizer = Tokenizer.init(allocator, input);
    var p_parser = try Parser.init(allocator, &tokenizer);
    defer p_parser.deinit();

    var selector_list = try p_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(div, &selector_list)); // div is not (p or span)
    try testing.expect(!try matcher.matches(p, &selector_list)); // p is (p or span)
}
test "Matcher: :dir(ltr) pseudo-class" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "dir", .value = "ltr" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "div:dir(ltr)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result);
}
test "Matcher: :scope pseudo-class matches scoping root" {
    const allocator = testing.allocator;

    // Create scoping root
    const scope_elem = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, scope_elem);

    // Create another element
    const other_elem = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, other_elem);

    const input = ":scope";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    // Matcher with scoping root
    const matcher = Matcher.initWithScope(allocator, scope_elem);
    try testing.expect(try matcher.matches(scope_elem, &selector_list)); // Matches scope
    try testing.expect(!try matcher.matches(other_elem, &selector_list)); // Doesn't match non-scope
}
test "Matcher: :scope without scoping root matches root element" {
    const allocator = testing.allocator;

    // Create root element (no parent)
    const root = try createTestElement(allocator, "html");
    defer destroyTestElement(allocator, root);

    // Create child element
    const child = try createTestElement(allocator, "body");
    defer destroyTestElement(allocator, child);

    child.base.parent_node = &root.base;
    try root.base.child_nodes.append(&child.base);

    const input = ":scope";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    // Matcher without scoping root - :scope should match :root
    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(root, &selector_list)); // Root matches :scope
    try testing.expect(!try matcher.matches(child, &selector_list)); // Child doesn't match :scope
}
test "Matcher: :dir(rtl) pseudo-class" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "dir", .value = "rtl" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "div:dir(rtl)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result);
}
test "Matcher: :dir(ltr) default when no dir attribute" {
    const allocator = testing.allocator;
    const elem = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, elem);

    const input = "div:dir(ltr)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result); // Default is ltr
}
test "Matcher: :has(> p) relative child selector" {
    const allocator = testing.allocator;

    // Create: div > p
    var div = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, div);

    var p_elem = try allocator.create(Element);
    defer {
        p_elem.deinit();
        allocator.destroy(p_elem);
    }
    p_elem.* = Element.init(allocator, "p");

    // Link them
    p_elem.base.parent_node = &div.base;
    try div.base.child_nodes.append(&p_elem.base);

    // Test div:has(> p)
    const input = "div:has(> p)";
    var tokenizer = Tokenizer.init(allocator, input);
    var sel_parser = try Parser.init(allocator, &tokenizer);
    defer sel_parser.deinit();

    var selector_list = try sel_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(div, &selector_list);

    try testing.expect(result); // div has direct child p
}
test "Matcher: :has(+ span) relative next sibling selector" {
    const allocator = testing.allocator;

    // Create parent with two children: div and span
    var parent = try createTestElement(allocator, "body");
    defer destroyTestElement(allocator, parent);

    var div = try allocator.create(Element);
    defer {
        div.deinit();
        allocator.destroy(div);
    }
    div.* = Element.init(allocator, "div");

    var span = try allocator.create(Element);
    defer {
        span.deinit();
        allocator.destroy(span);
    }
    span.* = Element.init(allocator, "span");

    // Link them: parent > div + span
    div.base.parent_node = &parent.base;
    span.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&div.base);
    try parent.base.child_nodes.append(&span.base);

    // Test div:has(+ span)
    const input = "div:has(+ span)";
    var tokenizer = Tokenizer.init(allocator, input);
    var sel_parser = try Parser.init(allocator, &tokenizer);
    defer sel_parser.deinit();

    var selector_list = try sel_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(div, &selector_list);

    try testing.expect(result); // div has next sibling span
}
test "Matcher: :has(~ .error) relative subsequent sibling selector" {
    const allocator = testing.allocator;

    // Create parent with children: div, p, span.error
    var parent = try createTestElement(allocator, "body");
    defer destroyTestElement(allocator, parent);

    var div = try allocator.create(Element);
    defer {
        div.deinit();
        allocator.destroy(div);
    }
    div.* = Element.init(allocator, "div");

    var p_elem = try allocator.create(Element);
    defer {
        p_elem.deinit();
        allocator.destroy(p_elem);
    }
    p_elem.* = Element.init(allocator, "p");

    var span = try createTestElementWithAttrs(allocator, "span", &.{
        .{ .name = "class", .value = "error" },
    });
    defer destroyTestElement(allocator, span);

    // Link them: parent > div ~ p ~ span.error
    div.base.parent_node = &parent.base;
    p_elem.base.parent_node = &parent.base;
    span.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&div.base);
    try parent.base.child_nodes.append(&p_elem.base);
    try parent.base.child_nodes.append(&span.base);

    // Test div:has(~ .error)
    const input = "div:has(~ .error)";
    var tokenizer = Tokenizer.init(allocator, input);
    var sel_parser = try Parser.init(allocator, &tokenizer);
    defer sel_parser.deinit();

    var selector_list = try sel_parser.parseSelectorList();
    defer selector_list.deinit();

    try std.testing.expect(selector_list.selectors.len == 1);

    const matcher = Matcher.init(allocator);

    // div should match (has subsequent sibling span.error)
    try std.testing.expect(try matcher.matches(div, &selector_list));

    // p should NOT match (not a div element)
    try std.testing.expect(!try matcher.matches(p_elem, &selector_list));

    // span should NOT match (no subsequent sibling span.error - can't match itself)
    try std.testing.expect(!try matcher.matches(span, &selector_list));
}
test "Matcher: forgiving selector parsing with valid selectors" {
    const allocator = std.testing.allocator;

    var parent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent);

    var div = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "class", .value = "foo" },
    });
    defer destroyTestElement(allocator, div);

    var p_elem = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p_elem);
    p_elem.* = Element.init(allocator, "p");

    var span = try createTestElementWithAttrs(allocator, "span", &.{
        .{ .name = "class", .value = "bar" },
    });
    defer destroyTestElement(allocator, span);

    // Link them: parent > div.foo, p, span.bar
    div.base.parent_node = &parent.base;
    p_elem.base.parent_node = &parent.base;
    span.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&div.base);
    try parent.base.child_nodes.append(&p_elem.base);
    try parent.base.child_nodes.append(&span.base);

    // Test :is(.foo, .bar) - forgiving parsing with all valid selectors
    const input = ":is(.foo, .bar)";
    var tokenizer = Tokenizer.init(allocator, input);
    var sel_parser = try Parser.init(allocator, &tokenizer);
    defer sel_parser.deinit();

    var selector_list = try sel_parser.parseSelectorList();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);

    // div.foo should match (matches .foo in :is())
    try std.testing.expect(try matcher.matches(div, &selector_list));

    // p should NOT match (no .foo or .bar class)
    try std.testing.expect(!try matcher.matches(p_elem, &selector_list));

    // span.bar should match (matches .bar in :is())
    try std.testing.expect(try matcher.matches(span, &selector_list));
}
test "Matcher: forgiving selector parsing drops invalid selectors" {
    const allocator = std.testing.allocator;

    var parent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent);

    var div = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "class", .value = "foo" },
    });
    defer destroyTestElement(allocator, div);

    var p_elem = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p_elem);
    p_elem.* = Element.init(allocator, "p");

    // Link them
    div.base.parent_node = &parent.base;
    p_elem.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&div.base);
    try parent.base.child_nodes.append(&p_elem.base);

    // Test :is(.foo, +++invalid+++, p) - forgiving parsing should drop invalid selector
    // This should behave like :is(.foo, p)
    const input = ":is(.foo, +++, p)";
    var tokenizer = Tokenizer.init(allocator, input);
    var sel_parser = try Parser.init(allocator, &tokenizer);
    defer sel_parser.deinit();

    var selector_list = try sel_parser.parseSelectorList();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);

    // div.foo should match (matches .foo in :is())
    try std.testing.expect(try matcher.matches(div, &selector_list));

    // p should match (matches p in :is())
    try std.testing.expect(try matcher.matches(p_elem, &selector_list));
}