//! Selector Quirks Implementation
//!
//! Implements the :active/:hover selector quirk per WHATWG Quirks Mode Standard §4.
//!
//! ## WHATWG Specification
//!
//! - Quirks Mode Standard §4: https://quirks.spec.whatwg.org/#the-active-and-hover-quirk
//!
//! ## The Quirk
//!
//! In quirks mode, a compound selector that uses :active or :hover pseudo-classes
//! must not match elements that would not also match :any-link, if the selector
//! has no type/attribute/ID/class/other pseudo-class/pseudo-element selectors.
//!
//! This means that in quirks mode:
//! - `:hover` alone only matches links (elements that match :any-link)
//! - `:hover.foo` matches any element with class "foo" (has class selector)
//! - `div:hover` matches any div (has type selector)
//! - `:hover` in no-quirks mode matches any element

const std = @import("std");
const QuirksMode = @import("mode.zig").QuirksMode;

/// Result of analyzing a compound selector for the :active/:hover quirk.
pub const ActiveHoverQuirkAnalysis = struct {
    /// True if the selector contains :active or :hover.
    has_active_or_hover: bool,

    /// True if the selector has other selectors (type, class, ID, attribute, etc.).
    has_other_selectors: bool,

    /// Check if the quirk should be applied to this selector.
    ///
    /// The quirk applies when:
    /// 1. Selector has :active or :hover, AND
    /// 2. Selector has NO other selectors (type, class, ID, attribute, etc.)
    ///
    /// When the quirk applies, the selector should only match elements
    /// that also match :any-link (i.e., links).
    pub fn quirkApplies(self: ActiveHoverQuirkAnalysis) bool {
        return self.has_active_or_hover and !self.has_other_selectors;
    }
};

/// Pseudo-class types for quirk analysis.
pub const PseudoClassType = enum {
    active,
    hover,
    other,
};

/// Simple selector types for quirk analysis.
pub const SimpleSelectorType = enum {
    type_selector, // div, p, etc.
    class_selector, // .foo
    id_selector, // #bar
    attribute_selector, // [href]
    pseudo_class, // :hover, :active, :first-child, etc.
    pseudo_element, // ::before, ::after, etc.
    universal, // *
};

/// Analyze a compound selector for the :active/:hover quirk.
///
/// This function takes a list of simple selectors and determines if the
/// :active/:hover quirk should apply.
///
/// ## Parameters
/// - `simple_selectors`: List of simple selector types in the compound
/// - `pseudo_class_types`: For each pseudo_class in simple_selectors, the type
///
/// ## Returns
/// Analysis result indicating if the quirk applies.
///
/// ## Example
/// ```zig
/// // Selector: :hover
/// const result = analyzeCompoundSelector(
///     &[_]SimpleSelectorType{.pseudo_class},
///     &[_]PseudoClassType{.hover},
/// );
/// try std.testing.expect(result.quirkApplies());
///
/// // Selector: div:hover
/// const result2 = analyzeCompoundSelector(
///     &[_]SimpleSelectorType{.type_selector, .pseudo_class},
///     &[_]PseudoClassType{.hover},
/// );
/// try std.testing.expect(!result2.quirkApplies());
/// ```
pub fn analyzeCompoundSelector(
    simple_selectors: []const SimpleSelectorType,
    pseudo_class_types: []const PseudoClassType,
) ActiveHoverQuirkAnalysis {
    var has_active_or_hover = false;
    var has_other_selectors = false;
    var pseudo_index: usize = 0;

    for (simple_selectors) |selector| {
        switch (selector) {
            .pseudo_class => {
                if (pseudo_index < pseudo_class_types.len) {
                    const pseudo_type = pseudo_class_types[pseudo_index];
                    pseudo_index += 1;

                    switch (pseudo_type) {
                        .active, .hover => {
                            has_active_or_hover = true;
                        },
                        .other => {
                            has_other_selectors = true;
                        },
                    }
                }
            },
            .type_selector, .class_selector, .id_selector, .attribute_selector, .pseudo_element => {
                has_other_selectors = true;
            },
            .universal => {
                // Universal selector (*) doesn't count as "other" for quirk purposes
                // Per browser behavior, `:hover` and `*:hover` behave the same in quirks mode
            },
        }
    }

    return .{
        .has_active_or_hover = has_active_or_hover,
        .has_other_selectors = has_other_selectors,
    };
}

/// Check if the :active/:hover quirk applies to a compound selector.
///
/// This is a convenience function that combines analysis with mode checking.
///
/// ## Parameters
/// - `mode`: Current quirks mode
/// - `simple_selectors`: List of simple selector types in the compound
/// - `pseudo_class_types`: For each pseudo_class in simple_selectors, the type
///
/// ## Returns
/// `true` if:
/// 1. Mode is quirks mode, AND
/// 2. Selector has :active or :hover, AND
/// 3. Selector has NO other selectors
///
/// When this returns `true`, the selector should only match elements
/// that also match :any-link (links).
pub fn activeHoverQuirkApplies(
    mode: QuirksMode,
    simple_selectors: []const SimpleSelectorType,
    pseudo_class_types: []const PseudoClassType,
) bool {
    if (!mode.hasSelectorQuirks()) {
        return false;
    }

    const analysis = analyzeCompoundSelector(simple_selectors, pseudo_class_types);
    return analysis.quirkApplies();
}

