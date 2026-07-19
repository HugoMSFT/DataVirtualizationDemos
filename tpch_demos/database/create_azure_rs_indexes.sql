USE [tpchsf100];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF SCHEMA_ID(N'rs') IS NULL
    THROW 50531, 'Schema rs is missing.', 1;

IF
(
    SELECT COUNT(*)
    FROM sys.tables AS t
    JOIN sys.schemas AS s
      ON s.schema_id = t.schema_id
    WHERE s.name = N'rs'
      AND t.is_external = 0
) <> 8
    THROW 50532, 'Expected eight copied rs tables.', 1;

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
    THROW 50533, 'The rs tables already contain indexes.', 1;
GO

RAISERROR(N'Creating the eight rs B-tree indexes', 10, 1) WITH NOWAIT;
ALTER TABLE rs.partsupp
    ADD CONSTRAINT partsupp_pk
    PRIMARY KEY CLUSTERED (ps_partkey, ps_suppkey)
    WITH (MAXDOP = 4);
CREATE UNIQUE NONCLUSTERED INDEX customer_pk
    ON rs.customer(c_custkey)
    WITH (MAXDOP = 4);
CREATE NONCLUSTERED INDEX lineitem_pk
    ON rs.lineitem(l_orderkey)
    WITH (MAXDOP = 4);
CREATE UNIQUE NONCLUSTERED INDEX nation_pk
    ON rs.nation(n_nationkey)
    WITH (MAXDOP = 4);
CREATE UNIQUE NONCLUSTERED INDEX orders_pk
    ON rs.orders(o_orderkey)
    WITH (MAXDOP = 4);
CREATE UNIQUE NONCLUSTERED INDEX part_pk
    ON rs.part(p_partkey)
    WITH (MAXDOP = 4);
CREATE UNIQUE NONCLUSTERED INDEX region_pk
    ON rs.region(r_regionkey)
    WITH (MAXDOP = 4);
CREATE UNIQUE NONCLUSTERED INDEX supplier_pk
    ON rs.supplier(s_suppkey)
    WITH (MAXDOP = 4);
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
GO
