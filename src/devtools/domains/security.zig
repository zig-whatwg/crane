//! The Security domain on page sessions: Security.setIgnoreCertificateErrors (design 3.2).
//!
//! TODO(lane cdpt): the handlers. Until then every Security command answers
//! "'Security.<command>' wasn't found" (src/devtools/dispatch.zig). The handler
//! interface is src/devtools/README.md's.

const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");

/// Per-session state of the domain.
pub const State = struct {};
