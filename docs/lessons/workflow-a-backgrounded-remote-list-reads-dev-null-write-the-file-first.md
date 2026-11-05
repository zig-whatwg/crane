# Workflow: A backgrounded remote list reads /dev/null - write the file first, then start the job

**Date**: 2026-11-04
**Lesson**: `crane-pool.sh on <mirror> 'cat > probe.sh && nohup bash probe.sh > log 2>&1 < /dev/null &' < probe.sh` left an empty probe.sh and an empty log, and the "job" ended at once.

**Why**: The trailing `&` backgrounds the whole `cat ... && nohup ...` list, and a non-interactive shell gives a background job /dev/null as its stdin. `cat` read nothing. Without the `&` (the push idiom `cat > f.new && mv f.new f`), the same stdin arrives.

**What Happened**: Lane chromeref2's first in-window probe launched in under a second, the wait on its pid returned at once, and probe.log was empty. Inside a timed window, that cost a round trip.

**Fix**: Separate the push from the start with `;`, so that only the job is backgrounded:
`crane-pool.sh on <mirror> 'cat > x.sh; wc -l x.sh; nohup bash x.sh > x.log 2>&1 < /dev/null & echo pid $!' < x.sh`.
Print the line count, so an empty push shows before anything waits on it.

**Takeaway**: **Never background the command that reads the pushed stdin: write the file, check its size, then start the detached job.**
