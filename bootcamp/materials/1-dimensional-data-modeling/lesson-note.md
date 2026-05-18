## **Dimensional Data Modeling Complex Data Type and Cumulation**

- What is a dimension?
    - attributes of an entity
    - some may identify an entity (e.g: user ID), other are just attributes
- Come in 2 flavors:
    - slowly-changing
    - fixed
    
    # 1. Knowing Your Data Consumer
    
    ## Why this matters
    
    - Data modeling is not just about storing data
    - It is about making data **usable for consumers**
    
    ## Types of consumers
    
    - Analysts
        - Write SQL queries
        - Need simple, flat tables
    - BI tools (Power BI, Looker)
        - Prefer star schema
        - Struggle with nested data
    - Data Scientists
        - May handle complex structures
        - Often reshape data anyway
    
    ## Key principle
    
    - Optimize for **querying and understanding**, not storage elegance
    
    ---
    
    ## Best Practices
    
    - Design **fact + dimension tables** for analytics
    - Avoid exposing raw nested structures to end users
    - Keep business logic centralized (e.g. in transformation layer)
    
    ---
    
    # 2. OLTP vs OLAP Data Modeling
    
    ## OLTP (Online Transaction Processing)
    
    Purpose:
    
    - Run applications (CRUD operations)
    
    Characteristics:
    
    - Highly normalized (3NF)
    - Many small tables
    - Frequent inserts/updates
    - Optimized for writes
    
    Examples:
    
    - Banking system
    - E-commerce orders
    
    ---
    
    ## OLAP (Online Analytical Processing)
    
    Purpose:
    
    - Reporting and analysis
    
    Characteristics:
    
    - Denormalized (star/snowflake schema)
    - Fact and dimension tables
    - Optimized for reads and aggregations
    
    Examples:
    
    - Data warehouse
    - BI dashboards
    
    ---
    
    ## Master Data
    
    - Optimizes for completedness of entity definitions, deduped
        
    ## Comparison
    
    - OLTP:
        - Data consistency
        - Efficient writes
        - Complex for analytics
    - OLAP:
        - Fast queries
        - Easy to understand
        - Data duplication
    
    ---
    
    ## Best Practice
    
    - Separate OLTP and OLAP systems
    - Transform normalized data → dimensional model
    
    ---
    
    # 3. Cumulative Table Design
    
    ## What is cumulative data?
    
    - Data that evolves over time
    - Multiple records represent different states
    - Core components:
        - 2 DF (yesterday and today)
        - FULL OUTER JOIN the 2 DF ⇒ COLEASCE to keep everything around
        - Hang onto all history
    - Usage:
        - growth analytics on FB (dim_all_users)
        - state transition tracking
    - Strengths:
        - historical analysis without shuffle
        - easy “transition” analysis
    - Drawbacks
        - can only be backfilled sequentially (since it relies on yesterday data we cannot backfill in parallel)
        - handling PII data can be a mess since deleted/ inactive users get carried forward
    - 
        
    ---
    
    ## Types of fact tables
    
    ### 1. Transaction Fact Table
    
    - One row per event
    - Example: each purchase
    
    ---
    
    ### 2. Snapshot Fact Table
    
    - Captures state at a specific time
    - Example: inventory at end of day
    
    ---
    
    ### 3. Accumulating Snapshot
    
    - Tracks lifecycle of an entity
    - Example: order progress
    
    ---
    
    ## Key challenge
    
    - Same entity appears multiple times
    - These are:
        - Not duplicates
        - Represent time evolution
    
    ---
    
    ## Best Practices
    
    - Store **full history** for analysis
    - Create derived tables for:
        - latest state
        - aggregated views
    
    ---
    
    ## Tradeoffs
    
    - Full history:
        - Enables trend analysis
        - Larger storage
    - Latest only:
        - Simpler
        - Loss of historical insight
    
    ---
    
    # 4. The Compactness vs Usability Tradeoff
    
    - The most usable tables usually:
        - Have no complex data types
        - Easily can be manipulated (WHERE and GROUP BY)
        - Use case: when analytics is the main consumer and the majority of consumers are other data engineers
    - The most compact tables (not human readable)
        - Are compressed to be as small as possible and can’t be queried directly until they are decoded
        - Use case: online systems where latency and data volumes matter a lot. Consumers are usually highly technical.
    - The middle-ground tables:
        - use complex data types (ARRAY. MAP, STRUCT) making querying tricker but also compacting more
            - Struct:
                - Keys are rigidly defined, compression is good
                - values can be any type
            - Map
                - Keys are loosely defined, compression is okay
                - values all have to be the same type
            - Array
                - ordinal
                - list of values that all have to be the same type
        - upstream staging/ master data where the majority of consumers are other data engineers
    
    ## Two approaches
    
    ### 1. Compact storage
    
    - Nested JSON / arrays
    - Minimal duplication
    
    Pros:
    
    - Efficient storage
    - Faster ingestion
    
    Cons:
    
    - Hard to query
    - Limited BI compatibility
    
    ---
    
    ### 2. Usable structure
    
    - Flattened tables
    - Separate dimensions
    
    Pros:
    
    - Easy querying
    - BI-friendly
    
    Cons:
    
    - More storage
    - Requires joins
    
    ---
    
    ## Key insight
    
    - Storage efficiency ≠ usability
    - Analytics systems prioritize **usability**
    
    ---
    
    ## Best Practice
    
    - Raw layer → compact
    - Analytics layer → flattened
    
    ---
    
    # 5. Temporal Cardinality Explosion
    
    ## What is it?
    
    - Rapid growth in row count when adding time dimension
        
    ---
    
    ## Why it happens
    
    - Snapshot data collected frequently
    - Each time point creates new rows
    
    ---
    
    ## Impact
    
    - Large datasets
    - Slower queries
    - Increased storage and compute cost
    
    ---
    
    ## Mitigation strategies
    
    ### 1. Partitioning
    
    - Partition tables by date/time
    
    ---
    
    ### 2. Filtering
    
    - Always limit queries by time range
    
    ---
    
    ### 3. Aggregation
    
    - Create summary tables (daily/hourly)
    
    ---
    
    ### 4. Selective retention
    
    - Keep detailed data for recent periods
    - Archive older data
    
    ---
    
    ## Tradeoffs
    
    - High granularity:
        - Detailed insights
        - Large data volume
    - Low granularity:
        - Efficient
        - Loss of detail
    
    ---
    
    # 6. Run-Length Encoding (RLE) Compression Gotchas
    
    ## What is RLE?
    
    - Compression technique:
        - Store repeated values efficiently
    
    Example:
    
    - A, A, A, B → (A,3), (B,1)
    
    ---
    
    ## Why it matters in data warehouses
    
    - Columnar databases rely on compression
    - Better compression = faster queries
                
    
    ---
    
    ## Challenges with temporal data
    
    ### 1. High-cardinality columns
    
    - Columns like timestamps are often unique
    - Reduce compression effectiveness
    
    ---
    
    ### 2. Frequent small changes
    
    - Slight variations break repetition patterns
    - Compression becomes less efficient
    
    ---
    
    ### 3. Flattened data increases rows
    
    - More rows → less repetition per column
    
    ---
    
    ## Mitigation strategies
    
    ### 1. Partitioning and clustering
    
    - Group similar data together
    
    ---
    
    ### 2. Separate static vs dynamic data
    
    - Static attributes → dimension tables
    - Dynamic attributes → fact tables
    
    ---
    
    ### 3. Avoid unnecessary duplication
    
    - Do not repeat large text fields in every row
    
    ---
    
    ## Tradeoffs
    
    - More normalization:
        - Better compression
        - More joins
    - More denormalization:
        - Easier queries
        - Worse compression
    
    ---
    
    # Final Key Takeaways
    
    - Design for **data consumers first**
    - Transform OLTP → OLAP for analytics
    - Cumulative data represents **state over time, not duplicates**
    - Accept tradeoffs:
        - compactness vs usability
        - detail vs performance
    - Time dimension can significantly increase data size
    - Compression benefits depend on data patterns, not just storage format