/**
 * @description Typed wire DTO returned from prompts/list.
 */
public inherited sharing class McpListedPrompt {
    public String name;
    public String description;
    public List<McpPromptArgumentDefinition> arguments;

    public McpListedPrompt() {
    }

    /**
     * @description Builds a listed prompt DTO from a prompt definition.
     * @param source Prompt definition.
     */
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

    /**
     * @description Validates required wire fields.
     */
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

    /**
     * @description Builds a null-clean wire map for JSON serialization.
     * @return Wire map with only non-null optional fields included.
     */
    public Map<String, Object> toWire() {
        this.validate();

        Map<String, Object> wire = new Map<String, Object>{ 'name' => this.name };

        if (!String.isBlank(this.description)) {
            wire.put('description', this.description);
        }

        if (this.arguments != null) {
            wire.put('arguments', this.arguments);
        }

        return wire;
    }
}
