-- Create services table if not exists
create table if not exists public.services (
  id uuid not null default gen_random_uuid(),
  name text not null,
  description text,
  created_at timestamp with time zone null default now(),
  constraint services_pkey primary key (id),
  constraint services_name_key unique (name)
) TABLESPACE pg_default;

-- Create mechanic_services table if not exists  
create table if not exists public.mechanic_services (
  id uuid not null default gen_random_uuid(),
  mechanic_id uuid not null,
  service_id uuid not null,
  created_at timestamp with time zone null default now(),
  constraint mechanic_services_pkey primary key (id),
  constraint mechanic_services_mechanic_id_fkey foreign key (mechanic_id) references mechanics (id) on delete cascade,
  constraint mechanic_services_service_id_fkey foreign key (service_id) references services (id) on delete cascade,
  constraint mechanic_services_unique unique (mechanic_id, service_id)
) TABLESPACE pg_default;

-- Create reviews table if not exists
create table if not exists public.reviews (
  id uuid not null default gen_random_uuid(),
  mechanic_id uuid not null,
  user_id uuid not null,
  rating double precision not null check (rating >= 0 and rating <= 5),
  comment text,
  created_at timestamp with time zone null default now(),
  constraint reviews_pkey primary key (id),
  constraint reviews_mechanic_id_fkey foreign key (mechanic_id) references mechanics (id) on delete cascade,
  constraint reviews_user_id_fkey foreign key (user_id) references users (id) on delete cascade
) TABLESPACE pg_default;

-- Insert some default services
INSERT INTO services (name, description) VALUES 
  ('Engine Repair', 'Complete engine diagnostics and repair'),
  ('Brake Service', 'Brake inspection, pad replacement, and repair'),
  ('Oil Change', 'Oil and filter change service'),
  ('Towing', 'Vehicle towing and roadside assistance'),
  ('Jump Start', 'Battery jump start service'),
  ('Tire Change', 'Flat tire replacement and repair'),
  ('Transmission', 'Transmission diagnostics and repair'),
  ('AC Repair', 'Air conditioning system repair'),
  ('Electrical', 'Electrical system diagnostics and repair'),
  ('Battery Replacement', 'Car battery testing and replacement'),
  ('Coolant Service', 'Coolant system maintenance'),
  ('Suspension Repair', 'Suspension system repair and maintenance')
ON CONFLICT (name) DO NOTHING;

-- Enable RLS
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE mechanic_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Services policies
CREATE POLICY "Services are viewable by everyone" ON services FOR SELECT USING (true);

-- Mechanic services policies
CREATE POLICY "Mechanic services are viewable by everyone" ON mechanic_services FOR SELECT USING (true);

CREATE POLICY "Mechanics can manage their own services" ON mechanic_services 
FOR ALL USING (auth.uid() = mechanic_id);

-- Reviews policies
CREATE POLICY "Reviews are viewable by everyone" ON reviews FOR SELECT USING (true);

CREATE POLICY "Users can create reviews" ON reviews 
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own reviews" ON reviews 
FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own reviews" ON reviews 
FOR DELETE USING (auth.uid() = user_id);
