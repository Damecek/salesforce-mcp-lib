/**
 * Example prompt for summarizing a Salesforce record.
 */
public class ExampleSummarizePrompt extends McpPromptDefinition {
    public ExampleSummarizePrompt() {
        this.name = 'summarize_record';
        this.description = 'Generate a prompt to summarize a Salesforce record';
        this.arguments = new List<McpPromptArgumentDefinition>{
            new McpPromptArgumentDefinition('objectName', 'API name of the object', true),
            new McpPromptArgumentDefinition('recordId', 'The record ID to summarize', true)
        };
    }
    public override McpPromptResult get(Map<String, String> arguments) {
        String objName = arguments.get('objectName');
        String recordId = arguments.get('recordId');
        McpPromptResult result = new McpPromptResult();
        result.description = 'Summarize ' + objName + ' record';
        result.messages = new List<McpPromptMessage>{
            new McpPromptMessage('user', new McpTextContent(
                'Please summarize the ' + objName + ' record with ID ' + recordId + '. Include key fields and current status.'
            ))
        };
        return result;
    }
}
