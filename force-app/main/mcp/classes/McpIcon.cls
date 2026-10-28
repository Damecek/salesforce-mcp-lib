/**
 * Icon for a server, tool, resource, template or prompt. Only https: and data: sources are accepted.
 */
public inherited sharing class McpIcon {
    private final String source;
    private String mimeTypeText;
    private List<String> sizeList;
    private String themeText;

    public McpIcon(String src) {
        if (String.isBlank(src)) {
            throw new McpConfigurationException('Icon src must not be blank');
        }
        String lower = src.toLowerCase();
        if (!lower.startsWith('https:') && !lower.startsWith('data:')) {
            throw new McpConfigurationException('Icon src must use the https: or data: scheme');
        }
        this.source = src;
    }

    public McpIcon mimeType(String value) {
        this.mimeTypeText = value;
        return this;
    }

    public McpIcon sizes(List<String> values) {
        this.sizeList = values;
        return this;
    }

    public McpIcon theme(String value) {
        if (!McpWire.same(value, 'light') && !McpWire.same(value, 'dark')) {
            throw new McpConfigurationException('Icon theme must be "light" or "dark"');
        }
        this.themeText = value;
        return this;
    }

    public Map<String, Object> toMap() {
        Map<String, Object> m = new Map<String, Object>{ 'src' => source };
        if (mimeTypeText != null) { m.put('mimeType', mimeTypeText); }
        if (sizeList != null) { m.put('sizes', sizeList); }
        if (themeText != null) { m.put('theme', themeText); }
        return m;
    }
}
