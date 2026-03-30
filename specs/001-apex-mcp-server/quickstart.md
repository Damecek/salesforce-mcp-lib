# Quickstart: MCP Server Framework for Salesforce Apex

**Feature**: 001-apex-mcp-server | **Date**: 2026-03-30

This guide walks a Salesforce developer through installing the package, implementing their first MCP tool, and connecting an AI agent — targeting under 30 minutes (SC-001).

---

## Prerequisites

- A Salesforce org with API access enabled (Enterprise, Unlimited, Performance, or Developer edition)
- Salesforce CLI (`sf`) installed
- Node.js >= 20 installed
- A Connected App configured for OAuth 2.0 Client Credentials flow (see [Connected App Setup](#connected-app-setup))

---

## Step 1: Install the Package (5 minutes)

Install the 2GP unlocked package into your org:

```bash
sf package install \
  --package SalesforceMcpLib@1.1.0-1 \
  --target-org my-org \
  --wait 10
```

Verify installation:

```bash
sf package installed list --target-org my-org
```

You should see `SalesforceMcpLib` in the installed packages list.

---

## Step 2: Implement Your First Tool (10 minutes)

### 2a. Create a Tool Class

Create a new Apex class in your org that extends `McpToolDefinition`:

```apex
public class QueryAccountsTool extends McpToolDefinition {

    public QueryAccountsTool() {
        this.name = 'query_accounts';
        this.description = 'Search for Salesforce Account records by name';
    }

    public override Map<String, Object> inputSchema() {
        return new Map<String, Object>{
            'type' => 'object',
            'properties' => new Map<String, Object>{
                'searchTerm' => new Map<String, Object>{
                    'type' => 'string',
                    'description' => 'Account name to search for'
                }
            },
            'required' => new List<String>{ 'searchTerm' }
        };
    }

    public override void validate(Map<String, Object> arguments) {
        if (!arguments.containsKey('searchTerm')) {
            throw new McpInvalidParamsException('searchTerm is required');
        }
    }

    public override McpToolResult execute(Map<String, Object> arguments) {
        String term = (String) arguments.get('searchTerm');
        List<Account> accounts = [
            SELECT Id, Name, Industry
            FROM Account
            WHERE Name LIKE :('%' + term + '%')
            LIMIT 10
        ];

        McpToolResult result = new McpToolResult();
        result.content = new List<McpTextContent>{
            new McpTextContent(JSON.serialize(accounts))
        };
        return result;
    }
}
```

### 2b. Create the REST Endpoint

Create a `@RestResource` class that registers your tool and delegates to the framework:

```apex
@RestResource(urlMapping='/mcp/v1')
global class MyMcpEndpoint {

    @HttpPost
    global static void handlePost() {
        McpServer server = new McpServer();

        // Register your tools
        server.registerTool(new QueryAccountsTool());

        // Delegate to the MCP framework
        server.handleRequest(RestContext.request, RestContext.response);
    }
}
```

### 2c. Deploy to Your Org

```bash
sf project deploy start \
  --source-dir force-app \
  --target-org my-org
```

---

## Step 3: Configure the Connected App (5 minutes)

### Connected App Setup

1. In Salesforce Setup, navigate to **App Manager** > **New Connected App**
2. Enable **OAuth Settings**:
   - Callback URL: `https://localhost/callback` (not used, but required)
   - Selected OAuth Scopes: **Access and manage your data (api)**
3. Enable **Client Credentials Flow** (checkbox)
4. Save and wait for propagation (~10 minutes for new apps)
5. Under **Manage** > **Edit Policies**:
   - Set **Permitted Users** to "Admin approved users are pre-authorized"
   - Set **IP Relaxation** to "Relax IP restrictions" (for development)
6. Assign a **Run As** user (this user's permissions determine API access)
7. Note the **Consumer Key** and **Consumer Secret**

---

## Step 4: Test with MCP Inspector (5 minutes)

### 4a. Start the Proxy with Inspector

```bash
npx @modelcontextprotocol/inspector \
  npx salesforce-mcp-lib \
    --instance-url https://your-org.my.salesforce.com \
    --client-id YOUR_CONSUMER_KEY \
    --client-secret YOUR_CONSUMER_SECRET \
    --endpoint /services/apexrest/mcp/v1
```

### 4b. Verify in the Inspector UI

1. The Inspector opens in your browser
2. The initialization handshake completes automatically
3. Navigate to the **Tools** tab — you should see `query_accounts`
4. Click the tool, enter a search term (e.g., `"Acme"`), and click **Execute**
5. Verify the response contains matching Account records

---

## Step 5: Connect an AI Agent (5 minutes)

### Claude Desktop Configuration

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "salesforce": {
      "command": "npx",
      "args": [
        "salesforce-mcp-lib",
        "--instance-url", "https://your-org.my.salesforce.com",
        "--client-id", "YOUR_CONSUMER_KEY",
        "--client-secret", "YOUR_CONSUMER_SECRET",
        "--endpoint", "/services/apexrest/mcp/v1"
      ]
    }
  }
}
```

Restart Claude Desktop. The Salesforce tools are now available to Claude.

---

## Adding Resources and Prompts

### Add a Resource

```apex
public class OrgInfoResource extends McpResourceDefinition {

    public OrgInfoResource() {
        this.uri = 'salesforce://org/info';
        this.name = 'Org Info';
        this.description = 'Basic information about the Salesforce org';
        this.mimeType = 'application/json';
    }

    public override McpResourceResult read() {
        Organization org = [SELECT Name, OrganizationType, IsSandbox FROM Organization LIMIT 1];
        McpResourceResult result = new McpResourceResult();
        McpResourceContentItem item = new McpResourceContentItem();
        item.uri = this.uri;
        item.mimeType = this.mimeType;
        item.text = JSON.serialize(org);
        result.contents = new List<McpResourceContentItem>{ item };
        return result;
    }
}
```

### Add a Prompt

```apex
public class DescribeObjectPrompt extends McpPromptDefinition {

    public DescribeObjectPrompt() {
        this.name = 'describe_object';
        this.description = 'Generate a prompt to describe a Salesforce object';
        this.arguments = new List<McpPromptArgumentDefinition>{
            new McpPromptArgumentDefinition('objectName', 'API name of the Salesforce object', true)
        };
    }

    public override McpPromptResult get(Map<String, String> arguments) {
        String objName = arguments.get('objectName');
        Schema.DescribeSObjectResult describe = Schema.getGlobalDescribe().get(objName).getDescribe();

        String text = 'Describe the Salesforce object: ' + describe.getLabel()
            + ' (API name: ' + describe.getName() + ')\n'
            + 'Fields: ' + describe.fields.getMap().size() + '\n'
            + 'Custom: ' + describe.isCustom();

        McpPromptResult result = new McpPromptResult();
        result.messages = new List<McpPromptMessage>{
            new McpPromptMessage('user', new McpTextContent(text))
        };
        return result;
    }
}
```

### Register Everything in the Endpoint

```apex
@RestResource(urlMapping='/mcp/v1')
global class MyMcpEndpoint {

    @HttpPost
    global static void handlePost() {
        McpServer server = new McpServer();

        // Tools
        server.registerTool(new QueryAccountsTool());

        // Resources
        server.registerResource(new OrgInfoResource());

        // Prompts
        server.registerPrompt(new DescribeObjectPrompt());

        server.handleRequest(RestContext.request, RestContext.response);
    }
}
```

---

## Best Practices

### Governor Limits

- Each MCP request runs as a single Apex transaction with standard governor limits
- CPU time limit: 10,000 ms — keep tool logic efficient
- Heap size limit: 6 MB — paginate large SOQL results
- SOQL queries: 100 per transaction — bulkify queries
- The framework itself uses minimal resources; your budget is almost entirely available to tool logic

### Error Handling

- Always implement `validate()` to catch bad input before execution
- Throw `McpInvalidParamsException` from `validate()` for clear error messages
- The framework catches all catchable exceptions and returns MCP-compliant errors
- Uncatchable `System.LimitException` (governor limits) is handled by the proxy

### Multiple Endpoints

You can create multiple `@RestResource` endpoints with different capability sets:

```apex
@RestResource(urlMapping='/mcp/sales')
global class SalesMcpEndpoint {
    @HttpPost
    global static void handlePost() {
        McpServer server = new McpServer();
        server.registerTool(new QueryAccountsTool());
        server.registerTool(new QueryOpportunitiesTool());
        server.handleRequest(RestContext.request, RestContext.response);
    }
}

@RestResource(urlMapping='/mcp/support')
global class SupportMcpEndpoint {
    @HttpPost
    global static void handlePost() {
        McpServer server = new McpServer();
        server.registerTool(new QueryCasesTool());
        server.registerTool(new CreateCaseTool());
        server.handleRequest(RestContext.request, RestContext.response);
    }
}
```

Configure separate proxy instances for each endpoint:

```bash
# Sales agent
npx salesforce-mcp-lib --endpoint /services/apexrest/mcp/sales ...

# Support agent
npx salesforce-mcp-lib --endpoint /services/apexrest/mcp/support ...
```

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| `401 Unauthorized` at startup | Invalid client credentials or Connected App not yet propagated | Verify consumer key/secret; wait 10 min for new Connected Apps |
| Tool not showing in Inspector | Tool not registered in endpoint class | Verify `registerTool()` is called before `handleRequest()` |
| `APEX_ERROR` in proxy logs | Unhandled Apex exception or governor limit exceeded | Check Salesforce debug logs for the failing transaction |
| Proxy exits immediately | Missing required CLI arguments | Check that all `--instance-url`, `--client-id`, `--client-secret`, `--endpoint` are provided |
| `DuplicateRegistrationException` | Two tools/resources/prompts with the same name/URI | Ensure all names and URIs are unique within an endpoint |
