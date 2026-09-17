-- Cache invalidation is updated atomically with gallery writes.
ALTER TABLE pets ADD COLUMN photo_revision BIGINT NOT NULL DEFAULT 0;
