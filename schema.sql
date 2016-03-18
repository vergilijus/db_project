SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS Forum;
DROP TABLE IF EXISTS Post;
DROP TABLE IF EXISTS User;
DROP TABLE IF EXISTS Thread;
DROP TABLE IF EXISTS Followers;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE User (
  id          INT UNSIGNED AUTO_INCREMENT NOT NULL,
  username    VARCHAR(63)                 NOT NULL,
  about       VARCHAR(5000)               NOT NULL,
  name        VARCHAR(63)                 NOT NULL,
  email       VARCHAR(63)                 NOT NULL,
  isAnonymous BOOL DEFAULT FALSE          NOT NULL,
  #   isDeleted   BOOLEAN DEFAULT FALSE NOT NULL,
  PRIMARY KEY (email),
  UNIQUE KEY (id)
);

# INSERT INTO User (username, about, name, email, isAnonymous)
# VALUES ('user1', 'hello im user1', 'John', 'example@mail.ru', FALSE);
# INSERT INTO User (username, about, name, email, isAnonymous)
# VALUES ('user2', 'hello im user1', 'John', 'example2@mail.ru', FALSE);
# INSERT INTO User (username, about, name, email, isAnonymous)
# VALUES ('user2', 'hello im user1', 'John', 'example3@mail.ru', FALSE);

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
  short_name VARCHAR(63)        NOT NULL, # todo: походу это primary key
  user       VARCHAR(63)        NOT NULL,
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
  message   VARCHAR(5000)         NOT NULL,
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

