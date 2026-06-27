import { pgTable, text, integer, timestamp, boolean, serial, uuid } from "drizzle-orm/pg-core"

// Better Auth tables
export const user = pgTable("user", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  email: text("email").notNull().unique(),
  emailVerified: boolean("emailVerified").notNull().default(false),
  image: text("image"),
  createdAt: timestamp("createdAt", { mode: "date" })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updatedAt", { mode: "date" })
    .notNull()
    .defaultNow(),
})

export const session = pgTable("session", {
  id: text("id").primaryKey(),
  expiresAt: timestamp("expiresAt", { mode: "date" }).notNull(),
  token: text("token").notNull().unique(),
  createdAt: timestamp("createdAt", { mode: "date" })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updatedAt", { mode: "date" })
    .notNull()
    .defaultNow(),
  ipAddress: text("ipAddress"),
  userAgent: text("userAgent"),
  userId: text("userId")
    .notNull()
    .references(() => user.id, { onDelete: "cascade" }),
})

export const account = pgTable("account", {
  id: text("id").primaryKey(),
  accountId: text("accountId").notNull(),
  providerId: text("providerId").notNull(),
  userId: text("userId")
    .notNull()
    .references(() => user.id, { onDelete: "cascade" }),
  accessToken: text("accessToken"),
  refreshToken: text("refreshToken"),
  idToken: text("idToken"),
  accessTokenExpiresAt: timestamp("accessTokenExpiresAt", { mode: "date" }),
  refreshTokenExpiresAt: timestamp("refreshTokenExpiresAt", { mode: "date" }),
  scope: text("scope"),
  password: text("password"),
  createdAt: timestamp("createdAt", { mode: "date" })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updatedAt", { mode: "date" })
    .notNull()
    .defaultNow(),
})

export const verification = pgTable("verification", {
  id: text("id").primaryKey(),
  identifier: text("identifier").notNull(),
  value: text("value").notNull(),
  expiresAt: timestamp("expiresAt", { mode: "date" }).notNull(),
  createdAt: timestamp("createdAt", { mode: "date" }).defaultNow(),
  updatedAt: timestamp("updatedAt", { mode: "date" }).defaultNow(),
})

// App tables
export const groups = pgTable("groups", {
  id: serial("id").primaryKey(),
  name: text("name").notNull(),
  description: text("description"),
  createdById: text("createdById")
    .notNull()
    .references(() => user.id, { onDelete: "cascade" }),
  createdAt: timestamp("createdAt", { mode: "date" })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updatedAt", { mode: "date" })
    .notNull()
    .defaultNow(),
})

export const groupMembers = pgTable("group_members", {
  id: serial("id").primaryKey(),
  groupId: integer("groupId")
    .notNull()
    .references(() => groups.id, { onDelete: "cascade" }),
  userId: text("userId")
    .notNull()
    .references(() => user.id, { onDelete: "cascade" }),
  role: text("role").notNull().default("member"), // 'admin' or 'member'
  joinedAt: timestamp("joinedAt", { mode: "date" })
    .notNull()
    .defaultNow(),
})

export const groupInvites = pgTable("group_invites", {
  id: text("id").primaryKey(), // Invite token/UUID
  groupId: integer("groupId")
    .notNull()
    .references(() => groups.id, { onDelete: "cascade" }),
  email: text("email").notNull(),
  invitedById: text("invitedById")
    .notNull()
    .references(() => user.id, { onDelete: "cascade" }),
  role: text("role").notNull().default("member"),
  status: text("status").notNull().default("pending"), // 'pending', 'accepted', 'declined'
  createdAt: timestamp("createdAt", { mode: "date" })
    .notNull()
    .defaultNow(),
  expiresAt: timestamp("expiresAt", { mode: "date" }).notNull(),
})

export const tasks = pgTable("tasks", {
  id: serial("id").primaryKey(),
  groupId: integer("groupId").references(() => groups.id, { onDelete: "cascade" }),
  userId: text("userId").notNull(),
  assignedTo: text("assignedTo").references(() => user.id, { onDelete: "set null" }),
  title: text("title").notNull(),
  description: text("description"),
  status: text("status").notNull().default("todo"),
  priority: text("priority").notNull().default("medium"),
  createdAt: timestamp("createdAt", { mode: "date" })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updatedAt", { mode: "date" })
    .notNull()
    .defaultNow(),
})

export const taskAttachments = pgTable("task_attachments", {
  id: serial("id").primaryKey(),
  taskId: integer("taskId")
    .notNull()
    .references(() => tasks.id, { onDelete: "cascade" }),
  fileName: text("fileName").notNull(),
  fileUrl: text("fileUrl").notNull(),
  fileType: text("fileType").notNull(),
  fileSize: integer("fileSize").notNull(),
  createdAt: timestamp("createdAt", { mode: "date" })
    .notNull()
    .defaultNow(),
})

// Multiple assignees per task (junction table)
export const taskAssignees = pgTable("task_assignees", {
  id: serial("id").primaryKey(),
  taskId: integer("taskId")
    .notNull()
    .references(() => tasks.id, { onDelete: "cascade" }),
  userId: text("userId")
    .notNull()
    .references(() => user.id, { onDelete: "cascade" }),
  assignedAt: timestamp("assignedAt", { mode: "date" })
    .notNull()
    .defaultNow(),
})

export type Group = typeof groups.$inferSelect
export type NewGroup = typeof groups.$inferInsert
export type GroupMember = typeof groupMembers.$inferSelect
export type NewGroupMember = typeof groupMembers.$inferInsert
export type GroupInvite = typeof groupInvites.$inferSelect
export type NewGroupInvite = typeof groupInvites.$inferInsert
export type Task = typeof tasks.$inferSelect
export type NewTask = typeof tasks.$inferInsert
export type TaskAttachment = typeof taskAttachments.$inferSelect
export type NewTaskAttachment = typeof taskAttachments.$inferInsert
export type TaskAssignee = typeof taskAssignees.$inferSelect
export type NewTaskAssignee = typeof taskAssignees.$inferInsert

