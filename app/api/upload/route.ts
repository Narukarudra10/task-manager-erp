export const dynamic = 'force-dynamic'

import { put } from '@vercel/blob'
import { type NextRequest, NextResponse } from 'next/server'
import { auth } from '@/lib/auth'
import { headers } from 'next/headers'
import fs from 'fs'
import path from 'path'

export async function POST(request: NextRequest) {
  try {
    const session = await auth.api.getSession({ headers: await headers() })
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const formData = await request.formData()
    const file = formData.get('file') as File

    if (!file) {
      return NextResponse.json({ error: 'No file provided' }, { status: 400 })
    }

    // Validate file type
    const allowedTypes = [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'video/mp4',
      'video/webm',
      'video/quicktime',
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ]

    if (!allowedTypes.includes(file.type)) {
      return NextResponse.json(
        { error: 'Invalid file type. Allowed: images, videos, PDFs, Word documents' },
        { status: 400 }
      )
    }

    // 50MB limit
    if (file.size > 50 * 1024 * 1024) {
      return NextResponse.json(
        { error: 'File too large. Maximum size is 50MB' },
        { status: 400 }
      )
    }

    // Sanitize filename to prevent directory traversal and XSS
    const rawFileName = file.name
    const extension = rawFileName.includes('.') ? rawFileName.split('.').pop() : ''
    const baseName = rawFileName.includes('.') ? rawFileName.substring(0, rawFileName.lastIndexOf('.')) : rawFileName
    const sanitizedBase = baseName.replace(/[^a-zA-Z0-9_-]/g, '_')
    const sanitizedExt = extension ? `.${extension.replace(/[^a-zA-Z0-9]/g, '')}` : ''
    const sanitizedFileName = `${sanitizedBase}${sanitizedExt}`
    const uniqueFileName = `${Date.now()}-${sanitizedFileName}`

    let fileUrl = ''

    // If Vercel Blob credentials are provided, use Vercel Blob
    if (process.env.BLOB_READ_WRITE_TOKEN) {
      const blob = await put(`tasks/${session.user.id}/${uniqueFileName}`, file, {
        access: 'public',
      })
      fileUrl = blob.url
    } else {
      // Otherwise, store files locally in public/uploads/
      const uploadDir = path.join(process.cwd(), 'public', 'uploads')
      
      // Ensure local upload directory exists
      if (!fs.existsSync(uploadDir)) {
        fs.mkdirSync(uploadDir, { recursive: true })
      }

      const filePath = path.join(uploadDir, uniqueFileName)
      const arrayBuffer = await file.arrayBuffer()
      const buffer = Buffer.from(arrayBuffer)

      await fs.promises.writeFile(filePath, buffer)
      fileUrl = `/uploads/${uniqueFileName}`
    }

    return NextResponse.json({
      url: fileUrl,
      fileName: sanitizedFileName,
      fileType: file.type,
      fileSize: file.size,
    })
  } catch (error) {
    console.error('Upload error:', error)
    return NextResponse.json({ error: 'Upload failed' }, { status: 500 })
  }
}
