## What is Spark?

- A **distributed compute framework** for processing very large amounts of data efficiently
- Leverages RAM far more effectively than previous tools (Hive, Java MapReduce) — much faster
- **Storage-agnostic**: decouples compute from storage, helping avoid vendor lock-in
- Huge community → great StackOverflow/ChatGPT support for troubleshooting

---

## When Spark is NOT the right choice

- Nobody else on the team knows Spark → bus factor risk
- Your company already uses something else heavily → inertia is often not worth overcoming

---

## How Spark Works: The 3 Pieces

### 1. The Plan

- Written in Python, Scala, or SQL
- Evaluated **lazily** — execution only happens when it *needs* to
- Execution triggers: writing output, or when the next step depends on the data itself (e.g. `dataframe.collect()`)

### 2. The Driver

- Reads the plan, decides when to execute, determines JOIN strategy and parallelism
- Key settings:
    - `spark.driver.memory` — bump up for complex jobs or those using `collect()`
    - `spark.driver.memoryOverheadFactor` — fraction for non-heap memory (usually 10%)

### 3. Executors

- Do the actual work
- Key settings:
    - `spark.executor.memory` — low value causes spill to disk → very slow
    - `spark.executor.cores` — default 4, shouldn't go above 6
    - `spark.executor.memoryOverheadFactor` — bump up for UDF-heavy jobs

---

## JOIN Strategies

| Strategy | When to use | Shuffle? |
| --- | --- | --- |
| **Shuffle sort-merge** (default since 2.3) | Both sides large | Yes |
| **Broadcast hash join** | Left side small (<10 MB default, ~1 GB safe max) | No |
| **Bucket join** | Pre-bucketed data; bucket counts must be multiples of each other | No |

> 💡 Use `explain()` on a dataframe to inspect which JOIN strategy Spark will use.
> 

---

## Shuffle

