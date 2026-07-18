-- Run this once in Supabase SQL Editor.
-- Adds storage for user-added "Mode of Conveyance" options (Settings -> Conveyance
-- modes in the app), alongside the built-in list (Auto, Taxi, Train, Bus,
-- Two-wheeler, Own Car, Rapido, Ola, Uber, Other).

alter table profile add column if not exists custom_modes jsonb not null default '[]'::jsonb;
