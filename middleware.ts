import { NextRequest, NextResponse } from 'next/server'

export function middleware(request: NextRequest) {
  const origin = request.headers.get('origin')

  // Check if origin is a local development origin (localhost, 127.0.0.1, or Android Emulator loopback 10.0.2.2)
  const isLocalOrigin = origin && /^https?:\/\/(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$/.test(origin)

  // Handle preflight OPTIONS requests
  if (request.method === 'OPTIONS') {
    const preflightHeaders: Record<string, string> = {
      'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, Cookie, Accept, X-Requested-With',
    }

    if (isLocalOrigin) {
      preflightHeaders['Access-Control-Allow-Origin'] = origin
      preflightHeaders['Access-Control-Allow-Credentials'] = 'true'
    } else {
      preflightHeaders['Access-Control-Allow-Origin'] = '*'
    }

    return new NextResponse(null, {
      status: 204,
      headers: preflightHeaders,
    })
  }

  // Handle actual requests
  const response = NextResponse.next()

  if (origin && isLocalOrigin) {
    response.headers.set('Access-Control-Allow-Origin', origin)
    response.headers.set('Access-Control-Allow-Credentials', 'true')
  } else if (origin) {
    response.headers.set('Access-Control-Allow-Origin', '*')
  }
  
  response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS')
  response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, Cookie, Accept, X-Requested-With')

  return response
}

export const config = {
  matcher: '/api/:path*',
}
