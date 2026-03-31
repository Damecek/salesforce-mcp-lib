/**
 * Result returned by McpPromptDefinition#get(Map).
 */
public class McpPromptResult extends JsonRpcResultBase {
    public String description;
    public List<McpPromptMessage> messages;
}
