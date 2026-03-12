/**
 * @description Typed wire DTO returned from prompts/list.
 */
public inherited sharing class McpListedPrompt {
    public String name;
    public String description;
    public List<McpPromptArgumentDefinition> arguments;

    public McpListedPrompt() {
    }

    public McpListedPrompt(McpPromptDefinition source) {
        if (source == null) {
            return;
        }

        this.name = source.name;
        this.description = source.description;
        this.arguments = source.arguments == null
            ? null
            : new List<McpPromptArgumentDefinition>(source.arguments);
    }

    public void validate() {
        if (String.isBlank(this.name)) {
            throw new McpInvalidParamsException('Prompt name is required.');
        }

        if (this.arguments != null) {
            for (McpPromptArgumentDefinition argument : this.arguments) {
                if (argument == null) {
                    throw new McpInvalidParamsException('Prompt argument definition cannot be null.');
                }
                argument.validate();
            }
        }
    }
}
