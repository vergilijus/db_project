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
  follower INT UNSIGNED NOT NULL,
  followee INT UNSIGNED NOT NULL,
  FOREIGN KEY (follower)
  REFERENCES User (id),
  FOREIGN KEY (followee)
  REFERENCES User (id)
);

CREATE TABLE Forum (
  id         INT AUTO_INCREMENT NOT NULL,
  name       VARCHAR(127)       NOT NULL,
  short_name VARCHAR(127)       NOT NULL,
  user       VARCHAR(63)        NOT NULL,
  PRIMARY KEY (short_name),
  UNIQUE KEY (id),
  FOREIGN KEY (user)
  REFERENCES User (email)
);

CREATE TABLE Thread (
  id        INT AUTO_INCREMENT     NOT NULL,
  date      DATETIME               NOT NULL,
  title     VARCHAR(255)           NOT NULL,
  forum     VARCHAR(127)           NOT NULL,
  isClosed  BOOLEAN DEFAULT FALSE  NOT NULL,
  isDeleted BOOLEAN DEFAULT FALSE  NOT NULL,
  message   VARCHAR(5000)          NOT NULL,
  slug      VARCHAR(255)           NOT NULL,
  user      VARCHAR(63)            NOT NULL,
  likes     INT UNSIGNED DEFAULT 0 NOT NULL,
  dislikes  INT UNSIGNED DEFAULT 0 NOT NULL,
  points    BIGINT DEFAULT 0       NOT NULL,
  posts     INT UNSIGNED DEFAULT 0 NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (forum)
  REFERENCES Forum (short_name),
  FOREIGN KEY (user)
  REFERENCES User (email)
  #   todo
)
  ENGINE = INNODB;

CREATE TABLE Post (
  id         INT AUTO_INCREMENT NOT NULL,
  date       DATE               NOT NULL,
  thread     INT                NOT NULL,
  forum      VARCHAR(127)       NOT NULL,
  user       VARCHAR(63)        NOT NULL,
  parent     INT, # todo foreign key,
  isApproved BOOLEAN,
  PRIMARY KEY (id),
  FOREIGN KEY (thread)
  REFERENCES Thread (id),
  FOREIGN KEY (user)
  REFERENCES User (email),
  FOREIGN KEY (forum)
  REFERENCES Forum (short_name)
  #   todo
)
  ENGINE = INNODB;

# todo: узнать что делать с дочерними постами удаленного поста

