USE [tpchsf10_columnstore];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF SCHEMA_ID(N'rs') IS NULL
    THROW 50511, 'Schema rs is missing.', 1;

IF
(
    SELECT COUNT(*)
    FROM sys.tables AS t
    JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id
    WHERE s.name = N'rs'
      AND t.is_external = 0
) <> 8
    THROW 50512, 'Expected eight copied rs tables.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.tables AS t
    JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id
    JOIN sys.indexes AS i
        ON i.object_id = t.object_id
    WHERE s.name = N'rs'
      AND t.is_external = 0
      AND i.index_id <> 0
)
    THROW 50513, 'The rs tables already contain indexes.', 1;
GO

RAISERROR(N'Creating rs primary keys', 10, 1) WITH NOWAIT;
ALTER TABLE rs.nation
    ADD CONSTRAINT nation_pk PRIMARY KEY CLUSTERED (n_nationkey);
ALTER TABLE rs.region
    ADD CONSTRAINT region_pk PRIMARY KEY CLUSTERED (r_regionkey);
ALTER TABLE rs.customer
    ADD CONSTRAINT customer_pk PRIMARY KEY CLUSTERED (c_custkey)
    WITH (MAXDOP = 4);
ALTER TABLE rs.part
    ADD CONSTRAINT part_pk PRIMARY KEY CLUSTERED (p_partkey)
    WITH (MAXDOP = 4);
ALTER TABLE rs.partsupp
    ADD CONSTRAINT partsupp_pk PRIMARY KEY CLUSTERED (ps_partkey, ps_suppkey)
    WITH (MAXDOP = 4);
ALTER TABLE rs.supplier
    ADD CONSTRAINT supplier_pk PRIMARY KEY CLUSTERED (s_suppkey)
    WITH (MAXDOP = 4);
GO

RAISERROR(N'Creating rs supporting indexes', 10, 1) WITH NOWAIT;
CREATE NONCLUSTERED INDEX n_regionkey_ind
    ON rs.nation(n_regionkey)
    WITH (FILLFACTOR = 100, SORT_IN_TEMPDB = ON, MAXDOP = 4);
CREATE NONCLUSTERED INDEX ps_suppkey_ind
    ON rs.partsupp(ps_suppkey)
    WITH (FILLFACTOR = 100, SORT_IN_TEMPDB = ON, MAXDOP = 4);
CREATE NONCLUSTERED INDEX s_nationkey_ind
    ON rs.supplier(s_nationkey)
    WITH (FILLFACTOR = 100, SORT_IN_TEMPDB = ON, MAXDOP = 4);
GO

RAISERROR(N'Creating rs lineitem indexes', 10, 1) WITH NOWAIT;
CREATE CLUSTERED INDEX l_shipdate_ind
    ON rs.lineitem(l_shipdate)
    WITH (FILLFACTOR = 95, SORT_IN_TEMPDB = OFF, MAXDOP = 4);
CREATE NONCLUSTERED INDEX l_orderkey_ind
    ON rs.lineitem(l_orderkey)
    WITH (FILLFACTOR = 95, SORT_IN_TEMPDB = ON, MAXDOP = 4);
CREATE NONCLUSTERED INDEX l_partkey_ind
    ON rs.lineitem(l_partkey)
    WITH (FILLFACTOR = 95, SORT_IN_TEMPDB = ON, MAXDOP = 4);
GO

RAISERROR(N'Creating rs orders indexes', 10, 1) WITH NOWAIT;
CREATE CLUSTERED INDEX o_orderdate_ind
    ON rs.orders(o_orderdate)
    WITH (FILLFACTOR = 95, SORT_IN_TEMPDB = ON, MAXDOP = 4);
ALTER TABLE rs.orders
    ADD CONSTRAINT orders_pk PRIMARY KEY NONCLUSTERED (o_orderkey)
    WITH (FILLFACTOR = 95, MAXDOP = 4);
