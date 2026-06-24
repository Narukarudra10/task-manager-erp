export const dynamic = 'force-dynamic'

import { type NextRequest, NextResponse } from 'next/server'
import { auth } from '@/lib/auth'
import { db } from '@/lib/db'
import { groups, groupMembers } from '@/lib/db/schema'
import { eq, sql } from 'drizzle-orm'
import { headers } from 'next/headers'

export async function GET() {
  try {
    const session = await auth.api.getSession({ headers: await headers() })
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    // Fetch groups that the user is a member of
    const userGroups = await db
      .select({
        id: groups.id,
        name: groups.name,
        description: groups.description,
        role: groupMembers.role,
        joinedAt: groupMembers.joinedAt,
      })
      .from(groupMembers)
      .innerJoin(groups, eq(groupMembers.groupId, groups.id))
      .where(eq(groupMembers.userId, session.user.id))

    return NextResponse.json({ groups: userGroups })
  } catch (error) {
    console.error('Error fetching groups:', error)
    return NextResponse.json({ error: 'Failed to fetch groups' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await auth.api.getSession({ headers: await headers() })
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const data = await request.json()
    if (!data.name) {
      return NextResponse.json({ error: 'Group name is required' }, { status: 400 })
    }

    // 1. Insert new group
    const [newGroup] = await db
      .insert(groups)
      .values({
        name: data.name,
        description: data.description || null,
        createdById: session.user.id,
      })
      .returning()

    // 2. Insert creator as admin in group_members
    await db.insert(groupMembers).values({
      groupId: newGroup.id,
      userId: session.user.id,
      role: 'admin',
    })

    return NextResponse.json({ group: newGroup })
  } catch (error) {
    console.error('Error creating group:', error)
    return NextResponse.json({ error: 'Failed to create group' }, { status: 500 })
  }
}
