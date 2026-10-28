/**
 * Small JSON Schema builder with an honest validation subset.
 *
 * Validated: type (string, integer, number, boolean, object, array, plus null via nullable()),
 * properties, required, additionalProperties:false, enum (strings), minLength, maxLength, minimum,
 * maximum, minItems, maxItems, items (single schema). title, description, default and format are
 * emitted but never validated. Lengths count UTF-16 code units.
 */
public inherited sharing class McpSchema {
    public static final Integer MAX_ERRORS = 10;
    public static final Integer RAW_MAX_DEPTH = 16;
    public static final Integer RAW_MAX_NODES = 1000;
    public static final Integer RAW_MAX_COLLECTION = 200;

    private final String kind;
    private Boolean nullableFlag = false;
    private List<String> propertyNames = new List<String>();
    private Map<String, McpSchema> propertyMap = new Map<String, McpSchema>();
    private Set<String> requiredNames = new Set<String>();
    private Boolean closedFlag = false;
    private Integer minLen;
    private Integer maxLen;
    private Decimal minVal;
    private Decimal maxVal;
    private Integer minItemCount;
    private Integer maxItemCount;
    private McpSchema itemSchema;
    private List<String> enumValues;
    private String titleText;
    private String descriptionText;
    private String formatText;
    private Object defaultObject;
    private Boolean hasDefault = false;

    private McpSchema(String kind) {
        this.kind = kind;
    }

    public static McpSchema str() { return new McpSchema('string'); }
    public static McpSchema integer() { return new McpSchema('integer'); }
    public static McpSchema num() { return new McpSchema('number'); }
    public static McpSchema bool() { return new McpSchema('boolean'); }
    public static McpSchema obj() { return new McpSchema('object'); }

    public static McpSchema arr(McpSchema items) {
        McpSchema s = new McpSchema('array');
        s.itemSchema = items;
        return s;
    }

    public static McpSchema enumOf(List<String> values) {
        if (values == null || values.isEmpty()) {
            throw new McpConfigurationException('enumOf requires at least one value');
        }
        McpSchema s = new McpSchema('string');
        s.enumValues = values;
        return s;
    }

    public McpSchema property(String name, McpSchema schema) {
        if (String.isBlank(name) || schema == null) {
            throw new McpConfigurationException('Schema property needs a name and a schema');
        }
        if (this.kind != 'object') {
            throw new McpConfigurationException('Properties can only be added to an object schema');
        }
        if (!propertyMap.containsKey(name)) { propertyNames.add(name); }
        propertyMap.put(name, schema);
        return this;
    }

    public McpSchema requiredProperty(String name, McpSchema schema) {
        property(name, schema);
        requiredNames.add(name);
        return this;
    }

    public McpSchema closed() { this.closedFlag = true; return this; }
    public McpSchema nullable() { this.nullableFlag = true; return this; }
    public McpSchema title(String value) { this.titleText = value; return this; }
    public McpSchema describe(String value) { this.descriptionText = value; return this; }
    public McpSchema format(String value) { this.formatText = value; return this; }
    public McpSchema defaultValue(Object value) { this.defaultObject = value; this.hasDefault = true; return this; }
    public McpSchema minLength(Integer value) { this.minLen = value; return this; }
    public McpSchema maxLength(Integer value) { this.maxLen = value; return this; }
    public McpSchema minimum(Decimal value) { this.minVal = value; return this; }
    public McpSchema maximum(Decimal value) { this.maxVal = value; return this; }
    public McpSchema minItems(Integer value) { this.minItemCount = value; return this; }
    public McpSchema maxItems(Integer value) { this.maxItemCount = value; return this; }

    public String kindName() {
        return kind;
    }

    public Map<String, Object> toMap() {
        Map<String, Object> m = new Map<String, Object>();
        if (nullableFlag) {
            m.put('type', new List<Object>{ kind, 'null' });
        } else {
            m.put('type', kind);
        }
        if (titleText != null) { m.put('title', titleText); }
        if (descriptionText != null) { m.put('description', descriptionText); }
        if (formatText != null) { m.put('format', formatText); }
        if (hasDefault) { m.put('default', defaultObject); }
        if (enumValues != null) { m.put('enum', enumValues); }
        if (minLen != null) { m.put('minLength', minLen); }
        if (maxLen != null) { m.put('maxLength', maxLen); }
        if (minVal != null) { m.put('minimum', minVal); }
        if (maxVal != null) { m.put('maximum', maxVal); }
        if (minItemCount != null) { m.put('minItems', minItemCount); }
        if (maxItemCount != null) { m.put('maxItems', maxItemCount); }
        if (kind == 'object') {
            Map<String, Object> props = new Map<String, Object>();
            for (String name : propertyNames) {
                props.put(name, propertyMap.get(name).toMap());
            }
            m.put('properties', props);
            if (!requiredNames.isEmpty()) {
                List<String> required = new List<String>();
                for (String name : propertyNames) {
                    if (requiredNames.contains(name)) { required.add(name); }
                }
                m.put('required', required);
            }
            if (closedFlag) { m.put('additionalProperties', false); }
        }
        if (itemSchema != null) { m.put('items', itemSchema.toMap()); }
        return m;
    }

    /**
     * Validates a value against this schema. Returns at most MAX_ERRORS messages, empty when valid.
     * Recursion follows the schema, so its depth is bounded by the (registration-checked) schema depth.
     */
    public List<String> validate(Object value, String path) {
        List<String> errors = new List<String>();
        check(value, path, errors);
        return errors;
    }

    private void check(Object value, String path, List<String> errors) {
        if (errors.size() >= MAX_ERRORS) { return; }
        if (value == null) {
            if (!nullableFlag) { report(errors, path + ': must not be null'); }
            return;
        }
        if (kind == 'string') {
            checkString(value, path, errors);
        } else if (kind == 'integer' || kind == 'number') {
            checkNumber(value, path, errors);
        } else if (kind == 'boolean') {
            if (!(value instanceof Boolean)) { report(errors, path + ': must be a boolean'); }
        } else if (kind == 'object') {
            checkObject(value, path, errors);
        } else if (kind == 'array') {
            checkArray(value, path, errors);
        }
    }

    private void checkString(Object value, String path, List<String> errors) {
        if (!(value instanceof String)) {
            report(errors, path + ': must be a string');
            return;
        }
        String s = (String) value;
        if (minLen != null && s.length() < minLen) { report(errors, path + ': must have at least ' + minLen + ' characters'); }
        if (maxLen != null && s.length() > maxLen) { report(errors, path + ': must have at most ' + maxLen + ' characters'); }
        if (enumValues != null) {
            Boolean found = false;
            for (String allowed : enumValues) {
                if (McpWire.same(allowed, s)) { found = true; break; }
            }
            if (!found) { report(errors, path + ': must be one of ' + String.join(enumValues, ', ')); }
        }
    }

    private void checkNumber(Object value, String path, List<String> errors) {
        Decimal d = toDecimal(value);
        if (d == null) {
            report(errors, path + ': must be ' + (kind == 'integer' ? 'an integer' : 'a number'));
            return;
        }
        if (kind == 'integer' && d.stripTrailingZeros().scale() > 0) {
            report(errors, path + ': must be an integer');
            return;
        }
        if (minVal != null && d < minVal) { report(errors, path + ': must be at least ' + minVal); }
        if (maxVal != null && d > maxVal) { report(errors, path + ': must be at most ' + maxVal); }
    }

    private void checkObject(Object value, String path, List<String> errors) {
        if (!(value instanceof Map<String, Object>)) {
            report(errors, path + ': must be an object');
            return;
        }
        Map<String, Object> m = (Map<String, Object>) value;
        for (String name : propertyNames) {
            if (errors.size() >= MAX_ERRORS) { return; }
            if (requiredNames.contains(name) && !m.containsKey(name)) {
                report(errors, path + '.' + name + ': is required');
            }
        }
        for (String name : propertyNames) {
            if (errors.size() >= MAX_ERRORS) { return; }
            if (m.containsKey(name)) { propertyMap.get(name).check(m.get(name), path + '.' + name, errors); }
        }
        if (closedFlag) {
            for (String key : m.keySet()) {
                if (errors.size() >= MAX_ERRORS) { return; }
                if (!propertyMap.containsKey(key)) { report(errors, path + '.' + key + ': is not allowed'); }
            }
        }
    }

    private void checkArray(Object value, String path, List<String> errors) {
        if (!(value instanceof List<Object>)) {
            report(errors, path + ': must be an array');
            return;
        }
        List<Object> items = (List<Object>) value;
        if (minItemCount != null && items.size() < minItemCount) { report(errors, path + ': must have at least ' + minItemCount + ' items'); }
        if (maxItemCount != null && items.size() > maxItemCount) { report(errors, path + ': must have at most ' + maxItemCount + ' items'); }
        if (itemSchema != null) {
            for (Integer i = 0; i < items.size() && errors.size() < MAX_ERRORS; i++) {
                itemSchema.check(items[i], path + '[' + i + ']', errors);
            }
        }
    }

    private static void report(List<String> errors, String message) {
        if (errors.size() < MAX_ERRORS) { errors.add(message); }
    }

    private static Decimal toDecimal(Object value) {
        if (value instanceof Integer) { return Decimal.valueOf((Integer) value); }
        if (value instanceof Long) { return Decimal.valueOf((Long) value); }
        if (value instanceof Decimal) { return (Decimal) value; }
        if (value instanceof Double) { return Decimal.valueOf((Double) value); }
        return null;
    }

    /**
     * Registration check for a raw or built schema map. The walk is iterative and counts every value,
     * including data-like leaves (enum, default, examples), against the node and collection limits.
     * Rejects any x-mcp-header key and any $ref that does not start with '#'.
     */
    public static void checkRaw(Map<String, Object> raw, Boolean requireObjectRoot, String label) {
        if (raw == null) {
            throw new McpConfigurationException(label + ' must not be null');
        }
        if (requireObjectRoot && !McpWire.same(raw.get('type'), 'object')) {
            throw new McpConfigurationException(label + ' root type must be "object"');
        }
        List<Object> stack = new List<Object>{ raw };
        List<Integer> depths = new List<Integer>{ 0 };
        Integer nodes = 0;
        while (!stack.isEmpty()) {
            Integer last = stack.size() - 1;
            Object value = stack.remove(last);
            Integer depth = depths.remove(last);
            nodes++; // counted so guardCollection sees processed plus pending nodes
            if (value instanceof Map<String, Object>) {
                Map<String, Object> m = (Map<String, Object>) value;
                guardCollection(depth, m.size(), nodes + stack.size(), label);
                for (String key : m.keySet()) {
                    Object child = m.get(key);
                    if (McpWire.same(key, 'x-mcp-header')) {
                        throw new McpConfigurationException(label + ' must not use x-mcp-header');
                    }
                    if (McpWire.same(key, '$ref') && !(child instanceof String && ((String) child).startsWith('#'))) {
                        throw new McpConfigurationException(label + ' $ref must be a local reference starting with #');
                    }
                    stack.add(child);
                    depths.add(depth + 1);
                }
            } else if (value instanceof List<Object>) {
                List<Object> l = (List<Object>) value;
                guardCollection(depth, l.size(), nodes + stack.size(), label);
                for (Object item : l) {
                    stack.add(item);
                    depths.add(depth + 1);
                }
            } else if (!McpWire.isScalar(value)) {
                throw new McpConfigurationException(label + ' contains a value that is not JSON-native (for example a Set or a custom object)');
            }
        }
    }

    private static void guardCollection(Integer depth, Integer size, Integer pending, String label) {
        if (depth >= RAW_MAX_DEPTH) {
            throw new McpConfigurationException(label + ' is nested deeper than ' + RAW_MAX_DEPTH + ' levels');
        }
        if (size > RAW_MAX_COLLECTION || pending + size > RAW_MAX_NODES) {
            throw new McpConfigurationException(label + ' has a collection larger than the allowed size');
        }
    }
}
