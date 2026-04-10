# Apex Public API Contract

**Feature**: 001-apex-mcp-server | **Date**: 2026-03-30

This contract defines the public Apex API surface that subscriber developers use to implement MCP tools, resources, and prompts. These are the classes distributed in the 2GP unlocked package.

---

## McpServer

The main entry point. Subscribers create an instance, register capabilities, and delegate request handling.

```apex
public class McpServer {

    /**
     * Register a tool implementation. Throws if a tool with the same name
     * is already registered.
     * @param tool The tool definition to register
     * @throws McpExceptions.DuplicateRegistrationException on duplicate name
     */
    public void registerTool(McpToolDefinition tool);

    /**
     * Register a resource implementation. Throws if a resource with the same
     * URI is already registered.
     * @param resource The resource definition to register
     * @throws McpExceptions.DuplicateRegistrationException on duplicate URI
     */
    public void registerResource(McpResourceDefinition resource);

    /**
     * Register a prompt implementation. Throws if a prompt with the same name
     * is already registered.
     * @param prompt The prompt definition to register
     * @throws McpExceptions.DuplicateRegistrationException on duplicate name
     */
    public void registerPrompt(McpPromptDefinition prompt);

    /**
     * Register a resource template implementation. Throws if a template with
     * the same URI template is already registered.
     * @param template The resource template definition to register
     */
    public void registerResourceTemplate(McpResourceTemplateDefinition template);

    /**
     * Process an incoming JSON-RPC request from the REST endpoint.
     * Parses the request body, routes to the correct handler, and writes
     * the JSON-RPC response to the RestResponse.
     * @param req The Salesforce RestRequest
     * @param res The Salesforce RestResponse
     */
    public void handleRequest(RestRequest req, RestResponse res);
}
```

### Usage Pattern

```apex
@RestResource(urlMapping='/mcp/v1')
global inherited sharing class MyMcpEndpoint {

    @HttpPost
    global static void handlePost() {
        McpServer server = new McpServer();

        // Register tools
        server.registerTool(new QueryAccountsTool());
        server.registerTool(new CreateCaseTool());

        // Register resources
        server.registerResource(new AccountSchemaResource());

        // Register prompts
        server.registerPrompt(new SummarizeOpportunityPrompt());

        // Delegate to framework
        server.handleRequest(RestContext.request, RestContext.response);
    }
}
```

**Notes**:
- Registration happens on every request because Apex `@RestResource` endpoints are stateless. This is by design — it allows subscribers to conditionally register capabilities based on the running user's permissions or other per-request context.
- In this 2GP unlocked package, subscriber-facing framework classes remain `public`; the endpoint is `global` only because it is an Apex REST entry point.
- `inherited sharing` and `with sharing` control record-level sharing behavior only. They don't enforce object permissions or field-level security by themselves.

---

## McpToolDefinition (abstract)

Base class that subscribers extend to implement MCP tools.

```apex
public abstract class McpToolDefinition {

    /** Unique tool name. Set in the constructor. */
    public String name;

    /** Human-readable description. Set in the constructor. */
    public String description;

    /** Optional tool annotations (hints for clients). */
    public McpToolAnnotations annotations;

    /**
     * Define the JSON Schema for this tool's input parameters.
     * Must return a Map mirroring JSON Schema structure with
     * "type": "object" at the top level.
     * @return Map<String, Object> representing the input JSON Schema
     */
    public abstract Map<String, Object> inputSchema();

    /**
     * Validate the provided arguments before execution.
     * Called by the framework before execute(). If validation fails,
     * throw McpInvalidParamsException with a descriptive message.
     * The framework translates this into an isError:true result.
     * @param arguments Deserialized tool arguments from the client
     * @throws McpInvalidParamsException if validation fails
     */
    public abstract void validate(Map<String, Object> arguments);

    /**
     * Execute the tool logic with validated arguments.
     * Only called if validate() succeeds without throwing.
     * @param arguments Deserialized tool arguments from the client
     * @return McpToolResult containing content blocks
     */
    public abstract McpToolResult execute(Map<String, Object> arguments);
}
```

### Subscriber Implementation Example

```apex
public with sharing class QueryAccountsTool extends McpToolDefinition {

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
                    'description' => 'Account name search term'
                },
                'maxResults' => new Map<String, Object>{
                    'type' => 'integer',
                    'description' => 'Maximum number of results (default 10)'
                }
            },
            'required' => new List<String>{ 'searchTerm' }
        };
    }

    public override void validate(Map<String, Object> arguments) {
        if (!arguments.containsKey('searchTerm')) {
            throw new McpInvalidParamsException('searchTerm is required');
        }
        String term = (String) arguments.get('searchTerm');
        if (String.isBlank(term) || term.length() < 2) {
            throw new McpInvalidParamsException(
                'searchTerm must be at least 2 characters'
            );
        }
    }

    public override McpToolResult execute(Map<String, Object> arguments) {
        String term = (String) arguments.get('searchTerm');
        Integer maxResults = arguments.containsKey('maxResults')
            ? (Integer) arguments.get('maxResults')
            : 10;

        List<Account> accounts = [
            SELECT Id, Name, Industry
            FROM Account
            WHERE Name LIKE :('%' + term + '%')
            LIMIT :maxResults
        ];

        McpToolResult result = new McpToolResult();
        result.content = new List<McpTextContent>{
            new McpTextContent(JSON.serialize(accounts))
        };
        return result;
    }
}
```

