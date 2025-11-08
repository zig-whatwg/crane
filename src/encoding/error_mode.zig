//! Error modes for encoding/decoding operations
//!
//! Spec: https://encoding.spec.whatwg.org/#error-mode

/// Error mode determines how encoding/decoding handles errors
pub const ErrorMode = enum {
    /// Replace unmappable/malformed sequences with U+FFFD (replacement character)
    /// Used by default for decoders
    replacement,

    /// Return error immediately on unmappable/malformed sequences
    /// Used by XML processors and strict contexts
    fatal,

    /// Encode unmappable characters as HTML numeric character references (&#NNNN;)
    /// Used only for encoders in HTML form submission
    /// Example: U+06DE → "&#1758;"
    html,
};
