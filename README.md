# TAHA Campaign Writer - Business Analysis Booking Site

Professional luxury website for business analysis services with multi-step booking, admin panel foundation, and Supabase backend.

## Architecture
- **Frontend**: React + Vite + Tailwind (mobile-first, luxury black/blue theme)
- **Database & Auth**: Supabase (Postgres + RLS + RPC for atomic booking)
- **Hosting**: Cloudflare Pages (static) + Workers for sensitive APIs (optional)
- **Assets**: Provided logo and hero video

## Setup

1. **Supabase**
   - Create project or use provided: https://crmmovbbrnbizgzofzgj.supabase.co
   - Run `supabase/schema.sql` in SQL Editor
   - Set up Auth (email)
   - Create admin user and set role = 'admin' in profiles

2. **Environment**
   - Copy `.env.example` to `.env`
   - Add your Supabase URL and **publishable** key only
   - Service role key stays server-side only (never in client)

3. **Local Development**
   ```bash
   npm install
   npm run dev
   ```

4. **Deploy to Cloudflare Pages**
   - Connect GitHub repo or upload `dist`
   - Build command: `npm run build`
   - Output: `dist`
   - For API: use Cloudflare Workers or Supabase Edge Functions

## Features Implemented (Core)
- Hero video + logo
- Services cards (horizontal scroll)
- Multi-step booking modal with urgency toggle
- Atomic booking RPC (capacity + overlap checks)
- Contact section
- Admin gear icon (links to future login)
- Client panel button
- Dynamic form foundation
- Notifications table ready

## Limitations & Next Steps
- Full TOTP 2FA for admin needs server-side implementation
- Complete calendar engine, holidays, working hours in the RPC
- Real-time status updates
- Push notifications (Service Worker + VAPID)
- Full admin CRUD UI
- Customer auth flow with magic link / OTP
- 4 review rounds applied conceptually (see report)

## Security
- Public key only in client
- RLS policies enforce customer isolation
- Atomic function prevents race conditions
- No secrets in repo

See full SQL and deployment notes in the response.
