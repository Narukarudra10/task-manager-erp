import { type NextRequest, NextResponse } from 'next/server'
import { auth } from '@/lib/auth'
import { db } from '@/lib/db'
import { tasks, taskAttachments, taskAssignees, user, groupMembers } from '@/lib/db/schema'
import { desc, eq, and, inArray } from 'drizzle-orm'
import { alias } from 'drizzle-orm/pg-core'
import { headers } from 'next/headers'

// Define alias for joining the user table for creator info
const creator = alias(user, 'creator')

// Helper function to check if user belongs to group
async function isUserGroupMember(userId: string, groupId: number): Promise<boolean> {
  const membership = await db
    .select()
    .from(groupMembers)
    .where(
      and(
        eq(groupMembers.groupId, groupId),
        eq(groupMembers.userId, userId)
      )
    )
    .limit(1)
  return membership.length > 0
}

// Helper function to get all group IDs a user belongs to
async function getUserGroupIds(userId: string): Promise<number[]> {
  const memberships = await db
    .select({ groupId: groupMembers.groupId })
    .from(groupMembers)
    .where(eq(groupMembers.userId, userId))
  return memberships.map((m) => m.groupId)
}

export async function GET(request: NextRequest) {
  try {
    const session = await auth.api.getSession({ headers: await headers() })
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { searchParams } = new URL(request.url)
    const groupIdStr = searchParams.get('groupId')
    
    let allowedGroupIds: number[] = []

    if (groupIdStr) {
      const groupId = parseInt(groupIdStr, 10)
      const isMember = await isUserGroupMember(session.user.id, groupId)
      if (!isMember) {
        return NextResponse.json({ error: 'Forbidden. You are not a member of this group.' }, { status: 403 })
      }
      allowedGroupIds = [groupId]
    } else {
      allowedGroupIds = await getUserGroupIds(session.user.id)
      if (allowedGroupIds.length === 0) {
        return NextResponse.json({ tasks: [] })
      }
    }

    // Fetch all tasks with creator info
    const allTasks = await db
      .select({
        id: tasks.id,
        groupId: tasks.groupId,
        userId: tasks.userId,
        title: tasks.title,
        description: tasks.description,
        status: tasks.status,
        priority: tasks.priority,
        createdAt: tasks.createdAt,
        updatedAt: tasks.updatedAt,
        creatorName: creator.name,
        creatorEmail: creator.email,
        creatorImage: creator.image,
      })
      .from(tasks)
      .leftJoin(creator, eq(tasks.userId, creator.id))
      .where(inArray(tasks.groupId, allowedGroupIds))
      .orderBy(desc(tasks.createdAt))

    const taskIds = allTasks.map((t) => t.id)
    
    // Fetch attachments
    let attachments: (typeof taskAttachments.$inferSelect)[] = []
    if (taskIds.length > 0) {
      const allAttachments = await db.select().from(taskAttachments)
      attachments = allAttachments.filter((a) => taskIds.includes(a.taskId))
    }

    // Fetch all assignees for these tasks with user info
    let assigneeRows: { taskId: number; userId: string; name: string | null; email: string | null; image: string | null; assignedAt: Date }[] = []
    if (taskIds.length > 0) {
      assigneeRows = await db
        .select({
          taskId: taskAssignees.taskId,
          userId: taskAssignees.userId,
          name: user.name,
          email: user.email,
          image: user.image,
          assignedAt: taskAssignees.assignedAt,
        })
        .from(taskAssignees)
        .leftJoin(user, eq(taskAssignees.userId, user.id))
        .where(inArray(taskAssignees.taskId, taskIds))
    }

    // Build tasks with assignees and attachments
    const tasksWithData = allTasks.map((task) => ({
      ...task,
      attachments: attachments.filter((a) => a.taskId === task.id),
      assignees: assigneeRows
        .filter((a) => a.taskId === task.id)
        .map((a) => ({
          userId: a.userId,
          name: a.name,
          email: a.email,
          image: a.image,
        })),
    }))

    return NextResponse.json({ tasks: tasksWithData })
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

    if (!data.groupId) {
      return NextResponse.json({ error: 'Group Context (groupId) is required' }, { status: 400 })
    }
    const groupId = parseInt(data.groupId, 10)

    const isMember = await isUserGroupMember(session.user.id, groupId)
    if (!isMember) {
      return NextResponse.json({ error: 'Forbidden. You are not a member of this group.' }, { status: 403 })
    }

    const [task] = await db
      .insert(tasks)
      .values({
        groupId: groupId,
        userId: session.user.id,
        title: data.title,
        description: data.description || null,
        priority: data.priority || 'medium',
        status: data.status || 'todo',
      })
      .returning()

    // Handle multiple assignees
    const assigneeIds: string[] = data.assignees || (data.assignedTo ? [data.assignedTo] : [])
    if (assigneeIds.length > 0) {
      await db.insert(taskAssignees).values(
        assigneeIds.map((userId: string) => ({
          taskId: task.id,
          userId,
        }))
      )
    }

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

    const [targetTask] = await db
      .select({ groupId: tasks.groupId })
      .from(tasks)
      .where(eq(tasks.id, data.id))
      .limit(1)

    if (!targetTask) {
      return NextResponse.json({ error: 'Task not found' }, { status: 404 })
    }

    if (targetTask.groupId) {
      const isMember = await isUserGroupMember(session.user.id, targetTask.groupId)
      if (!isMember) {
        return NextResponse.json({ error: 'Forbidden. You do not have access to this group\'s tasks.' }, { status: 403 })
      }
    }

    const updateData: Record<string, any> = { updatedAt: new Date() }
    if (data.status !== undefined) updateData.status = data.status

    await db
      .update(tasks)
      .set(updateData)
      .where(eq(tasks.id, data.id))

    // Handle assignees update (replace all assignees)
    if (data.assignees !== undefined) {
      // Delete existing assignees
      await db.delete(taskAssignees).where(eq(taskAssignees.taskId, data.id))

      // Insert new assignees
      const assigneeIds: string[] = data.assignees || []
      if (assigneeIds.length > 0) {
        await db.insert(taskAssignees).values(
          assigneeIds.map((userId: string) => ({
            taskId: data.id,
            userId,
          }))
        )
      }
    }

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

    const [targetTask] = await db
      .select({ groupId: tasks.groupId })
      .from(tasks)
      .where(eq(tasks.id, id))
      .limit(1)

    if (!targetTask) {
      return NextResponse.json({ error: 'Task not found' }, { status: 404 })
    }

    if (targetTask.groupId) {
      const isMember = await isUserGroupMember(session.user.id, targetTask.groupId)
      if (!isMember) {
        return NextResponse.json({ error: 'Forbidden. You do not have access to this group\'s tasks.' }, { status: 403 })
      }
    }

    await db.delete(tasks).where(eq(tasks.id, id))

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Error deleting task:', error)
    return NextResponse.json({ error: 'Failed to delete task' }, { status: 500 })
  }
}
