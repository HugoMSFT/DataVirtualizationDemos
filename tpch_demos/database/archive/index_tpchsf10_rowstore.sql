USE tpchsf10_rowstore;
GO

SET NOCOUNT ON;

IF (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0) <> 8
    THROW 50031, 'Expected eight copied tables before creating indexes.', 1;

IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id IN
    (SELECT object_id FROM sys.tables WHERE is_ms_shipped = 0) AND type <> 0)
    THROW 50032, 'Target tables already contain indexes.', 1;
GO

RAISERROR(N'Creating primary keys', 10, 1) WITH NOWAIT;
ALTER TABLE dbo.nation
    ADD CONSTRAINT nation_pk PRIMARY KEY CLUSTERED (n_nationkey);
ALTER TABLE dbo.region
    ADD CONSTRAINT region_pk PRIMARY KEY CLUSTERED (r_regionkey);
ALTER TABLE dbo.customer
    ADD CONSTRAINT customer_pk PRIMARY KEY CLUSTERED (c_custkey)
    WITH (MAXDOP = 4);
ALTER TABLE dbo.part
    ADD CONSTRAINT part_pk PRIMARY KEY CLUSTERED (p_partkey)
    WITH (MAXDOP = 4);
ALTER TABLE dbo.partsupp
    ADD CONSTRAINT partsupp_pk PRIMARY KEY CLUSTERED (ps_partkey, ps_suppkey)
    WITH (MAXDOP = 4);
ALTER TABLE dbo.supplier
    ADD CONSTRAINT supplier_pk PRIMARY KEY CLUSTERED (s_suppkey)
    WITH (MAXDOP = 4);
GO

RAISERROR(N'Creating supporting rowstore indexes', 10, 1) WITH NOWAIT;
CREATE NONCLUSTERED INDEX n_regionkey_ind
    ON dbo.nation(n_regionkey)
    WITH (FILLFACTOR = 100, SORT_IN_TEMPDB = ON, MAXDOP = 4);
CREATE NONCLUSTERED INDEX ps_suppkey_ind
    ON dbo.partsupp(ps_suppkey)
    WITH (FILLFACTOR = 100, SORT_IN_TEMPDB = ON, MAXDOP = 4);
CREATE NONCLUSTERED INDEX s_nationkey_ind
    ON dbo.supplier(s_nationkey)
    WITH (FILLFACTOR = 100, SORT_IN_TEMPDB = ON, MAXDOP = 4);
GO

RAISERROR(N'Creating lineitem rowstore indexes', 10, 1) WITH NOWAIT;
CREATE CLUSTERED INDEX l_shipdate_ind
    ON dbo.lineitem(l_shipdate)
    WITH (FILLFACTOR = 95, SORT_IN_TEMPDB = OFF, MAXDOP = 4);
CREATE NONCLUSTERED INDEX l_orderkey_ind
    ON dbo.lineitem(l_orderkey)
    WITH (FILLFACTOR = 95, SORT_IN_TEMPDB = ON, MAXDOP = 4);
CREATE NONCLUSTERED INDEX l_partkey_ind
    ON dbo.lineitem(l_partkey)
    WITH (FILLFACTOR = 95, SORT_IN_TEMPDB = ON, MAXDOP = 4);
GO

RAISERROR(N'Creating orders rowstore indexes', 10, 1) WITH NOWAIT;
CREATE CLUSTERED INDEX o_orderdate_ind
    ON dbo.orders(o_orderdate)
    WITH (FILLFACTOR = 95, SORT_IN_TEMPDB = ON, MAXDOP = 4);
ALTER TABLE dbo.orders
    ADD CONSTRAINT orders_pk PRIMARY KEY NONCLUSTERED (o_orderkey)
    WITH (FILLFACTOR = 95, MAXDOP = 4);
GO

RAISERROR(N'Creating foreign keys', 10, 1) WITH NOWAIT;
ALTER TABLE dbo.customer WITH NOCHECK
    ADD CONSTRAINT customer_nation_fk
    FOREIGN KEY (c_nationkey) REFERENCES dbo.nation(n_nationkey);
ALTER TABLE dbo.lineitem WITH NOCHECK
    ADD CONSTRAINT lineitem_partkey_fk
    FOREIGN KEY (l_partkey) REFERENCES dbo.part(p_partkey);
ALTER TABLE dbo.lineitem WITH NOCHECK
    ADD CONSTRAINT lineitem_suppkey_fk
    FOREIGN KEY (l_suppkey) REFERENCES dbo.supplier(s_suppkey);
ALTER TABLE dbo.nation WITH NOCHECK
    ADD CONSTRAINT nation_region_fk
    FOREIGN KEY (n_regionkey) REFERENCES dbo.region(r_regionkey);
ALTER TABLE dbo.partsupp WITH NOCHECK
    ADD CONSTRAINT partsupp_part_fk
    FOREIGN KEY (ps_partkey) REFERENCES dbo.part(p_partkey);
ALTER TABLE dbo.partsupp WITH NOCHECK
    ADD CONSTRAINT partsupp_supplier_fk
    FOREIGN KEY (ps_suppkey) REFERENCES dbo.supplier(s_suppkey);
ALTER TABLE dbo.supplier WITH NOCHECK
    ADD CONSTRAINT supplier_nation_fk
    FOREIGN KEY (s_nationkey) REFERENCES dbo.nation(n_nationkey);
ALTER TABLE dbo.orders WITH NOCHECK
    ADD CONSTRAINT order_customer_fk
    FOREIGN KEY (o_custkey) REFERENCES dbo.customer(c_custkey);
ALTER TABLE dbo.lineitem WITH NOCHECK
    ADD CONSTRAINT lineitem_partsupp_fk
    FOREIGN KEY (l_partkey, l_suppkey)
    REFERENCES dbo.partsupp(ps_partkey, ps_suppkey);
ALTER TABLE dbo.lineitem WITH NOCHECK
    ADD CONSTRAINT lineitem_order_fk
    FOREIGN KEY (l_orderkey) REFERENCES dbo.orders(o_orderkey);
GO

ALTER TABLE dbo.customer WITH CHECK CHECK CONSTRAINT customer_nation_fk;
ALTER TABLE dbo.lineitem WITH CHECK CHECK CONSTRAINT lineitem_partkey_fk;
ALTER TABLE dbo.lineitem WITH CHECK CHECK CONSTRAINT lineitem_suppkey_fk;
ALTER TABLE dbo.nation WITH CHECK CHECK CONSTRAINT nation_region_fk;
ALTER TABLE dbo.partsupp WITH CHECK CHECK CONSTRAINT partsupp_part_fk;
ALTER TABLE dbo.partsupp WITH CHECK CHECK CONSTRAINT partsupp_supplier_fk;
ALTER TABLE dbo.supplier WITH CHECK CHECK CONSTRAINT supplier_nation_fk;
ALTER TABLE dbo.orders WITH CHECK CHECK CONSTRAINT order_customer_fk;
ALTER TABLE dbo.lineitem WITH CHECK CHECK CONSTRAINT lineitem_partsupp_fk;
ALTER TABLE dbo.lineitem WITH CHECK CHECK CONSTRAINT lineitem_order_fk;
GO

RAISERROR(N'Updating statistics', 10, 1) WITH NOWAIT;
EXEC sys.sp_updatestats;
CHECKPOINT;
GO
