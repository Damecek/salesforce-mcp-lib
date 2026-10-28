/**
 * Internal. Carries a JSON-RPC error plus the HTTP status the Streamable HTTP transport must use.
 */
public class McpProtocolException extends Exception {
    public Integer errorCode;
    public Object errorData;
    public Integer httpStatus;

    public McpProtocolException(Integer errorCode, String message, Integer httpStatus) {
        this(message);
        this.errorCode = errorCode;
        this.httpStatus = httpStatus;
    }

    public McpProtocolException(Integer errorCode, String message, Integer httpStatus, Object errorData) {
        this(errorCode, message, httpStatus);
        this.errorData = errorData;
    }
}
