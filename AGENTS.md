# AGENTS.md — Instructions for Building MAIA

> MAIA — **M**ission **A**ware **I**ncident **A**uthority
>
> The open source platform for coordinated emergency response.

This file instructs AI coding agents (Claude, Codex, etc.) on the architecture, conventions,
constraints, and decisions for **MAIA**.
Every choice described here is final and must not be questioned
unless explicitly revised in this document.

---

## 0. Language Policy — Non-Negotiable

**English is the sole language of this project, without exception.**

This applies to:
- All source code (function names, variable names, class names, constants)
- All code comments and inline documentation
- All docstrings
- All commit messages (following Conventional Commits)
- All documentation files (AGENTS.md, README.md, docs/)
- All configuration file comments
- All test names and test descriptions
- All error messages returned by the API
- All log messages
- All GitHub Actions workflow steps and comments
- All PR and issue templates

**There are no exceptions.** If a word or phrase exists only in another language
(e.g. an Italian place name in a test fixture), it may appear as a data value,
never as an identifier, comment, or documentation text.

Any contribution containing non-English identifiers, comments, or documentation
must be rejected in code review and will fail the CI lint step.

---

## 1. Project Context

MAIA (**M**ission **A**ware **I**ncident **A**uthority) is an open source
ticketing system for managing natural disasters and emergency response.
It allows an operations center to:

- Create and manage **rescue teams** with specializations
- Create and manage **equipment** with specific characteristics
- Create and manage **incidents** of varying severity
- **Assign** teams and equipment to incidents
- View incident areas, vehicle and team positions on a **live map**
- Access all functionality via **REST API**
- Guarantee an **immutable audit log** of every operation

This is a critical system: correctness, security, and traceability are not optional.

---

## 2. Technology Stack — Irrevocable Decisions

| Layer | Technology | Notes |
|---|---|---|
| Backend | **Python + FastAPI** | async, strong typing |
| ORM | **SQLAlchemy 2.x** (async) | never string-concatenated queries |
| Validation | **Pydantic v2** | every input/output typed |
| Database | **PostgreSQL 16 + PostGIS 3.4** | native geographic geometries |
| Migrations | **Alembic** | never manual schema changes |
| Auth | **JWT** (PyJWT) + **OAuth2** | refresh token with rotation |
| Container | **Docker** (multi-stage build) | final image non-root, minimal |
| Reverse proxy | **Caddy** or **Nginx** | TLS termination, rate limiting, CORS |
| Real-time | **WebSocket** (FastAPI native) | live map updates |
| CI/CD | **GitHub Actions** | fully automated pipeline |
| Registry | **ghcr.io** | tagged with commit SHA, never just `latest` |

---

## 3. Repository Structure

