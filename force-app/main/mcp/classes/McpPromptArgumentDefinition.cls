/**
 * @description Typed prompt argument descriptor exposed to clients.
 */
public inherited sharing class McpPromptArgumentDefinition {
    public String name;
    public String description;
    public Boolean required = false;

    public McpPromptArgumentDefinition() {
    }

    /**
     * @description Creates a prompt argument descriptor.
     * @param argumentName Argument name.
     * @param argumentDescription Human-readable description.
     * @param isRequired Whether the argument is required.
     */
    public McpPromptArgumentDefinition(String argumentName, String argumentDescription, Boolean isRequired) {
        this.name = argumentName;
        this.description = argumentDescription;
        this.required = isRequired == null ? false : isRequired;
    }

    /**
     * @description Validates required fields.
     */
    public void validate() {
        if (String.isBlank(this.name)) {
            throw new McpInvalidParamsException('Prompt argument name is required.');
        }
    }
}
