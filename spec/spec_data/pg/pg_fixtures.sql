-- Some sample database to test few features.
CREATE TABLE questions (
  id serial PRIMARY KEY,
  content text NOT NULL,
  encoded text,
  labels text[] NOT NULL DEFAULT '{}'::text[],
  custom jsonb,
  topic_id bigint
);

CREATE TABLE topics (
  id serial PRIMARY KEY,
  name varchar(50) NOT NULL
);

INSERT INTO topics(id, name) VALUES(1001, 'Science');
INSERT INTO topics(id, name) VALUES(1002, 'Politics');

INSERT INTO questions(id, content, encoded, topic_id, labels, custom) VALUES(
  2001, '(C) Why is Hydrogen less dense than Argon?', '1.2.3.4', 1001,
  ARRAY['science', 'physics'], '{"a": 1, "b": 2}'
);

INSERT INTO questions(id, content, encoded, topic_id, labels, custom) VALUES(
  2002, '(B) Why talking about politics during a dinner is a recipe for disaster?',
  '1.2.3.4', 1002, ARRAY['politics', 'society'], '{"a": 1, "b": 3}'
);

INSERT INTO questions(id, content, encoded, topic_id, labels) VALUES(
  2003, '(A) Why the sky is blue?', '1.2.3.2', 1001, ARRAY['science', 'sky']
);

-- Employee table for testing index_impl with query_count
CREATE TABLE employees (
  id serial PRIMARY KEY,
  name varchar(100) NOT NULL,
  email varchar(150) NOT NULL,
  department varchar(50) NOT NULL,
  salary integer NOT NULL,
  hire_date date NOT NULL DEFAULT CURRENT_DATE
);

-- Generate 1500 employee records using generate_series
INSERT INTO employees (name, email, department, salary, hire_date)
SELECT
  'Employee ' || generate_series,
  'employee' || generate_series || '@company.com',
  CASE
    WHEN generate_series % 4 = 0 THEN 'Engineering'
    WHEN generate_series % 4 = 1 THEN 'Marketing'
    WHEN generate_series % 4 = 2 THEN 'Sales'
    ELSE 'HR'
  END,
  30000 + (generate_series * 100),
  CURRENT_DATE - (generate_series || ' days')::interval
FROM generate_series(1, 1500);
