ALTER TABLE "TenantGroup" ADD CONSTRAINT "TenantGroup_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "AnnouncementTemplate" ADD CONSTRAINT "AnnouncementTemplate_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
