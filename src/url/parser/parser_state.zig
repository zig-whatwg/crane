//! URL Parser State Machine
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#url-parsing
//! Spec Reference: Lines 1049-1479
//!
//! The URL parser is a state machine with 21 states. Each state processes
//! one code point at a time and transitions to other states based on the
//! input character and current context.
//!
//! State transitions follow the spec precisely to ensure correct URL parsing.

const std = @import("std");

/// URL Parser State (spec lines 1049-1479)
///
/// The basic URL parser is a state machine. Each state processes the current
/// code point and may transition to another state or return failure.
///
/// States are listed in the order they appear in the spec:
/// 1. scheme start state (line 1061)
/// 2. scheme state (line 1071)
/// 3. no scheme state (line 1121)
/// 4. special relative or authority state (line 1131)
/// 5. path or authority state (line 1137)
/// 6. relative state (line 1143)
/// 7. relative slash state (line 1169)
/// 8. special authority slashes state (line 1181)
/// 9. special authority ignore slashes state (line 1187)
/// 10. authority state (line 1193)
/// 11. host state / hostname state (line 1229-1230)
/// 12. port state (line 1274)
/// 13. file state (line 1306)
/// 14. file slash state (line 1344)
/// 15. file host state (line 1352)
/// 16. path start state (line 1379)
/// 17. path state (line 1400)
/// 18. opaque path state (line 1431)
/// 19. query state (line 1443)
/// 20. fragment state (line 1465)
pub const ParserState = enum {
    /// Scheme start state (spec line 1061)
    /// - Entry point for parsing
    /// - Looks for ASCII alpha to start scheme
    scheme_start,

    /// Scheme state (spec line 1071)
    /// - Accumulates scheme characters (alphanumeric, +, -, .)
    /// - Transitions when ':' is encountered
    scheme,

    /// No scheme state (spec line 1121)
    /// - Handles relative URLs with no scheme
    /// - Requires base URL
    no_scheme,

    /// Special relative or authority state (spec line 1131)
    /// - Handles special schemes with base URL of same scheme
    /// - Looks for "//" for authority
    special_relative_or_authority,

    /// Path or authority state (spec line 1137)
    /// - Decides between path and authority based on "/"
    path_or_authority,

    /// Relative state (spec line 1143)
    /// - Handles relative URL resolution
    /// - Copies components from base URL
    relative,

    /// Relative slash state (spec line 1169)
    /// - Handles slash after relative URL
    relative_slash,

    /// Special authority slashes state (spec line 1181)
    /// - Expects "//" after special scheme
    special_authority_slashes,

    /// Special authority ignore slashes state (spec line 1187)
    /// - Skips extra slashes before authority
    special_authority_ignore_slashes,

    /// Authority state (spec line 1193)
    /// - Parses username:password@
    /// - Accumulates buffer until host starts
    authority,

    /// Host state / Hostname state (spec line 1229-1230)
    /// - Parses host (domain, IPv4, IPv6, opaque)
    /// - Handles [ ] for IPv6 addresses
    host,

    /// Port state (spec line 1274)
    /// - Parses port number after ":"
    /// - Must be 16-bit unsigned integer
    port,

    /// File state (spec line 1306)
    /// - Handles file:// URLs
    /// - Special handling for Windows drive letters
    file,

    /// File slash state (spec line 1344)
    /// - Handles slash after file:
    file_slash,

    /// File host state (spec line 1352)
    /// - Parses host for file:// URLs
    /// - Special handling for localhost
    file_host,

    /// Path start state (spec line 1379)
    /// - Entry point for path parsing
    /// - Handles Windows drive letters for file: URLs
    path_start,

    /// Path state (spec line 1400)
    /// - Parses path segments
    /// - Handles % encoding, . and .. segments
    path,

    /// Opaque path state (spec line 1431)
    /// - Parses opaque path (cannot-be-a-base-URL)
    /// - Single string, not segmented
    opaque_path,

    /// Query state (spec line 1443)
    /// - Parses query string after "?"
    /// - Percent-encodes special characters
    query,

    /// Fragment state (spec line 1465)
    /// - Parses fragment after "#"
    /// - Last state in parsing
    fragment,
};

