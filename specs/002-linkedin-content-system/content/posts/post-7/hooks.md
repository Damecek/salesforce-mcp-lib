# Hooks: Post 7 - Generic Salesforce Access Is Not the Same as Agent-Usable Operations

**Topic**: 7 - Generic Salesforce Access Is Not the Same as Agent-Usable Operations

## 1. Pain-First

An AI agent queried hundreds of Salesforce records just to update one.
That is not a model failure. That is what happens when the tool surface knows your CRM only in generic terms.

## 2. Misconception-First

People keep saying agents just need access to Salesforce.
They do not. They need the right operations, with the right names, at the right level of business meaning.

## 3. Architecture-First

`salesforce-mcp-lib` does not auto-discover your org and hope for the best.
You register tools explicitly in Apex with `McpServer`, and the endpoint advertises only what you chose to expose.

## 4. Business-First

If the agent has to query 500 records to update one, the hidden cost is not intelligence.
It is wasted API budget, brittle plans, and a tool contract that is too generic for the business task.

## 5. Curiosity-First

What changes if an agent sees `update_billing_contact` instead of "search Accounts" plus "update record"?
Usually, fewer guesses, fewer queries, and a much shorter path to the right outcome.
