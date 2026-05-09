---
description: 'REST API design conventions: resource naming, HTTP methods, pagination, error responses, versioning, OpenAPI. USE FOR: designing APIs, writing endpoints, request/response contracts, API documentation.'
---

# API Design

## Resource Naming

- **Plural nouns** for collections: `/users`, `/appointments`, `/organizations`
- **Singular identifiers** for items: `/users/{userId}`, `/appointments/{appointmentId}`
- **Nested resources** for clear ownership: `/organizations/{orgId}/members`
- **No verbs in URLs** — use HTTP methods instead: `POST /users` not `POST /createUser`
- **Kebab-case** for multi-word: `/user-preferences`, not `/userPreferences`
- **Max 3 levels of nesting** — beyond that, use query params or top-level with filters

## HTTP Methods

| Method   | Purpose                    | Idempotent | Request Body | Success Code |
| -------- | -------------------------- | ---------- | ------------ | ------------ |
| `GET`    | Retrieve resource(s)       | Yes        | No           | `200`        |
| `POST`   | Create a resource          | No         | Yes          | `201`        |
| `PUT`    | Replace a resource entirely| Yes        | Yes          | `200`        |
| `PATCH`  | Partial update             | No*        | Yes          | `200`        |
| `DELETE` | Remove a resource          | Yes        | No           | `204`        |

*`PATCH` can be made idempotent with proper implementation.

## Status Codes

### Success
| Code  | Meaning         | Use When                                     |
| ----- | --------------- | -------------------------------------------- |
| `200` | OK              | Successful GET, PUT, PATCH                   |
| `201` | Created         | Successful POST that created a resource      |
| `204` | No Content      | Successful DELETE, or PUT/PATCH with no body  |

### Client Errors
| Code  | Meaning             | Use When                                           |
| ----- | ------------------- | -------------------------------------------------- |
| `400` | Bad Request         | Invalid request body, missing required fields      |
| `401` | Unauthorized        | Missing or invalid authentication                  |
| `403` | Forbidden           | Authenticated but not authorized for this resource |
| `404` | Not Found           | Resource doesn't exist                             |
| `409` | Conflict            | Duplicate resource, version conflict               |
| `422` | Unprocessable       | Valid JSON but business rule violation              |
| `429` | Too Many Requests   | Rate limit exceeded                                |

### Server Errors
| Code  | Meaning               | Use When                            |
| ----- | --------------------- | ----------------------------------- |
| `500` | Internal Server Error | Unexpected server failure           |
| `502` | Bad Gateway           | Upstream service failure            |
| `503` | Service Unavailable   | Maintenance or temporary overload   |

## Error Response Format

All errors use a consistent structure:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The request body is invalid.",
    "details": [
      {
        "field": "email",
        "message": "Must be a valid email address.",
        "value": "not-an-email"
      }
    ]
  }
}
```

### Rules
- `code` is a machine-readable string (UPPER_SNAKE_CASE)
- `message` is a human-readable summary (safe to display to end users)
- `details` is optional — used for field-level validation errors
- **Never expose stack traces, SQL, or internal paths in production**
- Use the same error shape for all error responses (400, 401, 403, 404, 500)

## Pagination

### Cursor-Based (preferred)

```
GET /users?limit=20&cursor=eyJpZCI6MTAwfQ
```

Response:
```json
{
  "data": [...],
  "meta": {
    "limit": 20,
    "hasMore": true,
    "nextCursor": "eyJpZCI6MTIwfQ"
  }
}
```

- Use cursor-based for real-time data, large datasets, or when items can be inserted/deleted
- Cursor is an opaque, base64-encoded value (not a page number)
- Always include `hasMore` so the client knows when to stop

### Offset-Based (simple cases)

```
GET /users?limit=20&offset=40
```

Response:
```json
{
  "data": [...],
  "meta": {
    "limit": 20,
    "offset": 40,
    "total": 150
  }
}
```

- Use offset-based only for small, stable datasets (admin panels, reports)
- Breaks when items are inserted/deleted between pages

## Response Envelope

Wrap responses consistently:

```json
{
  "data": { ... }
}
```

For collections:
```json
{
  "data": [...],
  "meta": {
    "limit": 20,
    "hasMore": true,
    "nextCursor": "..."
  }
}
```

## Filtering & Sorting

```
GET /appointments?status=confirmed&dateFrom=2024-01-01&sort=-createdAt
```

- Filter params match field names
- Sort with `-` prefix for descending: `sort=-createdAt` (desc), `sort=name` (asc)
- Multiple sort fields: `sort=-priority,createdAt`
- Date filters use ISO 8601: `2024-01-15T09:30:00Z`

## Versioning

Prefer **URL path versioning**:

```
/api/v1/users
/api/v2/users
```

- Increment the version only for **breaking changes**
- Adding new fields to responses is NOT a breaking change
- Removing fields, changing field types, or changing URL structure IS a breaking change
- Support at most 2 versions simultaneously (current + previous)
- Deprecation: add `Sunset` header with date, document migration path

## Request Validation

Validate at the API boundary:

```typescript
// ✅ Validate and parse at the handler level
const body = CreateUserSchema.parse(req.body);  // zod, joi, class-validator

// ❌ Don't scatter validation across service layers
```

### Rules
- Required fields: fail fast with `400` and list all missing fields
- Type coercion: accept `"123"` as number only if explicitly configured
- String fields: trim whitespace, check max length
- IDs: validate format (UUID, ObjectId, etc.) before querying
- Dates: accept ISO 8601 only
- Enums: validate against allowed values, return the allowed list in error

## Authentication & Authorization

### Headers
```
Authorization: Bearer {jwt_token}
```

### Patterns
- **Authentication** (who are you?) → middleware/guard, returns `401` if missing/invalid
- **Authorization** (can you do this?) → per-route or per-resource check, returns `403`
- Use middleware/guards for auth — don't repeat checks in every handler
- Rate limit by authenticated user, not just IP

## OpenAPI / Swagger

Document APIs with OpenAPI 3.x:

```yaml
openapi: 3.0.3
info:
  title: My API
  version: 1.0.0
paths:
  /users:
    get:
      summary: List users
      parameters:
        - name: limit
          in: query
          schema:
            type: integer
            default: 20
            maximum: 100
      responses:
        '200':
          description: List of users
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserListResponse'
```

### Rules
- Keep the spec in sync with the implementation — generate from code if possible
- Document all error responses, not just happy paths
- Include example values for request/response bodies
- Use `$ref` for shared schemas — don't duplicate
