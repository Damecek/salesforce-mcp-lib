/**
 * Base class for an MCP tool. Subclass it, configure it in the constructor and implement execute().
 * Arguments are validated against a builder input schema before validate() and execute() run.
 */
public abstract inherited sharing class McpTool {
    private static final Pattern NAME_PATTERN = Pattern.compile('^[A-Za-z0-9_.-]{1,128}$');

    private final String nameText;
    private String titleText;
    private String descriptionText;
    private McpIcon iconValue;
    private McpToolAnnotations annotationsValue;
    private Map<String, Object> metaMap;
    private McpSchema inputBuilder;
    private Map<String, Object> inputRaw;
    private McpSchema outputBuilder;
    private Map<String, Object> outputRaw;
    private Map<String, Object> inputCompiled;
    private Map<String, Object> outputCompiled;
    private McpSchema inputValidatorSchema;

    public McpTool(String name) {
        if (name == null || !NAME_PATTERN.matcher(name).matches()) {
            throw new McpConfigurationException('Tool name must be 1 to 128 characters from [A-Za-z0-9_.-]');
        }
        this.nameText = name;
    }

    public McpTool title(String value) { this.titleText = value; return this; }
    public McpTool description(String value) { this.descriptionText = value; return this; }
    public McpTool icon(McpIcon value) { this.iconValue = value; return this; }
    public McpTool annotations(McpToolAnnotations value) { this.annotationsValue = value; return this; }

    public McpTool meta(String key, Object value) {
        if (metaMap == null) { metaMap = new Map<String, Object>(); }
        metaMap.put(key, value);
        return this;
    }

    public McpTool input(McpSchema schema) {
        this.inputBuilder = schema;
        this.inputRaw = null;
        return this;
    }

    /** Trusted raw schema. The framework only checks that arguments is an object; validate() must do the rest. */
    public McpTool inputSchema(Map<String, Object> schema) {
        this.inputRaw = schema;
        this.inputBuilder = null;
        return this;
    }

    public McpTool output(McpSchema schema) {
        this.outputBuilder = schema;
        this.outputRaw = null;
        return this;
    }

    public McpTool outputSchema(Map<String, Object> schema) {
        this.outputRaw = schema;
        this.outputBuilder = null;
        return this;
    }

    public String getName() {
        return nameText;
    }

    public virtual void validate(McpRequest request) {
    }

    public abstract McpToolResult execute(McpRequest request);

    // Internal members used by McpRuntime.

    /** Checks and caches the schema maps. Called once at registration. */
    public void compile() {
        if (inputBuilder != null) {
            if (inputBuilder.kindName() != 'object') {
                throw new McpConfigurationException('Tool ' + nameText + ': input schema root must be an object');
            }
            inputCompiled = inputBuilder.toMap();
            inputValidatorSchema = inputBuilder;
        } else if (inputRaw != null) {
            inputCompiled = inputRaw;
            inputValidatorSchema = null;
        } else {
            inputCompiled = new Map<String, Object>{ 'type' => 'object', 'additionalProperties' => false };
            inputValidatorSchema = McpSchema.obj().closed(); // the advertised closed schema is enforced too
        }
        McpSchema.checkRaw(inputCompiled, true, 'Tool ' + nameText + ' input schema');
        if (outputBuilder != null) {
            outputCompiled = outputBuilder.toMap();
        } else {
            outputCompiled = outputRaw;
        }
        if (outputCompiled != null) {
            McpSchema.checkRaw(outputCompiled, false, 'Tool ' + nameText + ' output schema');
        }
    }

    /** The schema arguments are validated against: the builder schema, the closed empty object, or null for a raw schema. */
    public McpSchema inputValidator() { return inputValidatorSchema; }
    public McpSchema outputBuilderSchema() { return outputBuilder; }

    public Map<String, Object> toWire(Boolean legacy) {
        Map<String, Object> m = new Map<String, Object>{ 'name' => nameText, 'inputSchema' => inputCompiled };
        if (titleText != null) { m.put('title', titleText); }
        if (descriptionText != null) { m.put('description', descriptionText); }
        if (outputCompiled != null && !(legacy && !McpWire.same(outputCompiled.get('type'), 'object'))) {
            m.put('outputSchema', outputCompiled);
        }
        if (annotationsValue != null) { m.put('annotations', annotationsValue.toMap()); }
        if (iconValue != null) { m.put('icons', new List<Object>{ iconValue.toMap() }); }
        if (metaMap != null) { m.put('_meta', metaMap); }
        return m;
    }
}
