/**
 * Interface for mapping arbitrary Apex exceptions to JSON-RPC error objects.
 *
 * Implementations allow applications to translate domain-specific exceptions
 * into meaningful {@link JsonRpcError} responses instead of falling through
 * to the generic internal-error handler.
 */
public interface JsonRpcExceptionMapper {

    /**
     * Maps the given exception to a JSON-RPC error.
     *
     * @param e The caught exception.
     * @return A {@link JsonRpcError} representing the mapped error.
     */
    JsonRpcError mapException(Exception e);
}
