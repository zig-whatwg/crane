//! The DOM domain on page sessions: node ids, describeNode, resolveNode, getFrameOwner, the geometry reads (design 3.6).
//!
//! TODO(lane cdph): the handlers. Until then every DOM command answers
//! "'DOM.<command>' wasn't found" (src/devtools/dispatch.zig). The handler
//! interface is src/devtools/README.md's.

const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");

/// Per-session state of the domain.
pub const State = struct {};
