-- Add created_source column to track how checks were created
-- This helps distinguish automation-created checks from UI-created checks

ALTER TABLE checks ADD COLUMN IF NOT EXISTS created_source text;

-- Add comment explaining the column
COMMENT ON COLUMN checks.created_source IS 'Source of check creation: "automation", "ui", or NULL for legacy. Automation checks are those created by Terry (bookkeeping automation) or Send to Controller routine.';

-- Create index for quick filtering of automation checks
CREATE INDEX IF NOT EXISTS idx_checks_created_source ON checks(created_source) WHERE created_source IS NOT NULL;

-- Note: Existing checks keep created_source = NULL, which is backward compatible
-- New automation inserts should set created_source = 'automation'
-- UI inserts can optionally set created_source = 'ui' (but NULL works too)

-- For now, we use created_by IS NULL as the signal for automation checks
-- This works because automation uses service role key, so auth.uid() is NULL
