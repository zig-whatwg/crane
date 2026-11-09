//! The V8 adapter's node wrappers (the wrapper redesign,
//! tmp/redesign/wrapper-redesign-design.md sections 3.3 and 4).
//!
//! P1: the slot type. A node's one wrapper per agent is kept in its NodeBase,
//! in this adapter's engine.NodeWrapperSlot, which the adapter reaches only
//! through runtime.lifetime.slotOf (dom.refcount installs it). Until P2 it
//! holds what NodeBase.bound_v8_wrapper held: the wrapper cache entry's
//! `Global<Object>*` for the node's wrapper - BORROWED from that entry, set
//! when the cache takes the wrapper (wrapper_cache.zig `set`,
//! template_registry.wrapInstanceAsV8Object) and emptied by its first pass
//! (`unbindNode`). P2 constructs a weak `v8::Global` in place here
//! (pre-Oilpan Blink's `ScriptWrappable::m_wrapper`), P4 a TracedReference
//! (Blink's `TraceWrapperV8Reference`): the same 8 bytes.

/// engine.NodeWrapperSlot on V8: one pointer.
pub const NodeWrapperSlot = extern struct {
    /// The node's wrapper - the wrapper cache entry's `Global<Object>*`,
    /// BORROWED - or null for a node with none in this agent.
    handle: ?*anyopaque = null,

    pub const empty: NodeWrapperSlot = .{};

    pub fn isEmpty(self: *const NodeWrapperSlot) bool {
        return self.handle == null;
    }
};