```
disaster-response-platform/
├── AGENTS.md                        ← this file
├── README.md
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                   ← main pipeline
│   │   ├── dependency-update.yml    ← Dependabot
│   │   └── release.yml              ← automatic changelog
│   ├── CODEOWNERS
│   └── pull_request_template.md
├── backend/
│   ├── app/
│   │   ├── main.py                  ← FastAPI entrypoint
│   │   ├── api/
│   │   │   └── v1/                  ← ALWAYS versioned
│   │   │       ├── incidents.py
│   │   │       ├── teams.py
│   │   │       ├── equipment.py
│   │   │       ├── assignments.py
│   │   │       ├── map.py
│   │   │       ├── audit.py
│   │   │       └── auth.py
│   │   ├── core/
│   │   │   ├── config.py            ← settings from env vars (pydantic-settings)
│   │   │   ├── security.py          ← JWT, hashing, RBAC
│   │   │   ├── database.py          ← async engine and sessions
│   │   │   └── exceptions.py        ← domain exceptions
│   │   ├── models/                  ← SQLAlchemy ORM models
│   │   │   ├── incident.py
│   │   │   ├── team.py
│   │   │   ├── equipment.py
│   │   │   ├── assignment.py
│   │   │   ├── user.py
│   │   │   └── audit_log.py
│   │   ├── schemas/                 ← Pydantic schemas (separate input/output)
│   │   │   ├── incident.py          ← IncidentCreate, IncidentRead, IncidentUpdate
│   │   │   ├── team.py
│   │   │   ├── equipment.py
│   │   │   ├── assignment.py
│   │   │   └── common.py            ← PaginatedResponse, GeoJSON types
│   │   ├── services/                ← business logic (decoupled from routers)
│   │   │   ├── incident_service.py
│   │   │   ├── team_service.py
│   │   │   ├── equipment_service.py
│   │   │   └── assignment_service.py
│   │   ├── repositories/            ← DB access (Repository pattern)
│   │   │   ├── base.py
│   │   │   ├── incident_repository.py
│   │   │   └── ...
│   │   ├── audit/
│   │   │   ├── service.py           ← AuditService with hash chain
│   │   │   └── chain.py             ← SHA-256 hash chain verification
│   │   └── websocket/
│   │       └── manager.py           ← ConnectionManager for broadcast
│   ├── migrations/
│   │   ├── env.py
│   │   └── versions/
│   ├── tests/
│   │   ├── conftest.py              ← global fixtures
│   │   ├── unit/
│   │   │   ├── test_services/
│   │   │   ├── test_schemas/
│   │   │   ├── test_audit/
│   │   │   └── test_utils/
│   │   ├── integration/
│   │   │   ├── test_api/
│   │   │   ├── test_db/
│   │   │   └── test_websocket/
│   │   └── e2e/
│   │       ├── test_incident_lifecycle.py
│   │       ├── test_assignment_flow.py
│   │       └── test_audit_integrity.py
│   ├── Dockerfile
│   ├── pyproject.toml               ← centralized config (ruff, mypy, pytest, coverage)
│   ├── requirements.txt             ← pinned runtime dependencies with hashes (uv)
│   └── requirements-dev.txt         ← pinned runtime + dev dependencies with hashes (uv)
├── infrastructure/
│   ├── docker/
│   │   ├── docker-compose.yml       ← local development
│   │   ├── docker-compose.test.yml  ← full stack for E2E tests
│   │   └── docker-compose.prod.yml  ← production
│   └── nginx/
│       └── nginx.conf
├── scripts/
│   ├── wait-for-db.sh
│   └── verify-audit-chain.sh
└── docs/
    └── openapi/                     ← auto-generated by FastAPI
```

---

## 4. Layered Architecture — Strict Rules

The pattern is **Router → Service → Repository**. Never deviate.

```
HTTP Request
    │
    ▼
Router (api/v1/)           ← HTTP only: parsing, auth check, response
    │
    ▼
Service (services/)        ← ALL business logic lives here
    │                      ← always calls AuditService before commit
    ▼
Repository (repositories/) ← DB access only, zero business logic
    │
    ▼
SQLAlchemy + PostgreSQL
```

**Rules:**
- Routers never contain business logic
- Services never import from `fastapi` (Request, Response, etc.)
- Repositories never call services
- AuditService is called **within the same transaction** as the main operation
- Never raw SQL with string concatenation — always SQLAlchemy ORM or `text()` with bound parameters

---

## 5. Data Model — Constraints

### Required fields on every model

```python
# Every model MUST have:
id: UUID              # generated client-side (UUID v7) or server-side
created_at: datetime  # UTC, non-nullable
updated_at: datetime  # UTC, updated automatically
created_by: UUID      # FK → User
deleted_at: datetime  # nullable — ALWAYS soft delete, never physical DELETE
```

### Geographic geometries

- Always use SRID 4326 (WGS84 — standard GPS coordinates)
- Incidents have `affected_area: Geometry(Polygon, 4326)`
- Teams and equipment have `current_location: Geometry(Point, 4326)`
- Validate geometries **before** insert with PostGIS `ST_IsValid()`

### JSONB for flexible data

- `Team.specializations` → JSONB string array
- `Equipment.characteristics` → JSONB dict
- Never add columns for each new specialization or characteristic type

### Audit Log — separate table, never writable

```python
class AuditLog(Base):
    id: UUID
    timestamp: datetime    # UTC
    actor_id: UUID         # who performed the operation
    action: str            # e.g. "INCIDENT_CREATED"
    resource_type: str     # e.g. "incident"
    resource_id: UUID
    payload: JSONB         # complete data snapshot
    prev_hash: str         # SHA-256 of the previous record
    current_hash: str      # SHA-256 of this record
```

The application DB user must NOT have UPDATE/DELETE permissions on `audit_log`.
This must be enforced via PostgreSQL grants in the migration.

### Database roles

| Role | Env var | Privileges |
|---|---|---|
| migrator | `MIGRATION_DATABASE_URL` | Owns the database and schema; runs Alembic (DDL) |
| app | `DATABASE_URL` | `SELECT`, `INSERT`, `UPDATE` only — no `DELETE`/`TRUNCATE` (soft delete) |
| audit | `AUDIT_DATABASE_URL` | Read-only on `audit_log`, for chain verification |

