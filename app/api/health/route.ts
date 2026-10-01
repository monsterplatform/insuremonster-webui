import { NextResponse } from 'next/server';

/**
 * Liveness, plus the commit this image was built from (Dockerfile BUILD_COMMIT) so a deploy is
 * proven over HTTPS rather than by root on the box. `unknown` or `-dirty` means not proven.
 * Deliberately unauthenticated and free of config: health checkers send no credentials.
 */
export const dynamic = 'force-dynamic';

export function GET() {
  return NextResponse.json(
    {
      status: 'ok',
      timestamp: new Date().toISOString(),
      commit: process.env.BUILD_COMMIT || 'unknown',
    },
    { headers: { 'Cache-Control': 'no-store' } }
  );
}
