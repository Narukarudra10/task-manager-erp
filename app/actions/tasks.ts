"use server"

import { auth } from "@/lib/auth"
import { db } from "@/lib/db"
import { tasks } from "@/lib/db/schema"
import { and, desc, eq } from "drizzle-orm"
import { headers } from "next/headers"
import { revalidatePath } from "next/cache"

async function getUserId() {
  const session = await auth.api.getSession({ headers: await headers() })
  if (!session?.user) throw new Error("Unauthorized")
  return session.user.id
}

export async function getTasks() {
  const userId = await getUserId()
  return db
    .select()
    .from(tasks)
    .where(eq(tasks.userId, userId))
    .orderBy(desc(tasks.createdAt))
}

export async function createTask(data: {
  title: string
  description?: string
  priority?: string
}) {
  const userId = await getUserId()
  const [task] = await db
    .insert(tasks)
    .values({
      userId,
      title: data.title,
      description: data.description || null,
      priority: data.priority || "medium",
      status: "todo",
    })
    .returning()
  revalidatePath("/")
  return task
}

export async function updateTaskStatus(id: number, status: string) {
  const userId = await getUserId()
  await db
    .update(tasks)
    .set({ status, updatedAt: new Date() })
    .where(and(eq(tasks.id, id), eq(tasks.userId, userId)))
  revalidatePath("/")
}

export async function deleteTask(id: number) {
  const userId = await getUserId()
  await db.delete(tasks).where(and(eq(tasks.id, id), eq(tasks.userId, userId)))
  revalidatePath("/")
}
