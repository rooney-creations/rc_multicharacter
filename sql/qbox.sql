-- ============================================================================
-- rc_multicharacter - QBox (qbx_core) SQL Schema
-- Compatible with MySQL 8.0+ and MariaDB 10.3+ (100% idempotent)
-- ============================================================================

CREATE TABLE IF NOT EXISTS `users` (
  `userId` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username` VARCHAR(255) DEFAULT NULL,
  `license` VARCHAR(50) DEFAULT NULL,
  `license2` VARCHAR(50) DEFAULT NULL,
  `fivem` VARCHAR(20) DEFAULT NULL,
  `discord` VARCHAR(30) DEFAULT NULL,
  PRIMARY KEY (`userId`),
  KEY `idx_users_license` (`license`),
  KEY `idx_users_license2` (`license2`),
  KEY `idx_users_fivem` (`fivem`),
  KEY `idx_users_discord` (`discord`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `players` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `userId` INT UNSIGNED DEFAULT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `cid` INT(11) DEFAULT NULL,
  `license` VARCHAR(255) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `money` TEXT NOT NULL,
  `charinfo` TEXT DEFAULT NULL,
  `job` TEXT NOT NULL,
  `gang` TEXT DEFAULT NULL,
  `position` TEXT NOT NULL,
  `metadata` TEXT NOT NULL,
  `inventory` LONGTEXT DEFAULT NULL,
  `phone_number` VARCHAR(20) DEFAULT NULL,
  `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_logged_out` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`citizenid`),
  KEY `id` (`id`),
  KEY `last_updated` (`last_updated`),
  KEY `license` (`license`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `player_groups` (
  `citizenid` VARCHAR(50) NOT NULL,
  `group` VARCHAR(50) NOT NULL,
  `type` VARCHAR(50) NOT NULL,
  `grade` TINYINT(3) UNSIGNED NOT NULL,
  PRIMARY KEY (`citizenid`, `type`, `group`),
  CONSTRAINT `fk_rc_qbox_citizenid` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `playerskins` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(255) NOT NULL,
  `model` VARCHAR(255) NOT NULL,
  `skin` TEXT NOT NULL,
  `active` TINYINT(4) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `active` (`active`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rc_multicharacter_slots` (
  `identifier` VARCHAR(100) NOT NULL,
  `slots` INT(11) NOT NULL DEFAULT 3,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Safe idempotent column patches for pre-existing `players` tables (MySQL & MariaDB safe)
SET @col_userId = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'players' AND COLUMN_NAME = 'userId');
SET @sql_userId = IF(@col_userId = 0, 'ALTER TABLE `players` ADD COLUMN `userId` INT UNSIGNED DEFAULT NULL AFTER `id`', 'SELECT 1');
PREPARE stmt_userId FROM @sql_userId;
EXECUTE stmt_userId;
DEALLOCATE PREPARE stmt_userId;

SET @col_logout = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'players' AND COLUMN_NAME = 'last_logged_out');
SET @sql_logout = IF(@col_logout = 0, 'ALTER TABLE `players` ADD COLUMN `last_logged_out` TIMESTAMP NULL DEFAULT NULL AFTER `last_updated`', 'SELECT 1');
PREPARE stmt_logout FROM @sql_logout;
EXECUTE stmt_logout;
DEALLOCATE PREPARE stmt_logout;
