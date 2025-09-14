-- Create function to handle mechanic request rejection
-- This bypasses RLS policies by running with elevated privileges

CREATE OR REPLACE FUNCTION reject_mechanic_request(
  request_id uuid,
  rejection_reason text,
  mechanic_user_id uuid
) RETURNS json AS $$
DECLARE
  result json;
BEGIN
  -- Verify the mechanic is assigned to this request
  IF NOT EXISTS (
    SELECT 1 FROM requests 
    WHERE id = request_id 
    AND mechanic_id = mechanic_user_id
    AND status = 'pending'
  ) THEN
    RETURN json_build_object(
      'success', false, 
      'error', 'Request not found or not assigned to you'
    );
  END IF;

  -- Update the request status and clear mechanic assignment
  UPDATE requests SET
    status = 'canceled',
    mechanic_id = NULL,
    mech_lat = NULL,
    mech_lng = NULL,
    rejection_reason = rejection_reason,
    updated_at = NOW()
  WHERE id = request_id;

  -- Also add to ignored_requests table if it exists
  INSERT INTO ignored_requests (mechanic_id, request_id, reason, created_at)
  VALUES (mechanic_user_id, request_id, rejection_reason, NOW())
  ON CONFLICT (mechanic_id, request_id) DO NOTHING;

  RETURN json_build_object(
    'success', true,
    'message', 'Request rejected successfully',
    'request_id', request_id
  );
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION reject_mechanic_request(uuid, text, uuid) TO authenticated;