//! WebIDL Mixin Implementations
//!
//! This module provides shared implementations for WebIDL interface mixins.
//! These mixins define common functionality that can be included by multiple
//! interfaces (Document, Element, DocumentFragment, etc.)
//!
//! Available mixins:
//! - ParentNode: querySelector, querySelectorAll, children, firstElementChild,
//!               lastElementChild, childElementCount, prepend, append, replaceChildren
//! - NonElementParentNode: getElementById
//! - ChildNode: before, after, replaceWith, remove
//! - NonDocumentTypeChildNode: previousElementSibling, nextElementSibling
//! - Slottable: assignedSlot
//! - DocumentOrShadowRoot: activeElement, styleSheets, fullscreenElement, etc.
//! - XPathEvaluatorBase: createExpression, evaluate
//!
//! Mixin → Interface Mapping (from DOM spec):
//! | Mixin                    | Used By                                    |
//! |--------------------------|--------------------------------------------|
//! | ParentNode               | Document, Element, DocumentFragment        |
//! | NonElementParentNode     | Document, DocumentFragment                 |
//! | ChildNode                | DocumentType, Element, CharacterData       |
//! | NonDocumentTypeChildNode | Element, CharacterData                     |
//! | Slottable                | Element, Text                              |
//! | DocumentOrShadowRoot     | Document, ShadowRoot                       |
//! | XPathEvaluatorBase       | Document, XPathEvaluator                   |

const std = @import("std");

pub const ParentNode = @import("ParentNode.zig");
pub const NonElementParentNode = @import("NonElementParentNode.zig");
pub const ChildNode = @import("ChildNode.zig");
pub const NonDocumentTypeChildNode = @import("NonDocumentTypeChildNode.zig");
pub const Slottable = @import("Slottable.zig");
pub const DocumentOrShadowRoot = @import("DocumentOrShadowRoot.zig");
pub const XPathEvaluatorBase = @import("XPathEvaluatorBase.zig");

test {
    std.testing.refAllDecls(@This());
}
