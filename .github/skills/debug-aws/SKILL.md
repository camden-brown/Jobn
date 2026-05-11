---
name: debug-aws
description: 'AWS resource mappings and debugging procedures for a specific project. Provides log group names, DynamoDB table schemas, and investigation playbooks. Use when: debugging with CloudWatch, querying DynamoDB for investigation, mapping errors to AWS resources.'
---

# AWS Debug Context

This skill provides project-specific AWS resource mappings for the `@debugger` agent. Copy this skill into your project's `.github/skills/debug-aws/` directory and fill in the resource details.

## Setup

1. Copy this entire `debug-aws/` folder into your project's `.github/skills/` directory
2. Edit this file and `./references/resources.md` with your project's AWS details
3. Configure MCP servers in your project's `.vscode/mcp.json` (see template in Jobn's `templates/mcp.json.tmpl`)

## Resource Reference

See [AWS Resources](./references/resources.md) for the full mapping of:

- CloudWatch log groups per service
- DynamoDB table names, key schemas, and GSI patterns
- Common error patterns and where to look

## Investigation Playbooks

### Authentication / Authorization Errors

1. Check the auth service logs: use the log group from resources.md
2. Search for the user ID or session token
3. Look for `401`, `403`, or token expiration errors
4. Check the users/sessions table for stale or missing records

### Data Not Found / Stale Data

1. Query the relevant DynamoDB table by primary key
2. Check if the record exists and if TTL has expired
3. Check GSIs for consistency — the record may exist but not be indexed
4. Check CloudWatch for write failures (conditional check failures, throttling)

### 5xx / Unhandled Errors

1. Search CloudWatch for the error message or stack trace
2. Filter by request ID if available
3. Check for Lambda timeouts, OOM errors, or cold start issues
4. Check SQS DLQ for failed async processing

### Performance / Timeout Issues

1. Check CloudWatch metrics: Lambda duration, DynamoDB consumed capacity
2. Look for throttling (`ProvisionedThroughputExceededException`)
3. Check for N+1 query patterns in the logs (many sequential DynamoDB calls)
4. Look at X-Ray traces if available
