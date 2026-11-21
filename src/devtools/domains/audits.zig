//! The Audits domain on page sessions: Audits.enable (design 3.11).
//!
//! TODO(lane cdph): the handlers. Until then every Audits command answers
//! "'Audits.<command>' wasn't found" (src/devtools/dispatch.zig). The handler
//! interface is src/devtools/README.md's.

const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");

/// Per-session state of the domain.
pub const State = struct {};
