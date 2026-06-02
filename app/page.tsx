import { auth } from "@/lib/auth"
import { headers } from "next/headers"
import { redirect } from "next/navigation"
import { db } from "@/lib/db"
import { tasks, taskAttachments } from "@/lib/db/schema"
import { desc, eq } from "drizzle-orm"
import { Header } from "@/components/header"
import { TaskBoard } from "@/components/task-board"
import { AddTaskDialog } from "@/components/add-task-dialog"

export default async function HomePage() {
  const session = await auth.api.getSession({ headers: await headers() })
  if (!session?.user) redirect("/sign-in")

  // Fetch tasks with attachments
  const userTasks = await db
    .select()
    .from(tasks)
    .where(eq(tasks.userId, session.user.id))
    .orderBy(desc(tasks.createdAt))

  // Fetch all attachments for these tasks
  const taskIds = userTasks.map((t) => t.id)
  let attachments: (typeof taskAttachments.$inferSelect)[] = []
  
  if (taskIds.length > 0) {
    const allAttachments = await db.select().from(taskAttachments)
    attachments = allAttachments.filter((a) => taskIds.includes(a.taskId))
  }

  // Group attachments by task
  const tasksWithAttachments = userTasks.map((task) => ({
    ...task,
    attachments: attachments.filter((a) => a.taskId === task.id),
  }))

  return (
    <div className="h-screen flex flex-col bg-background overflow-hidden">
      <Header user={{ name: session.user.name, email: session.user.email }} />
      <main className="flex-1 container mx-auto px-4 py-6 flex flex-col min-h-0">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6 shrink-0">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Task Board</h1>
            <p className="text-muted-foreground mt-1">
              Manage and track your tasks across different stages
            </p>
          </div>
          <AddTaskDialog />
        </div>
        <div className="flex-1 min-h-0">
          <TaskBoard initialTasks={tasksWithAttachments} />
        </div>
      </main>
    </div>
  )
}
