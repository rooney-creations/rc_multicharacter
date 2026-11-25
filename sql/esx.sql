-- ============================================================================
-- rc_multicharacter - ESX Legacy (es_extended) SQL Schema
-- Compatible with MySQL 8.0+ and MariaDB 10.3+ (100% idempotent)
-- ============================================================================

CREATE TABLE IF NOT EXISTS `users` (
  `identifier` VARCHAR(60) NOT NULL,
  `ssn` VARCHAR(11) NULL DEFAULT NULL,
  `accounts` LONGTEXT NULL DEFAULT NULL,
  `group` VARCHAR(50) NULL DEFAULT 'user',
  `inventory` LONGTEXT NULL DEFAULT NULL,
  `job` VARCHAR(20) NULL DEFAULT 'unemployed',
  `job_grade` INT NULL DEFAULT 0,
  `loadout` LONGTEXT NULL DEFAULT NULL,
  `metadata` LONGTEXT NULL DEFAULT NULL,
  `position` LONGTEXT NULL DEFAULT NULL,
  `firstname` VARCHAR(50) NULL DEFAULT NULL,
  `lastname` VARCHAR(50) NULL DEFAULT NULL,
  `dateofbirth` VARCHAR(20) NULL DEFAULT NULL,
  `sex` VARCHAR(10) NULL DEFAULT NULL,
  `height` INT NULL DEFAULT 175,
  `nationality` VARCHAR(60) NULL DEFAULT NULL,
  `skin` LONGTEXT NULL DEFAULT NULL,
  `disabled` TINYINT(1) NULL DEFAULT 0,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `jobs` (
  `name` VARCHAR(50) NOT NULL,
  `label` VARCHAR(50) DEFAULT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `jobs` (`name`, `label`) VALUES ('unemployed', 'Unemployed');

CREATE TABLE IF NOT EXISTS `job_grades` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) DEFAULT NULL,
  `grade` INT NOT NULL,
  `name` VARCHAR(50) NOT NULL,
  `label` VARCHAR(50) NOT NULL,
  `salary` INT NOT NULL,
  `skin_male` LONGTEXT NOT NULL,
  `skin_female` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `job_grades` (`id`, `job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`)
VALUES (1, 'unemployed', 0, 'unemployed', 'Unemployed', 200, '{}', '{}');

CREATE TABLE IF NOT EXISTS `rc_multicharacter_slots` (
  `identifier` VARCHAR(100) NOT NULL,
  `slots` INT(11) NOT NULL DEFAULT 3,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Safe idempotent patches for pre-existing ESX `users` tables (MySQL 8.0 & MariaDB safe)
SET @col_firstname = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'firstname');
SET @sql_firstname = IF(@col_firstname = 0, 'ALTER TABLE `users` ADD COLUMN `firstname` VARCHAR(50) NULL DEFAULT NULL', 'SELECT 1');
PREPARE stmt_fn FROM @sql_firstname; EXECUTE stmt_fn; DEALLOCATE PREPARE stmt_fn;

SET @col_lastname = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'lastname');
SET @sql_lastname = IF(@col_lastname = 0, 'ALTER TABLE `users` ADD COLUMN `lastname` VARCHAR(50) NULL DEFAULT NULL', 'SELECT 1');
PREPARE stmt_ln FROM @sql_lastname; EXECUTE stmt_ln; DEALLOCATE PREPARE stmt_ln;

SET @col_dob = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'dateofbirth');
SET @sql_dob = IF(@col_dob = 0, 'ALTER TABLE `users` ADD COLUMN `dateofbirth` VARCHAR(20) NULL DEFAULT NULL', 'SELECT 1');
PREPARE stmt_dob FROM @sql_dob; EXECUTE stmt_dob; DEALLOCATE PREPARE stmt_dob;

SET @col_sex = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'sex');
SET @sql_sex = IF(@col_sex = 0, 'ALTER TABLE `users` ADD COLUMN `sex` VARCHAR(10) NULL DEFAULT NULL', 'SELECT 1');
PREPARE stmt_sex FROM @sql_sex; EXECUTE stmt_sex; DEALLOCATE PREPARE stmt_sex;

SET @col_height = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'height');
SET @sql_height = IF(@col_height = 0, 'ALTER TABLE `users` ADD COLUMN `height` INT NULL DEFAULT 175', 'SELECT 1');
PREPARE stmt_height FROM @sql_height; EXECUTE stmt_height; DEALLOCATE PREPARE stmt_height;

SET @col_nat = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'nationality');
SET @sql_nat = IF(@col_nat = 0, 'ALTER TABLE `users` ADD COLUMN `nationality` VARCHAR(60) NULL DEFAULT NULL', 'SELECT 1');
PREPARE stmt_nat FROM @sql_nat; EXECUTE stmt_nat; DEALLOCATE PREPARE stmt_nat;

SET @col_skin = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'skin');
SET @sql_skin = IF(@col_skin = 0, 'ALTER TABLE `users` ADD COLUMN `skin` LONGTEXT NULL DEFAULT NULL', 'SELECT 1');
PREPARE stmt_skin FROM @sql_skin; EXECUTE stmt_skin; DEALLOCATE PREPARE stmt_skin;

SET @col_disabled = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'disabled');
SET @sql_disabled = IF(@col_disabled = 0, 'ALTER TABLE `users` ADD COLUMN `disabled` TINYINT(1) NULL DEFAULT 0', 'SELECT 1');
PREPARE stmt_dis FROM @sql_disabled; EXECUTE stmt_dis; DEALLOCATE PREPARE stmt_dis;

SET @id_len = (SELECT IFNULL(CHARACTER_MAXIMUM_LENGTH, 60) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'identifier' LIMIT 1);
SET @sql_idlen = IF(@id_len < 60, 'ALTER TABLE `users` MODIFY COLUMN `identifier` VARCHAR(60) NOT NULL', 'SELECT 1');
PREPARE stmt_idlen FROM @sql_idlen; EXECUTE stmt_idlen; DEALLOCATE PREPARE stmt_idlen;
