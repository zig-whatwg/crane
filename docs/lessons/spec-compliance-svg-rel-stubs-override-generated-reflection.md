# Spec Compliance: SVG rel stubs override generated reflection

**Date**: 2026-10-20
**Lesson**: A NotImplemented accessor can hide a complete generated reflection implementation, including its existing object cache.

**Why**: Generated reflected members select an impl accessor when it exists; only absent accessors use the shared reflector. A leftover stub therefore changes observable behavior even when the IDL already describes it completely.

**What Happened**: SVGAElement's rel getter, setter, and relList getter still threw NotImplemented. The generated interface already provided DOMString reflection, a SameObject DOMTokenList, and PutForwards=value. All three aligned stable browsers passed the SVG relList coverage assertion, while Crane returned undefined.

**Fix**: Remove those three overrides. Keep the generated reflection and ownership machinery. Test attribute mutation in both directions, null-namespace/case selection, assignment forwarding including a user-defined setter, and GC with only the anchor or its token list retained. Read SVG 2 section 16.4.1 and HTML section 2.6.1 before changing the shared reflector.

**Takeaway**: **Trace generated accessor selection before adding an implementation; test the existing cache's observable identity and retention when enabling it.**