Default privileges for `app` are set when the roles are created; per-table
restrictions (e.g. `audit_log`) and `audit` grants belong in the migration that
creates the table. Local roles are created by `infrastructure/docker/postgres/20-maia-roles.sh`.

---

## 6. API Design — Conventions

- **Always** use the `/api/v1/` prefix — versioning is mandatory
- **Soft delete** exposed as HTTP `DELETE` but implemented with `deleted_at`
- **PATCH** for partial updates, never PUT on critical resources
- **Cursor-based pagination** always, never offset on growing datasets
- **Assignments** via dedicated endpoint: `POST /api/v1/incidents/{id}/assign`
- **Live map** via: `GET /api/v1/map/live` (GeoJSON snapshot) + `WS /api/v1/ws/map`
- **Audit trail** exposed read-only: `GET /api/v1/audit/{resource_type}/{id}`
- **Chain integrity check**: `GET /api/v1/audit/verify`

### HTTP Status Codes

| Situation | Code |
|---|---|
| Successful creation | 201 |
| Successful operation with no body | 204 |
| Resource not found | 404 |
| Insufficient permissions | 403 |
| Missing or invalid token | 401 |
| Invalid input | 422 (FastAPI default) |
| State conflict | 409 |

---

## 7. Security — Non-Negotiable Rules

### Authentication and authorization

- Roles: `OPERATOR` (full access), `VIEWER` (read-only), `API_CLIENT` (token for integrations)
- JWT expiry: **15 minutes**; refresh token with rotation, expiry **7 days**
- Every endpoint decorated with the minimum required permission
- Passwords: **argon2** (never bcrypt, never MD5/SHA1)
- No hardcoded secrets ever — everything from environment variables

### Container

- Multi-stage build: build phase separate from runtime
- Final image: **distroless** or minimal **alpine**
- Non-root user mandatory (`USER 1001`)
- Read-only filesystem where possible
- `--no-new-privileges` flag in compose/run
- No secrets in the image or Docker ARGs

### HTTP Headers (managed by reverse proxy)

```
Strict-Transport-Security: max-age=63072000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Content-Security-Policy: default-src 'self'
```

---

## 8. Testing — Pipeline Rules

### Minimum coverage: 95% (blocking)

The pipeline stops if coverage drops below 95%. No exceptions.

### pytest/coverage configuration in pyproject.toml

```toml
[tool.coverage.run]
branch = true    # measure branch coverage, not just line coverage
omit = [
    "app/main.py",
    "migrations/*",
    "tests/*",
]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",         # use sparingly, always with a comment
    "if TYPE_CHECKING:",
    "raise NotImplementedError",
    "if __name__ == .__main__.:",
]
```

### Test structure

**Unit tests** (`tests/unit/`):
- Zero external dependencies — everything mocked with `unittest.mock.AsyncMock`
- Test single functions/classes/services in isolation
- Use `@pytest.mark.parametrize` to cover all branches
- Must be fast (< 1s each)

**Integration tests** (`tests/integration/`):
- **Real PostGIS** database in a Docker container (same version as production)
- Every test runs inside a **rolled-back transaction** (`autouse=True` fixture)
- Test real API endpoints, geospatial queries, WebSocket connections
- Test application user has the same permissions as the production one

**E2E tests** (`tests/e2e/`):
- Full stack via `docker-compose.test.yml`
- Test complete business flows (incident creation → assignment → resolution)
- Verify audit hash chain integrity
- Verify audit log is immutable even with direct DB access

### Mandatory fixture pattern

```python
# conftest.py — always follow this pattern
@pytest.fixture(autouse=True)
async def db_transaction(engine):
    async with engine.connect() as conn:
        await conn.begin()
        yield conn
        await conn.rollback()  # ALWAYS rollback — no leftover data between tests
```

---

## 9. CI/CD Pipeline — GitHub Actions

### Stages and order (each stage blocks the next on failure)

```
1. lint           → ruff, mypy, black --check, isort --check, hadolint
2. unit-test      ┐
                  ├── parallel → coverage merge → coverage-gate (95%)
3. integration    ┘
4. build          → Docker image with SHA tag, SBOM, SLSA provenance
5. scan           → Trivy (CVE CRITICAL/HIGH = blocking), pip-audit, Semgrep
6. e2e-test       → full Docker Compose stack
7. deploy         → manual approval required (environment: production)
```