GO

RAISERROR(N'Creating and validating rs foreign keys', 10, 1) WITH NOWAIT;
ALTER TABLE rs.customer WITH NOCHECK
    ADD CONSTRAINT customer_nation_fk
    FOREIGN KEY (c_nationkey) REFERENCES rs.nation(n_nationkey);
ALTER TABLE rs.lineitem WITH NOCHECK
    ADD CONSTRAINT lineitem_partkey_fk
    FOREIGN KEY (l_partkey) REFERENCES rs.part(p_partkey);
ALTER TABLE rs.lineitem WITH NOCHECK
    ADD CONSTRAINT lineitem_suppkey_fk
    FOREIGN KEY (l_suppkey) REFERENCES rs.supplier(s_suppkey);
ALTER TABLE rs.nation WITH NOCHECK
    ADD CONSTRAINT nation_region_fk
    FOREIGN KEY (n_regionkey) REFERENCES rs.region(r_regionkey);
ALTER TABLE rs.partsupp WITH NOCHECK
    ADD CONSTRAINT partsupp_part_fk
    FOREIGN KEY (ps_partkey) REFERENCES rs.part(p_partkey);
ALTER TABLE rs.partsupp WITH NOCHECK
    ADD CONSTRAINT partsupp_supplier_fk
    FOREIGN KEY (ps_suppkey) REFERENCES rs.supplier(s_suppkey);
ALTER TABLE rs.supplier WITH NOCHECK
    ADD CONSTRAINT supplier_nation_fk
    FOREIGN KEY (s_nationkey) REFERENCES rs.nation(n_nationkey);
ALTER TABLE rs.orders WITH NOCHECK
    ADD CONSTRAINT order_customer_fk
    FOREIGN KEY (o_custkey) REFERENCES rs.customer(c_custkey);
ALTER TABLE rs.lineitem WITH NOCHECK
    ADD CONSTRAINT lineitem_partsupp_fk
    FOREIGN KEY (l_partkey, l_suppkey)
    REFERENCES rs.partsupp(ps_partkey, ps_suppkey);
ALTER TABLE rs.lineitem WITH NOCHECK
    ADD CONSTRAINT lineitem_order_fk
    FOREIGN KEY (l_orderkey) REFERENCES rs.orders(o_orderkey);
GO

ALTER TABLE rs.customer WITH CHECK CHECK CONSTRAINT customer_nation_fk;
ALTER TABLE rs.lineitem WITH CHECK CHECK CONSTRAINT lineitem_partkey_fk;
ALTER TABLE rs.lineitem WITH CHECK CHECK CONSTRAINT lineitem_suppkey_fk;
ALTER TABLE rs.nation WITH CHECK CHECK CONSTRAINT nation_region_fk;
ALTER TABLE rs.partsupp WITH CHECK CHECK CONSTRAINT partsupp_part_fk;
ALTER TABLE rs.partsupp WITH CHECK CHECK CONSTRAINT partsupp_supplier_fk;
ALTER TABLE rs.supplier WITH CHECK CHECK CONSTRAINT supplier_nation_fk;
ALTER TABLE rs.orders WITH CHECK CHECK CONSTRAINT order_customer_fk;
ALTER TABLE rs.lineitem WITH CHECK CHECK CONSTRAINT lineitem_partsupp_fk;
ALTER TABLE rs.lineitem WITH CHECK CHECK CONSTRAINT lineitem_order_fk;
GO

RAISERROR(N'Updating rs statistics', 10, 1) WITH NOWAIT;
UPDATE STATISTICS rs.region;
UPDATE STATISTICS rs.nation;
UPDATE STATISTICS rs.supplier;
UPDATE STATISTICS rs.customer;
UPDATE STATISTICS rs.part;
UPDATE STATISTICS rs.partsupp;
UPDATE STATISTICS rs.orders;
UPDATE STATISTICS rs.lineitem;
CHECKPOINT;
GO
