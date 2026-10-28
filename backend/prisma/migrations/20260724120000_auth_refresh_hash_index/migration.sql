-- Add a deterministic lookup key for refresh tokens.
-- Existing deployments must backfill this column before applying this migration;
-- this project currently stores refresh token hashes in tokenHash.
CREATE UNIQUE INDEX "RefreshToken_tokenHash_key" ON "RefreshToken"("tokenHash");
