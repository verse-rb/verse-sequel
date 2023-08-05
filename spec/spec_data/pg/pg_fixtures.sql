-- Some sample database to test few features.
CREATE TABLE questions (
  id serial PRIMARY KEY,
  content text NOT NULL,
  encoded text,
  topic_id bigint
);

CREATE TABLE topics (
  id serial PRIMARY KEY,
  name varchar(50) NOT NULL
);

INSERT INTO topics(id, name) VALUES(1001, 'Science');
INSERT INTO topics(id, name) VALUES(1002, 'Politics');

INSERT INTO questions(id, content, encoded, topic_id) VALUES(
  2001, 'Why is Hydrogen less dense than Argon?', '1.2.3.4', 1001
);

INSERT INTO questions(id, content, encoded, topic_id) VALUES(
  2002, 'Why talking about politics during a dinner is a recipe for disaster?', '1.2.3.4', 1002
);

INSERT INTO questions(id, content, topic_id) VALUES(
  2003, 'Why the sky is blue?', 1001
);