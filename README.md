# Crimosne OTP v4

Next.js + Supabase + RumahOTP deposit integration starter for Vercel.

Features: responsive white/blue UI, Supabase auth, wallet ledger, RumahOTP QRIS deposit creation/status verification, webhook endpoint, idempotent wallet crediting, admin dashboard, pricing/profit ledger, Telegram CS, realtime clock.

Setup:
1. Run supabase/schema.sql in Supabase SQL Editor.
2. Copy .env.example to .env.local and fill values.
3. npm install && npm run dev
4. Deploy to Vercel and add the same environment variables.
5. Webhook URL: https://YOUR-VERCEL-DOMAIN/api/webhooks/rumahotp
6. Promote an account to admin with:
update public.profiles set role='admin' where id='USER_UUID';

Security: never commit .env.local or expose RUMAHOTP_API_KEY. Deposit credit is server-side and reference-idempotent. Confirm the exact webhook/signature configuration in your RumahOTP account; this implementation verifies the deposit status server-side rather than trusting an incoming success flag.

The automated procurement/OTP retrieval flow for third-party account verification is intentionally not implemented.
