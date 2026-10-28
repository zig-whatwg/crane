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
//! var list = try selector.parse(allocator, "div.container");
//! defer list.deinit();
//! ```
//!
//! Matching against the DOM's platform objects is src/dom/selector_matching.zig.

pub const tokenizer = @import("tokenizer.zig");
pub const Tokenizer = tokenizer.Tokenizer;
pub const Token = tokenizer.Token;

pub const parser = @import("parser.zig");
pub const nesting = @import("nesting.zig");
pub const Parser = parser.Parser;
/// Selectors 4 17.1 "parse a selector".
pub const parse = parser.parseSelectorList;
pub const parseWithOptions = parser.parseWithOptions;
pub const parseCssomOwned = parser.parseCssomOwned;
pub const CssomSelector = parser.CssomSelector;
pub const isSupported = parser.isSupported;
pub const ParserError = parser.ParserError;
pub const NamespaceConstraint = parser.NamespaceConstraint;
pub const AttributeCase = parser.AttributeCase;
pub const Direction = parser.Direction;
pub const isHtmlCaseInsensitiveValueAttribute = parser.isHtmlCaseInsensitiveValueAttribute;
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
pub const Specificity = parser.Specificity;
pub const BacktrackingInfo = parser.BacktrackingInfo;

// Re-export ancestor hashes from infra for convenience
const infra = @import("infra");
pub const AncestorHashes = infra.AncestorHashes;
pub const AncestorBloomFilter = infra.AncestorBloomFilter;

pub const matcher = @import("matcher.zig");
pub const Matcher = matcher.Matcher;

pub const cache = @import("cache.zig");
pub const SelectorQueryCache = cache.SelectorQueryCache;
pub const NthIndexCache = cache.NthIndexCache;
pub const HasSelectorCache = cache.HasSelectorCache;

pub const context = @import("context.zig");
pub const MatchingContext = context.MatchingContext;
pub const MatchResult = context.MatchResult;

pub const fast_paths = @import("fast_paths.zig");
pub const FastPathType = fast_paths.FastPathType;
pub const SelectorAnalysis = fast_paths.SelectorAnalysis;
pub const analyzeSelector = fast_paths.analyzeSelector;
pub const extractIdFromSelector = fast_paths.extractIdFromSelector;
pub const isSimpleSelector = fast_paths.isSimpleSelector;
pub const isIdOnlySelector = fast_paths.isIdOnlySelector;
pub const isClassOnlySelector = fast_paths.isClassOnlySelector;
pub const isTagOnlySelector = fast_paths.isTagOnlySelector;

test {
    @import("std").testing.refAllDecls(@This());
}
