---
description: 'AWS CDK patterns: construct levels, stack organization, cross-stack references, testing, asset bundling. USE FOR: writing CDK infrastructure code, stack design, CDK testing.'
---

# AWS CDK Best Practices

## Construct Levels

| Level         | What It Is                                      | When to Use                                      |
| ------------- | ----------------------------------------------- | ------------------------------------------------ |
| L1 (`Cfn*`)   | Direct CloudFormation mapping                   | Only when L2/L3 doesn't exist or lacks a feature |
| L2            | Opinionated AWS resource with sensible defaults | Default choice for most resources                |
| L3 (Patterns) | Multi-resource compositions                     | Complex patterns (API + Lambda + DynamoDB)       |

**Prefer L2 constructs** — they handle IAM, encryption, logging defaults for you.

## Stack Organization

```
infra/
├── bin/
│   └── app.ts              # CDK app entry — instantiates stacks
├── lib/
│   ├── stacks/
│   │   ├── network-stack.ts      # VPC, subnets, security groups
│   │   ├── data-stack.ts         # DynamoDB, S3, ElastiCache
│   │   ├── api-stack.ts          # API Gateway, Lambda, ALB
│   │   └── monitoring-stack.ts   # CloudWatch, alarms, dashboards
│   └── constructs/
│       ├── api-lambda.ts         # Reusable Lambda + API GW construct
│       └── monitored-queue.ts    # SQS + DLQ + CloudWatch alarm
├── test/
│   ├── stacks/
│   └── constructs/
└── cdk.json
```

### Stack Boundaries

- **Separate stacks by lifecycle** — resources that change together belong together
- **Data stack** should rarely change (DynamoDB, S3) — separate from compute (Lambda, ECS)
- **Network stack** is foundational — other stacks depend on it
- Keep stacks small enough to deploy in < 5 minutes
- Max ~50 resources per stack (CloudFormation limit is 500, but deploys get slow)

## Cross-Stack References

```typescript
// data-stack.ts
export class DataStack extends cdk.Stack {
  public readonly table: dynamodb.Table;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);
    this.table = new dynamodb.Table(this, 'MainTable', { ... });
  }
}

// api-stack.ts
interface ApiStackProps extends cdk.StackProps {
  table: dynamodb.Table;
}

export class ApiStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: ApiStackProps) {
    super(scope, id, props);
    // Use props.table — CDK handles the cross-stack reference (export/import)
    props.table.grantReadWriteData(myLambda);
  }
}

// bin/app.ts
const dataStack = new DataStack(app, 'Data');
new ApiStack(app, 'Api', { table: dataStack.table });
```

- Pass resources via stack props — CDK auto-generates CloudFormation exports
- Avoid circular references between stacks
- Use SSM Parameter Store for values shared across independently deployed stacks

## Environment-Aware Stacks

```typescript
// bin/app.ts
const envConfig = {
  dev: { account: '111111111111', region: 'us-east-1' },
  prod: { account: '222222222222', region: 'us-east-1' },
};

const stage = app.node.tryGetContext('stage') || 'dev';
const env = envConfig[stage];

new ApiStack(app, `Api-${stage}`, {
  env,
  stage,
  domainName: stage === 'prod' ? 'api.example.com' : `api-${stage}.example.com`,
});
```

- Use CDK context (`-c stage=prod`) for environment selection
- Different AWS accounts per environment (security best practice)
- Scale resource capacity based on environment (dev: minimal, prod: production-grade)

## Context Values

```json
// cdk.json
{
  "context": {
    "stage": "dev",
    "domainName": "example.com",
    "vpcId": "vpc-12345"
  }
}
```

- Use `this.node.tryGetContext('key')` to read
- Don't put secrets in context — use AWS Secrets Manager or SSM Parameter Store
- Document all context keys in the README

## Asset Bundling (Lambda)

```typescript
new lambda.NodejsFunction(this, 'Handler', {
  entry: 'src/handlers/api.ts',
  handler: 'handler',
  runtime: lambda.Runtime.NODEJS_20_X,
  bundling: {
    minify: true,
    sourceMap: true,
    target: 'node20',
    externalModules: ['@aws-sdk/*'], // SDK v3 is in the Lambda runtime
  },
  environment: {
    TABLE_NAME: table.tableName,
    STAGE: stage,
  },
  memorySize: 256,
  timeout: cdk.Duration.seconds(30),
});
```

- Use `NodejsFunction` for automatic esbuild bundling
- Externalize AWS SDK v3 — it's in the Lambda runtime
- Set `memorySize` based on profiling (not default 128MB — often too low)
- Set explicit `timeout` — don't rely on the 3-second default

## IAM (Least Privilege)

```typescript
// ✅ Grant methods — scoped automatically
table.grantReadWriteData(lambdaFunction);
bucket.grantRead(lambdaFunction);
queue.grantSendMessages(lambdaFunction);

// ❌ Avoid broad policies
lambdaFunction.addToRolePolicy(
  new iam.PolicyStatement({
    actions: ['dynamodb:*'],
    resources: ['*'],
  }),
);
```

- Use L2 grant methods — they scope permissions to the specific resource
- Only use `addToRolePolicy` when grant methods don't cover your use case
- Never use `*` for resources or actions in production

## Testing

### Snapshot Tests

```typescript
test('stack matches snapshot', () => {
  const app = new cdk.App();
  const stack = new ApiStack(app, 'Test');
  const template = Template.fromStack(stack);
  expect(template.toJSON()).toMatchSnapshot();
});
```

### Assertion Tests (Preferred)

```typescript
test('DynamoDB table has encryption enabled', () => {
  const template = Template.fromStack(stack);
  template.hasResourceProperties('AWS::DynamoDB::Table', {
    SSESpecification: { SSEEnabled: true },
  });
});

test('Lambda has correct environment variables', () => {
  template.hasResourceProperties('AWS::Lambda::Function', {
    Environment: {
      Variables: Match.objectLike({
        TABLE_NAME: Match.anyValue(),
        STAGE: 'dev',
      }),
    },
  });
});
```

- Prefer assertion tests over snapshots — snapshots break on any change and are hard to review
- Test security properties: encryption, IAM policies, public access settings
- Test resource counts for critical resources: `template.resourceCountIs('AWS::Lambda::Function', 3)`

## Patterns to Avoid

- Don't hardcode AWS account IDs or ARNs — use `cdk.Aws.ACCOUNT_ID` or resource references
- Don't use `cdk.CfnOutput` for everything — only for values needed outside CDK
- Don't create resources without removal policies on stateful resources: `removalPolicy: cdk.RemovalPolicy.RETAIN`
- Don't deploy directly from your machine — use CI/CD with `cdk deploy`
- Don't mix infrastructure and application code in the same package
