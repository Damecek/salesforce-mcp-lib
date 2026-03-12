/**
 * @description Typed prompt argument descriptor exposed to clients.
 */
public inherited sharing class McpPromptArgumentDefinition {
    public String name;
    public String description;
    public Boolean required = false;

    public McpPromptArgumentDefinition() {
    }

    public McpPromptArgumentDefinition(String argumentName, String argumentDescription, Boolean isRequired) {
        this.name = argumentName;
        this.description = argumentDescription;
        this.required = isRequired == null ? false : isRequired;
    }

    public void validate() {
        if (String.isBlank(this.name)) {
            throw new McpInvalidParamsException('Prompt argument name is required.');
        }
    }
}
