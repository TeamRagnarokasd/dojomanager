-- Fix: Allow text/plain MIME type in user_docs bucket
-- The terms acceptance document is uploaded as a .txt file (text/plain),
-- but the bucket was only configured to accept image and PDF/Word types.
-- This migration adds text/plain to the allowed MIME types.

UPDATE storage.buckets
SET allowed_mime_types = array_append(allowed_mime_types, 'text/plain')
WHERE id = 'user_docs'
  AND NOT ('text/plain' = ANY(allowed_mime_types));
