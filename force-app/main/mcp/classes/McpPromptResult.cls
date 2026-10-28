/**
 * Result of prompts/get: an optional description and ordered user/assistant messages.
 */
public inherited sharing class McpPromptResult {
    private String descriptionText;
    private final List<Map<String, Object>> messageList = new List<Map<String, Object>>();
    private Map<String, Object> metaMap;

    public McpPromptResult description(String value) { this.descriptionText = value; return this; }
    public McpPromptResult user(McpContent content) { return addMessage('user', content); }
    public McpPromptResult assistant(McpContent content) { return addMessage('assistant', content); }

    public McpPromptResult meta(String key, Object value) {
        if (metaMap == null) { metaMap = new Map<String, Object>(); }
        metaMap.put(key, value);
        return this;
    }

    private McpPromptResult addMessage(String role, McpContent content) {
        if (content == null) {
            throw new McpConfigurationException('A prompt message needs content');
        }
        messageList.add(new Map<String, Object>{ 'role' => role, 'content' => content.toMap() });
        return this;
    }

    // Internal accessors for McpRuntime.
    public String descriptionValue() { return descriptionText; }
    public List<Map<String, Object>> messages() { return messageList; }
    public Map<String, Object> metaValues() { return metaMap; }
}
