public class ExampleQueryTool extends McpToolDefinition {
    public ExampleQueryTool() {
        this.name = 'query_accounts';
        this.description = 'Search for Account records by name';
        this.annotations = new McpToolAnnotations();
        this.annotations.readOnlyHint = true;
    }

    public override Map<String, Object> inputSchema() {
        return new Map<String, Object>{
            'type' => 'object',
            'properties' => new Map<String, Object>{
                'searchTerm' => new Map<String, Object>{
                    'type' => 'string',
                    'description' => 'Account name search term'
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
        List<Account> accounts = [SELECT Id, Name, Industry FROM Account WHERE Name LIKE :('%' + term + '%') LIMIT 10];
        McpToolResult result = new McpToolResult();
        result.content = new List<McpTextContent>{ new McpTextContent(JSON.serialize(accounts)) };
        return result;
    }
}
