# Spec Compliance: A legacy value alias can retain its specified spelling

**Date**: 2026-10-27
**Lesson**: Probe specified and computed values separately before choosing where a legacy value alias is normalized.

**Why**: Calling a value an alias does not make parse-time normalization observationally equivalent to computed-value normalization. CSSOM exposes both boundaries, including values substituted from custom properties.

**What Happened**: Row125 initially read overflow's overlay alias as a parse-time conversion to auto. Q31's three-browser probe found Chrome and Safari preserve specified overlay while Firefox converts it; every shipping implementation computes auto. The integrator ruled for the specified-value majority and the common computed result.

**Fix**: Keep overlay in the property-owned overflow grammar and convert only the four overflow longhands at computation. Reuse the existing escaped-name matching and real pending substitution. Pin lowercase specified readback, computed auto, valid two-axis shorthands, invalid longhand pairs, and allocation failures.

**Takeaway**: **An alias has observable boundaries: decide its grammar, stored value, specified spelling and computed value from the applicable rule and evidence.**
