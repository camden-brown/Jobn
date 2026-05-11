# AWS Resources

Fill in your project's AWS resource details below. The `@debugger` agent uses this as a lookup table when investigating issues.

Define each environment as a separate section. The agent will ask which environment to debug and use only that section's resources.

---

## Environments

| Environment | AWS Account    | AWS Profile          | Region      | Description    |
| ----------- | -------------- | -------------------- | ----------- | -------------- |
| qa          | `111111111111` | `my-project-qa`      | `us-east-1` | QA / testing   |
| staging     | `222222222222` | `my-project-staging` | `us-east-1` | Pre-production |
| prod        | `333333333333` | `my-project-prod`    | `us-east-1` | Production     |

### Naming Convention

If your resources follow a predictable naming pattern, document it here so the agent can derive names for any environment:

```yaml
# Pattern: {env}-{project}-{service}
# Examples:
#   qa-myapp-users       (DynamoDB table)
#   /aws/lambda/qa-myapp-auth  (CloudWatch log group)
#   qa-myapp-uploads     (S3 bucket)
prefix_pattern: '{env}-myapp'
```

If your resources do NOT follow a convention, list each environment's resources explicitly below.

---

## QA

### CloudWatch Log Groups

| Service       | Log Group                      | Description                     |
| ------------- | ------------------------------ | ------------------------------- |
| API Gateway   | `/aws/apigateway/qa-myapp-api` | API request/response logs       |
| Auth Lambda   | `/aws/lambda/qa-myapp-auth`    | Authentication handler          |
| Core Lambda   | `/aws/lambda/qa-myapp-core`    | Main business logic             |
| Worker Lambda | `/aws/lambda/qa-myapp-worker`  | Async processing (SQS consumer) |

### DynamoDB Tables

```yaml
table_name: 'qa-myapp-main'
partition_key: 'PK'
sort_key: 'SK'
```

### SQS Queues

| Queue                 | DLQ                       | Purpose                |
| --------------------- | ------------------------- | ---------------------- |
| `qa-myapp-processing` | `qa-myapp-processing-dlq` | Async order processing |

### S3 Buckets

| Bucket             | Purpose           |
| ------------------ | ----------------- |
| `qa-myapp-uploads` | User file uploads |

---

## Staging

### CloudWatch Log Groups

| Service       | Log Group                           | Description                     |
| ------------- | ----------------------------------- | ------------------------------- |
| API Gateway   | `/aws/apigateway/staging-myapp-api` | API request/response logs       |
| Auth Lambda   | `/aws/lambda/staging-myapp-auth`    | Authentication handler          |
| Core Lambda   | `/aws/lambda/staging-myapp-core`    | Main business logic             |
| Worker Lambda | `/aws/lambda/staging-myapp-worker`  | Async processing (SQS consumer) |

### DynamoDB Tables

```yaml
table_name: 'staging-myapp-main'
partition_key: 'PK'
sort_key: 'SK'
```

### SQS Queues

| Queue                      | DLQ                            | Purpose                |
| -------------------------- | ------------------------------ | ---------------------- |
| `staging-myapp-processing` | `staging-myapp-processing-dlq` | Async order processing |

### S3 Buckets

| Bucket                  | Purpose           |
| ----------------------- | ----------------- |
| `staging-myapp-uploads` | User file uploads |

---

## Prod

### CloudWatch Log Groups

| Service       | Log Group                        | Description                     |
| ------------- | -------------------------------- | ------------------------------- |
| API Gateway   | `/aws/apigateway/prod-myapp-api` | API request/response logs       |
| Auth Lambda   | `/aws/lambda/prod-myapp-auth`    | Authentication handler          |
| Core Lambda   | `/aws/lambda/prod-myapp-core`    | Main business logic             |
| Worker Lambda | `/aws/lambda/prod-myapp-worker`  | Async processing (SQS consumer) |

### DynamoDB Tables

```yaml
table_name: 'prod-myapp-main'
partition_key: 'PK'
sort_key: 'SK'
```

### SQS Queues

| Queue                   | DLQ                         | Purpose                |
| ----------------------- | --------------------------- | ---------------------- |
| `prod-myapp-processing` | `prod-myapp-processing-dlq` | Async order processing |

### S3 Buckets

| Bucket               | Purpose           |
| -------------------- | ----------------- |
| `prod-myapp-uploads` | User file uploads |

---

## Shared Schema

Key schemas and entity patterns are the same across all environments — only the table/resource names change.

### DynamoDB Key Patterns

```yaml
partition_key: 'PK' # e.g., USER#123, ORDER#456
sort_key: 'SK' # e.g., PROFILE, ORDER#timestamp#id

entities:
  user_profile:
    PK: 'USER#{userId}'
    SK: 'PROFILE'
  user_orders:
    PK: 'USER#{userId}'
    SK: 'ORDER#{timestamp}#{orderId}'
  order_detail:
    PK: 'ORDER#{orderId}'
    SK: 'DETAIL'
```

### GSIs

```yaml
GSI1:
  name: 'GSI1'
  partition_key: 'GSI1PK' # e.g., STATUS#active
  sort_key: 'GSI1SK' # e.g., timestamp
  use_case: 'Query orders by status'

GSI2:
  name: 'GSI2'
  partition_key: 'GSI2PK'
  sort_key: 'GSI2SK'
  use_case: 'Query by email for login lookup'
```

## Common Error Patterns

| Error Message / Code              | Likely Service       | What to Check                                            |
| --------------------------------- | -------------------- | -------------------------------------------------------- |
| `ConditionalCheckFailedException` | DynamoDB             | Optimistic lock conflict — check concurrent writes       |
| `Task timed out after X seconds`  | Lambda               | Function timeout — check cold starts, downstream latency |
| `AccessDeniedException`           | IAM                  | Missing permission — check Lambda execution role         |
| `TooManyRequestsException`        | API Gateway / Lambda | Throttling — check concurrency limits                    |
| `ValidationException`             | DynamoDB             | Bad key format — check PK/SK patterns above              |
