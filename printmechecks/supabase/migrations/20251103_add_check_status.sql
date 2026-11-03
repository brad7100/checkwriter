-- Add status column to checks table to support approval workflow
-- Status can be: 'pending', 'approved', 'voided'
-- Default is 'approved' for backward compatibility (all existing checks are approved)

ALTER TABLE checks ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'approved';

-- Add check constraint to ensure valid status values
ALTER TABLE checks ADD CONSTRAINT check_status_valid 
  CHECK (status IN ('pending', 'approved', 'voided'));

-- Create index for filtering by status
CREATE INDEX IF NOT EXISTS idx_checks_status ON checks(status);

-- Add trigger to prevent printing non-approved checks
-- This trigger fires BEFORE UPDATE and validates that only approved checks can be marked as printed
CREATE OR REPLACE FUNCTION validate_check_print_status()
RETURNS TRIGGER AS $$
BEGIN
  -- If is_printed is being changed from false to true (check is being printed)
  IF NEW.is_printed = true AND (OLD.is_printed IS NULL OR OLD.is_printed = false) THEN
    -- Only allow printing if status is 'approved'
    IF NEW.status != 'approved' THEN
      RAISE EXCEPTION 'Only approved checks can be printed. Current status: %', NEW.status;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_print_status_validation
  BEFORE UPDATE ON checks
  FOR EACH ROW
  EXECUTE FUNCTION validate_check_print_status();

-- Add comment explaining the status column
COMMENT ON COLUMN checks.status IS 'Check approval status: "pending" (awaiting approval), "approved" (ready to print), "voided" (cancelled). Only approved checks can be printed.';
