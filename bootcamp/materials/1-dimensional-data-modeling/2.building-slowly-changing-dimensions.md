## **Building Slowly Changing Dimensions**

## 🔁 What is Idempotency?

- A pipeline is **idempotent** if running it once or ten times produces the exact same result
    - Production behaviour and Backfill behaviour of the pipeline should be the same
- Doesn't matter when you run it — 9am, midnight, Monday, Friday — same output
- Failures are **silent**: no error thrown, but data is wrong. You only find out when an analyst notices inconsistencies

> 💡 **Analogy:** Like a vending machine — press B3 once or five times, always get the same chips. A broken one gives you chips + a Snickers on the second press. That's `INSERT INTO` without a truncate.
> 

---

## ⚠️ What Breaks Idempotency?

### ❌ INSERT INTO without truncating

- Runs stack rows silently — no error thrown

```sql
-- Run twice → duplicate rows
INSERT INTO player_stats
SELECT * FROM raw_player_seasons WHERE season = 1997;
```

✅ **Fix — DELETE + INSERT or MERGE**

```sql
DELETE FROM player_stats WHERE season = 1997;
INSERT INTO player_stats
SELECT * FROM raw_player_seasons WHERE season = 1997;

-- Or use MERGE (preferred)
MERGE INTO player_stats AS target
USING (SELECT * FROM raw_player_seasons WHERE season = 1997) AS source
ON target.player_name = source.player_name AND target.season = source.season
WHEN MATCHED THEN UPDATE SET pts = source.pts
WHEN NOT MATCHED THEN INSERT VALUES (source.player_name, source.season, source.pts);
```

### ❌ Open-ended date filters

- Returns different rows depending on *when* you run it

```sql
-- BAD: result changes over time
SELECT * FROM events WHERE event_date > '2024-01-01';

-- GOOD: always bounded
SELECT * FROM events
WHERE event_date > '2024-01-01' AND event_date <= '2024-01-31';
```

### ❌ Other causes

- Relying on the "latest" partition of an SCD table — latest changes over time
    - If your pipeline always joins to the latest partition, backfilling old dates will pick up the *current* dimension value, not the historical one
    - ⇒ Always time-bound joins
- Missing `depends_on_past` on cumulative pipelines — later runs skip earlier seasons silently
    - Cumulative pipelines build on each other — each run reads *yesterday's* output as input and appends to it
    - If a run fails or is skipped and the next run proceeds anyway, it reads a stale snapshot and appends over the gap — the missing period is gone forever
- Partial partition sensors — pipeline runs before all source data has arrived
    - A partition sensor checks whether a source partition exists before the pipeline runs — but *exists* is not the same as *complete*
    - If the upstream source writes data incrementally, a sensor that fires on first row will trigger your pipeline before all data has landed
    - Your pipeline runs on partial data, produces a partial result, and marks itself as successful — no error, wrong numbers

### Outcomes of not having idempotent pipelines

- backfilling causes inconsistencies between the old and restated data
- hard to troubleshoot
- cannot replicate the production behavior in unit testing
- silent failures

---

### **The lay of the land: what data modeling is solving**

- Every data model has two types of tables: **facts** (things that happen — orders, clicks, game stats) and **dimensions** (things that describe — players, users, products)
- Facts change constantly. Dimensions are meant to be stable — but they're not. A player changes team. A user changes country. A product changes price.
- The question SCD answers is: **when a dimension changes, what do you do with the old value?**
    - Also, how slow is SCD if a dim is not changing very quickly ⇒ Yes, SCD. But if it changes every week ⇒ we are only collapse a few days of data ⇒ might as well do a daily snapshot

| **Approach** | **What it does when a dimension changes** | **History kept?** | **Idempotent?** |
| --- | --- | --- | --- |
| **Latest snapshot** | Overwrites the row. Only the current value exists. | **None** | **No** |
| **Daily snapshot** | Saves a full copy of the dimension table every day (or month/year). No rows are updated — new partitions are appended. | **Full** | **Yes** |
| **SCD Type 1** | Overwrites in place — same as latest snapshot but called an SCD. Destroys history. | **None** | **No** |
| **SCD Type 2** | Adds a new row with a `valid_from` / `valid_to` range. The old row stays untouched. | **Full** | **Yes** |
| **SCD Type 3** | Adds a new column (`previous_value`). Only keeps one step back. | **One step** | **Partial** |

## 🕰️ Slowly Changing Dimensions (SCD)

- How you model dimension data that **changes over time** (e.g. player's country, user's plan tier)
- The type you pick determines whether historical queries can be trusted

| Type | Description | Idempotent? |
| --- | --- | --- |
| Type 0 | Value never changes (e.g. birth date) | ✅ Yes |
| Type 1 | Overwrite with latest — no history | ❌ No |
| Type 2 ⭐ | Full history via start/end date | ✅ Yes |
| Type 3 | Stores original + current only | ⚠️ Partial |

### ❌ Type 1 — backfill problem

- Player moves USA → Australia in 2024. Type 1 overwrites the row
- Backfilling 2022 stats shows the player as Australian — **silently wrong**

### ✅ Type 2 — full history preserved

| player_name | country | start_date | end_date |
| --- | --- | --- | --- |
| LeBron | USA | 2003-01-01 | 2024-05-31 |
| LeBron | Australia | 2024-06-01 | 9999-12-31 |

