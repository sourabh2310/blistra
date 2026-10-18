# Blistra AI

Open the sparkle button on a main app screen. Blistra AI can explain the app, help plan, and prepare entries for explicit approval.

## Collect → validate → review → approve

1. Describe what to add and provide the relevant details. The model retrieves the selected entry type's actual DTO field schema, required fields, supported choices and descriptions.
2. Required fields, formats, bean constraints, common conditional rules and owned resource references are checked on the server. Missing/invalid fields remain visible on a draft; approval is disabled.
3. A review card shows the destination, proposed values, unprovided optional fields/module defaults, and effects such as shared expenses or replacement of an existing habit schedule.
4. Use **Edit** for labeled fields, record selectors, choices, date/time pickers and nested items, then **Validate and review**. Edits increment the revision and reset the review checkbox. Alternatively, reply in chat with more details to produce a replacement draft.
5. Check that every field matches the details you supplied, then press **Approve and add**. Writing “approve” in chat cannot execute a command. The model never calls the approval endpoint.
6. Blistra's existing domain service checks live business rules and ownership again, saves the entry and returns a receipt. The app refreshes its dashboard/reminder data. **View in [module]** opens the owning screen.

One entry is saved per approval. Separate entries/schedules require separate reviews. Cancelled, superseded, expired or stale revisions cannot save. Drafts expire after 30 minutes. A row lock and stored receipt make duplicate/concurrent approval requests idempotent. Approval sends only the draft ID, revision and explicit review flag; it cannot replace the reviewed payload. If a response is lost, retry approval of that same draft rather than creating another one. Domain writes and the applied receipt commit atomically.

## Supported entries

| Module | Supported operations |
| --- | --- |
| Planner | Tasks, task lists, events |
| Health | Measurements, activities, sleep, symptom logs, health events, appointments |
| Medicines | Medicine records, schedules, dose records, refills |
| Diet | Meals with food items, items added to an existing meal, water intake |
| Habits | Habits, progress records, create/replace a habit schedule |
| Finance | Expenses and splits, accounts, categories, transactions, transfers, settlement proposals, trip groups |
| Reminders | General reminders |
| Documents | Opens the existing file picker/upload review form; the user selects the real file and explicitly uploads it |

The AI does not delete records, change account/security settings, invite other users, confirm another participant's settlement, or invent medical instructions. Settlement proposals still require the other participant's confirmation. Reminder delivery remains subject to permissions and device synchronization. Configured reminder type/timezone are deterministic module/profile settings displayed on the review card. Other unprovided optional fields use existing module defaults.

## Retrieval and model boundaries

The action catalog is an explicit server allowlist. Model output cannot select URLs, classes, database tables, SQL or methods. The small first request selects an entry type; a second request receives only that type's schema and the current draft. Recent chat context is bounded to 4,000 characters; unchanged draft fields remain available after older turns fall out of context. User-supplied values are filtered against exact supporting user quotes, with controlled status synonyms and relative-date normalization. Unsupported/invented values are dropped, so the user can provide them or enter them directly in Edit. Quote filtering is a grounding aid, not a guarantee of semantic correctness; the explicit field review remains required.

This is schema retrieval grounded in the live application contracts, not embedding/vector search. It does not need an external vector database. Linked record selectors read authenticated module APIs and show human-readable names. The model is not given an unrestricted database connection or automatic access to health records, financial history or uploaded documents. Behavior rules and examples are maintained in `backend/src/main/resources/ai/blistra-assistant.md`; model weights are not fine-tuned.

## Backend setup

The backend loads the ignored root `.env` when launched from the repository root or `backend/`. For Groq on Render:

```properties
BLISTRA_AI_ENABLED=true
FREELLM_API_KEY=your_groq_key
FREELLM_BASE_URL=https://api.groq.com/openai/v1
FREELLM_MODEL=openai/gpt-oss-120b
# Optional output budget, clamped to 256–4096:
FREELLM_MAX_TOKENS=2048
```

The variable names also support a FreeLLMAPI gateway. Local gateway settings are `FREELLM_BASE_URL=http://127.0.0.1:31415/v1` and a supported gateway model ID (`auto` only when that gateway supports it). Loopback refers to the backend's own machine/container. A hosted backend needs a reachable HTTPS gateway/provider. Keys belong only on the backend, never in Flutter or Git. Restart/redeploy after environment changes. Missing key/disabled AI/provider errors return a generic unavailable message.

Provider calls use OpenAI-compatible chat completions, Bearer authentication, a 45-second deadline, 5-second connect timeout and 64 KiB response cap. GPT-OSS uses low reasoning effort; draft extraction has a larger token budget than the original read-only chat. There are no automatic provider retries. Shared database budgets allow 20 provider calls per user and 200 total per 15-minute window, using the existing rate-limit setting/store. Entry requests normally use two calls, so they consume two units. Free provider quotas may impose tighter limits.

## Privacy, persistence and API

Messages and the current draft's values are sent to the configured AI gateway/provider for drafting. Provider retention policies apply. User record names loaded by selectors are displayed locally; a referenced record ID or manually entered value may be included in the next drafting request when refining that draft. An optional daily-summary toggle shares only today's planner/event, habit, dose, meal counts and water total; it is not consent to retrieve full account history. Turning the toggle off clears visible chat context but cannot retract data already sent.

Chat messages are not persisted by Blistra. Draft payloads and applied receipts are stored in PostgreSQL for review and safe retries. The scheduled cleanup removes unused drafts one day after expiry and all drafts/receipts after 30 days. Deleting the owning user cascades deletion. Responses use `Cache-Control: no-store`; prompts/provider bodies/keys are not logged. Clearing/closing chat discards its local state; old pending drafts remain unexecutable without their separate, authenticated approval request and expire automatically.

- `POST /api/v1/ai/entries/chat`: `{chat: {message, history, includeSummary}, draftId?}` → `{reply, draft?, uploadDocument}`.
- `GET /api/v1/ai/entries/catalog`: supported entry types and fields.
- `GET /api/v1/ai/entries/{id}`: owned draft or applied receipt.
- `PUT /api/v1/ai/entries/{id}`: `{revision, data}` → revised, validated template; no domain write.
- `POST /api/v1/ai/entries/{id}/approve`: `{revision, reviewed: true}` → saved receipt.
- `POST /api/v1/ai/entries/{id}/cancel`: `{revision}` → cancelled.
- The original `/api/v1/ai/chat` remains compatible with text-only clients and cannot create entries.

All routes require JWT authentication. Owners come exclusively from the security context. The V119 migration adds only the approval-draft table; entry creation still uses existing domain services and permissions. Validate live replies with the chosen provider/model before rollout: missing dates, unsupported currencies, unknown records, multi-turn edits, medical data supplied by the user, and requests to “approve” through chat should all be exercised.
