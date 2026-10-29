/** Deterministic, explainable opportunity risk rules (SYNTHETIC demo, rules version sales-demo-rules-1). Not a forecast model. */
public with sharing class SalesDemoRisk {
    public static final String RULES_VERSION = 'sales-demo-rules-1';

    public class Assessment {
        public Integer score = 0;
        public String level = 'low';
        public List<Map<String, Object>> factors = new List<Map<String, Object>>();
        public List<Map<String, Object>> steps = new List<Map<String, Object>>();
    }

    public static Assessment evaluate(SalesDemoData.Opp o) {
        Assessment a = new Assessment();
        Integer toClose = o.daysToClose();
        Integer idle = o.daysSinceActivity();
        if (toClose < 0) {
            add(a, 'overdue_close_date', 3, 'Close date ' + String.valueOf(o.closeDate) + ' passed ' + (-toClose) + ' days before 2026-10-29', 'Agree a revised close date with the buyer and update the opportunity');
        } else if (toClose <= 14 && (o.stage == 'prospecting' || o.stage == 'qualification')) {
            add(a, 'imminent_close_early_stage', 2, 'Closes in ' + toClose + ' days but the stage is ' + o.stage, 'Confirm scope and budget now, or move the close date to match the stage');
        }
        if (idle >= 30) {
            add(a, 'stale_activity', 3, 'Last activity ' + idle + ' days ago (30 or more)', 'Re-engage this week with a short check-in call');
        } else if (idle >= 14) {
            add(a, 'stale_activity', 2, 'Last activity ' + idle + ' days ago (14 to 29)', 'Schedule a check-in before the deal goes cold');
        }
        if (!o.decisionMakerEngaged) {
            add(a, 'no_decision_maker', 2, 'No decision maker engaged yet', 'Ask the champion to introduce the person who signs off');
        }
        if (!o.nextStepScheduled) {
            add(a, 'no_next_step', 1, 'No next step is scheduled', 'Book the next meeting or milestone with a date');
        }
        a.level = a.score >= 5 ? 'high' : (a.score >= 3 ? 'medium' : 'low');
        if (a.steps.isEmpty()) {
            a.steps.add(new Map<String, Object>{ 'priority' => 1, 'action' => 'Keep the current cadence and confirm the next milestone', 'rule' => 'none_triggered' });
        }
        return a;
    }

    private static void add(Assessment a, String rule, Integer points, String evidence, String action) {
        a.score += points;
        a.factors.add(new Map<String, Object>{ 'rule' => rule, 'points' => points, 'evidence' => evidence });
        a.steps.add(new Map<String, Object>{ 'priority' => a.steps.size() + 1, 'action' => action, 'rule' => rule });
    }

    public static McpSchema factorSchema() {
        return McpSchema.obj().requiredProperty('rule', McpSchema.str()).requiredProperty('points', McpSchema.integer().minimum(1).maximum(3)).requiredProperty('evidence', McpSchema.str());
    }

    public static McpSchema stepSchema() {
        return McpSchema.obj().requiredProperty('priority', McpSchema.integer().minimum(1)).requiredProperty('action', McpSchema.str()).requiredProperty('rule', McpSchema.str());
    }
}
