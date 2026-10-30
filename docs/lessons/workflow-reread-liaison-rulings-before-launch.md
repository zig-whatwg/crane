# Workflow: Re-read liaison rulings before launching

**Date**: 2026-10-30
**Lesson**: A valid saved preparation is not authorization to launch after the liaison changes its named main.

**Why**: Launch guards can verify hashes, job ownership and a scheduling window while still relying on an obsolete merge target. A summary can omit a ruling posted between preparation and launch.

**What Happened**: Row 128 prepared its final native predecessor on main 338f. The integrator named c7ab at 07:06 and corrected the merge sequence at 07:07. The row launched at 07:08 without incorporating those messages. By the time the ruling was read, the job had started. The liaison required preserving that run as information only and rebuilding the predecessor after the named merge.

**Fix**: Immediately before a merge, build or measurement launch, read the questions file through its latest entry, including rulings appended within earlier sections. Compare the current authorization with the prepared main, tree, scope and baseline. When they differ, retain the old preparation and evidence, rebind a new preparation, and follow the ruling for any existing job. Do not treat a GAP notice as proof that other authorization is unchanged.

**Takeaway**: **Scheduling clearance and current task authorization are separate checks.**
