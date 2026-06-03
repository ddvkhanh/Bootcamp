## Spark server vs notebook

### Spark server (Airbnb style)

- Every run is a fresh context — things get uncached automatically
- Great for testing — no state leaking between runs

### Notebook (Netflix style)

- Session persists across cells
- Must call `unpersist()` manually when done — cached data hangs around until explicitly released

> ⚠️ Databricks should be connected to GitHub. Every change goes through a PR review process with CI/CD checks. Treat notebooks like production code.
> 

---

## Caching

- Temporary views are **always recomputed** unless explicitly cached
- Caching stores a pre-computed result so subsequent references skip recomputation
- Caching is only worth it if the data **fits in memory** — if it doesn’t, you’re probably missing a staging table in your pipeline
- 

### Storage levels

| Storage level | Where data lives | Use when |
| --- | --- | --- |
| `MEMORY_ONLY` | RAM only | Data fits comfortably in memory |
| `DISK_ONLY` | Disk only | Data too large for memory |
| `MEMORY_AND_DISK` | RAM, spills to disk | Default — most common choice |

---

## Caching vs broadcast

|  | Caching | Broadcast join |
| --- | --- | --- |
| What it stores | Pre-computed values for re-use | Entire small dataset shipped to every executor |
| Data distribution | Stays partitioned — each executor holds its own partition | Full copy on every executor |
| Shuffle? | Doesn’t prevent shuffle | Prevents shuffle entirely |
| How to control | `df.cache()` / `df.persist()` | `spark.sql.autoBroadcastJoinThreshold` or `broadcast(df)` |

---

## DataFrame vs Dataset vs SparkSQL

| API | Language | Best for |
| --- | --- | --- |
| DataFrame | Python, Scala, Java, R | Hardened pipelines unlikely to change |
| SparkSQL | SQL | Collaborative pipelines with data scientists |
| Dataset | Scala only | Pipelines requiring unit + integration tests; use pure Scala functions instead of UDFs |

---

## UDFs — PySpark vs Scala

- Apache Arrow optimizations in recent Spark versions have made PySpark UDFs much closer to Scala performance
- Scala Dataset API lets you skip UDFs entirely — use pure Scala functions instead
- If writing a lot of UDFs in PySpark and performance matters, consider moving to Scala

---

## Parquet best practices

- Run-length encoding gives powerful compression — great fit for columnar data with repeated values
- **Never** use global `.sort()` — forces a full shuffle to produce a global order, painful and slow
- Use `.sortWithinPartitions()` instead — parallelizable, gets good distribution without global coordination

---

## Tuning guide

| Setting | Guidance | Watch out for |
| --- | --- | --- |
| `spark.executor.memory` | Size to your actual data — don’t blindly set 16 GB | Over-provisioning wastes cluster resources on every job |
| `spark.driver.memory` | Only bump if using `df.collect()` or running a very complex job | Default is usually fine — only change when you hit OOM on the driver |
| `spark.sql.shuffle.partitions` | Default is 200 — aim for ~100 MB per partition | Too few = large partitions, slow. Too many = tiny files, overhead |
| `spark.sql.adaptive.enabled` | AQE helps with skewed datasets (Spark 3+) | Wasteful overhead if the dataset is not actually skewed |

---
