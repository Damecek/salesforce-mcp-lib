/**
 * Completion suggestions for a prompt argument or a resource template variable.
 */
public inherited sharing class McpCompletion {
    private final List<String> valueList;
    private Integer totalCount;
    private Boolean hasMoreFlag;

    private McpCompletion(List<String> values) {
        this.valueList = values == null ? new List<String>() : values;
    }

    public static McpCompletion of(List<String> values) {
        return new McpCompletion(values);
    }

    public static McpCompletion none() {
        return new McpCompletion(null);
    }

    public McpCompletion total(Integer value) { this.totalCount = value; return this; }
    public McpCompletion hasMore(Boolean value) { this.hasMoreFlag = value; return this; }

    /** At most 100 values; a longer list is cut with hasMore:true and total set to the original size. */
    public Map<String, Object> toMap() {
        List<String> values = valueList;
        Integer total = totalCount;
        Boolean more = hasMoreFlag;
        if (values.size() > 100) {
            if (total == null) { total = values.size(); }
            more = true;
            List<String> cut = new List<String>();
            for (Integer i = 0; i < 100; i++) { cut.add(values[i]); }
            values = cut;
        }
        Map<String, Object> completion = new Map<String, Object>{ 'values' => values };
        if (total != null) { completion.put('total', total); }
        if (more != null) { completion.put('hasMore', more); }
        return new Map<String, Object>{ 'completion' => completion };
    }
}
