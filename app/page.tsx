import { auth } from "@/lib/auth"
import { headers } from "next/headers"
import { redirect } from "next/navigation"
import { getTasks } from "@/app/actions/tasks"
import { Header } from "@/components/header"
import { TaskBoard } from "@/components/task-board"
import { AddTaskDialog } from "@/components/add-task-dialog"

export default async function HomePage() {
  const session = await auth.api.getSession({ headers: await headers() })
  if (!session?.user) redirect("/sign-in")

  const tasks = await getTasks()

  return (
    <div className="min-h-screen bg-background">
      <Header user={{ name: session.user.name, email: session.user.email }} />
      <main className="container mx-auto px-4 py-8">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Task Board</h1>
            <p className="text-muted-foreground mt-1">
              Manage and track your tasks across different stages
            </p>
          </div>
          <AddTaskDialog />
        </div>
        <TaskBoard initialTasks={tasks} />
      </main>
    </div>
  )
}
