ALTER TABLE pets
 ADD COLUMN life_stage VARCHAR(12) NOT NULL DEFAULT 'OTHER',
 ADD COLUMN care_scenarios VARCHAR(40) NOT NULL DEFAULT 'DAILY';
-- Preserve the complete human template set offered before this migration.
UPDATE pets SET care_scenarios='DAILY,RECOVERY' WHERE subject_type='HUMAN';
