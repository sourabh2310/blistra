# ADR-017: Server-owned AI entry drafts and explicit approval

Status: Accepted  
Date: 2026-10-18

## Context

Blistra AI must collect entry details conversationally, identify missing fields, present a template and create the record only after the user approves it. A language-model statement such as “approved” cannot be evidence of human authorization. Mobile retries and concurrent requests must not create duplicates, and edits must invalidate earlier approvals.

## Decision

Use a fixed server catalog of supported domain create/record operations. Retrieve the chosen operation's DTO field schema at drafting time instead of maintaining a parallel model-defined database schema or an external vector index. Model output is untrusted structured data; quote-based grounding filters proposed values and the user reviews every field before saving. This is not model-weight training or a proof of semantic correctness.

Store the exact draft payload, owner, revision, expiry and state in PostgreSQL. Editing increments the revision. Replacing/cancelling a pending draft makes the old proposal ineligible. The approval endpoint accepts only ID, revision and an explicit review flag, obtains an owner-scoped row lock, and invokes the catalog's pinned domain service. The domain write and applied receipt commit in one transaction; later approvals return the receipt. The model has no approval tool and cannot select SQL, arbitrary URLs, method names or ownership identifiers.

Schema/type/constraint and bounded reference checks happen before review. Existing domain services recheck live permissions and business rules at execution; no validation dry run creates and rolls back domain records. Parent selection uses the existing authenticated APIs. Document uploads retain their real file-picker/review/upload flow. Shared settlements retain peer confirmation; medical fields come from the user, never recommendations by the model.

Drafts expire after 30 minutes. Cleanup removes unused drafts one day after expiry and all draft/receipt rows after 30 days. Deleting the owner cascades deletion. Prompts and provider response bodies are not logged. The privacy notice distinguishes temporary draft persistence from transient chat messages.

## Alternatives

- Direct model tool execution: rejected because model inference must not authorize a write.
- Client-only draft/approval state: rejected because the client could substitute a different payload, replay it, or lose an ambiguous response without a durable receipt.
- Arbitrary endpoint or SQL execution: rejected because domain authorization and validation must remain authoritative.
- Vector retrieval for entry schemas: deferred; DTO metadata is small, exact and versioned with the executable contract.

## Consequences

Every new entry type requires an explicit catalog registration and coverage. Schema changes are reflected in review fields and extraction context. Generic editors cover nested items and references but complex operations may still be easier in their native module forms. One approval creates one entry; the system does not silently execute multi-entry plans. Model/provider behavior still requires live evaluation before rollout.
