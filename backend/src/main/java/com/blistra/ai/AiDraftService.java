package com.blistra.ai;

import com.blistra.common.exception.*;
import com.blistra.common.time.UserTime;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.json.JsonMapper;
import java.time.*;
import java.util.*;

/** Stores the exact reviewed payload and serializes approval with a row lock. */
@Service
public class AiDraftService {
    public record Draft(UUID id, String action, String label, String module, Map<String, Object> data,
                        Map<String, String> errors, List<AiEntryCatalog.Field> fields, String effect,
                        int revision, String state, OffsetDateTime expiresAt, String timezone, Object result) {}
    private record Row(UUID id, String action, Map<String, Object> data, int revision, String state, OffsetDateTime expires, Object result) {}
    private final JdbcTemplate jdbc;
    private final JsonMapper mapper;
    private final CurrentUserProvider users;
    private final AiEntryCatalog catalog;
    private final UserTime time;
    @org.springframework.beans.factory.annotation.Value("${blistra.ai.enabled:false}") private boolean enabled;
    public AiDraftService(JdbcTemplate jdbc, JsonMapper mapper, CurrentUserProvider users, AiEntryCatalog catalog, UserTime time) {
        this.jdbc = jdbc; this.mapper = mapper; this.users = users; this.catalog = catalog; this.time = time;
    }

    @Transactional
    public Draft create(String action, Map<String, Object> data, UUID previous, int previousRevision) {
        if (!enabled) throw new AiUnavailableException();
        data = new LinkedHashMap<>(data);
        if (action.equals("reminder")) {
            // Deterministic module/profile settings are visible in the template, never invented by the model.
            data.putIfAbsent("type", "GENERAL"); data.putIfAbsent("timezone", time.zone().toString());
        }
        catalog.entry(action); bounded(data);
        UUID owner = users.getCurrentUser().getId();
        if (previous != null) {
            Row old = row(previous, true);
            pending(old, previousRevision);
            jdbc.update("UPDATE ai_entry_drafts SET state='SUPERSEDED' WHERE id=?", previous);
        }
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO ai_entry_drafts(id,user_id,entry_type,payload) VALUES (?,?,?,?)", id, owner, action, mapper.writeValueAsString(data));
        return view(row(id, false));
    }

    @Transactional(readOnly = true)
    public Draft get(UUID id) { return view(row(id, false)); }

    @Transactional
    public Draft edit(UUID id, int revision, Map<String, Object> data) {
        if (!enabled) throw new AiUnavailableException();
        bounded(data); Row row = row(id, true); pending(row, revision);
        jdbc.update("UPDATE ai_entry_drafts SET payload=?,revision=revision+1 WHERE id=?", mapper.writeValueAsString(data), id);
        return view(row(id, false));
    }

    @Transactional
    public Draft approve(UUID id, int revision, boolean reviewed) {
        if (!enabled) throw new AiUnavailableException();
        if (!reviewed) throw new BadRequestException("Review every supplied field and explicitly approve the entry.");
        Row row = row(id, true);
        if (row.revision != revision) throw new InvalidStateException("This draft changed. Review its latest version before approving.");
        if (row.state.equals("APPLIED")) return view(row); // Lost response / repeated tap: return existing result.
        pending(row, revision);
        Object result = catalog.execute(row.action, row.data);
        jdbc.update("UPDATE ai_entry_drafts SET state='APPLIED',result=? WHERE id=?", mapper.writeValueAsString(result), id);
        return view(row(id, false));
    }

    @Transactional
    public void cancel(UUID id, int revision) {
        Row row = row(id, true); pending(row, revision);
        jdbc.update("UPDATE ai_entry_drafts SET state='CANCELLED' WHERE id=?", id);
    }

    private void pending(Row row, int revision) {
        if (!row.state.equals("PENDING")) throw new InvalidStateException("This draft is no longer awaiting approval.");
        if (row.revision != revision) throw new InvalidStateException("This draft changed. Review its latest version.");
        if (!row.expires.isAfter(OffsetDateTime.now(ZoneOffset.UTC))) throw new InvalidStateException("This draft expired. Create a new draft.");
    }
    @SuppressWarnings("unchecked")
    private Row row(UUID id, boolean lock) {
        UUID owner = users.getCurrentUser().getId();
        var rows = jdbc.query("SELECT * FROM ai_entry_drafts WHERE id=? AND user_id=?" + (lock ? " FOR UPDATE" : ""),
                (rs, n) -> new Row(id, rs.getString("entry_type"), mapper.readValue(rs.getString("payload"), Map.class),
                        rs.getInt("revision"), rs.getString("state"), rs.getObject("expires_at", OffsetDateTime.class),
                        rs.getString("result") == null ? null : mapper.readValue(rs.getString("result"), Object.class)), id, owner);
        if (rows.isEmpty()) throw new ResourceNotFoundException("AI draft not found");
        return rows.getFirst();
    }
    private Draft view(Row row) {
        var entry = catalog.entry(row.action);
        return new Draft(row.id, row.action, entry.label(), entry.module(), row.data,
                row.state.equals("PENDING") ? catalog.errors(row.action, row.data) : Map.of(), entry.fields(), entry.effect(),
                row.revision, row.state, row.expires, time.zone().toString(), row.result);
    }
    private void bounded(Map<String, Object> data) {
        if (data == null || mapper.writeValueAsString(data).length() > 24000)
            throw new BadRequestException("The entry is too large. Use at most 24,000 characters.");
    }
    @org.springframework.scheduling.annotation.Scheduled(fixedDelay = 3600000, initialDelay = 3600000)
    public void expire() {
        // Expired drafts are not usable; retain applied receipts for retry safety for 30 days.
        jdbc.update("DELETE FROM ai_entry_drafts WHERE (state <> 'APPLIED' AND expires_at < CURRENT_TIMESTAMP - INTERVAL '1 day') OR created_at < CURRENT_TIMESTAMP - INTERVAL '30 days'");
    }
}
