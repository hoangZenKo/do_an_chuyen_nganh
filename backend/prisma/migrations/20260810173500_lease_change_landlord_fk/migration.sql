-- AddForeignKey
ALTER TABLE "LeaseChange" ADD CONSTRAINT "LeaseChange_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
