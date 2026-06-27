import { betterAuth } from "better-auth"
import { drizzleAdapter } from "better-auth/adapters/drizzle"
import { bearer } from "better-auth/plugins"
import { db } from "./db"
import * as schema from "./db/schema"
import { eq, and } from "drizzle-orm"
import { sendPasswordResetEmail } from "./email"

const getBaseURL = () => {
  if (process.env.BETTER_AUTH_URL) return process.env.BETTER_AUTH_URL
  if (process.env.VERCEL_PROJECT_PRODUCTION_URL)
    return `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
  if (process.env.VERCEL_URL) return `https://${process.env.VERCEL_URL}`
  if (process.env.V0_RUNTIME_URL) return process.env.V0_RUNTIME_URL
  return "http://localhost:3000"
}

const getTrustedOrigins = () => {
  const origins: string[] = [
    "http://localhost:*",
    "https://localhost:*",
  ]
  if (process.env.BETTER_AUTH_URL) origins.push(process.env.BETTER_AUTH_URL)
  if (process.env.VERCEL_PROJECT_PRODUCTION_URL)
    origins.push(`https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`)
  if (process.env.VERCEL_URL) origins.push(`https://${process.env.VERCEL_URL}`)
  if (process.env.V0_RUNTIME_URL) origins.push(process.env.V0_RUNTIME_URL)
  return origins
}

export const auth = betterAuth({
  database: drizzleAdapter(db, {
    provider: "pg",
    schema: schema,
  }),
  secret: process.env.BETTER_AUTH_SECRET || "f3b9c2a8e10d1c7d2e4f5a6b7c8d9e0f",
  baseURL: getBaseURL(),
  trustedOrigins: getTrustedOrigins(),
  emailAndPassword: {
    enabled: true,
    sendResetPassword: async ({ user, url }) => {
      await sendPasswordResetEmail({
        toEmail: user.email,
        resetUrl: url,
        userName: user.name,
      })
    },
    resetPasswordTokenExpiresIn: 3600, // 1 hour
  },
  // Google OAuth — activate by setting GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in .env
  ...(process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET
    ? {
        socialProviders: {
          google: {
            clientId: process.env.GOOGLE_CLIENT_ID,
            clientSecret: process.env.GOOGLE_CLIENT_SECRET,
          },
        },
      }
    : {}),
  plugins: [
    bearer(),
  ],

  databaseHooks: {
    user: {
      create: {
        after: async (user) => {
          // Check for pending invites for this email
          const invites = await db
            .select()
            .from(schema.groupInvites)
            .where(
              and(
                eq(schema.groupInvites.email, user.email.toLowerCase().trim()),
                eq(schema.groupInvites.status, "pending")
              )
            )

          for (const invite of invites) {
            // 1. Add user to the group
            await db.insert(schema.groupMembers).values({
              groupId: invite.groupId,
              userId: user.id,
              role: invite.role,
            })

            // 2. Mark invite as accepted
            await db
              .update(schema.groupInvites)
              .set({ status: "accepted" })
              .where(eq(schema.groupInvites.id, invite.id))
          }
        },
      },
    },
  },
  ...(process.env.NODE_ENV === "development" && {
    advanced: {
      defaultCookieAttributes: {
        sameSite: "none",
        secure: true,
      },
    },
  }),
})
