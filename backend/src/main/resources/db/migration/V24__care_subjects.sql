ALTER TABLE pets
 ADD COLUMN subject_type VARCHAR(12) NOT NULL DEFAULT 'PET',
 ADD COLUMN relationship VARCHAR(60) NOT NULL DEFAULT '',
 ADD COLUMN subject_owner CHAR(36) NULL,
 ADD COLUMN consent_basis VARCHAR(20) NULL,
 ADD COLUMN consent_at TIMESTAMP(6) NULL,
 ADD COLUMN consent_revoked_at TIMESTAMP(6) NULL;
CREATE TABLE subject_grants (
 subject_id CHAR(36) NOT NULL,
 account_id CHAR(36) NOT NULL,
 access_level VARCHAR(12) NOT NULL,
 PRIMARY KEY(subject_id,account_id),
 FOREIGN KEY(subject_id) REFERENCES pets(id) ON DELETE CASCADE,
 FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
);
CREATE TABLE subject_consent_events (
 id CHAR(36) PRIMARY KEY,subject_id CHAR(36) NOT NULL,actor_id CHAR(36) NULL,
 action VARCHAR(20) NOT NULL,basis VARCHAR(20) NULL,
 happened_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 FOREIGN KEY(subject_id) REFERENCES pets(id) ON DELETE CASCADE,
 FOREIGN KEY(actor_id) REFERENCES accounts(id) ON DELETE SET NULL
);
CREATE TABLE medication_logs (
 id CHAR(36) PRIMARY KEY,task_id CHAR(36) NOT NULL,actor_id CHAR(36) NULL,
 request_id CHAR(36) NOT NULL UNIQUE,request_hash CHAR(64) NOT NULL,
 outcome VARCHAR(12) NOT NULL,actual_at TIMESTAMP(6) NOT NULL,
 medication VARCHAR(120) NOT NULL,dose VARCHAR(120) NOT NULL,notes VARCHAR(1000) NOT NULL,
 created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 FOREIGN KEY(task_id) REFERENCES care_tasks(id) ON DELETE CASCADE,
 FOREIGN KEY(actor_id) REFERENCES accounts(id) ON DELETE SET NULL,
 INDEX medication_task(task_id,created_at,id)
);
