import { type NextRequest, NextResponse } from 'next/server'
import { auth } from '@/lib/auth'
import { db } from '@/lib/db'
import { tasks, taskAttachments, user } from '@/lib/db/schema'
import { desc, eq } from 'drizzle-orm'
import { alias } from 'drizzle-orm/sqlite-core'
import { headers } from 'next/headers'

// Define aliases for joining the user table multiple times
const creator = alias(user, 'creator')
const assignee = alias(user, 'assignee')

export async function GET() {
  try {
    const session = await auth.api.getSession({ headers: await headers() })
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    // Fetch all tasks with their creator and assignee user information
    const allTasks = await db
      .select({
        id: tasks.id,
        userId: tasks.userId,
        assignedTo: tasks.assignedTo,
        title: tasks.title,
        description: tasks.description,
        status: tasks.status,
        priority: tasks.priority,
        createdAt: tasks.createdAt,
        updatedAt: tasks.updatedAt,
        creatorName: creator.name,
        creatorEmail: creator.email,
        creatorImage: creator.image,
        assigneeName: assignee.name,
        assigneeEmail: assignee.email,
        assigneeImage: assignee.image,
      })
      .from(tasks)
      .leftJoin(creator, eq(tasks.userId, creator.id))
      .leftJoin(assignee, eq(tasks.assignedTo, assignee.id))
      .orderBy(desc(tasks.createdAt))

    // Fetch attachments for all tasks
    const taskIds = allTasks.map((t) => t.id)
    let attachments: (typeof taskAttachments.$inferSelect)[] = []
    
    if (taskIds.length > 0) {
      // Fetch all attachments for efficiency
      const allAttachments = await db.select().from(taskAttachments)
      attachments = allAttachments.filter((a) => taskIds.includes(a.taskId))
    }

    // Group attachments by task
    const tasksWithAttachments = allTasks.map((task) => ({
      ...task,
      attachments: attachments.filter((a) => a.taskId === task.id),
    }))

    return NextResponse.json({ tasks: tasksWithAttachments })
  } catch (error) {
    console.error('Error fetching tasks:', error)
    return NextResponse.json({ error: 'Failed to fetch tasks' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await auth.api.getSession({ headers: await headers() })
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const data = await request.json()
    if (!data.title) {
      return NextResponse.json({ error: 'Title is required' }, { status: 400 })
    }

    const [task] = await db
      .insert(tasks)
      .values({
        userId: session.user.id,
        assignedTo: data.assignedTo || null,
        title: data.title,
        description: data.description || null,
        priority: data.priority || 'medium',
        status: 'todo',
      })
      .returning()

    if (data.attachments && data.attachments.length > 0) {
      await db.insert(taskAttachments).values(
        data.attachments.map((att: any) => ({
          taskId: task.id,
          fileName: att.fileName,
          fileUrl: att.fileUrl,
          fileType: att.fileType,
          fileSize: att.fileSize,
        }))
      )
    }

    return NextResponse.json({ task })
  } catch (error) {
    console.error('Error creating task:', error)
    return NextResponse.json({ error: 'Failed to create task' }, { status: 500 })
  }
}

export async function PATCH(request: NextRequest) {
  try {
    const session = await auth.api.getSession({ headers: await headers() })
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const data = await request.json()
    if (!data.id) {
      return NextResponse.json({ error: 'ID is required' }, { status: 400 })
    }

    const updateData: Record<string, any> = { updatedAt: new Date() }
    if (data.status !== undefined) updateData.status = data.status
    if (data.assignedTo !== undefined) updateData.assignedTo = data.assignedTo

    await db
      .update(tasks)
      .set(updateData)
      .where(eq(tasks.id, data.id))

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Error updating task:', error)
    return NextResponse.json({ error: 'Failed to update task' }, { status: 500 })
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const session = await auth.api.getSession({ headers: await headers() })
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { searchParams } = new URL(request.url)
    const idStr = searchParams.get('id')
    if (!idStr) {
      return NextResponse.json({ error: 'ID is required' }, { status: 400 })
    }
    const id = parseInt(idStr, 10)

    await db.delete(tasks).where(eq(tasks.id, id))

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Error deleting task:', error)
    return NextResponse.json({ error: 'Failed to delete task' }, { status: 500 })
  }
}
