import { drizzle } from "drizzle-orm/better-sqlite3"
import Database from "better-sqlite3"
import * as schema from "./schema"
import fs from "fs"
import path from "path"

let dbPath = process.env.DATABASE_URL || "sqlite.db"

if (process.env.VERCEL === '1' || process.env.VERCEL === 'true' || process.env.NOW_BUILDER === '1' || process.env.VERCEL) {
  // Serverless environments like Vercel have a read-only filesystem except for /tmp.
  dbPath = "/tmp/sqlite.db"
  
  // If the database doesn't exist in /tmp yet, copy the compiled/seed one from the app directory.
  if (!fs.existsSync(dbPath)) {
    const localDb = path.join(process.cwd(), "sqlite.db")
    if (fs.existsSync(localDb)) {
      try {
        fs.copyFileSync(localDb, dbPath)
        console.log("Successfully copied database to /tmp/sqlite.db")
      } catch (e) {
        console.error("Failed to copy database to /tmp:", e)
      }
    }
  }
}

export const sqlite = new Database(dbPath)
export const db = drizzle(sqlite, { schema })
