import { type NextRequest, NextResponse } from 'next/server'
import { auth } from '@/lib/auth'
import { db } from '@/lib/db'
import { groupInvites, groupMembers, groups, user } from '@/lib/db/schema'
import { eq, and, sql } from 'drizzle-orm'
import { headers } from 'next/headers'
import crypto from 'crypto'

// GET pending invites for current user's email
export async function GET() {
  try {
    const session = await auth.api.getSession({ headers: await headers() })
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const invites = await db
      .select({
        id: groupInvites.id,
        role: groupInvites.role,
        createdAt: groupInvites.createdAt,
        expiresAt: groupInvites.expiresAt,
        groupName: groups.name,
        groupDescription: groups.description,
        invitedByName: user.name,
        invitedByEmail: user.email,
      })
      .from(groupInvites)
      .innerJoin(groups, eq(groupInvites.groupId, groups.id))
      .innerJoin(user, eq(groupInvites.invitedById, user.id))
      .where(
        and(
          eq(groupInvites.email, session.user.email.toLowerCase().trim()),
          eq(groupInvites.status, 'pending')
        )
      )

    return NextResponse.json({ invites })
  } catch (error) {
    console.error('Error fetching invitations:', error)
    return NextResponse.json({ error: 'Failed to fetch invitations' }, { status: 500 })
  }
}

// POST create/send invitation (requires admin role)
export async function POST(request: NextRequest) {
  try {
    const session = await auth.api.getSession({ headers: await headers() })
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const data = await request.json()
    const { groupId, email, role } = data

    if (!groupId || !email) {
      return NextResponse.json({ error: 'groupId and email are required' }, { status: 400 })
    }

    // Verify current user is admin of the group
    const membership = await db
      .select()
      .from(groupMembers)
      .where(
        and(
          eq(groupMembers.groupId, groupId),
          eq(groupMembers.userId, session.user.id),
          eq(groupMembers.role, 'admin')
        )
      )
      .limit(1)

    if (membership.length === 0) {
      return NextResponse.json({ error: 'Forbidden. Only group admins can invite members.' }, { status: 403 })
    }

    // Generate unique token for invite
    const inviteId = crypto.randomUUID()

    // Invites expire in 7 days
    const expiresAt = new Date()
    expiresAt.setDate(expiresAt.getDate() + 7)

    const [invite] = await db
      .insert(groupInvites)
      .values({
        id: inviteId,
        groupId,
        email: email.toLowerCase().trim(),
        invitedById: session.user.id,
        role: role || 'member',
        expiresAt,
      })
      .returning()

    return NextResponse.json({ invite })
  } catch (error) {
    console.error('Error creating invitation:', error)
    return NextResponse.json({ error: 'Failed to invite user' }, { status: 500 })
  }
}

// PATCH accept/decline invitation
export async function PATCH(request: NextRequest) {
  try {
    const session = await auth.api.getSession({ headers: await headers() })
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const data = await request.json()
    const { inviteId, action } = data // action can be 'accept' or 'decline'

    if (!inviteId || !action || !['accept', 'decline'].includes(action)) {
      return NextResponse.json({ error: 'inviteId and valid action are required' }, { status: 400 })
    }

    // Find the invite
    const invite = await db.query.groupInvites.findFirst({
      where: and(
        eq(groupInvites.id, inviteId),
        eq(groupInvites.status, 'pending')
      ),
    })

    if (!invite) {
      return NextResponse.json({ error: 'Invitation not found or no longer pending' }, { status: 404 })
    }

    // Verify it is for this user's email
    if (invite.email.toLowerCase() !== session.user.email.toLowerCase()) {
      return NextResponse.json({ error: 'This invitation belongs to another email address' }, { status: 403 })
    }

    if (action === 'accept') {
      // 1. Join group
      await db.insert(groupMembers).values({
        groupId: invite.groupId,
        userId: session.user.id,
        role: invite.role,
      })

      // 2. Mark accepted
      await db
        .update(groupInvites)
        .set({ status: 'accepted' })
        .where(eq(groupInvites.id, inviteId))

      return NextResponse.json({ success: true, message: 'Invitation accepted successfully' })
    } else {
      // Mark declined
      await db
        .update(groupInvites)
        .set({ status: 'declined' })
        .where(eq(groupInvites.id, inviteId))

      return NextResponse.json({ success: true, message: 'Invitation declined successfully' })
    }
  } catch (error) {
    console.error('Error updating invitation:', error)
    return NextResponse.json({ error: 'Failed to update invitation' }, { status: 500 })
  }
}
