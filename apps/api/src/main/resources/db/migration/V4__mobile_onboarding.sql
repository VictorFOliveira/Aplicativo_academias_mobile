INSERT INTO saas_plans(code,name,monthly_price_cents,active)
VALUES ('MOBILE','Cactus Fight',3000,true)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE academy_onboardings (
  id uuid PRIMARY KEY,
  academy_id uuid NOT NULL UNIQUE REFERENCES academies(id) ON DELETE CASCADE,
  owner_id uuid NOT NULL,
  document_type text NOT NULL CHECK (document_type IN ('CPF','CNPJ')),
  document_encrypted text NOT NULL,
  contact_phone text NOT NULL,
  billing_period text NOT NULL CHECK (billing_period IN ('MONTHLY','YEARLY')),
  payment_method text NOT NULL CHECK (payment_method IN ('PIX','CARD')),
  first_due_date date NOT NULL,
  amount_cents integer NOT NULL CHECK (amount_cents > 0),
  billing_status text NOT NULL DEFAULT 'PENDING_PAYMENT' CHECK (billing_status = 'PENDING_PAYMENT'),
  code_encrypted text,
  code_expires_at timestamptz NOT NULL,
  attempts integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  verified_at timestamptz,
  FOREIGN KEY (academy_id,owner_id) REFERENCES users(academy_id,id) ON DELETE CASCADE
);
