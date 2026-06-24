import { drizzle } from "drizzle-orm/postgres-js"
import type { PostgresJsDatabase } from "drizzle-orm/postgres-js"
import postgres from "postgres"
import * as schema from "./schema"

type Schema = typeof schema

let _client: ReturnType<typeof postgres> | null = null
let _db: PostgresJsDatabase<Schema> | null = null

function getClient(): ReturnType<typeof postgres> {
  if (!_client) {
    const connectionString = process.env.DATABASE_URL
    if (!connectionString) {
      throw new Error(
        "DATABASE_URL environment variable is not set. " +
        "Please configure it before starting the application."
      )
    }
    _client = postgres(connectionString)
  }
  return _client
}

export function getDb(): PostgresJsDatabase<Schema> {
  if (!_db) {
    _db = drizzle(getClient(), { schema })
  }
  return _db
}

// Lazy proxy so existing `import { db } from '@/lib/db'` call sites continue
// to work without modification — the connection is only opened on first use.
export const db = new Proxy({} as PostgresJsDatabase<Schema>, {
  get(_target, prop) {
    return (getDb() as any)[prop]
  },
})