- Shuffle partitions and parallelism are linked → use `spark.sql.shuffle.partitions`
    - Should never use RDD API (which is linked to spark.default.parallelism
- **Low-medium volume:** shuffle is fine and makes life easier
- **High volume (>10 TB):** painful — at Netflix, shuffle killed the IP enrichment pipeline
- As scale goes up ⇒ not as performant

### Minimizing shuffle at high volumes

- **Bucket the data** if multiple JOINs or aggregations happen downstream
- Always use **powers of 2** for bucket counts
- Bucket joins only work if both tables have bucket counts that are multiples of each other

## Bucket

## What bucketing actually does

- Spark hashes a chosen column (e.g. `user_id`) and assigns every row to a numbered bucket file
- Rows with the same hash land in the same bucket — on **both** tables
- At join time, Spark pairs bucket #N from table A with bucket #N from table B — no network shuffle needed
- Upfront cost paid once at write time; every downstream join is free

---

## How to create a bucketed table

```python
# Bucket by user_id into 256 buckets (power of 2)
df.write \
    .bucketBy(256, "user_id") \
    .sortBy("user_id") \
    .saveAsTable("events_bucketed")

# Both tables must be bucketed on the same column
df_users.write \
    .bucketBy(256, "user_id") \
    .sortBy("user_id") \
    .saveAsTable("users_bucketed")

# JOIN — Spark detects matching bucket layout, skips shuffle entirely
spark.sql("""
    SELECT e.user_id, u.country, COUNT(*) as cnt
    FROM events_bucketed e
    JOIN users_bucketed u ON e.user_id = u.user_id
    GROUP BY e.user_id, u.country
""")
```

---

## Why always powers of 2?

- The bucket join compatibility rule: two tables can join without shuffle **only if their bucket counts are multiples of each other**
- Powers of 2 (64, 128, 256, 512, 1024…) are always clean multiples of each other — every combination is compatible
- Use a non-power-of-2 (e.g. 300 + 200 → 1.5) and Spark **silently falls back to a full shuffle sort-merge join** — no error, no warning, all savings lost

### Compatible pairs ✅

- 256 + 128 → 256 / 128 = 2 ✓
- 512 + 256 → 512 / 256 = 2 ✓
- 512 + 128 → 512 / 128 = 4 ✓

### Incompatible pairs ❌

- 256 + 100 → 256 / 100 = 2.56 ✗ → silently falls back to shuffle
- 300 + 200 → 300 / 200 = 1.5 ✗ → silently falls back to shuffle

> 💡 You can safely grow over time: bucketed at 256 today, need 512 later — still compatible (512 / 256 = 2). Stick to the sequence 64 → 128 → 256 → 512 → 1024.
> 

---

## Bucketing vs SMB (sorted-merge bucket) joins

- Adding `sortBy()` on the same column upgrades a bucket join to an **SMB join**
- Within each bucket, rows are sorted — Spark merges two sorted lists in a single linear pass instead of building a hash table
- This is the fastest possible join in Spark

| Join type | Shuffle? | How it works | Relative speed |
| --- | --- | --- | --- |
| Shuffle sort-merge (default) | Yes | Move all rows across network, sort, join | 1x baseline |
| Bucket join (no sort) | No | Co-locate by bucket, hash join within bucket | ~6x faster |
| SMB join (bucket + sortBy) | No | Co-locate by bucket, merge two sorted lists linearly | ~24x faster |

---

## How many buckets to choose

- Bucket count = initial parallelism — Spark creates exactly that many output files
- Too few → large files, slow reads. Too many → thousands of tiny files, overhead kills performance
- Target ~256 MB per bucket file

| Table size | Recommended bucket count |
| --- | --- |
| < 10 GB | Don't bucket — use broadcast join instead |
| 10–100 GB | 64 or 128 |
| 100 GB – 1 TB | 256 or 512 |
| > 1 TB | 512 or 1024 |

---

## Drawbacks and gotchas

- Initial write is slow — Spark hashes and sorts all rows into bucket files (one-time cost)
- Tables that change schema frequently are expensive to re-bucket — requires rewriting the entire table
- Queries joining on a different column than the bucket column get **no benefit** — shuffle still happens
- Incompatible bucket counts cause a **silent fallback to shuffle** — always use `explain()` to confirm the join strategy
- Not worth it for small tables (<10 GB) — broadcast join is simpler and faster

---

## Quick reference

| Scenario | Decision |
| --- | --- |
| Same large table joined repeatedly downstream | Bucket it — high ROI |
| One-off ad-hoc join | Skip bucketing — shuffle is fine |
| Tables joined on the same key, sorted output needed | Use SMB (bucketBy + sortBy) |
| One side fits in memory (<1 GB) | Broadcast join — no bucketing needed |
| Picking bucket count | Always power of 2: 64, 128, 256, 512, 1024 |
| Join not skipping shuffle despite bucketing | Check counts are multiples — verify with `explain()` |

---

## Skew

- Some partitions get dramatically more data (e.g. Beyoncé gets far more notifications than average)
- **Symptom:** job stalls at 99% and fails; or box-and-whiskers plot shows extreme outliers

### Solutions

- **Spark 3+:** set `spark.sql.adaptive.enabled = True` (adaptive query execution)
- **Pre-Spark 3:** salt the GROUP BY — GROUP BY a random number, aggregate, then GROUP BY again
- **Note for AVG:** break into SUM and COUNT before salting, then divide at the end

---

## Data Sources & Output

### Can read from

- Lake: Delta Lake, Apache Iceberg, Hive metastore
- RDBMS: Postgres, Oracle
- API: REST calls (careful — this runs on the driver, not executors)
- Flat files: CSV, JSON

### Output best practices

- Almost always partition output on `date` (execution date of the pipeline)
- Called "ds partitioning" in big tech

---

## Managed vs Unmanaged Spark

|  | Managed (Databricks) | Unmanaged (big tech) |
| --- | --- | --- |
| **Notebooks** | Yes — primary workflow | POC only |
| **Testing** | Run the notebook | `spark-submit` from CLI |
| **Version control** | Git or notebook versioning | Git |

---

