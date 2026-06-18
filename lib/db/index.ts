import { drizzle } from "drizzle-orm/better-sqlite3"
import Database from "better-sqlite3"
import * as schema from "./schema"
import fs from "fs"
import path from "path"

let dbPath = process.env.DATABASE_URL || "sqlite.db"

if (process.env.VERCEL === '1' || process.env.VERCEL === 'true' || process.env.NOW_BUILDER === '1' || process.env.VERCEL) {
  // Serverless environments like Vercel have a read-only filesystem except for /tmp.
  dbPath = "/tmp/sqlite.db"
}

// Ensure the directory for the database file exists (e.g. creating /data on persistent volume)
const dbDir = path.dirname(dbPath)
if (dbDir && dbDir !== "." && !fs.existsSync(dbDir)) {
  try {
    fs.mkdirSync(dbDir, { recursive: true })
    console.log(`Created database directory: ${dbDir}`)
  } catch (e) {
    console.error(`Failed to create database directory: ${dbDir}`, e)
  }
}

// If the database file doesn't exist yet, copy the compiled/seed one from the app directory.
if (!fs.existsSync(dbPath)) {
  const localDb = path.join(process.cwd(), "sqlite.db")
  // Don't copy if it's the exact same file (e.g. local sqlite.db)
  if (fs.existsSync(localDb) && path.resolve(localDb) !== path.resolve(dbPath)) {
    try {
      fs.copyFileSync(localDb, dbPath)
      console.log(`Successfully initialized database at ${dbPath} by copying from root sqlite.db`)
    } catch (e) {
      console.error(`Failed to copy database to ${dbPath}:`, e)
    }
  }
}

export const sqlite = new Database(dbPath)
export const db = drizzle(sqlite, { schema })
