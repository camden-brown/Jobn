---
description: 'AWS service patterns for DynamoDB, SQS, CloudWatch, S3, CloudFront, and Elasticsearch. USE FOR: implementing AWS integrations, data modeling, infrastructure patterns.'
---

# AWS Best Practices

## DynamoDB

### Single-Table Design

- Prefer single-table design — multiple entity types in one table, differentiated by partition key patterns
- Use composite keys: `PK: USER#123`, `SK: ORDER#2024-01-15#456`
- Design access patterns first, then model the table to serve them

### Key Design Patterns

| Pattern      | PK           | SK                          | Use Case            |
| ------------ | ------------ | --------------------------- | ------------------- |
| Single item  | `USER#123`   | `PROFILE`                   | User profile lookup |
| One-to-many  | `USER#123`   | `ORDER#timestamp#id`        | User's orders       |
| Many-to-many | `TEAM#456`   | `MEMBER#123` + inverted GSI | Team membership     |
| Time-series  | `SENSOR#789` | `2024-01-15T10:30:00Z`      | IoT readings        |

### GSI (Global Secondary Index) Patterns

- Use GSIs for alternate access patterns — design them like separate tables
- GSI key overloading: reuse generic attribute names (`GSI1PK`, `GSI1SK`) across entity types
- Sparse indexes: only items with the GSI key attributes appear in the index
- Project only needed attributes to minimize GSI cost

### Best Practices

- Use `ExpressionAttributeNames` for reserved words
- Use conditional writes (`ConditionExpression`) for optimistic locking
- Batch operations: `BatchGetItem` (max 100), `BatchWriteItem` (max 25)
- Use TTL for automatic expiration (e.g., session tokens, temp data)
- Avoid hot partitions — distribute writes across partition keys

## SQS

### Message Handling

- Always use **visibility timeout** appropriate for your processing time (default: 30s)
- Implement **idempotent consumers** — messages can be delivered more than once
- Use **Dead Letter Queues (DLQ)** with `maxReceiveCount` of 3–5 for failed messages
- Delete messages only after successful processing
- Use `MessageGroupId` for FIFO queues when ordering matters within a group

### Patterns

- **Fan-out**: SNS topic → multiple SQS queues (one per consumer type)
- **Batch processing**: `MaxNumberOfMessages` up to 10, process in parallel
- **Backpressure**: monitor `ApproximateNumberOfMessagesVisible` in CloudWatch

## CloudWatch

### Metrics & Alarms

- Use custom metrics for business KPIs (e.g., `OrdersPlaced`, `PaymentFailures`)
- Use dimensions to slice metrics: `{ ServiceName: 'auth', Environment: 'prod' }`
- Set alarms with appropriate thresholds:
  - **Error rate**: alarm when > 1% of requests are errors
  - **Latency**: P99 latency > acceptable threshold
  - **Queue depth**: `ApproximateNumberOfMessagesVisible` growing over time
- Use `MetricMath` for computed metrics (error rate = errors / total \* 100)

### Logging

- Use structured JSON logging — not plaintext
- Include: `requestId`, `userId`, `action`, `duration`, `statusCode`
- Use log levels appropriately: `ERROR` for failures, `WARN` for degraded, `INFO` for business events, `DEBUG` for development
- Set log retention policies to control costs

## S3

- Use meaningful key prefixes: `uploads/{userId}/{date}/{filename}`
- Enable versioning for critical buckets
- Use presigned URLs for client-side uploads/downloads — never expose bucket credentials
- Set lifecycle rules for cost optimization (transition to IA/Glacier, expiration)
- Enable server-side encryption (SSE-S3 or SSE-KMS)
- Block public access by default — use CloudFront for public content

## CloudFront

- Use CloudFront as the CDN in front of S3 and API Gateway
- Set cache behaviors per path pattern: `/api/*` (no cache), `/assets/*` (long cache)
- Use Origin Access Control (OAC) — not Origin Access Identity (OAI, legacy)
- Invalidation paths: `/index.html` for SPA deployments, `/*` sparingly (costs per path)
- Use custom error responses to serve `index.html` for SPA 404s
- Set `Cache-Control` headers at the origin — don't rely solely on CloudFront TTL settings

## Elasticsearch / OpenSearch

- Design index mappings upfront — dynamic mapping causes type conflicts
- Use aliases for zero-downtime reindexing
- Optimize queries: prefer `filter` context over `query` context for exact matches (cacheable)
- Use bulk API for indexing multiple documents
- Set `refresh_interval` to `30s` for write-heavy workloads (not the default `1s`)
- Monitor cluster health: `_cluster/health`, shard count, disk usage

## General AWS Patterns

- **Least privilege IAM** — grant only the permissions needed, never use `*` for actions or resources
- **Environment separation** — use separate AWS accounts or at minimum separate resource naming: `{service}-{env}`
- **Retry with backoff** — use exponential backoff with jitter for all AWS API calls
- **Infrastructure as Code** — use CDK (see CDK skill) for all resource provisioning
- **Tagging** — tag all resources with at minimum: `Environment`, `Service`, `Owner`, `CostCenter`
