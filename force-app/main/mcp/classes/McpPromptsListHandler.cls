/**
 * Handler for the prompts/list JSON-RPC method.
 * Returns all registered MCP prompt definitions with their metadata.
 */
public inherited sharing class McpPromptsListHandler extends JsonRpcMethodHandler {
    private final List<McpPromptDefinition> prompts;

    public McpPromptsListHandler(List<McpPromptDefinition> prompts) {
        super('prompts/list', null, null);
        this.prompts = prompts;
    }

    public override JsonRpcResponse invoke(JsonRpcInvocationContext context) {
        List<Map<String, Object>> promptEntries = new List<Map<String, Object>>();
        for (McpPromptDefinition prompt : this.prompts) {
            Map<String, Object> entry = new Map<String, Object>();
            entry.put('name', prompt.name);
            if (prompt.description != null) {
                entry.put('description', prompt.description);
            }
            if (prompt.arguments != null && !prompt.arguments.isEmpty()) {
                List<Map<String, Object>> argEntries = new List<Map<String, Object>>();
                for (McpPromptArgumentDefinition arg : prompt.arguments) {
                    Map<String, Object> argEntry = new Map<String, Object>();
                    argEntry.put('name', arg.name);
                    if (arg.description != null) {
                        argEntry.put('description', arg.description);
                    }
                    if (arg.required != null) {
                        argEntry.put('required', arg.required);
                    }
                    argEntries.add(argEntry);
                }
                entry.put('arguments', argEntries);
            }
            promptEntries.add(entry);
        }
        Map<String, Object> result = new Map<String, Object>();
        result.put('prompts', promptEntries);
        return JsonRpcResponse.success(context.requestId, result);
    }
}
