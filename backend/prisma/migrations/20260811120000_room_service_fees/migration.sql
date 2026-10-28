-- CreateTable
CREATE TABLE "RoomServiceFee" (
    "id" TEXT NOT NULL,
    "roomId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "amount" INTEGER NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RoomServiceFee_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "RoomServiceFee_roomId_idx" ON "RoomServiceFee"("roomId");

-- CreateIndex
CREATE INDEX "RoomServiceFee_roomId_isActive_idx" ON "RoomServiceFee"("roomId", "isActive");

-- AddForeignKey
ALTER TABLE "RoomServiceFee" ADD CONSTRAINT "RoomServiceFee_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE;
