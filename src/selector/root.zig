//! CSS Selectors Level 4 Implementation
//!
//! Complete implementation of CSS Selectors Level 4 specification.
//! Provides tokenization, parsing, and matching for all selector types.
//!
//! ## Modules
//! - `tokenizer` - CSS tokenization (CSS Syntax Module Level 3)
//! - `parser` - Selector parsing (recursive descent)
//! - `matcher` - Selector matching (right-to-left evaluation)
//!
//! ## Usage
//! ```zig
//! const selector = @import("selector");
//!
//! // Tokenize
//! var tokenizer = selector.Tokenizer.init(allocator, "div.container");
//! const token = try tokenizer.nextToken();
//!
//! // Parse (coming soon in Phase 2)
//! // Match (coming soon in Phase 3)
//! ```

pub const tokenizer = @import("tokenizer.zig");
pub const Tokenizer = tokenizer.Tokenizer;
pub const Token = tokenizer.Token;

pub const parser = @import("parser.zig");
pub const Parser = parser.Parser;
pub const SelectorList = parser.SelectorList;
pub const ComplexSelector = parser.ComplexSelector;
pub const CompoundSelector = parser.CompoundSelector;
pub const SimpleSelector = parser.SimpleSelector;
pub const Combinator = parser.Combinator;
pub const AttributeSelector = parser.AttributeSelector;
pub const AttributeMatcher = parser.AttributeMatcher;
pub const PseudoClassSelector = parser.PseudoClassSelector;
pub const PseudoClassKind = parser.PseudoClassKind;
pub const NthPattern = parser.NthPattern;
pub const PseudoElementSelector = parser.PseudoElementSelector;

pub const matcher = @import("matcher.zig");
pub const Matcher = matcher.Matcher;

test {
    @import("std").testing.refAllDecls(@This());
}
