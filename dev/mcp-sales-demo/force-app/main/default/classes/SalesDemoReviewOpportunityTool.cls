/** Explains the risk of one open opportunity with the fixed rules in SalesDemoRisk and proposes prioritized next steps. */
public with sharing class SalesDemoReviewOpportunityTool extends McpTool {
    public SalesDemoReviewOpportunityTool() {
        super('sales_demo_review_opportunity');
        title('Review opportunity risk and next steps')
            .description('SYNTHETIC DEMO DATA. Scores one open opportunity with fixed, explainable rules (rules version ' + SalesDemoRisk.RULES_VERSION + ') and lists the triggered factors with evidence and the next steps. Closed or unknown opportunities return a tool error. This is a demo rule set, not a forecast model.')
            .annotations(SalesDemoData.safeHints('Review opportunity risk and next steps'))
            .input(McpSchema.obj().closed().requiredProperty('opportunityId', SalesDemoData.opportunityIdSchema()))
            .output(McpSchema.obj()
                .requiredProperty('demoData', McpSchema.bool())
                .requiredProperty('dataNotice', McpSchema.str())
                .requiredProperty('asOf', McpSchema.str().format('date'))
                .requiredProperty('rulesVersion', McpSchema.str())
                .requiredProperty('opportunity', SalesDemoData.opportunitySchema())
                .requiredProperty('riskScore', McpSchema.integer().minimum(0).maximum(10))
                .requiredProperty('riskLevel', McpSchema.enumOf(SalesDemoData.RISK_LEVELS).describe('high at 5 points or more, medium at 3 or 4, low below 3'))
                .requiredProperty('factors', McpSchema.arr(SalesDemoRisk.factorSchema()).maxItems(5))
                .requiredProperty('nextSteps', McpSchema.arr(SalesDemoRisk.stepSchema()).minItems(1).maxItems(6)));
    }

    public override McpToolResult execute(McpRequest request) {
        SalesDemoData.Opp o = SalesDemoData.requireOpp(request.requireString('opportunityId'));
        if (!o.isOpen()) {
            throw new McpException('Opportunity "' + o.id + '" is ' + o.stage + '. Only open opportunities can be reviewed.');
        }
        SalesDemoRisk.Assessment risk = SalesDemoRisk.evaluate(o);
        return McpToolResult.structured(new Map<String, Object>{
            'demoData' => true, 'dataNotice' => SalesDemoData.NOTICE, 'asOf' => String.valueOf(SalesDemoData.AS_OF),
            'rulesVersion' => SalesDemoRisk.RULES_VERSION, 'opportunity' => SalesDemoData.opportunityMap(o, risk),
            'riskScore' => risk.score, 'riskLevel' => risk.level, 'factors' => risk.factors, 'nextSteps' => risk.steps
        }).add(SalesDemoData.opportunityLink(o)).add(SalesDemoData.accountLink(SalesDemoData.account(o.accountId)));
    }
}
