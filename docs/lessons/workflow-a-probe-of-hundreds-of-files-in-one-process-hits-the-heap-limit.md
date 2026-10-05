# Workflow: A probe of hundreds of files in one runner process hits V8's heap limit

**Date**: 2026-10-04
**Lesson**: A 939-file probe that got only one runner token ran every file in one process, and crashed (SIGTRAP, no Zig stack) on a file that passes alone and in its 50-file prefix: the process had reached 1.15 GB of V8 heap with 582 native contexts retained across files.

**Why**: `crane-measure.sh run` gives a job its fair share of the runner pool - one token when chat is busy - and the runner then runs the whole list in one process. Native contexts accumulate across files in a process (~0.7 per file in navigation-api/ and html/browsers/: frames and popups whose realms outlive their page), so heap grows ~1 MB per file until V8's limit traps. Base and tip grow at the same rate: not a regression, an artifact of the run's shape.

**What Happened**: navigation batch 6's t3 probe reported one CRASH (location-ancestor-origins.sub.html). Isolated: 0/2. Its 50-file prefix: 0/4. The journal's heap_used_kb and native_contexts columns, sorted by index, showed the climb to the crash.

**Fix**: probes go through `crane-measure.sh sweep` with CHUNK=100 - one process per 100 files - and gather the chunks' wptreports (the lane's tmp/chat/probe.sh). Read heap_used_kb/native_contexts before chasing a crash a single process produced late in a long list.

**Takeaway**: **Never run a long list in one runner process: chunk it, or a late crash is the heap limit, not the file.**
