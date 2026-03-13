/**
 * @description Typed MCP prompt message payload.
 */
public inherited sharing class McpPromptMessage {
    private static final Set<String> ALLOWED_ROLES = new Set<String>{ 'user', 'assistant' };

    public String role;
    public McpTextContent content;

    public McpPromptMessage() {
    }

    public McpPromptMessage(String messageRole, McpTextContent messageContent) {
        this.role = messageRole;
        this.content = messageContent;
    }

    public static McpPromptMessage userText(String text) {
        return new McpPromptMessage('user', new McpTextContent(text));
    }

    public static McpPromptMessage assistantText(String text) {
        return new McpPromptMessage('assistant', new McpTextContent(text));
    }

    public void validate() {
        if (String.isBlank(this.role)) {
            throw new McpInvalidParamsException('Prompt message role is required.');
        }

        if (!ALLOWED_ROLES.contains(this.role)) {
            throw new McpInvalidParamsException('Prompt message role must be user or assistant.');
        }

        if (this.content == null) {
            throw new McpInvalidParamsException('Prompt message content is required.');
        }

        this.content.validate();
    }
}
