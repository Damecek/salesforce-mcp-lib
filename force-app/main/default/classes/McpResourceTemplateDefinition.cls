/**
 * @description Declarative resource template descriptor exposed by the MCP library.
 */
public inherited sharing class McpResourceTemplateDefinition {
    /** @description Stable template name used by call endpoint. */
    public String name;
    /** @description URI template string. */
    public String uriTemplate;
    /** @description Optional textual description. */
    public String description;
    private Type argumentsTypeValue = JsonRpcParamsBase.class;

    public McpResourceTemplateDefinition() {
    }

    /**
     * @description Creates a template descriptor.
     * @param templateName Stable template name.
     * @param templateUri URI template pattern.
     */
    public McpResourceTemplateDefinition(String templateName, String templateUri) {
        this(templateName, templateUri, JsonRpcParamsBase.class);
    }

    /**
     * @description Creates a template descriptor with explicit typed arguments DTO.
     * @param templateName Stable template name.
     * @param templateUri URI template pattern.
     * @param argumentsType Typed arguments DTO extending JsonRpcParamsBase.
     */
    public McpResourceTemplateDefinition(String templateName, String templateUri, Type argumentsType) {
        this.name = templateName;
        this.uriTemplate = templateUri;
        this.argumentsTypeValue = argumentsType == null ? JsonRpcParamsBase.class : argumentsType;
    }

    /**
     * @description Returns the declared typed arguments DTO.
     * @return Arguments type extending JsonRpcParamsBase.
     */
    public Type argumentsType() {
        return this.argumentsTypeValue;
    }

    /** @description Validates required descriptor fields. */
    public void validate() {
        if (String.isBlank(this.name)) {
            throw new McpInvalidParamsException('Resource template name is required.');
        }

        if (String.isBlank(this.uriTemplate)) {
            throw new McpInvalidParamsException('Resource template uriTemplate is required.');
        }

        validateArgumentsType(this.argumentsTypeValue, 'Resource template arguments type');
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
