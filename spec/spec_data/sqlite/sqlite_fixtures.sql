-- Some sample database to test few features.
CREATE TABLE questions (
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  content text NOT NULL,
  encoded text,
  topic_id bigint,
  custom jsonb
);

CREATE TABLE topics (
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  name varchar(50) NOT NULL
);

INSERT INTO topics(id, name) VALUES(1001, 'Science');
INSERT INTO topics(id, name) VALUES(1002, 'Politics');

INSERT INTO questions(id, content, encoded, topic_id) VALUES(
  2001, '(C) Why is Hydrogen less dense than Argon?', '1.2.3.4', 1001
);

INSERT INTO questions(id, content, encoded, topic_id) VALUES(
  2002, '(B) Why talking about politics during a dinner is a recipe for disaster?', '1.2.3.4', 1002
);

INSERT INTO questions(id, content, topic_id) VALUES(
  2003, '(A) Why the sky is blue?', 1001
);

-- Employee table for testing index_impl with query_count
CREATE TABLE employees (
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  name varchar(100) NOT NULL,
  email varchar(150) NOT NULL,
  department varchar(50) NOT NULL,
  salary integer NOT NULL,
  hire_date date NOT NULL DEFAULT CURRENT_DATE
);

-- Generate 1500 employee records using a recursive CTE (SQLite equivalent of generate_series)
WITH RECURSIVE employee_generator(x) AS (
  SELECT 1
  UNION ALL
  SELECT x+1 FROM employee_generator WHERE x < 1500
)
INSERT INTO employees (name, email, department, salary, hire_date)
SELECT
  'Employee ' || x,
  'employee' || x || '@company.com',
  CASE
    WHEN x % 4 = 0 THEN 'Engineering'
    WHEN x % 4 = 1 THEN 'Marketing'
    WHEN x % 4 = 2 THEN 'Sales'
    ELSE 'HR'
  END,
  30000 + (x * 100),
  date('now', '-' || x || ' days')
FROM employee_generator;
