/**
 * Marker object for a single client capability.
 *
 * <p>An instance of this class is present in
 * {@link McpInitializeCapabilities} when the client supports the
 * corresponding capability. The class intentionally has no fields --
 * its mere presence in the deserialized structure is the signal.</p>
 */
public class McpInitializeCapabilityEntry {
    // Empty marker -- presence indicates capability support.
}
