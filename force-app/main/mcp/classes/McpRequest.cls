/**
 * What a handler sees of the current request. Built by the framework; the static for... methods
 * build one for unit tests.
 */
public inherited sharing class McpRequest {
    private String methodText;
    private String protocolVersionText;
    private Boolean legacyFlag = false;
    private Map<String, Object> metaMap = new Map<String, Object>();
    private Map<String, Object> clientInfoMap = new Map<String, Object>();
    private Map<String, Object> clientCapabilitiesMap = new Map<String, Object>();
    private String nameText;
    private Map<String, Object> argumentMap = new Map<String, Object>();
    private Map<String, String> promptArgumentMap = new Map<String, String>();
    private String uriText;
    private Map<String, String> variableMap = new Map<String, String>();

    public static McpRequest forTool(String name, Map<String, Object> args) {
        McpRequest r = new McpRequest();
        r.methodText = 'tools/call';
        r.nameText = name;
        r.argumentMap = args == null ? new Map<String, Object>() : args;
        return r;
    }

    public static McpRequest forPrompt(String name, Map<String, String> args) {
        McpRequest r = new McpRequest();
        r.methodText = 'prompts/get';
        r.nameText = name;
        r.promptArgumentMap = args == null ? new Map<String, String>() : args;
        return r;
    }

    public static McpRequest forResource(String uri) {
        return forResource(uri, null);
    }

    public static McpRequest forResource(String uri, Map<String, String> variables) {
        McpRequest r = new McpRequest();
        r.methodText = 'resources/read';
        r.uriText = uri;
        r.variableMap = variables == null ? new Map<String, String>() : variables;
        return r;
    }

    public String method() { return methodText; }
    public String protocolVersion() { return protocolVersionText; }
    public Boolean isLegacy() { return legacyFlag; }
    public Map<String, Object> clientInfo() { return clientInfoMap; }
    public Map<String, Object> clientCapabilities() { return clientCapabilitiesMap; }
    public Map<String, Object> meta() { return metaMap; }
    public String name() { return nameText; }
    public Map<String, Object> arguments() { return argumentMap; }
    public Map<String, String> promptArguments() { return promptArgumentMap; }
    public String uri() { return uriText; }
    public String variable(String name) { return variableMap.get(name); }
    public Map<String, String> variables() { return variableMap; }

    public Object get(String key) {
        return argumentMap.get(key);
    }

    public String getString(String key) {
        Object v = argumentMap.get(key);
        if (v == null) { return null; }
        if (!(v instanceof String)) { throw typeError(key, 'a string'); }
        return (String) v;
    }

    public String requireString(String key) {
        String v = getString(key);
        if (v == null) { throw new McpException('Argument "' + key + '" is required'); }
        return v;
    }

    public Integer getInteger(String key) {
        Long v = getLong(key);
        if (v == null) { return null; }
        if (v > 2147483647L || v < -2147483648L) { throw typeError(key, 'an integer in the 32-bit range'); }
        return (Integer) v;
    }

    public Long getLong(String key) {
        Object v = argumentMap.get(key);
        if (v == null) { return null; }
        if (v instanceof Integer) { return (Long) ((Integer) v); }
        if (v instanceof Long) { return (Long) v; }
        if (v instanceof Decimal) {
            try {
                Decimal d = ((Decimal) v).stripTrailingZeros();
                if (d.scale() <= 0 && d.abs() <= 9223372036854775807L) { return d.longValue(); }
            } catch (Exception e) {
                // falls through to the type error
            }
        }
        throw typeError(key, 'an integer');
    }

    public Decimal getDecimal(String key) {
        Object v = argumentMap.get(key);
        if (v == null) { return null; }
        if (v instanceof Integer) { return Decimal.valueOf((Integer) v); }
        if (v instanceof Long) { return Decimal.valueOf((Long) v); }
        if (v instanceof Decimal) { return (Decimal) v; }
        if (v instanceof Double) { return Decimal.valueOf((Double) v); }
        throw typeError(key, 'a number');
    }

    public Boolean getBoolean(String key) {
        Object v = argumentMap.get(key);
        if (v == null) { return null; }
        if (!(v instanceof Boolean)) { throw typeError(key, 'a boolean'); }
        return (Boolean) v;
    }

    public Map<String, Object> getMap(String key) {
        Object v = argumentMap.get(key);
        if (v == null) { return null; }
        if (!(v instanceof Map<String, Object>)) { throw typeError(key, 'an object'); }
        return (Map<String, Object>) v;
    }

    public List<Object> getList(String key) {
        Object v = argumentMap.get(key);
        if (v == null) { return null; }
        if (!(v instanceof List<Object>)) { throw typeError(key, 'an array'); }
        return (List<Object>) v;
    }

    private McpException typeError(String key, String expected) {
        return new McpException('Argument "' + key + '" must be ' + expected);
    }

    // Internal initialisers used by McpRuntime.
    public McpRequest initContext(String method, String protocolVersion, Boolean legacy, Map<String, Object> meta) {
        this.methodText = method;
        this.protocolVersionText = protocolVersion;
        this.legacyFlag = legacy;
        if (meta != null) {
            this.metaMap = meta;
            Object info = meta.get('io.modelcontextprotocol/clientInfo');
            if (info instanceof Map<String, Object>) { this.clientInfoMap = (Map<String, Object>) info; }
            Object caps = meta.get('io.modelcontextprotocol/clientCapabilities');
            if (caps instanceof Map<String, Object>) { this.clientCapabilitiesMap = (Map<String, Object>) caps; }
        }
        return this;
    }

    public McpRequest initTool(String name, Map<String, Object> args) {
        this.nameText = name;
        this.argumentMap = args;
        return this;
    }

    public McpRequest initPrompt(String name, Map<String, String> args) {
        this.nameText = name;
        this.promptArgumentMap = args;
        return this;
    }

    public McpRequest initResource(String uri, Map<String, String> variables) {
        this.uriText = uri;
        this.variableMap = variables == null ? new Map<String, String>() : variables;
        return this;
    }
}
