# Hooks: Post 1 — Your Salesforce Org Already Speaks AI — It Just Needs a Protocol

**Topic**: 1 — Your Salesforce Org Already Speaks AI — It Just Needs a Protocol

## 1. Pain-First
You've built three custom REST endpoints this quarter just to let AI agents read Salesforce data.
Each one has its own auth flow, its own error handling, and its own documentation that no agent can discover on its own.
There's a protocol that eliminates all of that — and it runs natively in Apex.

## 2. Misconception-First
Everyone assumes connecting AI to Salesforce means pulling data out of the org.
Extract, transform, feed to a model — it's the default playbook. But the org already has the data, the permissions, and the business logic.
What it was missing was a protocol. Now it has one.

## 3. Architecture-First
77 Apex classes. 6 TypeScript modules. Zero external production dependencies.
That's the full stack of a native MCP server running inside Salesforce — no middleware, no third-party libraries, no node_modules.
Here's why the "zero dependencies" constraint was a design requirement, not a limitation.

## 4. Business-First
A single Salesforce MCP endpoint replaces every custom REST integration your AI agents currently depend on.
One protocol, one security model, one deploy — and every agent that connects tomorrow uses the same standard interface.
The first endpoint takes 12 lines of Apex.

## 5. Curiosity-First
What if your Salesforce org could tell an AI agent exactly what it's capable of — every tool, every resource, every prompt — without you writing a single line of documentation?
That's what the Model Context Protocol does. And it now runs natively in Apex.
