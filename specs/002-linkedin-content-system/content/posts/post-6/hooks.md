# Hooks: Post 6 — Salesforce Has a New Interface — This One Is for AI Agents

**Topic**: 6 — Salesforce Has a New Interface — This One Is for AI Agents

## 1. Pain-First

You've spent years building business logic in Salesforce — screen flows, SOQL queries, validation rules. Now an AI agent needs the same data and processes, and your options are: rebuild everything as REST endpoints, or replicate data into yet another system.
There should be a third option.

## 2. Misconception-First

Most teams think connecting AI agents to Salesforce means building new APIs or exporting data. But the logic is already there — what's missing isn't the capability, it's the interface.
Page layouts serve humans. MCP tools serve agents. Same org, same security, same data.

## 3. Architecture-First

`ExampleQueryTool.cls` is 35 lines of Apex. It wraps a SOQL query in three methods — `inputSchema()`, `validate()`, `execute()` — and exposes it as an MCP tool that any AI agent can discover and call.
That same query powered a record page yesterday. Today it powers an agent.

## 4. Business-First

One Salesforce org. Years of tested business logic. Screen flows, SOQL queries, approval processes — all built for humans. Now accessible to AI agents through the same security model, without moving data or rewriting logic.
The interface changed. The business logic didn't.

## 5. Curiosity-First

What if every screen flow in your Salesforce org was also an AI agent tool?
Not rebuilt as an API. Not replicated in middleware. The exact same subflow, called by an agent through a standard protocol, with the same permissions your users already have.
