"use client"

import { useTransition } from "react"
import useSWR from "swr"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { 
  MoreHorizontal, 
  Trash2, 
  ArrowRight, 
  ArrowLeft,
  Circle,
  Clock,
  CheckCircle2,
  Paperclip,
  FileText,
  Image,
  Video,
  ExternalLink
} from "lucide-react"
import { type Task, type TaskAttachment } from "@/lib/db/schema"
import { updateTaskStatus, deleteTask } from "@/app/actions/tasks"

interface TaskWithAttachments extends Task {
  attachments: TaskAttachment[]
}

interface TaskBoardProps {
  initialTasks: TaskWithAttachments[]
}

const statusConfig = {
  todo: { 
    label: "To Do", 
    icon: Circle,
    color: "bg-muted/50 border-muted-foreground/20"
  },
  in_progress: { 
    label: "In Progress", 
    icon: Clock,
    color: "bg-blue-50 border-blue-200 dark:bg-blue-950/30 dark:border-blue-800"
  },
  done: { 
    label: "Done", 
    icon: CheckCircle2,
    color: "bg-green-50 border-green-200 dark:bg-green-950/30 dark:border-green-800"
  },
}

const priorityColors = {
  low: "bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300",
  medium: "bg-amber-100 text-amber-700 dark:bg-amber-900/50 dark:text-amber-300",
  high: "bg-red-100 text-red-700 dark:bg-red-900/50 dark:text-red-300",
}

const fetcher = (url: string) => fetch(url).then((res) => res.json())

function getFileIcon(type: string) {
  if (type.startsWith("image/")) return <Image className="h-3 w-3" />
  if (type.startsWith("video/")) return <Video className="h-3 w-3" />
  return <FileText className="h-3 w-3" />
}

