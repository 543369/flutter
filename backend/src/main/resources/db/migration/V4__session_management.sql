ALTER TABLE account_sessions
 ADD COLUMN session_id CHAR(36) NULL,
 ADD COLUMN device_name VARCHAR(80) NOT NULL DEFAULT 'Unknown device',
 ADD COLUMN created_at TIMESTAMP(6) NULL,
 ADD COLUMN last_seen_at TIMESTAMP(6) NULL;
UPDATE account_sessions SET session_id=UUID();
ALTER TABLE account_sessions MODIFY session_id CHAR(36) NOT NULL,
 ADD UNIQUE KEY unique_session_id(session_id);
