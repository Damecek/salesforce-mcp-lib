/**
 * Base class for a prompt template. Arguments are declared with argument() and arrive as strings.
 */
public abstract inherited sharing class McpPrompt {
    private static final Pattern NAME_PATTERN = Pattern.compile('^[A-Za-z0-9_.-]{1,128}$');

    private final String nameText;
    private String titleText;
    private String descriptionText;
    private McpIcon iconValue;
    private Map<String, Object> metaMap;
    private final List<Map<String, Object>> argumentList = new List<Map<String, Object>>();
    private final Map<String, Boolean> argumentRequired = new Map<String, Boolean>();

    public McpPrompt(String name) {
        if (name == null || !NAME_PATTERN.matcher(name).matches()) {
            throw new McpConfigurationException('Prompt name must be 1 to 128 characters from [A-Za-z0-9_.-]');
        }
        this.nameText = name;
    }

    public McpPrompt title(String value) { this.titleText = value; return this; }
    public McpPrompt description(String value) { this.descriptionText = value; return this; }
    public McpPrompt icon(McpIcon value) { this.iconValue = value; return this; }

    public McpPrompt meta(String key, Object value) {
        if (metaMap == null) { metaMap = new Map<String, Object>(); }
        metaMap.put(key, value);
        return this;
    }

    public McpPrompt argument(String name, String description, Boolean required) {
        if (String.isBlank(name) || argumentRequired.containsKey(name)) {
            throw new McpConfigurationException('Prompt argument names must be non-blank and unique');
        }
        Map<String, Object> m = new Map<String, Object>{ 'name' => name };
        if (description != null) { m.put('description', description); }
        if (required != null) { m.put('required', required); }
        argumentList.add(m);
        argumentRequired.put(name, required == true);
        return this;
    }

    public String getName() {
        return nameText;
    }

    public abstract McpPromptResult get(McpRequest request);

    public virtual McpCompletion complete(String argumentName, String value, Map<String, String> context) {
        return McpCompletion.none();
    }

    // Internal members used by McpRuntime.
    public Boolean declaresArgument(String name) { return argumentRequired.containsKey(name); }

    public List<String> requiredArguments() {
        List<String> names = new List<String>();
        for (Map<String, Object> a : argumentList) {
            String name = (String) a.get('name');
            if (argumentRequired.get(name)) { names.add(name); }
        }
        return names;
    }

    public Map<String, Object> toWire() {
        Map<String, Object> m = new Map<String, Object>{ 'name' => nameText };
        if (titleText != null) { m.put('title', titleText); }
        if (descriptionText != null) { m.put('description', descriptionText); }
        if (!argumentList.isEmpty()) { m.put('arguments', argumentList); }
        if (iconValue != null) { m.put('icons', new List<Object>{ iconValue.toMap() }); }
        if (metaMap != null) { m.put('_meta', metaMap); }
        return m;
    }
}
