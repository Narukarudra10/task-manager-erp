import { NextResponse } from 'next/server'
import { auth } from '@/lib/auth'
import { db } from '@/lib/db'
import { tasks, taskAttachments } from '@/lib/db/schema'
import { and, desc, eq } from 'drizzle-orm'
import { headers } from 'next/headers'

export async function GET() {
  try {
    const session = await auth.api.getSession({ headers: await headers() })
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const userTasks = await db
      .select()
      .from(tasks)
      .where(eq(tasks.userId, session.user.id))
      .orderBy(desc(tasks.createdAt))

    // Fetch attachments for all tasks
    const taskIds = userTasks.map((t) => t.id)
    let attachments: (typeof taskAttachments.$inferSelect)[] = []
    
    if (taskIds.length > 0) {
      attachments = await db
        .select()
        .from(taskAttachments)
        .where(
          taskIds.length === 1
            ? eq(taskAttachments.taskId, taskIds[0])
            : eq(taskAttachments.taskId, taskIds[0]) // Drizzle doesn't have inArray for serial, so we'll fetch per task
        )
      
      // Actually fetch all attachments for efficiency
      const allAttachments = await db.select().from(taskAttachments)
      attachments = allAttachments.filter((a) => taskIds.includes(a.taskId))
    }

    // Group attachments by task
    const tasksWithAttachments = userTasks.map((task) => ({
      ...task,
      attachments: attachments.filter((a) => a.taskId === task.id),
    }))

    return NextResponse.json({ tasks: tasksWithAttachments })
  } catch (error) {
    console.error('Error fetching tasks:', error)
    return NextResponse.json({ error: 'Failed to fetch tasks' }, { status: 500 })
  }
}
