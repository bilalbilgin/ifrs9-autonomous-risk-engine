# Enterprise IFRS 9 Credit Risk Engine and CI/CD Pipeline

End-to-end financial risk analytics and data validation pipeline built on PostgreSQL, Python (PyTest), and GitLab CI/CD, featuring automated Root Cause Analysis (RCA) via GitLab Duo Agentic AI.

---

## Executive Summary
This project implements an automated, audit-ready data engineering and credit risk calculation framework in compliance with IFRS 9 / Basel regulatory standards.

The pipeline models credit card portfolio migrations across delinquency buckets (Roll-Rate Matrix), computes Expected Credit Loss (ECL = EAD * PD * LGD), and enforces continuous data integrity tests on every commit using containerized GitLab CI/CD pipelines.

---

## System Architecture and Tech Stack

```text
   Raw Banking Data (fact_statements)
                  │
                  ▼
   PostgreSQL Staging & Transformations
   ├── Roll-Rate Migration Matrix (v_roll_rate_matrix)
   └── Staged ECL Calculations (v_ecl_calculation)
                  │
                  ▼
   Automated Verification Layer (GitLab CI/CD)
   ├── PostgreSQL Container Service (ifrs9_db)
   ├── Schema Migration & Constraint Execution
   ├── PyTest Suite (Domain Logic & Boundary Assertions)
   └── GitLab Secret Detection Scanner
                  │
                  ▼
   GitLab Duo AI (Agentic RCA & Auto-Remediation)