```sql
-- Backfilling 2022 correctly picks up USA
WHERE '2022-01-01' BETWEEN start_date AND end_date
```

### ⚠️ Type 3 — partial history problem

- Stores only `original_country` and `current_country`
- If a player moved twice (USA → France → Australia), **France is lost forever**
- During backfill you can't tell which column was correct at a given point in time

---

## 🔗 Cumulative Pipelines & depends_on_past

- Cumulative tables append history each run — each season builds on the last
- If the 1997 run is skipped and 1998 runs anyway → reads 1996 snapshot and appends 1998 → **1997 silently missing**
- Set `depends_on_past = True` in Airflow to enforce the chain

| Run | season_stats result |
| --- | --- |
| 1996 | [(1996, ...)] |
| 1997 | [(1996, ...), (1997, ...)] |
| 1998 (skipped 1997) | [(1996, ...), (1998, ...)] ← wrong |

---

## ✅ Quick Reference

| Pattern | Idempotent? | Fix |
| --- | --- | --- |
| `INSERT INTO` without truncate | ❌ No | Use `MERGE` or `DELETE`  • insert |
| Open-ended date filter | ❌ No | Always bound both start and end |
| SCD Type 1 | ❌ No | Use Type 2 |
| SCD Type 3 | ⚠️ Partial | Use Type 2 if backfill matters |
| SCD Type 2 | ✅ Yes | Filter on time: `BETWEEN start AND end` |
| Cumulative pipeline | ❌ No | Set `depends_on_past = True` |

## **Graph Data Modelling**

## ➕ Additive vs Non-Additive Dimensions

- A dimension is **additive** if you can sum its groups without double-counting — the total equals the sum of all parts
- A dimension is **non-additive** if a single entity can belong to multiple groups at once, making simple aggregation wrong
- Non-additive dimensions are usually only non-additive for `COUNT` — `SUM` aggregations are often still fine

> 💡 **Key rule:** A dimension is additive over a time window if and only if the grain of data over that window can only ever be one value at a time.
> 

### Examples

| Dimension | Additive? | Why |
| --- | --- | --- |
| Age | ✅ Yes | A person has exactly one age — 20yo + 30yo + 40yo = total population |
| Platform (web/Android/iOS) | ❌ No | A user can be active on multiple platforms — summing over-counts |
| Car model (Civic/Accord/Corolla) | ❌ No | A driver can own multiple models — summing over-counts |

> ✅ **Practical benefit:** Additive dimensions let you skip `COUNT(DISTINCT)` on pre-aggregated tables — a significant performance win at scale.
> 

---

## 📋 Enums — When and Why

- Best for **low-to-medium cardinality** dimensions with a known, exhaustive list of values
- Country starts to push the limits — hundreds of values make enums harder to manage

### Why use enums?

- **Built-in data quality** — invalid values are rejected at write time, no bad data slips through
- **Built-in documentation** — the enum definition is a self-documenting contract of valid states
- **Static fields** — values are locked, schema changes are explicit and intentional
- **Great for subpartitions** — exhaustive list lets you chunk a big pipeline into manageable parallel pieces

### Real-world enum pattern use cases

| Company | Shared schema | Sources mapped in |
| --- | --- | --- |
| Airbnb | Unit Economics | fees, coupons, credits, insurance, taxes, infrastructure cost |
| Netflix | Infrastructure Graph | apps, databases, servers, codebases, CI/CD jobs |
| Facebook | Family of Apps | Facebook, Instagram, WhatsApp, Messenger, Oculus, Threads |

> 💡 When you have many disparate sources that need to map into one unified schema, enums define the "type" column that identifies which source each row came from — keeping the schema clean and the pipeline modular.
> 

---

## 🗂️ Flexible Schemas

- Used when you need to absorb many sources into a single table without rigid column definitions
- Typically an `other_properties` column stores rarely-used attributes as JSON or a MAP type

### Benefits

- No `ALTER TABLE` needed for new columns
- No tons of NULL columns in the schema
- Great for rarely-used-but-needed fields

### Drawbacks

- Worse compression (especially JSON)
- Harder to query and read
- Less BI tool friendly

---

## 🕸️ Graph Data Modeling

- Graph modeling is **relationship-focused**, not entity-focused — the edges (connections) are the primary subject
- Entities (vertices) are intentionally simple; the richness lives in how they connect

### Vertex schema (entities)

```
identifier   STRING
type         STRING
properties   MAP
```

### Edge schema (relationships)

```
subject_identifier   STRING
subject_type         VERTEX_TYPE
object_identifier    STRING
object_type          VERTEX_TYPE
edge_type            EDGE_TYPE
properties           MAP
```

### NBA example

| subject | subject_type | edge_type | object | object_type |
| --- | --- | --- | --- | --- |
| Michael Jordan | Player | PLAYS_ON | Chicago Bulls | Team |
| John Stockton | Player | PLAYS_ON | Utah Jazz | Team |
| Michael Jordan | Player | PLAYS_AGAINST | John Stockton | Player |

> ⚠️ **Key difference from relational modeling:** In relational modeling you design entities first, then relationships. In graph modeling you start with the relationships — entities are just lightweight anchors. Great for traversal queries, less natural for entity-centric analytics.
> 

---

