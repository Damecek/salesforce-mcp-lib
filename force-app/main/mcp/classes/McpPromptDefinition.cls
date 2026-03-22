/**
 * @description Declarative prompt descriptor exposed by the MCP library.
 */
public inherited sharing class McpPromptDefinition {
    /** @description Stable prompt name. */
    public String name;
    /** @description Optional prompt description. */
    public String description;
    /** @description Optional list of argument descriptors. */
    public List<McpPromptArgumentDefinition> arguments;
    private Type argumentsTypeValue = JsonRpcParamsBase.class;

    public McpPromptDefinition() {
    }

    /**
     * @description Creates a prompt descriptor.
     * @param promptName Stable prompt name.
     * @param promptDescription Human-readable description.
     */
    public McpPromptDefinition(String promptName, String promptDescription) {
        this(promptName, promptDescription, JsonRpcParamsBase.class);
    }

    /**
     * @description Creates a prompt descriptor with explicit typed arguments DTO.
     * @param promptName Stable prompt name.
     * @param promptDescription Human-readable description.
     * @param argumentsType Typed arguments DTO extending JsonRpcParamsBase.
     */
    public McpPromptDefinition(String promptName, String promptDescription, Type argumentsType) {
        this.name = promptName;
        this.description = promptDescription;
        this.argumentsTypeValue = argumentsType == null ? JsonRpcParamsBase.class : argumentsType;
    }

    /**
     * @description Returns the declared typed arguments DTO.
     * @return Arguments type extending JsonRpcParamsBase.
     */
    public Type argumentsType() {
        return this.argumentsTypeValue;
    }

    /**
     * @description Validates required descriptor fields.
     */
    public void validate() {
        if (String.isBlank(this.name)) {
            throw new McpInvalidParamsException('Prompt name is required.');
        }

        validateArgumentsType(this.argumentsTypeValue, 'Prompt arguments type');

        if (this.arguments != null) {
            for (McpPromptArgumentDefinition argument : this.arguments) {
                if (argument == null) {
                    throw new McpInvalidParamsException('Prompt argument definition cannot be null.');
                }
                argument.validate();
            }
        }
    }

    private static void validateArgumentsType(Type candidateType, String label) {
        if (candidateType == null) {
            throw new McpInvalidParamsException(label + ' is required.');
        }

        Object probe;
        try {
            probe = candidateType.newInstance();
        } catch (Exception ex) {
            throw new McpInvalidParamsException(label + ' must be instantiable.');
        }

        if (!(probe instanceof JsonRpcParamsBase)) {
            throw new McpInvalidParamsException(label + ' must extend JsonRpcParamsBase.');
        }
    }
}
