-- Fix duration column type to support decimal values
-- Swift's TimeInterval is Double, which can have decimal places

ALTER TABLE transcripts 
ALTER COLUMN duration TYPE NUMERIC USING duration::NUMERIC;
