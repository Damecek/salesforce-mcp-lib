/**
 * Typed representation of a JSON-RPC 2.0 request ID.
 *
 * Per the JSON-RPC 2.0 specification the id field MUST be a String,
 * an Integer (Number with no fractional part), or null. This class
 * wraps the raw value and provides safe factory construction plus
 * serialization helpers.
 */
public class JsonRpcIdValue {

    private final Object value;

    /**
     * Private constructor -- use factory methods to create instances.
     *
     * @param value The raw ID value (String, Integer, or null).
     */
    private JsonRpcIdValue(Object value) {
        this.value = value;
    }

    // ── Factory methods ──────────────────────────────────────────────

    /**
     * Creates an ID from a String value.
     *
     * @param value The string identifier.
     * @return A new JsonRpcIdValue wrapping the string.
     */
    public static JsonRpcIdValue fromString(String value) {
        return new JsonRpcIdValue(value);
    }

    /**
     * Creates an ID from an Integer value.
     *
     * @param value The integer identifier.
     * @return A new JsonRpcIdValue wrapping the integer.
     */
    public static JsonRpcIdValue fromInteger(Integer value) {
        return new JsonRpcIdValue(value);
    }

    /**
     * Creates a null ID (valid per JSON-RPC 2.0 for error responses
     * where the request id could not be determined).
     *
     * @return A new JsonRpcIdValue representing null.
     */
    public static JsonRpcIdValue fromNull() {
        return new JsonRpcIdValue(null);
    }

    /**
     * Auto-detects the type from a raw deserialized JSON value.
     *
     * <p>{@code JSON.deserializeUntyped()} produces String, Integer/Long/Decimal,
     * or null. This factory normalises the value to String, Integer, or null.</p>
     *
     * @param raw The raw object obtained from JSON deserialization.
     * @return A new JsonRpcIdValue with the appropriate type.
     */
    public static JsonRpcIdValue fromRaw(Object raw) {
        if (raw == null) {
            return fromNull();
        }
        if (raw instanceof String) {
            return fromString((String) raw);
        }
        if (raw instanceof Integer) {
            return fromInteger((Integer) raw);
        }
        if (raw instanceof Long) {
            return fromInteger(((Long) raw).intValue());
        }
        if (raw instanceof Decimal) {
            return fromInteger(((Decimal) raw).intValue());
        }
        return new JsonRpcIdValue(raw);
    }

    // ── Instance methods ─────────────────────────────────────────────

    /**
     * Returns the raw value suitable for inclusion in a JSON-RPC response.
     *
     * @return The underlying String, Integer, or null.
     */
    public Object serialize() {
        return this.value;
    }

    /**
     * Indicates whether this ID represents a null value.
     *
     * @return {@code true} when the stored value is null.
     */
    public Boolean isNull() {
        return this.value == null;
    }
}
