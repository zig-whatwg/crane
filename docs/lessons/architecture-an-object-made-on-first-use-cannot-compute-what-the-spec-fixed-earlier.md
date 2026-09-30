# Architecture: An object made on first use cannot compute what the spec fixed at an earlier moment

**Date**: 2026-09-30
**Lesson**: `navigation.activation` is set when the document is activated, and it names the entries as they were then. Crane makes a window's Navigation object only when script first asks for it, which can be after `history.replaceState()` has already replaced the entry the activation names. The inputs have to be recorded at activation and the object built from them later.

**Why**: HTML "update document for history step application" step 7 sets the activation from previousEntryForActivation, the navigation type, and the current entry *at that moment*. A same-document replace later gives the entry a new ID in place, and a replace navigation changes the previous entry in place, so neither can be read back afterwards. A lazy object that computes on first use reads the wrong state.

**What Happened**: activation-replace and activation-history-replaceState expect `activation.entry` to be the entry the document was activated with - orphaned (index -1) after a replace - and `activation.from` to keep the key, ID and URL the replaced entry had.

**Fix**: `recordInHistory` records, before the new document's parser runs, a `joint_history.Activation` - the navigation type and snapshots of previousEntryForActivation and of the committed entry - on the entry's document state (one per state). Navigation builds its NavigationActivation from that record when it is made or first asked, uses the entry objects it hands out when the entries still exist, and fresh ones from the snapshots when they do not. The host-loaded top-level page, which no navigation of Crane's committed, gets a replace activation with no old entry.

**Takeaway**: **If an API object is made on first use, whatever the spec fixes at an earlier moment must be recorded at that moment - where the object will look - and built from the record, never recomputed from current state.**
