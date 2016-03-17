DROP TABLE IF EXISTS Forum;
DROP TABLE IF EXISTS Post;
DROP TABLE IF EXISTS User;
DROP TABLE IF EXISTS Thread;
DROP TABLE IF EXISTS Followers;

CREATE TABLE User (
  id          INT UNSIGNED AUTO_INCREMENT NOT NULL,
  username    VARCHAR(63)                 NOT NULL,
  about       VARCHAR(127)                NOT NULL,
  name        VARCHAR(63)                 NOT NULL,
  email       VARCHAR(63)                 NOT NULL,
  isAnonymous BOOL DEFAULT FALSE          NOT NULL,
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
  name       VARCHAR(100)       NOT NULL,
  short_name VARCHAR(50)        NOT NULL, # todo: походу это primary key
  user       VARCHAR(50)        NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (user)
  REFERENCES User (email)
);

CREATE TABLE Thread (
  id        INT AUTO_INCREMENT    NOT NULL,
  date      DATE                  NOT NULL,
  title     VARCHAR(255)          NOT NULL,
  forum     VARCHAR(63)           NOT NULL, # todo: foreign key
  isClosed  BOOLEAN DEFAULT FALSE NOT NULL,
  isDeleted BOOLEAN DEFAULT FALSE NOT NULL,
  message   VARCHAR(255)          NOT NULL,
  slug      VARCHAR(255)          NOT NULL,
  user      VARCHAR(63)           NOT NULL, # todo: foreign key
  PRIMARY KEY (id)
  #   todo
)
  ENGINE = INNODB;

CREATE TABLE Post (
  id         INT AUTO_INCREMENT NOT NULL,
  date       DATE               NOT NULL,
  thread     INT                NOT NULL,
  parent     INT, # todo foreign key,
  isApproved BOOLEAN,
  PRIMARY KEY (id),
  FOREIGN KEY (thread)
  REFERENCES Thread (id)
  #   todo
)
  ENGINE = INNODB;

# todo: узнать что делать с дочерними постами удаленного поста

