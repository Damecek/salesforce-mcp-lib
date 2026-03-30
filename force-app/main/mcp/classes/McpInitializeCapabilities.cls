/**
 * Client capabilities declared during MCP initialization.
 *
 * <p>Each field is an optional capability entry whose presence indicates
 * the client supports that capability.</p>
 */
public class McpInitializeCapabilities {

    /** Root-listing capability. Present when the client can supply workspace roots. */
    public McpInitializeCapabilityEntry roots;

    /** Sampling capability. Present when the client supports LLM sampling requests. */
    public McpInitializeCapabilityEntry sampling;
}
