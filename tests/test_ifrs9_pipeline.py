import os
import psycopg2
import pytest

@pytest.fixture(scope="module")
def db_conn():
    conn = psycopg2.connect(
        host=os.getenv("POSTGRES_HOST", "postgres"),
        database=os.getenv("POSTGRES_DB", "ifrs9_db"),
        user=os.getenv("POSTGRES_USER", "postgres"),
        password=os.getenv("POSTGRES_PASSWORD", "postgres_pass")
    )
    yield conn
    conn.close()

def test_fact_statements_record_count(db_conn):
    query = "SELECT COUNT(*) FROM fact_statements;"
    with db_conn.cursor() as cur:
        cur.execute(query)
        count = cur.fetchone()[0]
        assert count == 30

def test_roll_rate_matrix_percentages_sum_to_hundred(db_conn):
    query = """
    SELECT prev_bucket, (pct_to_current + pct_to_1_30 + pct_to_31_60 + pct_to_60_plus) AS total_pct
    FROM v_roll_rate_matrix;
    """
    with db_conn.cursor() as cur:
        cur.execute(query)
        rows = cur.fetchall()
        assert len(rows) > 0
        for prev_bucket, total_pct in rows:
            assert abs(float(total_pct) - 100.0) < 0.05

def test_ecl_calculation_validity(db_conn):
    query = "SELECT risk_bucket, ead, pd, lgd, ecl FROM v_ecl_calculation;"
    with db_conn.cursor() as cur:
        cur.execute(query)
        rows = cur.fetchall()
        assert len(rows) > 0
        for row in rows:
            risk_bucket, ead, pd, lgd, ecl = row
            assert float(ead) >= 0
            assert 0.0 <= float(pd) <= 1.0
            assert 0.0 <= float(lgd) <= 1.0
            assert float(ecl) >= 0