// ============================================================================
// Tests
// ============================================================================

test "analyzeCompoundSelector - :hover alone" {
    const result = analyzeCompoundSelector(
        &[_]SimpleSelectorType{.pseudo_class},
        &[_]PseudoClassType{.hover},
    );

    try std.testing.expect(result.has_active_or_hover);
    try std.testing.expect(!result.has_other_selectors);
    try std.testing.expect(result.quirkApplies());
}

test "analyzeCompoundSelector - :active alone" {
    const result = analyzeCompoundSelector(
        &[_]SimpleSelectorType{.pseudo_class},
        &[_]PseudoClassType{.active},
    );

    try std.testing.expect(result.has_active_or_hover);
    try std.testing.expect(!result.has_other_selectors);
    try std.testing.expect(result.quirkApplies());
}

test "analyzeCompoundSelector - div:hover (type selector)" {
    const result = analyzeCompoundSelector(
        &[_]SimpleSelectorType{ .type_selector, .pseudo_class },
        &[_]PseudoClassType{.hover},
    );

    try std.testing.expect(result.has_active_or_hover);
    try std.testing.expect(result.has_other_selectors);
    try std.testing.expect(!result.quirkApplies());
}

test "analyzeCompoundSelector - .foo:hover (class selector)" {
    const result = analyzeCompoundSelector(
        &[_]SimpleSelectorType{ .class_selector, .pseudo_class },
        &[_]PseudoClassType{.hover},
    );

    try std.testing.expect(result.has_active_or_hover);
    try std.testing.expect(result.has_other_selectors);
    try std.testing.expect(!result.quirkApplies());
}

test "analyzeCompoundSelector - #foo:hover (ID selector)" {
    const result = analyzeCompoundSelector(
        &[_]SimpleSelectorType{ .id_selector, .pseudo_class },
        &[_]PseudoClassType{.hover},
    );

    try std.testing.expect(result.has_active_or_hover);
    try std.testing.expect(result.has_other_selectors);
    try std.testing.expect(!result.quirkApplies());
}

test "analyzeCompoundSelector - [href]:hover (attribute selector)" {
    const result = analyzeCompoundSelector(
        &[_]SimpleSelectorType{ .attribute_selector, .pseudo_class },
        &[_]PseudoClassType{.hover},
    );

    try std.testing.expect(result.has_active_or_hover);
    try std.testing.expect(result.has_other_selectors);
    try std.testing.expect(!result.quirkApplies());
}

test "analyzeCompoundSelector - :hover:focus (other pseudo-class)" {
    const result = analyzeCompoundSelector(
        &[_]SimpleSelectorType{ .pseudo_class, .pseudo_class },
        &[_]PseudoClassType{ .hover, .other },
    );

    try std.testing.expect(result.has_active_or_hover);
    try std.testing.expect(result.has_other_selectors);
    try std.testing.expect(!result.quirkApplies());
}

test "analyzeCompoundSelector - *:hover (universal selector)" {
    const result = analyzeCompoundSelector(
        &[_]SimpleSelectorType{ .universal, .pseudo_class },
        &[_]PseudoClassType{.hover},
    );

    try std.testing.expect(result.has_active_or_hover);
    try std.testing.expect(!result.has_other_selectors);
    try std.testing.expect(result.quirkApplies());
}

test "analyzeCompoundSelector - :hover::before (pseudo-element)" {
    const result = analyzeCompoundSelector(
        &[_]SimpleSelectorType{ .pseudo_class, .pseudo_element },
        &[_]PseudoClassType{.hover},
    );

    try std.testing.expect(result.has_active_or_hover);
    try std.testing.expect(result.has_other_selectors);
    try std.testing.expect(!result.quirkApplies());
}

test "analyzeCompoundSelector - :focus alone (no active/hover)" {
    const result = analyzeCompoundSelector(
        &[_]SimpleSelectorType{.pseudo_class},
        &[_]PseudoClassType{.other},
    );

    try std.testing.expect(!result.has_active_or_hover);
    try std.testing.expect(result.has_other_selectors);
    try std.testing.expect(!result.quirkApplies());
}

test "activeHoverQuirkApplies - quirks mode with :hover" {
    const applies = activeHoverQuirkApplies(
        .quirks,
        &[_]SimpleSelectorType{.pseudo_class},
        &[_]PseudoClassType{.hover},
    );

    try std.testing.expect(applies);
}

test "activeHoverQuirkApplies - no-quirks mode with :hover" {
    const applies = activeHoverQuirkApplies(
        .no_quirks,
        &[_]SimpleSelectorType{.pseudo_class},
        &[_]PseudoClassType{.hover},
    );

    try std.testing.expect(!applies);
}

test "activeHoverQuirkApplies - limited-quirks mode with :hover" {
    const applies = activeHoverQuirkApplies(
        .limited_quirks,
        &[_]SimpleSelectorType{.pseudo_class},
        &[_]PseudoClassType{.hover},
    );

    try std.testing.expect(!applies);
}

test "activeHoverQuirkApplies - quirks mode with div:hover" {
    const applies = activeHoverQuirkApplies(
        .quirks,
        &[_]SimpleSelectorType{ .type_selector, .pseudo_class },
        &[_]PseudoClassType{.hover},
    );

    try std.testing.expect(!applies);
}
