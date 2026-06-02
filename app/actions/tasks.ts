"use server"

import { auth } from "@/lib/auth"
import { db } from "@/lib/db"
import { tasks, taskAttachments } from "@/lib/db/schema"
import { and, eq } from "drizzle-orm"
import { headers } from "next/headers"

async function getUserId() {
  const session = await auth.api.getSession({ headers: await headers() })
  if (!session?.user) throw new Error("Unauthorized")
  return session.user.id
}

export async function createTask(data: {
  title: string
  description?: string
  priority?: string
  attachments?: { fileName: string; fileUrl: string; fileType: string; fileSize: number }[]
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

  // Add attachments if any
  if (data.attachments && data.attachments.length > 0) {
    await db.insert(taskAttachments).values(
      data.attachments.map((att) => ({
        taskId: task.id,
        fileName: att.fileName,
        fileUrl: att.fileUrl,
        fileType: att.fileType,
        fileSize: att.fileSize,
      }))
    )
  }

  return task
}

export async function updateTaskStatus(id: number, status: string) {
  const userId = await getUserId()
  await db
    .update(tasks)
    .set({ status, updatedAt: new Date() })
    .where(and(eq(tasks.id, id), eq(tasks.userId, userId)))
}

export async function deleteTask(id: number) {
  const userId = await getUserId()
  await db.delete(tasks).where(and(eq(tasks.id, id), eq(tasks.userId, userId)))
}
