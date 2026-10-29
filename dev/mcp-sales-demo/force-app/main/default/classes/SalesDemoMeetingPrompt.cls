/** Prompt prepare_account_meeting: tells the assistant how to prepare a meeting with the demo tools and embeds the playbook. */
public with sharing class SalesDemoMeetingPrompt extends McpPrompt {
    public SalesDemoMeetingPrompt() {
        super('prepare_account_meeting');
        title('Prepare an account meeting (demo)')
            .description('SYNTHETIC DEMO. Builds a meeting-preparation request for one account and an optional goal.')
            .argument('accountId', 'Demo account id, for example demo-account-northstar', true)
            .argument('goal', 'Meeting goal: ' + String.join(SalesDemoData.GOALS, ', '), false);
    }

    public override McpPromptResult get(McpRequest request) {
        SalesDemoData.Account a = SalesDemoData.requireAccount(request.promptArguments().get('accountId'));
        String goal = request.promptArguments().get('goal');
        if (goal != null && !SalesDemoData.GOALS.contains(goal)) {
            throw new McpException('Unknown goal "' + goal.abbreviate(64) + '". Use one of: ' + String.join(SalesDemoData.GOALS, ', '));
        }
        String text = 'Prepare me for a meeting with ' + a.name + ' (' + a.id + '). Goal: ' + (goal == null ? 'general account review' : goal) + '.\n'
            + '1. Call sales_demo_get_account_brief for ' + a.id + '.\n'
            + '2. Call sales_demo_review_opportunity for every opportunity with riskLevel medium or high.\n'
            + '3. Call sales_demo_draft_follow_up with channel meeting_agenda for the riskiest one.\n'
            + 'The data is synthetic. Do not claim it is real CRM data and do not send anything.';
        return new McpPromptResult().description('Meeting preparation for ' + a.name)
            .user(McpContent.text(text))
            .user(McpContent.embedded(McpResourceContents.text(SalesDemoPlaybookResource.URI, 'text/markdown', SalesDemoPlaybookResource.text())))
            .user(SalesDemoData.accountLink(a));
    }

    public override McpCompletion complete(String argumentName, String value, Map<String, String> context) {
        if (argumentName == 'accountId') { return accountIds(value); }
        String prefix = value == null ? '' : value.toLowerCase();
        List<String> hits = new List<String>();
        for (String g : SalesDemoData.GOALS) { if (g.startsWith(prefix)) { hits.add(g); } }
        return McpCompletion.of(hits).total(hits.size()).hasMore(false);
    }

    public static McpCompletion accountIds(String value) {
        String prefix = value == null ? '' : value.toLowerCase();
        List<String> hits = new List<String>();
        for (SalesDemoData.Account a : SalesDemoData.accounts()) { if (a.id.startsWith(prefix)) { hits.add(a.id); } }
        return McpCompletion.of(hits).total(hits.size()).hasMore(false);
    }
}
