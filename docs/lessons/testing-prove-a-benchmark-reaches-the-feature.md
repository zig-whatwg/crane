# Testing: Prove a benchmark reaches the feature

**Date**: 2026-10-06
**Lesson**: A custom benchmark must assert that its setup actually invokes the feature being measured.

**Why**: Memory counters can plateau even when the intended operation never runs. A benchmark's successful exit proves only the statements it executed.

**What Happened**: A gc_bench body defined a form-associated custom element and discarded instances from document.createElement. Adding internals/state operations exposed that the constructor had never run: the benchmark's about:blank document retains the default XML document type, so createElement supplies a null namespace and skips custom-element lookup. The earlier flat counters measured ordinary elements.

**Fix**: Use createElementNS with the HTML namespace in this benchmark and assert that the constructor-created internals exists before measuring churn. Keep the same assertion in the full measurement. Treat the earlier result as an invalid feature measurement, and separately record the host document-initialization gap.

**Takeaway**: **A benchmark needs an observable feature precondition before its memory numbers are evidence.**
