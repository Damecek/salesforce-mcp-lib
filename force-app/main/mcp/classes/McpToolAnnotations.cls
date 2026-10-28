/**
 * Behaviour hints for a tool. Clients must treat them as untrusted hints.
 */
public inherited sharing class McpToolAnnotations {
    private String titleText;
    private Boolean readOnlyHint;
    private Boolean destructiveHint;
    private Boolean idempotentHint;
    private Boolean openWorldHint;

    public McpToolAnnotations title(String value) {
        this.titleText = value;
        return this;
    }

    public McpToolAnnotations readOnly(Boolean value) {
        this.readOnlyHint = value;
        return this;
    }

    public McpToolAnnotations destructive(Boolean value) {
        this.destructiveHint = value;
        return this;
    }

    public McpToolAnnotations idempotent(Boolean value) {
        this.idempotentHint = value;
        return this;
    }

    public McpToolAnnotations openWorld(Boolean value) {
        this.openWorldHint = value;
        return this;
    }

    public Map<String, Object> toMap() {
        Map<String, Object> m = new Map<String, Object>();
        if (titleText != null) { m.put('title', titleText); }
        if (readOnlyHint != null) { m.put('readOnlyHint', readOnlyHint); }
        if (destructiveHint != null) { m.put('destructiveHint', destructiveHint); }
        if (idempotentHint != null) { m.put('idempotentHint', idempotentHint); }
        if (openWorldHint != null) { m.put('openWorldHint', openWorldHint); }
        return m;
    }
}
