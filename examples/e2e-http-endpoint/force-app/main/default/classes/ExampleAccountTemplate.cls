/**
 * Example resource template: salesforce://account/{id} reads one Account in user mode.
 */
public with sharing class ExampleAccountTemplate extends McpResourceTemplate {
    public ExampleAccountTemplate() {
        super('salesforce://account/{id}', 'account');
        title('Account').description('One Account record as JSON').mimeType('application/json');
    }

    public override McpResourceResult read(McpRequest request) {
        Id recordId;
        try {
            recordId = Id.valueOf(request.variable('id'));
        } catch (Exception e) {
            return null;
        }
        List<Account> rows = [SELECT Id, Name, Industry FROM Account WHERE Id = :recordId WITH USER_MODE LIMIT 1];
        if (rows.isEmpty()) { return null; }
        return McpResourceResult.of(McpResourceContents.text(request.uri(), 'application/json', JSON.serialize(rows[0])));
    }
}
