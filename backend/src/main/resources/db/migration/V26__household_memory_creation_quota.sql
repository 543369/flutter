ALTER TABLE households ADD COLUMN memory_created_count BIGINT NOT NULL DEFAULT 0;

-- Deleted historical stories cannot be reconstructed; seed from retained stories.
UPDATE households h SET memory_created_count = (
  SELECT COUNT(*) FROM pet_memories m JOIN pets p ON p.id=m.pet_id
  WHERE p.household_id=h.id
);
