CREATE DATABASE IF NOT EXISTS design_studio CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE design_studio;

CREATE TABLE user_account (
  user_id       INT AUTO_INCREMENT PRIMARY KEY,
  full_name     VARCHAR(120) NOT NULL,
  email         VARCHAR(190) NOT NULL UNIQUE,
  role          ENUM('owner','designer','assistant','contractor') NOT NULL DEFAULT 'owner',
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE client (
  client_id       INT AUTO_INCREMENT PRIMARY KEY,
  name            VARCHAR(160) NOT NULL,
  contact_email   VARCHAR(190) NOT NULL,
  phone           VARCHAR(40),
  billing_address TEXT,
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE project (
  project_id     INT AUTO_INCREMENT PRIMARY KEY,
  client_id      INT NOT NULL,
  name           VARCHAR(180) NOT NULL,
  status         ENUM('planning','active','on_hold','completed','cancelled') NOT NULL DEFAULT 'planning',
  start_date     DATE,
  due_date       DATE,
  billing_type   ENUM('hourly','fixed') NOT NULL DEFAULT 'hourly',
  hourly_rate    DECIMAL(10,2) DEFAULT NULL,
  fixed_fee      DECIMAL(10,2) DEFAULT NULL,
  budget_amount  DECIMAL(10,2) DEFAULT NULL,
  description    TEXT,
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_project_client FOREIGN KEY (client_id) REFERENCES client(client_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE service (
  service_id    INT AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(140) NOT NULL,
  default_rate  DECIMAL(10,2) NOT NULL,
  description   TEXT
);

CREATE TABLE project_service (
  project_id   INT NOT NULL,
  service_id   INT NOT NULL,
  quantity     DECIMAL(10,2) NOT NULL DEFAULT 1.0,
  rate         DECIMAL(10,2) NOT NULL,
  notes        VARCHAR(255),
  PRIMARY KEY(project_id, service_id),
  CONSTRAINT fk_ps_proj FOREIGN KEY (project_id) REFERENCES project(project_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_ps_serv FOREIGN KEY (service_id) REFERENCES service(service_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE task (
  task_id        INT AUTO_INCREMENT PRIMARY KEY,
  project_id     INT NOT NULL,
  title          VARCHAR(200) NOT NULL,
  status         ENUM('todo','in_progress','blocked','done') NOT NULL DEFAULT 'todo',
  priority       ENUM('low','normal','high','urgent') NOT NULL DEFAULT 'normal',
  due_date       DATE,
  estimate_hours DECIMAL(6,2),
  assigned_to    INT,
  CONSTRAINT fk_task_project FOREIGN KEY (project_id) REFERENCES project(project_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_task_user FOREIGN KEY (assigned_to) REFERENCES user_account(user_id)
    ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE time_entry (
  time_entry_id   INT AUTO_INCREMENT PRIMARY KEY,
  project_id      INT NOT NULL,
  task_id         INT,
  user_id         INT NOT NULL,
  start_time      DATETIME NOT NULL,
  end_time        DATETIME NOT NULL,
  duration_min    INT GENERATED ALWAYS AS (TIMESTAMPDIFF(MINUTE, start_time, end_time)) STORED,
  billable        BOOLEAN NOT NULL DEFAULT TRUE,
  hourly_rate     DECIMAL(10,2) DEFAULT NULL,
  CONSTRAINT fk_te_proj FOREIGN KEY (project_id) REFERENCES project(project_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_te_task FOREIGN KEY (task_id) REFERENCES task(task_id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT fk_te_user FOREIGN KEY (user_id) REFERENCES user_account(user_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CHECK (end_time > start_time)
);

CREATE TABLE file_asset (
  file_id      INT AUTO_INCREMENT PRIMARY KEY,
  project_id   INT NOT NULL,
  task_id      INT,
  file_type    ENUM('brief','asset','deliverable','reference') NOT NULL,
  filename     VARCHAR(255) NOT NULL,
  url          VARCHAR(500) NOT NULL,
  uploaded_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  version      VARCHAR(40),
  notes        VARCHAR(255),
  CONSTRAINT fk_file_proj FOREIGN KEY (project_id) REFERENCES project(project_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_file_task FOREIGN KEY (task_id) REFERENCES task(task_id)
    ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE revision (
  revision_id   INT AUTO_INCREMENT PRIMARY KEY,
  project_id    INT NOT NULL,
  task_id       INT,
  rev_number    INT NOT NULL,
  requested_by  ENUM('client','internal') NOT NULL DEFAULT 'client',
  notes         TEXT,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_rev_proj FOREIGN KEY (project_id) REFERENCES project(project_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_rev_task FOREIGN KEY (task_id) REFERENCES task(task_id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  UNIQUE KEY uq_rev_per_project (project_id, rev_number)
);

CREATE TABLE expense (
  expense_id    INT AUTO_INCREMENT PRIMARY KEY,
  project_id    INT NOT NULL,
  description   VARCHAR(200) NOT NULL,
  vendor        VARCHAR(120),
  amount        DECIMAL(10,2) NOT NULL,
  expense_date  DATE NOT NULL,
  billable      BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT fk_exp_proj FOREIGN KEY (project_id) REFERENCES project(project_id)
    ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE communication_log (
  comm_id      INT AUTO_INCREMENT PRIMARY KEY,
  project_id   INT,
  client_id    INT,
  user_id      INT,
  happened_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  channel      ENUM('email','call','meeting','message') NOT NULL,
  subject      VARCHAR(200),
  notes        TEXT,
  CONSTRAINT fk_comm_proj FOREIGN KEY (project_id) REFERENCES project(project_id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT fk_comm_client FOREIGN KEY (client_id) REFERENCES client(client_id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT fk_comm_user FOREIGN KEY (user_id) REFERENCES user_account(user_id)
    ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE estimate (
  estimate_id   INT AUTO_INCREMENT PRIMARY KEY,
  client_id     INT NOT NULL,
  project_id    INT,
  issue_date    DATE NOT NULL,
  status        ENUM('draft','sent','accepted','rejected') NOT NULL DEFAULT 'draft',
  currency      CHAR(3) NOT NULL DEFAULT 'USD',
  subtotal      DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  tax           DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  total         DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  CONSTRAINT fk_est_client FOREIGN KEY (client_id) REFERENCES client(client_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_est_project FOREIGN KEY (project_id) REFERENCES project(project_id)
    ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE estimate_line_item (
  item_id       INT AUTO_INCREMENT PRIMARY KEY,
  estimate_id   INT NOT NULL,
  description   VARCHAR(200) NOT NULL,
  quantity      DECIMAL(10,2) NOT NULL DEFAULT 1.0,
  unit_price    DECIMAL(10,2) NOT NULL,
  service_id    INT,
  CONSTRAINT fk_eli_est FOREIGN KEY (estimate_id) REFERENCES estimate(estimate_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_eli_service FOREIGN KEY (service_id) REFERENCES service(service_id)
    ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE invoice (
  invoice_id    INT AUTO_INCREMENT PRIMARY KEY,
  client_id     INT NOT NULL,
  project_id    INT,
  issue_date    DATE NOT NULL,
  due_date      DATE,
  status        ENUM('draft','sent','paid','void') NOT NULL DEFAULT 'draft',
  currency      CHAR(3) NOT NULL DEFAULT 'USD',
  subtotal      DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  tax           DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  total         DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  CONSTRAINT fk_inv_client FOREIGN KEY (client_id) REFERENCES client(client_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_inv_project FOREIGN KEY (project_id) REFERENCES project(project_id)
    ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE invoice_line_item (
  item_id       INT AUTO_INCREMENT PRIMARY KEY,
  invoice_id    INT NOT NULL,
  description   VARCHAR(200) NOT NULL,
  quantity      DECIMAL(10,2) NOT NULL DEFAULT 1.0,
  unit_price    DECIMAL(10,2) NOT NULL,
  project_id    INT,
  time_entry_id INT,
  service_id    INT,
  CONSTRAINT fk_ili_inv FOREIGN KEY (invoice_id) REFERENCES invoice(invoice_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_ili_proj FOREIGN KEY (project_id) REFERENCES project(project_id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT fk_ili_te FOREIGN KEY (time_entry_id) REFERENCES time_entry(time_entry_id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT fk_ili_service FOREIGN KEY (service_id) REFERENCES service(service_id)
    ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE payment (
  payment_id    INT AUTO_INCREMENT PRIMARY KEY,
  invoice_id    INT NOT NULL,
  payment_date  DATE NOT NULL,
  amount        DECIMAL(10,2) NOT NULL,
  method        ENUM('cash','card','ach','wire','paypal','stripe','other') NOT NULL,
  reference     VARCHAR(120),
  CONSTRAINT fk_pay_invoice FOREIGN KEY (invoice_id) REFERENCES invoice(invoice_id)
    ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE INDEX ix_task_project ON task(project_id, status);
CREATE INDEX ix_time_entry_project ON time_entry(project_id, user_id);
CREATE INDEX ix_invoice_client_status ON invoice(client_id, status);
CREATE INDEX ix_payment_invoice ON payment(invoice_id);

CREATE OR REPLACE VIEW v_client_balances AS
SELECT
  c.client_id,
  c.name AS client_name,
  COALESCE(SUM(i.total),0) AS invoiced_total,
  COALESCE(SUM(p.amount),0) AS payments_total,
  COALESCE(SUM(i.total),0) - COALESCE(SUM(p.amount),0) AS balance_due
FROM client c
LEFT JOIN invoice i ON i.client_id = c.client_id AND i.status IN ('sent','paid')
LEFT JOIN payment p ON p.invoice_id = i.invoice_id
GROUP BY c.client_id, c.name;

CREATE OR REPLACE VIEW v_project_profitability AS
SELECT
  pr.project_id,
  pr.name AS project_name,
  c.name AS client_name,
  COALESCE((SELECT SUM(i.total) FROM invoice i WHERE i.project_id = pr.project_id AND i.status IN ('sent','paid')),0) AS invoiced_total,
  COALESCE((SELECT SUM((CASE WHEN te.hourly_rate IS NULL THEN pr.hourly_rate ELSE te.hourly_rate END)
                        * (te.duration_min/60))
            FROM time_entry te WHERE te.project_id = pr.project_id AND te.billable = TRUE),0) AS labor_cost,
  COALESCE((SELECT SUM(e.amount) FROM expense e WHERE e.project_id = pr.project_id AND e.billable = TRUE),0) AS expenses_cost,
  COALESCE((SELECT SUM(i.total) FROM invoice i WHERE i.project_id = pr.project_id AND i.status IN ('sent','paid')),0)
   - (COALESCE((SELECT SUM((CASE WHEN te.hourly_rate IS NULL THEN pr.hourly_rate ELSE te.hourly_rate END)
                        * (te.duration_min/60))
            FROM time_entry te WHERE te.project_id = pr.project_id AND te.billable = TRUE),0)
      + COALESCE((SELECT SUM(e.amount) FROM expense e WHERE e.project_id = pr.project_id AND e.billable = TRUE),0)
     ) AS profit_estimate
FROM project pr
JOIN client c ON c.client_id = pr.client_id;

INSERT INTO user_account(full_name,email,role) VALUES
('Noorjahan Kanok','studio@kanok.design','owner'),
('Alex Rivera','alex@collab.design','contractor');

INSERT INTO client(name,contact_email,phone,billing_address) VALUES
('Acme Foods','maria@acmefoods.com','+1-212-555-0183','123 Market St, NYC, NY'),
('BrightPath Clinic','admin@brightpathclinic.org','+1-718-555-0197','77 Health Ave, Queens, NY');

INSERT INTO service(name,default_rate,description) VALUES
('Logo Design',120.00,'Logo concepting and final mark'),
('Brand Guidelines',110.00,'Type/colors/usage rules'),
('Social Media Kit',95.00,'Templates and variants'),
('Print Layout',100.00,'Brochure/poster/flyer layout');

INSERT INTO project(client_id,name,status,billing_type,hourly_rate,fixed_fee,budget_amount,description,start_date,due_date) VALUES
(1,'Acme Rebrand','active','fixed',NULL,4500.00,5000.00,'Logo + brand guide','2025-09-10','2025-10-10'),
(2,'Clinic Brochure','active','hourly',100.00,NULL,1500.00,'Tri-fold brochure','2025-09-12','2025-09-30');

INSERT INTO project_service(project_id,service_id,quantity,rate,notes) VALUES
(1,1,1,120.00,'Logo'),
(1,2,1,110.00,'Guidelines'),
(2,4,1,100.00,'6 pages');

INSERT INTO task(project_id,title,status,priority,due_date,estimate_hours,assigned_to) VALUES
(1,'Logo concepts','in_progress','high','2025-09-22',12.0,1),
(1,'Brand guide draft','todo','normal','2025-09-28',10.0,1),
(2,'Brochure layout','in_progress','normal','2025-09-20',8.0,2);

INSERT INTO time_entry(project_id,task_id,user_id,start_time,end_time,billable,hourly_rate) VALUES
(1,1,1,'2025-09-15 10:00:00','2025-09-15 13:30:00',TRUE,120.00),
(2,3,2,'2025-09-16 09:00:00','2025-09-16 12:00:00',TRUE,100.00);

INSERT INTO expense(project_id,description,vendor,amount,expense_date,billable) VALUES
(1,'Stock photo pack','Adobe Stock',45.00,'2025-09-15',TRUE),
(2,'Font license','MyFonts',29.00,'2025-09-16',TRUE);

INSERT INTO estimate(client_id,project_id,issue_date,status,currency,subtotal,tax,total)
VALUES (1,1,'2025-09-12','sent','USD',4300.00,387.00,4687.00);

INSERT INTO estimate_line_item(estimate_id,description,quantity,unit_price,service_id) VALUES
(LAST_INSERT_ID(),'Logo Design',1,2500.00,1),
((SELECT estimate_id FROM estimate ORDER BY estimate_id DESC LIMIT 1),'Brand Guidelines',1,1800.00,2);

INSERT INTO invoice(client_id,project_id,issue_date,due_date,status,currency,subtotal,tax,total)
VALUES (2,2,'2025-09-17','2025-10-01','sent','USD',329.00,0.00,329.00);

INSERT INTO invoice_line_item(invoice_id,description,quantity,unit_price,project_id,service_id)
VALUES
((SELECT invoice_id FROM invoice WHERE project_id=2),'Design hours (3h @ $100)',3,100.00,2,4),
((SELECT invoice_id FROM invoice WHERE project_id=2),'Font license',1,29.00,2,NULL);

INSERT INTO payment(invoice_id,payment_date,amount,method,reference)
VALUES ((SELECT invoice_id FROM invoice WHERE project_id=2),'2025-09-18',200.00,'card','AUTH123');

-- Example queries to run manually after loading data:
-- SELECT * FROM v_client_balances;
-- SELECT * FROM v_project_profitability;
