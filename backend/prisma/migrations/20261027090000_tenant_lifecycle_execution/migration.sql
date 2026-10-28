CREATE TABLE "TenantLifecycleExecution" (
  "id" TEXT NOT NULL,
  "requestId" TEXT NOT NULL,
  "requestKey" TEXT NOT NULL,
  "requestHash" TEXT NOT NULL,
  "resultLeaseId" TEXT,
  "actorId" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "TenantLifecycleExecution_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "TenantLifecycleExecution_requestId_key" ON "TenantLifecycleExecution"("requestId");
CREATE UNIQUE INDEX "TenantLifecycleExecution_requestKey_key" ON "TenantLifecycleExecution"("requestKey");
ALTER TABLE "TenantLifecycleExecution" ADD CONSTRAINT "TenantLifecycleExecution_requestId_fkey"
  FOREIGN KEY ("requestId") REFERENCES "TenantLifecycleRequest"("id") ON DELETE CASCADE ON UPDATE CASCADE;
