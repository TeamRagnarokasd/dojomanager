-- Client-side companion to the server-side trigger added in
-- 20261010140000_blocco_pagamenti_non_verificati.sql: a build strictly
-- below app_version.min_payment_build is blocked from even STARTING a new
-- SumUp/Satispay payment (checked client-side before the create-payment
-- call), instead of being allowed to pay and only then hit the trigger's
-- rejection with nothing to show for it. The DB trigger remains the real
-- security backstop regardless of this value.
--
-- IMPORTANT: 184 is the version_code of the currently published APK (the
-- one still carrying the vulnerable manual "hai pagato?" flow this
-- incident is about). min_payment_build is set to 185 here as a
-- placeholder for "the first build built from this fix" — whoever
-- actually builds and publishes that APK must come back and raise this
-- value (and the main version_code/apk_url columns, as usual) to match
-- its real build number, or old APKs will keep being let through.

alter table public.app_version add column if not exists min_payment_build integer;

update public.app_version set min_payment_build = 185;