### Pipeline rules

- Unit and integration tests run **in parallel** to reduce total time
- The **coverage gate** waits for both and merges reports before deciding
- **Trivy** blocks the pipeline on CRITICAL or HIGH CVEs in the image
- **Semgrep** uses rulesets: `p/python`, `p/jwt`, `p/sql-injection`, `p/secrets`
- **pip-audit** checks CVEs in Python dependencies
- Deployment to `production` requires manual approval in GitHub Environments
- Images are tagged `ghcr.io/{repo}:{git-sha}` — NEVER just `latest` in production
- SBOM and SLSA provenance generated on every build

### Branch strategy

- `main` → deployable code, protected (no direct push, PR required, CI green, 1 review)
- `develop` → continuous integration
- `feature/*`, `fix/*` → working branches
- `hotfix/*` → direct merge to main via PR in emergencies
- Linear history required on main (squash or rebase, no merge commits)

---

## 10. Code Conventions

### Python

- **ruff** for linting (replaces flake8, isort, pyupgrade)
- **mypy** in strict mode — no implicit `Any`
- **black** for formatting — no custom configuration
- Type hints required on every public function
- Docstrings required on every class and non-trivial public function
- f-strings for interpolation, never `%` or `.format()`
- `async/await` everywhere — never blocking calls on the main thread

### Naming

- Files and modules: `snake_case`
- Classes: `PascalCase`
- Constants: `UPPER_SNAKE_CASE`
- Variables and functions: `snake_case`
- URL endpoints: `kebab-case` (e.g. `/api/v1/incident-assignments`)
- JSON fields in API responses: `snake_case`

### Error handling

- Never `except Exception` without explicit re-raise or logging
- Domain exceptions defined in `core/exceptions.py`
- Routers map domain exceptions to HTTP responses via dedicated handlers
- No tracebacks exposed in API responses in production

---

## 11. Environment Variables — Configuration

All sensitive and environment-specific configuration comes from env vars.
No hardcoded values, no `.env` in the repository (only `.env.example`).

```bash
# Database
DATABASE_URL=postgresql+asyncpg://user:pass@host:5432/dbname
MIGRATION_DATABASE_URL=postgresql+asyncpg://migrator:pass@host:5432/dbname
AUDIT_DATABASE_URL=postgresql+asyncpg://audit_user:pass@host:5432/auditdb

# Auth
JWT_SECRET_KEY=              # min 32 bytes, generate with: openssl rand -hex 32
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7

# Application
ENVIRONMENT=production       # development | testing | production
LOG_LEVEL=INFO
CORS_ORIGINS=                # comma-separated list

# Security
RATE_LIMIT_PER_MINUTE=60
```

---

## 12. Architectural Decisions — Not Open for Discussion

1. **Always soft delete** — in an emergency system, nothing is ever permanently deleted
2. **UUID v7 as IDs** — time-sortable, client-side generatable for idempotency
3. **Audit log in the same transaction** as the main operation — atomicity guaranteed
4. **PostGIS for geometries** — never separate lat/lon float columns
5. **Cursor-based pagination** — never offset on tables that grow during emergencies
6. **API versioning in the URL** — `/api/v1/` from day one, non-negotiable
7. **Image tagged with commit SHA** — complete traceability of what is running in production
8. **Branch coverage** (not just line coverage) — `branch = true` in coverage config
9. **Blocking security scan** — critical CVEs block deployment, they do not merely warn
10. **No secrets in the Docker image** — everything from env vars or a secrets manager

---

## 13. How to Add a New Feature

Always follow this order:

1. Add/modify the **SQLAlchemy model** in `models/`
2. Create the **Alembic migration** (`alembic revision --autogenerate`)
3. Define **Pydantic schemas** (Create, Read, Update) in `schemas/`
4. Implement the **repository** in `repositories/`
5. Implement the **service** in `services/` (including the AuditService call)
6. Implement the **router** in `api/v1/`
7. Register the router in `main.py`
8. Write **unit tests** for the service (mock the repository)
9. Write **integration tests** for the endpoint (real DB)
10. Verify that **coverage does not drop below 95%**
11. Open a PR — the CI pipeline must be fully green

---

## 14. References

- Initial architecture discussion: see `docs/architecture-decisions.md`
- OpenAPI spec: auto-generated by FastAPI at `/docs` and `/redoc`
- Changelog: auto-generated by `release.yml` via Conventional Commits
