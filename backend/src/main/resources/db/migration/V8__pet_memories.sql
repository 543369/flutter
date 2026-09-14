CREATE TABLE pet_memories (
 id CHAR(36) PRIMARY KEY,
 pet_id CHAR(36) NOT NULL,
 author_id CHAR(36) NULL,
 title VARCHAR(120) NOT NULL,
 story TEXT NOT NULL,
 happened_on DATE NOT NULL,
 created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE,
 FOREIGN KEY (author_id) REFERENCES accounts(id) ON DELETE SET NULL,
 INDEX idx_memory_pet_date (pet_id, happened_on, created_at)
);
CREATE TABLE pet_memory_photos (
 memory_id CHAR(36) NOT NULL,
 position_index INT NOT NULL,
 photo_data MEDIUMTEXT NOT NULL,
 PRIMARY KEY (memory_id, position_index),
 FOREIGN KEY (memory_id) REFERENCES pet_memories(id) ON DELETE CASCADE
);
