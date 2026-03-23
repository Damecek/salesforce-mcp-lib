/**
 * @description Declarative tool descriptor exposed by the MCP library.
 * @example
 * {@code
 * McpToolDefinition toolDef = new McpToolDefinition('math.sum', 'Sum two integers');
 * toolDef.inputSchema = new Map<String, Object>{ 'type' => 'object' };
 * }
 */
public inherited sharing class McpToolDefinition {
    /** @description Stable unique tool name. */
    public String name;
    /** @description Human-readable tool description. */
    public String description;
    /** @description Optional JSON-Schema-like input descriptor. */
    public Map<String, Object> inputSchema;
    /** @description Optional tool annotations. */
    public McpToolAnnotations annotations;
    private Type argumentsTypeValue = JsonRpcParamsBase.class;

    public McpToolDefinition() {
    }

    /**
     * @description Creates a tool descriptor.
     * @param toolName Unique tool name.
     * @param toolDescription Human-readable description.
     */
    public McpToolDefinition(String toolName, String toolDescription) {
        this(toolName, toolDescription, JsonRpcParamsBase.class);
    }

    /**
     * @description Creates a tool descriptor with explicit typed arguments DTO.
     * @param toolName Unique tool name.
     * @param toolDescription Human-readable description.
     * @param argumentsType Typed arguments DTO extending JsonRpcParamsBase.
     */
    public McpToolDefinition(String toolName, String toolDescription, Type argumentsType) {
        this.name = toolName;
        this.description = toolDescription;
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
            throw new McpInvalidParamsException('Tool name is required.');
        }
        validateArgumentsType(this.argumentsTypeValue, 'Tool arguments type');
    }

    /**
     * @description Returns the normalized input schema used for tools/list responses.
     * @return Declared schema or default no-argument object schema.
     */
    public Map<String, Object> listedInputSchema() {
        if (this.inputSchema != null) {
            return cloneMap(this.inputSchema);
        }
        return new Map<String, Object>{
            'type' => 'object',
            'additionalProperties' => false
        };
    }

    private static Map<String, Object> cloneMap(Map<String, Object> source) {
        if (source == null) {
            return null;
        }
        return (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(source));
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
