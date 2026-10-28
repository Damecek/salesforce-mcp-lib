/**
 * Example prompt for summarizing a Salesforce record.
 */
public with sharing class ExampleSummarizePrompt extends McpPrompt {
    public ExampleSummarizePrompt() {
        super('summarize_record');
        title('Summarize record')
            .description('Generate a prompt to summarize a Salesforce record')
            .argument('objectName', 'API name of the object', true)
            .argument('recordId', 'The record ID to summarize', true);
    }

    public override McpPromptResult get(McpRequest request) {
        String objName = request.promptArguments().get('objectName');
        String recordId = request.promptArguments().get('recordId');
        return new McpPromptResult()
            .description('Summarize ' + objName + ' record')
            .user(McpContent.text('Please summarize the ' + objName + ' record with ID ' + recordId + '. Include key fields and current status.'));
    }
}
