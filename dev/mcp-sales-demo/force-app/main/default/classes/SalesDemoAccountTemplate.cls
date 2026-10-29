/** Resource template demo-sales://accounts/{accountId}: a markdown brief for one synthetic account. */
public with sharing class SalesDemoAccountTemplate extends McpResourceTemplate {
    public SalesDemoAccountTemplate() {
        super(SalesDemoData.ACCOUNT_URI + '{accountId}', 'account_brief');
        title('Account brief (demo)').description('SYNTHETIC DEMO. Markdown brief of one account and its open opportunities.').mimeType('text/markdown');
    }

    public override McpResourceResult read(McpRequest request) {
        SalesDemoData.Account a = SalesDemoData.account(request.variable('accountId'));
        if (a == null) { return null; }
        List<String> lines = new List<String>{
            '# ' + a.name, SalesDemoData.NOTICE, '',
            'Segment ' + a.segment + ', region ' + a.region + ', owner ' + a.owner + ', currency ' + a.currencyCode + '.',
            'Open pipeline: ' + SalesDemoData.openPipeline(a.id) + ' ' + a.currencyCode + '.', '', '## Open opportunities'
        };
        for (SalesDemoData.Opp o : SalesDemoData.oppsFor(a.id, false)) {
            lines.add('- ' + o.id + ': ' + o.name + ', ' + o.stage + ', ' + o.amount + ' ' + a.currencyCode + ', closes ' + String.valueOf(o.closeDate) + ', risk ' + SalesDemoRisk.evaluate(o).level);
        }
        if (lines[lines.size() - 1] == '## Open opportunities') { lines.add('None.'); }
        return McpResourceResult.of(McpResourceContents.text(request.uri(), 'text/markdown', String.join(lines, '\n')));
    }

    public override McpCompletion complete(String argumentName, String value, Map<String, String> context) {
        return SalesDemoMeetingPrompt.accountIds(value);
    }
}
