ALTER TABLE accounts
 ADD COLUMN family_role VARCHAR(12) NOT NULL DEFAULT 'ADMIN',
 ADD COLUMN permissions VARCHAR(100) NOT NULL DEFAULT 'CARE,HEALTH,MEMORIES,PETS,REPORTS',
 ADD COLUMN access_until TIMESTAMP(6) NULL;
-- Preserve a deterministic administrator in each existing home.
UPDATE accounts a JOIN (SELECT household_id,MIN(id) administrator FROM accounts GROUP BY household_id) h
 ON a.household_id=h.household_id SET a.family_role=IF(a.id=h.administrator,'ADMIN','MEMBER');
ALTER TABLE invites ADD COLUMN family_role VARCHAR(12) NOT NULL DEFAULT 'MEMBER',
 ADD COLUMN permissions VARCHAR(100) NOT NULL DEFAULT 'CARE,HEALTH,MEMORIES,PETS,REPORTS',
 ADD COLUMN access_until TIMESTAMP(6) NULL;
-- Online column addition avoids rebuilding existing care history.
-- Assignment is household-validated by the API and cleared on account deletion/leave.
ALTER TABLE care_tasks ADD COLUMN assigned_to CHAR(36) NULL, ALGORITHM=INSTANT;
CREATE TABLE health_records (
 id CHAR(36) PRIMARY KEY, pet_id CHAR(36) NOT NULL, author_id CHAR(36) NULL,
 kind VARCHAR(12) NOT NULL, title VARCHAR(120) NOT NULL, notes TEXT NOT NULL,
 happened_on DATE NOT NULL, weight_kg DECIMAL(8,3) NULL,
 folder VARCHAR(60) NOT NULL DEFAULT '',
 created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE,
 FOREIGN KEY (author_id) REFERENCES accounts(id) ON DELETE SET NULL,
 INDEX idx_health_pet_date (pet_id,happened_on,id)
);
CREATE TABLE health_attachments (
 record_id CHAR(36) NOT NULL, position_index INT NOT NULL, photo_data MEDIUMTEXT NOT NULL,
 PRIMARY KEY(record_id,position_index),
 FOREIGN KEY (record_id) REFERENCES health_records(id) ON DELETE CASCADE
);
