## Where can bugs be caught?

| Stage | Scenario | Outcome |
| --- | --- | --- |
| Development | Unit tests and integration tests catch the bug before it ships | ✅ Best case |
| Production, pre-table | Write-audit-publish (WAP) pattern catches the bug before it lands in tables | ⚠️ Still okay |
| Production, in tables | A data analyst finds the bug — ruins trust, ruins mood, nobody wins | ❌ Worst case |

---

## Why SWE has higher quality standards than DE

- **Risk** — a server going down or non-responsive frontend stops the business; a pipeline delay is less visible
- **Maturation** — SWE is a more mature field; TDD and BDD are still new in data engineering
- **Talent diversity** — DEs come from more varied backgrounds than SWEs, leading to inconsistent quality norms

---

## How DE will become riskier over time

- Every day the notification ML pipeline was delayed at Facebook caused a **~10% drop in CTR** — data freshness directly impacts ML effectiveness
- Data drives experimentation — as trust in data rises, the blast radius of quality bugs rises too
- LLMs will automate the SQL and analytics layer — DEs who can’t write tests are more exposed

---

## Why most organizations miss the mark

- Zach didn’t write a single data quality check or unit test in his **first 18 months at Facebook**
- Data analytics doesn’t have a culture of automated excellence — “this chart looks weird” is the norm at too many orgs
- Business wants answers fast; engineers don’t want to die from tech debt — who wins depends on the strength of engineering leadership

> ⚠️ Don’t cut corners to go faster — go faster in a more **sustainable** fashion.
> 

---

## Data engineering capability roadmap

| Dimension | How it gets solved |
| --- | --- |
| Latency | Streaming pipelines and microbatch patterns |
| Quality | Best practices, WAP pattern, Great Expectations, unit + integration tests |
| Completeness | Communication with domain experts and data contracts |
| Ease of access | Data products and proper data modeling |

---

## DE with a software engineering mindset

- **Code is 90% read by humans** — optimize for readability, not just execution
- **Silent failures are your enemy** — fail the pipeline loudly when bad data arrives
- **Loud failures via CI/CD** — tests + gates catch bugs before production
- **DRY + YAGNI** — don’t repeat yourself; don’t build what you don’t need yet. SQL fights DRY — use CTEs and macros
- **Design documents** — write before you build; surfaces assumptions and prevents wasted work
- **Care about efficiency** — understand data structures, algorithms, JOIN costs, and shuffle

---

## Should DEs learn SWE best practices?

- **Short answer: YES**
- LLMs will make the SQL and analytics layer more susceptible to automation
- If you don’t want to learn these things — go into **analytics engineering** instead
- **Data engineering is engineering** — treat it as such