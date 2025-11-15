//! RegisteredObserver types for mutation observation
//! Spec: https://dom.spec.whatwg.org/#mutation-observers

const MutationObserverInit = @import("mutation_observer_init").MutationObserverInit;
const MutationObserver = @import("mutation_observer").MutationObserver;

/// DOM §7.1 - RegisteredObserver
///
/// Represents an observer registered on a node.
pub const RegisteredObserver = struct {
    /// The MutationObserver object
    observer: *MutationObserver,

    /// The options for this registration
    options: MutationObserverInit,

    /// Whether this is a transient registered observer
    /// Transient observers are created when a node with subtree observers is removed
    /// and are automatically cleaned up after notifying mutations.
    /// Spec: https://dom.spec.whatwg.org/#transient-registered-observer
    is_transient: bool = false,

    /// For transient observers, the source registered observer from the parent node
    /// We match by observer + options since pointers into lists are unstable
    /// Spec: The transient registered observer has an associated source which is a registered observer
    source_observer: ?*MutationObserver = null,
    source_options: ?MutationObserverInit = null,
};

/// DOM §7.1 - TransientRegisteredObserver
///
/// A registered observer that tracks mutations within a removed node's descendants.
pub const TransientRegisteredObserver = struct {
    /// The base registered observer
    registered: RegisteredObserver,

    /// The source registered observer (from parent node)
    source: *RegisteredObserver,
};
