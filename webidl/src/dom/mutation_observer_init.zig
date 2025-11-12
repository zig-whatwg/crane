//! MutationObserverInit dictionary per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#dictdef-mutationobserverinit

/// DOM §7.1 - MutationObserverInit dictionary
///
/// Options for observing mutations.
pub const MutationObserverInit = struct {
    /// Observe mutations to target's children
    childList: bool = false,

    /// Observe mutations to target's attributes
    /// Can be omitted if attributeOldValue or attributeFilter is specified
    attributes: ?bool = null,

    /// Observe mutations to target's data (CharacterData nodes)
    /// Can be omitted if characterDataOldValue is specified
    characterData: ?bool = null,

    /// Observe mutations to not just target, but also target's descendants
    subtree: bool = false,

    /// Record attribute value before mutation (implies attributes = true)
    attributeOldValue: ?bool = null,

    /// Record data before mutation (implies characterData = true)
    characterDataOldValue: ?bool = null,

    /// List of attribute local names to observe (implies attributes = true)
    /// If not specified, observe all attributes
    attributeFilter: ?[]const []const u8 = null,
};
