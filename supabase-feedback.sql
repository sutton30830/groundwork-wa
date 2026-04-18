create extension if not exists pgcrypto;

create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  provider_id text not null,
  outcome text not null check (outcome in ('got_through', 'no_luck')),
  reason text not null,
  other_text text,
  zip_code text,
  session_id text not null,
  created_at timestamptz not null default now()
);

create index if not exists feedback_provider_created_at_idx
  on public.feedback (provider_id, created_at desc);

create index if not exists feedback_session_provider_created_at_idx
  on public.feedback (session_id, provider_id, created_at desc);

alter table public.feedback enable row level security;

drop policy if exists "feedback_insert_anon" on public.feedback;
create policy "feedback_insert_anon"
on public.feedback
for insert
to anon, authenticated
with check (true);

drop policy if exists "feedback_no_public_select" on public.feedback;
create policy "feedback_no_public_select"
on public.feedback
for select
to anon, authenticated
using (false);

create or replace function public.prevent_feedback_duplicates()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1
    from public.feedback f
    where f.session_id = new.session_id
      and f.provider_id = new.provider_id
      and f.outcome = new.outcome
      and f.reason = new.reason
      and f.created_at >= now() - interval '60 seconds'
  ) then
    raise exception 'Duplicate feedback submission';
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_feedback_duplicates on public.feedback;
create trigger prevent_feedback_duplicates
before insert on public.feedback
for each row
execute function public.prevent_feedback_duplicates();
