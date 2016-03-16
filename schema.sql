DROP TABLE IF EXISTS Forum;
DROP TABLE IF EXISTS Post;
DROP TABLE IF EXISTS User;
DROP TABLE IF EXISTS Thread;

CREATE TABLE Forum (
  id         INT AUTO_INCREMENT NOT NULL,
  name       VARCHAR(100)       NOT NULL,
  short_name VARCHAR(50)        NOT NULL,
  user       VARCHAR(50)        NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE Thread (
  id INT AUTO_INCREMENT NOT NULL,
  PRIMARY KEY (id)
  #   todo
)
  ENGINE = INNODB;

CREATE TABLE Post (
  id     INT AUTO_INCREMENT NOT NULL,
  date   DATE               NOT NULL,
  thread INT                NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (thread)
  REFERENCES Thread (id)
  #   todo
)
  ENGINE = INNODB;

CREATE TABLE User (
  id       INT AUTO_INCREMENT NOT NULL,
  username VARCHAR(30)        NOT NULL,
  about    VARCHAR(100)       NOT NULL,
  name     VARCHAR(50)        NOT NULL,
  email    VARCHAR(50)        NOT NULL,
  isAnonymous BOOL DEFAULT FALSE not NULL,
  PRIMARY KEY (id)
  #   todo
);

