/**
 * Base class for a resource template (RFC 6570 level 1). Read through resources/read.
 */
public abstract inherited sharing class McpResourceTemplate {
    private final McpUriTemplate parsed;
    private final String nameText;
    private String titleText;
    private String descriptionText;
    private String mimeTypeText;
    private McpAnnotations annotationsValue;
    private McpIcon iconValue;
    private Map<String, Object> metaMap;

    public McpResourceTemplate(String uriTemplate, String name) {
        if (String.isBlank(name)) {
            throw new McpConfigurationException('Resource template needs a name');
        }
        this.parsed = new McpUriTemplate(uriTemplate);
        this.nameText = name;
    }

    public McpResourceTemplate title(String value) { this.titleText = value; return this; }
    public McpResourceTemplate description(String value) { this.descriptionText = value; return this; }
    public McpResourceTemplate mimeType(String value) { this.mimeTypeText = value; return this; }
    public McpResourceTemplate annotations(McpAnnotations value) { this.annotationsValue = value; return this; }
    public McpResourceTemplate icon(McpIcon value) { this.iconValue = value; return this; }

    public McpResourceTemplate meta(String key, Object value) {
        if (metaMap == null) { metaMap = new Map<String, Object>(); }
        metaMap.put(key, value);
        return this;
    }

    public String getUriTemplate() {
        return parsed.template();
    }

    public McpUriTemplate uriTemplateParser() {
        return parsed;
    }

    /** Return null when no resource exists for the matched variables. */
    public abstract McpResourceResult read(McpRequest request);

    public virtual McpCompletion complete(String argumentName, String value, Map<String, String> context) {
        return McpCompletion.none();
    }

    public Map<String, Object> toWire() {
        Map<String, Object> m = new Map<String, Object>{ 'uriTemplate' => parsed.template(), 'name' => nameText };
        if (titleText != null) { m.put('title', titleText); }
        if (descriptionText != null) { m.put('description', descriptionText); }
        if (mimeTypeText != null) { m.put('mimeType', mimeTypeText); }
        if (annotationsValue != null) { m.put('annotations', annotationsValue.toMap()); }
        if (iconValue != null) { m.put('icons', new List<Object>{ iconValue.toMap() }); }
        if (metaMap != null) { m.put('_meta', metaMap); }
        return m;
    }
}
