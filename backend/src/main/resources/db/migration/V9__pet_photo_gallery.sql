CREATE TABLE pet_photos (
 pet_id CHAR(36) NOT NULL,
 position_index INT NOT NULL,
 photo_data MEDIUMTEXT NOT NULL,
 PRIMARY KEY (pet_id, position_index),
 FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE
);

INSERT INTO pet_photos(pet_id, position_index, photo_data)
 SELECT id, 0, photo_data FROM pets WHERE photo_data IS NOT NULL AND photo_data <> '';
