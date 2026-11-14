# Testing: Measure a kept object of every wrapper shape - one representative hides what another carries

**Date**: 2026-11-13
**Lesson**: A per-wrapper memory figure is true of the shape that was measured. The binding makes several shapes of wrapper (a node's, a plain platform object's, a holder's, one behind a legacy platform object's proxy), and each can carry something the others do not.

**Why**: The wrapper redesign and the V8 15.7 port were measured on `div`, `Text` and `Event`. A legacy platform object with named properties (HTMLCollection, NamedNodeMap, HTMLFormControlsCollection, HTMLOptionsCollection, Storage, ...) is wrapped in a Proxy, and `v8_CreateLegacyPlatformObjectProxy` built that proxy's handler afresh for every wrapper: an object and ten FunctionTemplates with their Functions. None of the measured shapes has a proxy, so nothing saw it.

**What Happened**: Lane wrap1 batch 2 was told to re-measure "Event, URLSearchParams, DOMTokenList, an attribute NamedNodeMap / Attr path" before writing code. The Event, URLSearchParams and DOMTokenList rows agreed to the byte (312-320 B of wrapper machinery each). The NamedNodeMap row did not finish: 400,000 kept `el.attributes` reached V8's heap limit ("Ineffective mark-compacts"). At 50,000 and 100,000 it read 3,860 B of V8 heap per wrapper, 4,800 B resident. The cause was read in the code in minutes; the fix (one handler per realm) took a kept NamedNodeMap or HTMLCollection from 3,700-3,930 B of V8 heap to under 300 (tests/v8/wrap1_legacy_proxy_handler_test.zig). The Attr row found a second one of the same kind: reading `el.getAttributeNode` once adds 220 B to the ELEMENT's wrapper, because the element keeps each Attr under a private property named by the Attr's address (a registered symbol and a map transition per element).

**Fix**:
1. List the wrapper shapes from the code that makes them (template_registry.wrapInstanceAsV8Object's branches: node, holder, legacy platform object proxy, Location; the constructor path), and put one row per shape in the measurement.
2. Read each row as a slope between two counts of kept objects with forced collections, per owner (V8's heap, the C++ heap, handle bytes, malloc, Zig): an outlier in ONE owner's column names where to look.
3. A row that crashes or runs out of heap is a finding, not a failed run: read why before lowering its count.
4. For a paired object (a wrapper plus what its owner writes on itself to keep it), measure the difference against the owner alone - the cost may be on the owner.

**Takeaway**: **Measure one kept object of every shape the binding makes. The expensive one is the shape nobody thought to measure.**
