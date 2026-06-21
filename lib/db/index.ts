import { drizzle } from "drizzle-orm/postgres-js"
import postgres from "postgres"
import * as schema from "./schema"

// Get connection string from environment
const connectionString = process.env.DATABASE_URL || "postgres://localhost:5432/postgres"

// Basic validation to prevent build-time crashes if URL is momentarily invalid
const isValidUrl = (url: string) => {
  return url.startsWith('postgres://') || url.startsWith('postgresql://');
}

// Fallback for build-time if the URL is not yet a valid Postgres URL
const finalUrl = isValidUrl(connectionString)
  ? connectionString
  : "postgres://localhost:5432/postgres"

export const client = postgres(finalUrl)
export const db = drizzle(client, { schema })
