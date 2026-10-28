/**
 * Example tool that queries Account records by name. Runs in user mode, so field-level security and
 * object permissions of the calling user apply.
 */
public with sharing class ExampleQueryTool extends McpTool {
    public ExampleQueryTool() {
        super('query_accounts');
        title('Query accounts')
            .description('Search for Account records by name')
            .input(McpSchema.obj()
                .requiredProperty('searchTerm', McpSchema.str().describe('Account name search term').minLength(2).maxLength(80))
                .property('limit', McpSchema.integer().minimum(1).maximum(50))
                .closed())
            .output(McpSchema.obj()
                .requiredProperty('accounts', McpSchema.arr(McpSchema.obj()
                    .requiredProperty('id', McpSchema.str())
                    .requiredProperty('name', McpSchema.str())
                    .property('industry', McpSchema.str().nullable()))))
            .annotations(new McpToolAnnotations().readOnly(true).openWorld(false));
    }

    public override McpToolResult execute(McpRequest request) {
        String escaped = request.requireString('searchTerm').replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_');
        String pattern = '%' + escaped + '%';
        Integer max = request.getInteger('limit') == null ? 10 : request.getInteger('limit');
        List<Object> rows = new List<Object>();
        for (Account a : [SELECT Id, Name, Industry FROM Account WHERE Name LIKE :pattern WITH USER_MODE ORDER BY Name LIMIT :max]) {
            rows.add(new Map<String, Object>{ 'id' => a.Id, 'name' => a.Name, 'industry' => a.Industry });
        }
        return McpToolResult.structured(new Map<String, Object>{ 'accounts' => rows });
    }
}
