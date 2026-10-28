-- CreateTable
CREATE TABLE "RoomAsset" (
    "id" TEXT NOT NULL,
    "roomId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "condition" TEXT NOT NULL DEFAULT 'good',
    "value" INTEGER,
    "purchasedAt" TIMESTAMP(3),
    "note" TEXT,
    "imageUrl" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RoomAsset_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RoomInspection" (
    "id" TEXT NOT NULL,
    "roomId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "dueAt" TIMESTAMP(3) NOT NULL,
    "completedAt" TIMESTAMP(3),
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RoomInspection_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "RoomAsset_roomId_idx" ON "RoomAsset"("roomId");

-- CreateIndex
CREATE INDEX "RoomInspection_roomId_idx" ON "RoomInspection"("roomId");

-- CreateIndex
CREATE INDEX "RoomInspection_dueAt_idx" ON "RoomInspection"("dueAt");

-- CreateIndex
CREATE INDEX "RoomInspection_completedAt_idx" ON "RoomInspection"("completedAt");

-- AddForeignKey
ALTER TABLE "RoomAsset" ADD CONSTRAINT "RoomAsset_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RoomInspection" ADD CONSTRAINT "RoomInspection_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE;
