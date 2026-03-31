/**
 * Handler for the prompts/get JSON-RPC method.
 * Looks up a prompt by name, invokes it with the provided arguments,
 * and returns the generated messages.
 */
public class McpPromptsGetHandler extends JsonRpcMethodHandler {
    private final Map<String, McpPromptDefinition> promptsByName;

    public McpPromptsGetHandler(List<McpPromptDefinition> prompts) {
        super('prompts/get', null, null);
        this.promptsByName = new Map<String, McpPromptDefinition>();
        for (McpPromptDefinition prompt : prompts) {
            this.promptsByName.put(prompt.name, prompt);
        }
    }

    public override JsonRpcResponse invoke(JsonRpcInvocationContext context) {
        Map<String, Object> params = (Map<String, Object>) context.rawRequest.get('params');
        if (params == null) {
            return JsonRpcResponse.failure(context.requestId, JsonRpcError.invalidParams('Missing params'));
        }
        String promptName = (String) params.get('name');
        if (promptName == null) {
            return JsonRpcResponse.failure(context.requestId, JsonRpcError.invalidParams('Missing required field: name'));
        }
        McpPromptDefinition prompt = this.promptsByName.get(promptName);
        if (prompt == null) {
            return JsonRpcResponse.failure(context.requestId, JsonRpcError.invalidParams('Unknown prompt: ' + promptName));
        }

        // Extract arguments as Map<String, String>
        Map<String, String> arguments = new Map<String, String>();
        Object rawArgs = params.get('arguments');
        if (rawArgs != null) {
            Map<String, Object> argsMap = (Map<String, Object>) rawArgs;
            for (String key : argsMap.keySet()) {
                Object val = argsMap.get(key);
                arguments.put(key, val != null ? String.valueOf(val) : null);
            }
        }

        McpPromptResult promptResult = prompt.get(arguments);

        // Build wire format
        Map<String, Object> result = new Map<String, Object>();
        if (promptResult.description != null) {
            result.put('description', promptResult.description);
        }
        List<Map<String, Object>> messagesWire = new List<Map<String, Object>>();
        if (promptResult.messages != null) {
            for (McpPromptMessage msg : promptResult.messages) {
                Map<String, Object> msgMap = new Map<String, Object>();
                msgMap.put('role', msg.role);
                Map<String, Object> contentMap = new Map<String, Object>();
                contentMap.put('type', msg.content.type);
                contentMap.put('text', msg.content.text);
                msgMap.put('content', contentMap);
                messagesWire.add(msgMap);
            }
        }
        result.put('messages', messagesWire);
        return JsonRpcResponse.success(context.requestId, result);
    }
}
