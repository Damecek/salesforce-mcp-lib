/**
 * Optional annotations on content blocks, resources and templates.
 */
public inherited sharing class McpAnnotations {
    private List<String> audienceList;
    private Decimal priorityValue;
    private String lastModifiedText;

    public McpAnnotations audience(List<String> roles) {
        if (roles != null) {
            for (String role : roles) {
                if (!McpWire.same(role, 'user') && !McpWire.same(role, 'assistant')) {
                    throw new McpConfigurationException('Annotation audience must be "user" or "assistant"');
                }
            }
        }
        this.audienceList = roles;
        return this;
    }

    public McpAnnotations priority(Decimal value) {
        if (value != null && (value < 0 || value > 1)) {
            throw new McpConfigurationException('Annotation priority must be between 0 and 1');
        }
        this.priorityValue = value;
        return this;
    }

    public McpAnnotations lastModified(Datetime value) {
        this.lastModifiedText = value == null ? null : value.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        return this;
    }

    public McpAnnotations lastModified(String isoTimestamp) {
        this.lastModifiedText = isoTimestamp;
        return this;
    }

    public Map<String, Object> toMap() {
        Map<String, Object> m = new Map<String, Object>();
        if (audienceList != null) { m.put('audience', audienceList); }
        if (priorityValue != null) { m.put('priority', priorityValue); }
        if (lastModifiedText != null) { m.put('lastModified', lastModifiedText); }
        return m;
    }
}
