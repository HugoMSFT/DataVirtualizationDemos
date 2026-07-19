import os


def required_env(name):
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"{name} must be set")
    return value


def required_secret(name):
    file_name = os.environ.get(f"{name}_FILE")
    if file_name:
        with open(file_name, encoding="utf-8") as secret_file:
            value = secret_file.read().rstrip("\r\n")
    else:
        value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"{name} or {name}_FILE must be set")
    return value


server = required_env("MSSQL_SERVER")
database = required_env("MSSQL_DATABASE")
username = required_env("MSSQL_USERNAME")
password = required_secret("MSSQL_PASSWORD")

print("SETTING AZURE SQL TPROC-H SF10 CONFIGURATION")
dbset("db", "mssqls")
dbset("bm", "TPC-H")

diset("connection", "mssqls_tcp", "true")
diset("connection", "mssqls_port", "1433")
diset("connection", "mssqls_azure", "true")
diset("connection", "mssqls_encrypt_connection", "true")
diset("connection", "mssqls_trust_server_cert", "false")
diset("connection", "mssqls_linux_server", server)
diset("connection", "mssqls_linux_authent", "sql")
diset("connection", "mssqls_linux_odbc", "{ODBC Driver 18 for SQL Server}")
diset("connection", "mssqls_uid", username)
diset("connection", "mssqls_pass", password)

diset("tpch", "mssqls_num_tpch_threads", 4)
diset("tpch", "mssqls_scale_fact", 10)
diset("tpch", "mssqls_maxdop", 4)
diset("tpch", "mssqls_tpch_dbase", database)
diset("tpch", "mssqls_colstore", "true")
diset("tpch", "mssqls_tpch_use_bcp", "true")
diset("tpch", "mssqls_tpch_partition_orders_and_lineitems", "false")
diset("tpch", "mssqls_tpch_advanced_stats", "false")

print("SCHEMA BUILD STARTED")
buildschema()
print("SCHEMA BUILD COMPLETED")
exit()
