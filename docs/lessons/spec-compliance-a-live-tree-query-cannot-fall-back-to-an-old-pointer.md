# Spec Compliance: A live tree query cannot fall back to an old pointer

**Date**: 2026-10-10
**Lesson**: A tree accessor must return null after its last matching child is removed, even when a parser cache still names that child.

**Why**: Searching the live tree first does not make a getter live if an empty result triggers a fallback to a remembered node. That fallback runs precisely when the cached node is no longer a child.

**What Happened**: Document.documentElement and doctype walked the current children, then returned their parser-populated fields on a miss. Removing the parsed root left documentElement, head and body exposing the detached subtree; removing the doctype still exposed it. Documents built through createHTMLDocument did not populate those fields, so their removal tests passed and concealed the difference.

**Fix**: Audit every writer before removing the fallback. The live construction paths linked the root before caching it; an apparently suspect namespace-less adapter helper had no callers. Pin initial window and iframe documents, DOMParser, navigation and document.write with documentElement.parentNode === document. Also check namespace and head/body on the initial documents, so a strict accessor does not expose malformed producers as a regression. Then return only what the child walk finds, and test removal in both parsed and DOM-created documents.

**Takeaway**: **An empty live query is an answer, not a cache miss.** Test the transition from a match to no match, using every producer that populates remembered state.
