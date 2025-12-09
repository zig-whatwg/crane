//! HTML Parser
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html
//! HTML Standard §13 "Parsing HTML documents"
//!
//! This module implements the HTML parsing algorithm as defined in the
//! WHATWG HTML Standard. It consists of:
//! - Tokenization (§13.2.5): Converting input into tokens
//! - Tree construction (§13.2.6): Building the DOM tree from tokens
//!
//! The tokenizer processes the input stream character by character using
//! an 80-state state machine, emitting tokens like DOCTYPE, start tags,
//! end tags, comments, and characters.

const std = @import("std");

// Token types
pub const Token = @import("tokens.zig").Token;
pub const TagToken = @import("tokens.zig").TagToken;
pub const DoctypeToken = @import("tokens.zig").DoctypeToken;
pub const CommentToken = @import("tokens.zig").CommentToken;
pub const Attribute = @import("tokens.zig").Attribute;

// Tokenizer states
pub const State = @import("tokenizer_states.zig").State;
pub const getStateName = @import("tokenizer_states.zig").getStateName;
pub const isRcdataState = @import("tokenizer_states.zig").isRcdataState;
pub const isRawtextState = @import("tokenizer_states.zig").isRawtextState;
pub const isScriptDataState = @import("tokenizer_states.zig").isScriptDataState;
pub const isCharacterReferenceState = @import("tokenizer_states.zig").isCharacterReferenceState;

// Parse errors
pub const ParseError = @import("parse_errors.zig").ParseError;
pub const ParseErrorCode = @import("parse_errors.zig").ParseErrorCode;
pub const ParseErrorCallback = @import("parse_errors.zig").ParseErrorCallback;
pub const ParseErrorCollector = @import("parse_errors.zig").ParseErrorCollector;
pub const getErrorDescription = @import("parse_errors.zig").getErrorDescription;

// Input stream
pub const InputStream = @import("input_stream.zig").InputStream;
pub const InputCharacter = @import("input_stream.zig").InputCharacter;

// Tokenizer
pub const Tokenizer = @import("tokenizer.zig").Tokenizer;

// Tree construction
pub const TreeBuilder = @import("tree_builder.zig").TreeBuilder;
pub const InsertionMode = @import("tree_builder.zig").InsertionMode;
pub const TreeNode = @import("tree_builder.zig").TreeNode;
pub const QuirksMode = @import("tree_builder.zig").QuirksMode;
pub const Namespace = @import("tree_builder.zig").Namespace;
pub const FormattingEntry = @import("tree_builder.zig").FormattingEntry;
pub const ElementCategory = @import("tree_builder.zig").ElementCategory;

// NOTE: DomTreeAdapter is exported from html (full.zig), not html_core/parser,
// because it requires runtime and interfaces which aren't available in html_core.

// Named character references (entities)
pub const entities = @import("entities.zig");

// Fragment parsing (innerHTML, DOMParser, etc.)
pub const fragment_parser = @import("fragment_parser.zig");
pub const parseFragment = fragment_parser.parseFragment;
pub const parseHTMLFromString = fragment_parser.parseHTMLFromString;
pub const FragmentParseResult = fragment_parser.FragmentParseResult;
pub const FragmentParseOptions = fragment_parser.FragmentParseOptions;

// Tag name string interning (performance optimization)
pub const tag_name_intern = @import("tag_name_intern.zig");
pub const internTagName = tag_name_intern.intern;
pub const isKnownHtmlTag = tag_name_intern.isKnownHtmlTag;
pub const eqlInternedTag = tag_name_intern.eqlInterned;

// Document write support (document.write/writeln/open/close)
pub const document_write = @import("document_write.zig");
pub const DocumentWriteState = document_write.DocumentWriteState;
pub const DocumentWriteError = document_write.DocumentWriteError;
pub const documentOpen = document_write.documentOpen;
pub const documentWrite = document_write.documentWrite;
pub const documentWriteln = document_write.documentWriteln;
pub const documentClose = document_write.documentClose;

test {
    // Run all parser tests
    std.testing.refAllDecls(@This());
    _ = @import("tokens.zig");
    _ = @import("tokenizer_states.zig");
    _ = @import("parse_errors.zig");
    _ = @import("input_stream.zig");
    _ = @import("tokenizer.zig");
    _ = @import("tree_builder.zig");
    _ = @import("entities.zig");
    _ = @import("fragment_parser.zig");
    _ = @import("document_write.zig");
    _ = @import("tag_name_intern.zig");
    // NOTE: dom_tree_adapter.zig tests are run from html (full.zig) module
}
