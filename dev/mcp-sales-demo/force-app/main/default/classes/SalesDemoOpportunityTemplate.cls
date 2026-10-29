/** Resource template demo-sales://opportunities/{opportunityId}: a markdown risk explanation for one opportunity. */
public with sharing class SalesDemoOpportunityTemplate extends McpResourceTemplate {
    public SalesDemoOpportunityTemplate() {
        super(SalesDemoData.OPPORTUNITY_URI + '{opportunityId}', 'opportunity_review');
        title('Opportunity review (demo)').description('SYNTHETIC DEMO. Markdown summary of one opportunity with its triggered risk rules.').mimeType('text/markdown');
    }

    public override McpResourceResult read(McpRequest request) {
        SalesDemoData.Opp o = SalesDemoData.opp(request.variable('opportunityId'));
        if (o == null) { return null; }
        SalesDemoData.Account a = SalesDemoData.account(o.accountId);
        List<String> lines = new List<String>{
            '# ' + o.name, SalesDemoData.NOTICE, '',
            a.name + ', ' + o.stage + ', ' + o.amount + ' ' + a.currencyCode + ', closes ' + String.valueOf(o.closeDate) + '.'
        };
        if (o.isOpen()) {
            SalesDemoRisk.Assessment risk = SalesDemoRisk.evaluate(o);
            lines.add('Risk: ' + risk.level + ' (' + risk.score + ' points).');
            for (Map<String, Object> f : risk.factors) { lines.add('- ' + f.get('rule') + ' (+' + f.get('points') + '): ' + f.get('evidence')); }
        } else {
            lines.add('Closed, not scored.');
        }
        return McpResourceResult.of(McpResourceContents.text(request.uri(), 'text/markdown', String.join(lines, '\n')));
    }

    public override McpCompletion complete(String argumentName, String value, Map<String, String> context) {
        String prefix = value == null ? '' : value.toLowerCase();
        List<String> hits = new List<String>();
        for (SalesDemoData.Account a : SalesDemoData.accounts()) {
            for (SalesDemoData.Opp o : SalesDemoData.oppsFor(a.id, true)) {
                if (o.id.startsWith(prefix)) { hits.add(o.id); }
            }
        }
        return McpCompletion.of(hits).total(hits.size()).hasMore(false);
    }
}
