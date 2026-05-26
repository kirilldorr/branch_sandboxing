/*
  Warnings:

  - You are about to drop the `adminuser` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropTable
PRAGMA foreign_keys=off;
DROP TABLE "adminuser";
PRAGMA foreign_keys=on;

-- CreateTable
CREATE TABLE "apartments" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "created_at" DATETIME,
    "title" TEXT NOT NULL,
    "square_meter" REAL,
    "price" DECIMAL NOT NULL,
    "number_of_rooms" INTEGER,
    "description" TEXT,
    "country" TEXT,
    "listed" BOOLEAN NOT NULL,
    "realtor_id" TEXT
);
