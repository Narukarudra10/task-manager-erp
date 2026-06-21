export const dynamic = 'force-dynamic'

import { type NextRequest, NextResponse } from 'next/server'
import { auth } from '@/lib/auth'
import { db } from '@/lib/db'
import { tasks, taskAttachments, user, groupMembers } from '@/lib/db/schema'
import { desc, eq, and, inArray } from 'drizzle-orm'
import { alias } from 'drizzle-orm/pg-core'
import { headers } from 'next/headers'

// Define aliases for joining the user table multiple times
const creator = alias(user, 'creator')
const assignee = alias(user, 'assignee')

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
      // If no groupId specified, fetch tasks for all groups the user is part of
      allowedGroupIds = await getUserGroupIds(session.user.id)
      if (allowedGroupIds.length === 0) {
        return NextResponse.json({ tasks: [] })
      }
    }

    // Fetch all tasks matching the allowed groups with user info
    const allTasks = await db
      .select({
        id: tasks.id,
        groupId: tasks.groupId,
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
      .where(inArray(tasks.groupId, allowedGroupIds))
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

    if (!data.groupId) {
      return NextResponse.json({ error: 'Group Context (groupId) is required' }, { status: 400 })
    }
    const groupId = parseInt(data.groupId, 10)

    // Check group membership
    const isMember = await isUserGroupMember(session.user.id, groupId)
    if (!isMember) {
      return NextResponse.json({ error: 'Forbidden. You are not a member of this group.' }, { status: 403 })
    }

    const [task] = await db
      .insert(tasks)
      .values({
        groupId: groupId,
        userId: session.user.id,
        assignedTo: data.assignedTo || null,
        title: data.title,
        description: data.description || null,
        priority: data.priority || 'medium',
        status: data.status || 'todo',
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

    // Fetch the task first to check its groupId
    const [targetTask] = await db
      .select({ groupId: tasks.groupId })
      .from(tasks)
      .where(eq(tasks.id, data.id))
      .limit(1)

    if (!targetTask) {
      return NextResponse.json({ error: 'Task not found' }, { status: 404 })
    }

    // Enforce group membership checks
    if (targetTask.groupId) {
      const isMember = await isUserGroupMember(session.user.id, targetTask.groupId)
      if (!isMember) {
        return NextResponse.json({ error: 'Forbidden. You do not have access to this group\'s tasks.' }, { status: 403 })
      }
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

    // Fetch task to check access
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
