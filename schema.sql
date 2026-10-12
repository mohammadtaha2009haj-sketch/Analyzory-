-- TAHA Campaign Writer / Business Analysis Site Schema
-- Run this in Supabase SQL Editor
-- Creates tables, indexes, RLS, functions for atomic booking

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==================== TABLES ====================

-- Profiles / Users (extends auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  phone TEXT,
  email TEXT UNIQUE,
  role TEXT DEFAULT 'customer' CHECK (role IN ('customer', 'admin')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Services
CREATE TABLE IF NOT EXISTS public.services (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  icon TEXT, -- emoji or icon name
  duration_minutes INTEGER DEFAULT 60,
  sessions_min INTEGER DEFAULT 1,
  is_active BOOLEAN DEFAULT true,
  display_order INTEGER DEFAULT 0,
  price_urgent_extra NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Dynamic form fields per service (versioned)
CREATE TABLE IF NOT EXISTS public.service_form_fields (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  service_id UUID REFERENCES public.services(id) ON DELETE CASCADE,
  field_key TEXT NOT NULL,
  label TEXT NOT NULL,
  field_type TEXT NOT NULL CHECK (field_type IN ('text', 'textarea', 'number', 'date', 'select', 'multiselect', 'checkbox')),
  is_required BOOLEAN DEFAULT false,
  options JSONB, -- for select
  default_value TEXT,
  display_order INTEGER DEFAULT 0,
  validation_rules JSONB,
  is_visible BOOLEAN DEFAULT true,
  version INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(service_id, field_key, version)
);

-- Business settings
CREATE TABLE IF NOT EXISTS public.settings (
  id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  business_name TEXT DEFAULT 'TAHA Campaign Writer',
  slogan TEXT DEFAULT 'تحلیل حرفه‌ای کسب‌وکار برای رشد پایدار',
  timezone TEXT DEFAULT 'Asia/Tehran',
  working_days INTEGER[] DEFAULT ARRAY[1,2,3,4,5], -- 0=Sun ... 6=Sat
  working_hours_start TIME DEFAULT '09:00',
  working_hours_end TIME DEFAULT '18:00',
  daily_capacity INTEGER DEFAULT 5,
  max_projects_per_day INTEGER DEFAULT 8,
  min_gap_minutes INTEGER DEFAULT 30,
  advance_booking_days INTEGER DEFAULT 30,
  allow_urgent_override BOOLEAN DEFAULT true,
  contact_phone TEXT DEFAULT '09918760129',
  instagram_id TEXT DEFAULT '@taha_campaign',
  telegram_id TEXT DEFAULT '@taha_campaign',
  contact_links_active BOOLEAN DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Holidays
CREATE TABLE IF NOT EXISTS public.holidays (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  date DATE NOT NULL UNIQUE,
  title TEXT,
  is_active BOOLEAN DEFAULT true
);

-- Bookings
CREATE TABLE IF NOT EXISTS public.bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tracking_code TEXT UNIQUE NOT NULL,
  customer_id UUID REFERENCES auth.users(id),
  service_id UUID REFERENCES public.services(id),
  full_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  business_type TEXT,
  business_name TEXT,
  channel_id TEXT,
  is_urgent BOOLEAN DEFAULT false,
  start_datetime TIMESTAMPTZ,
  end_datetime TIMESTAMPTZ,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'confirmed', 'rejected')),
  notes TEXT,
  form_snapshot JSONB, -- frozen form answers
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Booking form answers (historical)
CREATE TABLE IF NOT EXISTS public.booking_answers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID REFERENCES public.bookings(id) ON DELETE CASCADE,
  field_key TEXT NOT NULL,
  field_label TEXT,
  answer_value TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Status history
CREATE TABLE IF NOT EXISTS public.booking_status_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID REFERENCES public.bookings(id) ON DELETE CASCADE,
  old_status TEXT,
  new_status TEXT NOT NULL,
  changed_by UUID REFERENCES auth.users(id),
  changed_at TIMESTAMPTZ DEFAULT NOW(),
  note TEXT
);

-- Notifications
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  booking_id UUID REFERENCES public.bookings(id),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  is_read BOOLEAN DEFAULT false,
  type TEXT DEFAULT 'in_app', -- in_app or push
  scheduled_for TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Push subscriptions (optional)
CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL,
  p256dh TEXT,
  auth TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, endpoint)
);

-- ==================== INDEXES ====================
CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_start ON public.bookings(start_datetime);
CREATE INDEX IF NOT EXISTS idx_bookings_customer ON public.bookings(customer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_service ON public.bookings(service_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_services_active ON public.services(is_active, display_order);

-- ==================== FUNCTIONS ====================

-- Generate unique tracking code
CREATE OR REPLACE FUNCTION public.generate_tracking_code()
RETURNS TEXT AS $$
BEGIN
  RETURN 'TAHA-' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT || CLOCK_TIMESTAMP()::TEXT) FROM 1 FOR 8));
END;
$$ LANGUAGE plpgsql;

