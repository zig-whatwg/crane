// DOM Standard: NonDocumentTypeChildNode mixin tests
// Spec: https://dom.spec.whatwg.org/#interface-nondocumenttypechildnode

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const CharacterData = dom.CharacterData;
const Comment = dom.Comment;
const DocumentType = dom.DocumentType;
const Element = dom.Element;
const Text = dom.Text;

const testing = std.testing;

// NOTE: These are placeholder tests. Full implementation requires:
// - Complete Element implementation
// - Complete CharacterData implementation
// - Complete node tree traversal

test "NonDocumentTypeChildNode - previousElementSibling with element sibling" {
    // TODO: Implement test
    // 1. Create parent element
    // 2. Append element1
    // 3. Append element2
    // 4. Call element2.previousElementSibling
    // 5. Verify returns element1
}

test "NonDocumentTypeChildNode - previousElementSibling skips non-elements" {
    // TODO: Implement test
    // 1. Create parent element
    // 2. Append element1
    // 3. Append text node (non-element)
    // 4. Append comment node (non-element)
    // 5. Append element2
    // 6. Call element2.previousElementSibling
    // 7. Verify returns element1 (skipping text and comment)
}

test "NonDocumentTypeChildNode - previousElementSibling returns null" {
    // TODO: Implement test
    // 1. Create parent element
    // 2. Append text node (non-element)
    // 3. Append element1
    // 4. Call element1.previousElementSibling
    // 5. Verify returns null (no element siblings before)
}

test "NonDocumentTypeChildNode - nextElementSibling with element sibling" {
    // TODO: Implement test
    // 1. Create parent element
    // 2. Append element1
    // 3. Append element2
    // 4. Call element1.nextElementSibling
    // 5. Verify returns element2
}

test "NonDocumentTypeChildNode - nextElementSibling skips non-elements" {
    // TODO: Implement test
    // 1. Create parent element
    // 2. Append element1
    // 3. Append text node (non-element)
    // 4. Append comment node (non-element)
    // 5. Append element2
    // 6. Call element1.nextElementSibling
    // 7. Verify returns element2 (skipping text and comment)
}

test "NonDocumentTypeChildNode - nextElementSibling returns null" {
    // TODO: Implement test
    // 1. Create parent element
    // 2. Append element1
    // 3. Append text node (non-element)
    // 4. Call element1.nextElementSibling
    // 5. Verify returns null (no element siblings after)
}

test "NonDocumentTypeChildNode - Element includes mixin" {
    // TODO: Verify Element has NonDocumentTypeChildNode attributes
    // 1. Create Element node
    // 2. Verify .previousElementSibling attribute exists
    // 3. Verify .nextElementSibling attribute exists
}

test "NonDocumentTypeChildNode - CharacterData includes mixin" {
    // TODO: Verify CharacterData has NonDocumentTypeChildNode attributes
    // 1. Create CharacterData node (Text, Comment, etc.)
    // 2. Verify .previousElementSibling attribute exists
    // 3. Verify .nextElementSibling attribute exists
}

test "NonDocumentTypeChildNode - DocumentType does NOT include mixin" {
    // Web compatibility: previousElementSibling and nextElementSibling
    // are NOT exposed on DocumentType nodes
    //
    // TODO: Verify DocumentType does NOT have NonDocumentTypeChildNode
    // 1. Check that DocumentType type does not have .previousElementSibling
    // 2. Check that DocumentType type does not have .nextElementSibling
    // 3. This is a compile-time check - verify correct types
}

test "NonDocumentTypeChildNode - complex sibling navigation" {
    // TODO: Implement comprehensive test
    // 1. Create parent with mixed children:
    //    - element1
    //    - text1
    //    - comment1
    //    - element2
    //    - text2
    //    - element3
    // 2. Verify element2.previousElementSibling == element1
    // 3. Verify element2.nextElementSibling == element3
    // 4. Verify text2.previousElementSibling == element2
    // 5. Verify text2.nextElementSibling == element3
}

test "NonDocumentTypeChildNode - first element has no previous" {
    // TODO: Implement test
    // 1. Create parent with element as first child
    // 2. Add non-element children before it? (impossible)
    // 3. Verify element.previousElementSibling returns null
}

test "NonDocumentTypeChildNode - last element has no next" {
    // TODO: Implement test
    // 1. Create parent with element as last child
    // 2. Add non-element children after it
    // 3. Verify element.nextElementSibling returns null
}
