# Spec Compliance: Container lengths must select usable size containers

**Date**: 2026-10-28
**Lesson**: Read the engine's unit conversion as well as its query selector: selecting a container for a query does not establish that it can supply a container-relative length.

**Why**: A selected query container without a principal box can evaluate a query to Unknown. Container length conversion may instead skip it and select a usable outer container, or fall back to the small viewport when none exists.

**What Happened**: Row 127 initially read WebKit's ContainerQueryEvaluator and proposed retaining lengths against boxless containers. Reading StyleLengthResolution's actual conversion exposed the missing step. Background Chrome 156, Firefox 158 and Safari 27 probes agreed: `display:none` and `contents` containers are skipped; a hidden consumer can still use a boxed ancestor. Logical `cqi`/`cqb` axes map through the consumer's writing mode, then each physical axis selects independently. A further probe corrected an accidental citation to layout containment: non-atomic inline, table and table-cell boxes do not qualify for size or inline-size containment.

**Fix**: Follow CSS Conditional 5 §7 and CSS Contain 2 §§3.1–3.2. Reuse the native size-containment applicability predicate. Walk flat ancestors, excluding a real consumer and including a generated pseudo's originating element. Skip boxless candidates and candidates below a `display:none` ancestor. Keep the distinction between no eligible container and an eligible container whose geometry the host cannot supply. Pin mixed writing modes, per-axis selection, slots, pseudos, hidden consumers and box types separately.

Primary implementation read for design, with no copied code: [WebKit StyleLengthResolution.cpp, pinned 7ac4be3e](https://github.com/WebKit/WebKit/blob/7ac4be3e0769e089dce617718671b93be5371ab9/Source/WebCore/style/values/primitives/StyleLengthResolution.cpp), `resolveContainerUnit` and logical-axis conversion. Probe evidence is retained in the row's Q96/Q100 package.

**Takeaway**: **Trace the value-producing operation to its final consumer; an intermediate selection helper can deliberately accept candidates that unit resolution must skip.**