---

## McpResourceDefinition (abstract)

Base class for MCP resources.

```apex
public abstract class McpResourceDefinition {

    /** Unique resource URI. */
    public String uri;

    /** Human-readable name. */
    public String name;

    /** Description. */
    public String description;

    /** Content MIME type. */
    public String mimeType;

    /**
     * Read the resource content.
     * @return McpResourceResult containing content items
     */
    public abstract McpResourceResult read();
}
```

### Subscriber Implementation Example

```apex
public class AccountSchemaResource extends McpResourceDefinition {

    public AccountSchemaResource() {
        this.uri = 'salesforce://schema/Account';
        this.name = 'Account Schema';
        this.description = 'Field definitions for the Account object';
        this.mimeType = 'application/json';
    }

    public override McpResourceResult read() {
        List<Map<String, String>> fields = new List<Map<String, String>>();
        for (Schema.SObjectField f : Account.SObjectType.getDescribe().fields.getMap().values()) {
            Schema.DescribeFieldResult dfr = f.getDescribe();
            fields.add(new Map<String, String>{
                'name' => dfr.getName(),
                'type' => dfr.getType().name(),
                'label' => dfr.getLabel()
            });
        }

        McpResourceResult result = new McpResourceResult();
        McpResourceContentItem item = new McpResourceContentItem();
        item.uri = this.uri;
        item.mimeType = this.mimeType;
        item.text = JSON.serialize(fields);
        result.contents = new List<McpResourceContentItem>{ item };
        return result;
    }
}
```

---

## McpPromptDefinition (abstract)

Base class for MCP prompts.

```apex
public abstract class McpPromptDefinition {

    /** Unique prompt name. */
    public String name;

    /** Description. */
    public String description;

    /** Argument definitions. */
    public List<McpPromptArgumentDefinition> arguments;

    /**
     * Generate prompt messages for the given arguments.
     * @param arguments Key-value map of prompt arguments
     * @return McpPromptResult containing messages
     */
    public abstract McpPromptResult get(Map<String, String> arguments);
}
```

### Subscriber Implementation Example

```apex
public class SummarizeOpportunityPrompt extends McpPromptDefinition {

    public SummarizeOpportunityPrompt() {
        this.name = 'summarize_opportunity';
        this.description = 'Generate a summary prompt for a Salesforce Opportunity';
        this.arguments = new List<McpPromptArgumentDefinition>{
            new McpPromptArgumentDefinition('opportunityId', 'Salesforce Opportunity ID', true)
        };
    }

    public override McpPromptResult get(Map<String, String> arguments) {
        String oppId = arguments.get('opportunityId');
        Opportunity opp = [
            SELECT Name, Amount, StageName, CloseDate, Account.Name
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];

        String promptText = 'Summarize this Salesforce Opportunity:\n\n'
            + 'Name: ' + opp.Name + '\n'
            + 'Account: ' + opp.Account.Name + '\n'
            + 'Amount: $' + opp.Amount + '\n'
            + 'Stage: ' + opp.StageName + '\n'
            + 'Close Date: ' + String.valueOf(opp.CloseDate);

        McpPromptResult result = new McpPromptResult();
        result.messages = new List<McpPromptMessage>{
            new McpPromptMessage('user', new McpTextContent(promptText))
        };
        return result;
    }
}
```

---

## McpResourceTemplateDefinition (abstract)

Base class for URI-templated resources.

```apex
public abstract class McpResourceTemplateDefinition {

    /** URI template (RFC 6570). */
    public String uriTemplate;

    /** Human-readable name. */
    public String name;

    /** Description. */
    public String description;

    /** Content MIME type. */
    public String mimeType;

    /**
     * Read resource content using expanded template arguments.
     * @param templateArguments Expanded URI template parameters
     * @return McpResourceResult containing content items
     */
    public abstract McpResourceResult read(Map<String, String> templateArguments);
}
```

---

## Result Types

### McpToolResult

```apex
public class McpToolResult extends JsonRpcResultBase {
    public List<McpTextContent> content;
    public Boolean isError;  // null or false = success, true = tool error
}
```

### McpResourceResult

```apex
public class McpResourceResult extends JsonRpcResultBase {
    public List<McpResourceContentItem> contents;
}
```

### McpResourceContentItem

```apex
public class McpResourceContentItem {
    public String uri;
    public String mimeType;
    public String text;   // mutually exclusive with blob
    public String blob;   // base64-encoded, mutually exclusive with text
}
```

### McpPromptResult

```apex
public class McpPromptResult extends JsonRpcResultBase {
    public String description;
    public List<McpPromptMessage> messages;
}
```

### McpPromptMessage

```apex
public class McpPromptMessage {
    public String role;         // "user" or "assistant"
    public McpTextContent content;
}
```

### McpTextContent

```apex
public class McpTextContent {
    public String type = 'text';
    public String text;

    public McpTextContent(String text) {
        this.text = text;
    }
}
```

---

## Error Types

### McpInvalidParamsException

Thrown by tool `validate()` methods to signal argument validation failure. The framework catches this and returns an `isError: true` tool result.

```apex
public class McpInvalidParamsException extends Exception {}
```

### McpExceptions

Container for framework-level exception types.

```apex
public class McpExceptions {
    public class DuplicateRegistrationException extends Exception {}
}
```
