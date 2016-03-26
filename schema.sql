CREATE DATABASE IF NOT EXISTS db_api
  DEFAULT CHARACTER SET utf8
  DEFAULT COLLATE utf8_general_ci;
GRANT ALL PRIVILEGES ON db_api.* TO 'tp_user'@'localhost'
IDENTIFIED BY 'qwerty';


USE technopark;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS Forum;
DROP TABLE IF EXISTS Post;
DROP TABLE IF EXISTS User;
DROP TABLE IF EXISTS Thread;
DROP TABLE IF EXISTS Followers;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE User (
  id          INT UNSIGNED AUTO_INCREMENT NOT NULL,
  email       VARCHAR(63)                 NOT NULL,
  isAnonymous BOOL DEFAULT FALSE          NOT NULL,
  username    VARCHAR(63)   DEFAULT NULL,
  about       VARCHAR(5000) DEFAULT NULL,
  name        VARCHAR(63)   DEFAULT NULL,
  #   isDeleted   BOOLEAN DEFAULT FALSE NOT NULL,
  PRIMARY KEY (email),
  UNIQUE KEY (id)
);

CREATE TABLE Followers (
  follower VARCHAR(63) NOT NULL,
  followee VARCHAR(63) NOT NULL,
  PRIMARY KEY (follower, followee),
  FOREIGN KEY (follower)
  REFERENCES User (email),
  FOREIGN KEY (followee)
  REFERENCES User (email)
);

CREATE TABLE Forum (
  id         INT UNSIGNED AUTO_INCREMENT NOT NULL,
  name       VARCHAR(127)                NOT NULL,
  short_name VARCHAR(127)                NOT NULL,
  user       VARCHAR(63)                 NOT NULL,
  PRIMARY KEY (short_name),
  UNIQUE KEY (id),
  FOREIGN KEY (user)
  REFERENCES User (email)
);

CREATE TABLE Thread (
  id        INT UNSIGNED AUTO_INCREMENT NOT NULL,
  date      DATETIME                    NOT NULL,
  title     VARCHAR(255)                NOT NULL,
  forum     VARCHAR(127)                NOT NULL,
  isClosed  BOOLEAN DEFAULT FALSE       NOT NULL,
  isDeleted BOOLEAN DEFAULT FALSE       NOT NULL,
  message   VARCHAR(5000)               NOT NULL,
  slug      VARCHAR(255)                NOT NULL,
  user      VARCHAR(63)                 NOT NULL,
  likes     INT UNSIGNED DEFAULT 0      NOT NULL,
  dislikes  INT UNSIGNED DEFAULT 0      NOT NULL,
  points    BIGINT DEFAULT 0            NOT NULL,
  posts     INT UNSIGNED DEFAULT 0      NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (forum)
  REFERENCES Forum (short_name),
  FOREIGN KEY (user)
  REFERENCES User (email)
  #   todo
)
  ENGINE = INNODB;

CREATE TABLE Post (
  id            INT UNSIGNED AUTO_INCREMENT NOT NULL,
  date          DATETIME                    NOT NULL,
  thread        INT UNSIGNED                NOT NULL,
  message       VARCHAR(5000)               NOT NULL,
  user          VARCHAR(63)                 NOT NULL,
  forum         VARCHAR(127)                NOT NULL,
  parent        INT UNSIGNED DEFAULT NULL,
  isApproved    BOOL DEFAULT FALSE          NOT NULL,
  isHighlighted BOOL DEFAULT FALSE          NOT NULL,
  isEdited      BOOL DEFAULT FALSE          NOT NULL,
  isSpam        BOOL DEFAULT FALSE          NOT NULL,
  isDeleted     BOOL DEFAULT FALSE          NOT NULL,

  PRIMARY KEY (id),
  FOREIGN KEY (thread)
  REFERENCES Thread (id),
  FOREIGN KEY (user)
  REFERENCES User (email),
  FOREIGN KEY (forum)
  REFERENCES Forum (short_name),
  FOREIGN KEY (parent)
  REFERENCES Post (id)
  #   todo
)
  ENGINE = INNODB;

# todo: узнать что делать с дочерними постами удаленного поста

