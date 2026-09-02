-- Add category column to sponsors table
ALTER TABLE public.sponsors
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'sponsor'
    CHECK (category IN ('sponsor', 'affiliazione'));

-- Insert static affiliations data (migrating from hardcoded UI)
-- Use ON CONFLICT DO NOTHING to avoid duplicates if run multiple times
INSERT INTO public.sponsors (name, description, image_url, external_url, status, display_order, category)
VALUES
  (
    'FEDERKOMBAT',
    'Il Team Ragnarok è ufficialmente affiliato alla Federazione Italiana Savate Kickboxing • Muay Thai Shoot Boxe • Sambo • MMA • Grappling',
    'https://dojomanage9222.builtwithrocket.new/assets/images/149037-1756509894793.png',
    'https://www.federkombat.it',
    'active',
    10,
    'affiliazione'
  ),
  (
    'UIJJ',
    'Il Team Ragnarok è affiliato all''Unione Italiana Jiu-Jitsu, riconoscimento che attesta la qualità dell''insegnamento e la competenza tecnica nella disciplina del Brazilian Jiu-Jitsu.',
    'https://dojomanage9222.builtwithrocket.new/assets/images/162741-1758188985237.jpg',
    'https://www.uijj.it',
    'active',
    11,
    'affiliazione'
  ),
  (
    'ROLLING JJ ACADEMY',
    'Il Team Ragnarok è affiliato alla Rolling JJ Academy per l''insegnamento del Brazilian Jiu-Jitsu e del Grappling con metodologie e curriculum di altissimo livello.',
    'https://dojomanage9222.builtwithrocket.new/assets/images/149046-1756510853047.jpg',
    'https://www.rollingjjacademy.com',
    'active',
    12,
    'affiliazione'
  ),
  (
    'NETWORK AURORA',
    'Il Team Ragnarok fa parte del Network Aurora, il più importante network in Italia per le MMA, garantendo standard di eccellenza nella formazione degli atleti.',
    'https://dojomanage9222.builtwithrocket.new/assets/images/146802-1756510514652.jpg',
    'https://www.networkauroramma.it',
    'active',
    13,
    'affiliazione'
  )
ON CONFLICT (name) DO UPDATE SET
  category = EXCLUDED.category,
  description = EXCLUDED.description,
  image_url = EXCLUDED.image_url,
  display_order = EXCLUDED.display_order;

-- Update RLS: allow all authenticated users to read sponsors (already exists, but ensure it covers category)
-- The existing RLS policies on sponsors should already allow SELECT for all authenticated users
-- No new policies needed since we're just adding a column
