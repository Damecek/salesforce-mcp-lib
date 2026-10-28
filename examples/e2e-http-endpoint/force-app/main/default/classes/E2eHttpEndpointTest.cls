@IsTest
private class E2eHttpEndpointTest {
    private static Map<String, Object> call(String method, String params) {
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.headers.put('MCP-Protocol-Version', '2025-11-25');
        req.requestBody = Blob.valueOf('{"jsonrpc":"2.0","id":1,"method":"' + method + '","params":' + params + '}');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        E2eHttpEndpoint.post();
        return (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
    }

    @IsTest
    static void queryToolFindsAccountsAndEscapesWildcards() {
        insert new List<Account>{ new Account(Name = 'Acme 100%'), new Account(Name = 'Acme Corp') };
        Map<String, Object> result = (Map<String, Object>) call('tools/call', '{"name":"query_accounts","arguments":{"searchTerm":"100%"}}').get('result');
        List<Object> accounts = (List<Object>) ((Map<String, Object>) result.get('structuredContent')).get('accounts');
        Assert.areEqual(1, accounts.size());
        Assert.areEqual('Acme 100%', ((Map<String, Object>) accounts[0]).get('name'));
    }

    @IsTest
    static void templateReadsOneAccountAndReportsMissingOnes() {
        Account a = new Account(Name = 'Read me');
        insert a;
        Map<String, Object> found = (Map<String, Object>) call('resources/read', '{"uri":"salesforce://account/' + a.Id + '"}').get('result');
        Assert.areEqual(1, ((List<Object>) found.get('contents')).size());
        Assert.isNotNull(call('resources/read', '{"uri":"salesforce://account/not-an-id"}').get('error'));
        Assert.isNotNull(call('resources/read', '{"uri":"salesforce://account/001000000000000AAA"}').get('error'));
    }

    @IsTest
    static void orgResourceAndPromptWork() {
        Map<String, Object> org = (Map<String, Object>) call('resources/read', '{"uri":"salesforce://org/info"}').get('result');
        Assert.isNotNull(org.get('contents'));
        Map<String, Object> prompt = (Map<String, Object>) call('prompts/get', '{"name":"summarize_record","arguments":{"objectName":"Account","recordId":"001"}}').get('result');
        Assert.areEqual(1, ((List<Object>) prompt.get('messages')).size());
    }
}
