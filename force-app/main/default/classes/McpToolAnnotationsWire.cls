/**
 * @description Normalized wire DTO for tool annotations returned from tools/list.
 */
public inherited sharing class McpToolAnnotationsWire {
    public Boolean readOnlyHint;
    public Boolean destructiveHint;
    public Boolean idempotentHint;
    public Boolean openWorldHint;

    public McpToolAnnotationsWire() {
    }

    public McpToolAnnotationsWire(McpToolAnnotations source) {
        if (source == null) {
            return;
        }

        this.readOnlyHint = source.readOnlyHint;
        this.destructiveHint = source.destructiveHint;
        this.idempotentHint = source.idempotentHint;
        this.openWorldHint = source.openWorldHint;
    }

    public Boolean hasValues() {
        return this.readOnlyHint != null ||
            this.destructiveHint != null ||
            this.idempotentHint != null ||
            this.openWorldHint != null;
    }

    public Map<String, Object> toWire() {
        Map<String, Object> wire = new Map<String, Object>();

        if (this.readOnlyHint != null) {
            wire.put('readOnlyHint', this.readOnlyHint);
        }

        if (this.destructiveHint != null) {
            wire.put('destructiveHint', this.destructiveHint);
        }

        if (this.idempotentHint != null) {
            wire.put('idempotentHint', this.idempotentHint);
        }

        if (this.openWorldHint != null) {
            wire.put('openWorldHint', this.openWorldHint);
        }

        return wire;
    }
}