function TaskCard({ 
  task, 
  onStatusChange, 
  onDelete 
}: { 
  task: TaskWithAttachments
  onStatusChange: (id: number, status: string) => void
  onDelete: (id: number) => void
}) {
  const [isPending, startTransition] = useTransition()

  const getNextStatus = () => {
    if (task.status === "todo") return "in_progress"
    if (task.status === "in_progress") return "done"
    return null
  }

  const getPrevStatus = () => {
    if (task.status === "done") return "in_progress"
    if (task.status === "in_progress") return "todo"
    return null
  }

  const nextStatus = getNextStatus()
  const prevStatus = getPrevStatus()

  return (
    <Card className={`transition-all hover:shadow-md ${isPending ? "opacity-50" : ""}`}>
      <CardContent className="p-4">
        <div className="flex items-start justify-between gap-2">
          <div className="flex-1 min-w-0">
            <h4 className="font-medium text-sm truncate">{task.title}</h4>
            {task.description && (
              <p className="text-xs text-muted-foreground mt-1 line-clamp-2">
                {task.description}
              </p>
            )}
          </div>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" className="h-8 w-8 shrink-0">
                <MoreHorizontal className="h-4 w-4" />
                <span className="sr-only">Open menu</span>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              {prevStatus && (
                <DropdownMenuItem
                  onClick={() => startTransition(() => onStatusChange(task.id, prevStatus))}
                >
                  <ArrowLeft className="mr-2 h-4 w-4" />
                  Move to {statusConfig[prevStatus as keyof typeof statusConfig].label}
                </DropdownMenuItem>
              )}
              {nextStatus && (
                <DropdownMenuItem
                  onClick={() => startTransition(() => onStatusChange(task.id, nextStatus))}
                >
                  <ArrowRight className="mr-2 h-4 w-4" />
                  Move to {statusConfig[nextStatus as keyof typeof statusConfig].label}
                </DropdownMenuItem>
              )}
              <DropdownMenuItem
                onClick={() => startTransition(() => onDelete(task.id))}
                className="text-destructive focus:text-destructive"
              >
                <Trash2 className="mr-2 h-4 w-4" />
                Delete
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>

        {/* Attachments Preview */}
        {task.attachments && task.attachments.length > 0 && (
          <div className="mt-3 space-y-1">
            <div className="flex items-center gap-1 text-xs text-muted-foreground">
              <Paperclip className="h-3 w-3" />
              <span>{task.attachments.length} attachment{task.attachments.length > 1 ? 's' : ''}</span>
            </div>
            <div className="flex flex-wrap gap-1">
              {task.attachments.slice(0, 3).map((attachment) => (
                <a
                  key={attachment.id}
                  href={attachment.fileUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-1 px-2 py-1 bg-muted rounded text-xs hover:bg-muted/80 transition-colors max-w-[120px]"
                >
                  {getFileIcon(attachment.fileType)}
                  <span className="truncate">{attachment.fileName}</span>
                  <ExternalLink className="h-3 w-3 shrink-0" />
                </a>
              ))}
              {task.attachments.length > 3 && (
                <span className="px-2 py-1 bg-muted rounded text-xs">
                  +{task.attachments.length - 3} more
                </span>
              )}
            </div>
          </div>
        )}

        <div className="flex items-center gap-2 mt-3">
          <Badge 
            variant="secondary" 
            className={`text-xs ${priorityColors[task.priority as keyof typeof priorityColors] || priorityColors.medium}`}
          >
            {task.priority}
          </Badge>
          <span className="text-xs text-muted-foreground">
            {new Date(task.createdAt).toLocaleDateString()}
          </span>
        </div>
      </CardContent>
    </Card>
  )
}

function TaskColumn({ 
  status, 
  tasks, 
  onStatusChange, 
  onDelete 
}: { 
  status: keyof typeof statusConfig
  tasks: TaskWithAttachments[]
  onStatusChange: (id: number, status: string) => void
  onDelete: (id: number) => void
}) {
  const config = statusConfig[status]
  const Icon = config.icon

  return (
    <div className="flex flex-col min-w-[300px] md:min-w-0 h-full">
      <Card className={`border-2 ${config.color} flex flex-col h-full`}>
        <CardHeader className="pb-3 shrink-0">
          <CardTitle className="flex items-center gap-2 text-base font-semibold">
            <Icon className="h-5 w-5" />
            {config.label}
            <Badge variant="secondary" className="ml-auto">
              {tasks.length}
            </Badge>
          </CardTitle>
        </CardHeader>
        <CardContent className="flex-1 overflow-y-auto min-h-0 space-y-3 max-h-[calc(100vh-280px)]">
          {tasks.length === 0 ? (
            <p className="text-sm text-muted-foreground text-center py-8">
              No tasks yet
            </p>
          ) : (
            tasks.map((task) => (
              <TaskCard 
                key={task.id} 
                task={task} 
                onStatusChange={onStatusChange}
                onDelete={onDelete}
              />
            ))
          )}
        </CardContent>
      </Card>
    </div>
  )
}

export function TaskBoard({ initialTasks }: TaskBoardProps) {
  const { data, mutate } = useSWR<{ tasks: TaskWithAttachments[] }>(
    "/api/tasks",
    fetcher,
    {
      fallbackData: { tasks: initialTasks },
      revalidateOnFocus: true,
      refreshInterval: 0,
    }
  )

  const tasks = data?.tasks ?? initialTasks

  const handleStatusChange = async (id: number, status: string) => {
    // Optimistic update
    mutate(
      {
        tasks: tasks.map((task) =>
          task.id === id ? { ...task, status } : task
        ),
      },
      false
    )
    await updateTaskStatus(id, status)
    mutate()
  }

  const handleDelete = async (id: number) => {
    // Optimistic update
    mutate(
      {
        tasks: tasks.filter((task) => task.id !== id),
      },
      false
    )
    await deleteTask(id)
    mutate()
  }

  const todoTasks = tasks.filter((t) => t.status === "todo")
  const inProgressTasks = tasks.filter((t) => t.status === "in_progress")
  const doneTasks = tasks.filter((t) => t.status === "done")

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4 md:gap-6 h-full">
      <TaskColumn 
        status="todo" 
        tasks={todoTasks} 
        onStatusChange={handleStatusChange}
        onDelete={handleDelete}
      />
      <TaskColumn 
        status="in_progress" 
        tasks={inProgressTasks} 
        onStatusChange={handleStatusChange}
        onDelete={handleDelete}
      />
      <TaskColumn 
        status="done" 
        tasks={doneTasks} 
        onStatusChange={handleStatusChange}
        onDelete={handleDelete}
      />
    </div>
  )
}