-- Atomic booking function (core logic)
CREATE OR REPLACE FUNCTION public.create_booking_atomic(
  p_service_id UUID,
  p_full_name TEXT,
  p_phone TEXT,
  p_email TEXT,
  p_business_type TEXT,
  p_business_name TEXT,
  p_channel_id TEXT,
  p_is_urgent BOOLEAN,
  p_form_answers JSONB,
  p_requested_start TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_settings RECORD;
  v_service RECORD;
  v_start TIMESTAMPTZ;
  v_end TIMESTAMPTZ;
  v_tracking TEXT;
  v_booking_id UUID;
  v_capacity_ok BOOLEAN := false;
  v_attempts INTEGER := 0;
BEGIN
  -- Lock settings and service
  SELECT * INTO v_settings FROM public.settings WHERE id = 1 FOR UPDATE;
  SELECT * INTO v_service FROM public.services WHERE id = p_service_id AND is_active = true;
  IF v_service IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'خدمت فعال نیست');
  END IF;

  -- Simple next available slot logic (expand for full rules)
  -- For production: implement full calendar check with holidays, hours, capacity, gaps
  v_start := COALESCE(p_requested_start, NOW() + INTERVAL '1 day');
  -- Align to working hours (simplified)
  v_end := v_start + (v_service.duration_minutes || ' minutes')::INTERVAL;

  -- Check capacity (atomic)
  SELECT COUNT(*) < v_settings.daily_capacity INTO v_capacity_ok
  FROM public.bookings
  WHERE DATE(start_datetime AT TIME ZONE v_settings.timezone) = DATE(v_start AT TIME ZONE v_settings.timezone)
    AND status NOT IN ('rejected');

  IF NOT v_capacity_ok AND NOT (p_is_urgent AND v_settings.allow_urgent_override) THEN
    RETURN jsonb_build_object('success', false, 'error', 'ظرفیت روزانه پر است');
  END IF;

  -- Prevent overlap
  IF EXISTS (
    SELECT 1 FROM public.bookings
    WHERE status NOT IN ('rejected')
      AND tstzrange(start_datetime, end_datetime) && tstzrange(v_start, v_end)
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'تداخل زمانی با رزرو دیگر');
  END IF;

  v_tracking := public.generate_tracking_code();
  INSERT INTO public.bookings (
    tracking_code, service_id, full_name, phone, email,
    business_type, business_name, channel_id, is_urgent,
    start_datetime, end_datetime, form_snapshot, status
  ) VALUES (
    v_tracking, p_service_id, p_full_name, p_phone, p_email,
    p_business_type, p_business_name, p_channel_id, p_is_urgent,
    v_start, v_end, p_form_answers, 'pending'
  ) RETURNING id INTO v_booking_id;

  -- Insert answers
  -- (simplified; expand with loop over p_form_answers)

  -- Create admin notification
  INSERT INTO public.notifications (user_id, booking_id, title, body)
  SELECT id, v_booking_id, 'پروژه جدید...', 'رزرو جدید با کد ' || v_tracking
  FROM public.profiles WHERE role = 'admin' LIMIT 1;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', v_booking_id,
    'tracking_code', v_tracking,
    'start', v_start,
    'end', v_end,
    'status', 'pending'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== RLS ====================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

-- Public read active services
CREATE POLICY "Public read active services" ON public.services
  FOR SELECT USING (is_active = true);

-- Customers see own bookings
CREATE POLICY "Customers see own bookings" ON public.bookings
  FOR SELECT USING (auth.uid() = customer_id);

-- Admins full access (via role check in function or JWT claim)
CREATE POLICY "Admins manage bookings" ON public.bookings
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Similar policies for other tables...
CREATE POLICY "Public read settings" ON public.settings FOR SELECT USING (true);
CREATE POLICY "Admins update settings" ON public.settings FOR UPDATE USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ==================== SEED DATA ====================
INSERT INTO public.settings (id) VALUES (1) ON CONFLICT DO NOTHING;

INSERT INTO public.services (title, slug, description, icon, duration_minutes, display_order) VALUES
  ('کوچ', 'coach', 'جلسات کوچینگ شخصی و کسب‌وکار برای رشد هدفمند', '🎯', 90, 1),
  ('مشاوره', 'consult', 'مشاوره تخصصی آنالیز و استراتژی کسب‌وکار', '💬', 60, 2),
  ('برنامه', 'program', 'طراحی برنامه اجرایی سفارشی', '📋', 120, 3)
ON CONFLICT (slug) DO NOTHING;

-- Default form fields (version 1)
INSERT INTO public.service_form_fields (service_id, field_key, label, field_type, is_required, display_order)
SELECT id, 'sessions', 'تعداد جلسات', 'select', true, 1 FROM public.services WHERE slug = 'coach';

-- Note: Expand options, more fields, holidays, etc. in production.

COMMENT ON FUNCTION public.create_booking_atomic IS 'Atomic booking with capacity and overlap checks. Expand for full business rules, holidays, timezone.';
