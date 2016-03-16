DROP TABLE IF EXISTS Forum;
DROP TABLE IF EXISTS Post;
DROP TABLE IF EXISTS User;
DROP TABLE IF EXISTS Thread;

CREATE TABLE Forum (
  id         INT AUTO_INCREMENT NOT NULL,
  name       VARCHAR(100)       NOT NULL,
  short_name VARCHAR(50),
  user       VARCHAR(50),
  PRIMARY KEY (id)
);

CREATE TABLE Post (

  id     INT AUTO_INCREMENT NOT NULL,
  date   DATE,
  thread INT
  #   todo
);

CREATE TABLE User (
  id INT AUTO_INCREMENT NOT NULL
  #   todo
);

CREATE TABLE Thread (
  id INT AUTO_INCREMENT NOT NULL
  #   todo
);
