# JIRA Field Mappings

Reference for creating tickets via JIRA REST API v3.

## API Endpoint

```
POST https://{instance}.atlassian.net/rest/api/3/issue
```

## Authentication

Basic auth: `base64(email:api_token)`

```
Authorization: Basic <base64>
Content-Type: application/json
```

## Standard Fields

| Field      | API Path                    | Example                       |
| ---------- | --------------------------- | ----------------------------- |
| Project    | `fields.project.key`        | `"PROJ"`                      |
| Summary    | `fields.summary`            | `"Add user validation"`       |
| Issue Type | `fields.issuetype.name`     | `"Story"`, `"Bug"`, `"Task"`  |
| Priority   | `fields.priority.name`      | `"High"`, `"Medium"`, `"Low"` |
| Labels     | `fields.labels`             | `["backend", "api"]`          |
| Assignee   | `fields.assignee.accountId` | `"5f..."`                     |

## Description (ADF Format)

JIRA v3 uses Atlassian Document Format (ADF), not plain text:

```json
{
  "fields": {
    "description": {
      "type": "doc",
      "version": 1,
      "content": [
        {
          "type": "paragraph",
          "content": [{ "type": "text", "text": "Description text here" }]
        }
      ]
    }
  }
}
```

## Custom Fields

| Field        | Typical Custom Field ID | Notes                                                                               |
| ------------ | ----------------------- | ----------------------------------------------------------------------------------- |
| Story Points | `customfield_10016`     | Varies per instance — check `push.field_mappings.jira.story_points_field` in config |
| Sprint       | `customfield_10020`     | Sprint ID (integer), not name                                                       |
| Epic Link    | `customfield_10014`     | Epic issue key                                                                      |

**Finding custom field IDs**: `GET /rest/api/3/field` returns all fields with their IDs.

## Acceptance Criteria

JIRA has no standard acceptance criteria field. The convention in `push-tickets.sh` is to append acceptance criteria to the description body using ADF headings.

## Config Field Mappings

From `config.yaml` → `push.field_mappings.jira`:

```yaml
push:
  field_mappings:
    jira:
      story_points_field: 'customfield_10016'
```

## Response

A successful `POST /rest/api/3/issue` returns:

```json
{
  "id": "10001",
  "key": "PROJ-123",
  "self": "https://instance.atlassian.net/rest/api/3/issue/10001"
}
```

The browse URL is: `https://{instance}.atlassian.net/browse/{key}`

## Common Errors

| Status | Cause                                                                |
| ------ | -------------------------------------------------------------------- |
| 400    | Invalid field values (wrong custom field ID, missing required field) |
| 401    | Bad credentials (check email + API token)                            |
| 403    | No permission to create issues in the target project                 |
| 404    | Project key doesn't exist                                            |
