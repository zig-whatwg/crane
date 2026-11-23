//! The DOM agents' sink: the DOM's probes (dom.inspector_probes) sent to
//! every DOM-enabled page session of the node's Browser (lane cdpd1).

const inspector_probes = @import("dom").inspector_probes;

/// How many DOM agents are enabled in the process (the probes' gate).
pub fn enabledAgentCount() u32 {
    return inspector_probes.enabledAgentCount();
}
