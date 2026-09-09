CREATE TABLE households (id CHAR(36) PRIMARY KEY);
CREATE TABLE accounts (
 id CHAR(36) PRIMARY KEY, token_hash CHAR(64) NOT NULL UNIQUE,
 household_id CHAR(36) NOT NULL,
 FOREIGN KEY (household_id) REFERENCES households(id)
);
CREATE TABLE pets (
 id CHAR(36) PRIMARY KEY, household_id CHAR(36) NOT NULL,
 name VARCHAR(60) NOT NULL, species VARCHAR(16) NOT NULL,
 FOREIGN KEY (household_id) REFERENCES households(id) ON DELETE CASCADE
);
CREATE TABLE care_tasks (
 id CHAR(36) PRIMARY KEY, pet_id CHAR(36) NOT NULL,
 title VARCHAR(120) NOT NULL, due_at TIMESTAMP(6) NOT NULL,
 completed BOOLEAN NOT NULL DEFAULT FALSE,
 FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE,
 INDEX idx_tasks_due (pet_id, due_at)
);
CREATE TABLE invites (
 token_hash CHAR(64) PRIMARY KEY, household_id CHAR(36) NOT NULL,
 expires_at TIMESTAMP(6) NOT NULL,
 FOREIGN KEY (household_id) REFERENCES households(id) ON DELETE CASCADE
);
