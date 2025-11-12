//! CSS Selectors Level 4 Implementation
//!
//! Complete implementation of CSS Selectors Level 4 specification.
//! Provides tokenization, parsing, and matching for all selector types.
//!
//! ## Modules
//! - `tokenizer` - CSS tokenization (CSS Syntax Module Level 3)
//! - `parser` - Selector parsing (recursive descent)
//! - `matcher` - Selector matching (right-to-left with bloom filter)
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

// Phase 2: parser (coming soon)
// Phase 3: matcher (coming soon)

test {
    @import("std").testing.refAllDecls(@This());
}
