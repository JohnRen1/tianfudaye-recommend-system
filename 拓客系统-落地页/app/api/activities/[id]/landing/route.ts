import { NextRequest } from 'next/server';
import { createServiceClient } from '@/lib/supabase';
import { ok, fail } from '@/lib/api-response';
import type { ActivityLandingDetailDTO } from '@/lib/contracts/tracking';
import { TRACKING_ERROR_CODES } from '@/lib/contracts/tracking';

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;

  if (!id) {
    return fail(TRACKING_ERROR_CODES.TRACK_ACTIVITY_NOT_FOUND, '活动 id 不能为空', 400);
  }

  const serviceClient = createServiceClient();

  const { data: activity, error } = await serviceClient
    .from('activities')
    .select('id, name, start_at, end_at, place, teacher, speaker_title, description, cover_image, status')
    .eq('id', id)
    .eq('status', 'published')
    .single();

  if (error || !activity) {
    return fail(TRACKING_ERROR_CODES.TRACK_ACTIVITY_NOT_FOUND, '活动不存在或已下架', 404);
  }

  const startAt = activity.start_at as string;
  const endAt = (activity.end_at as string | null) ?? null;

  const date = startAt.slice(0, 10);
  const timeStart = startAt.slice(11, 16);
  const time = endAt ? `${timeStart} - ${endAt.slice(11, 16)}` : timeStart;

  const response: ActivityLandingDetailDTO = {
    id: activity.id as string,
    name: activity.name as string,
    date,
    time,
    location: (activity.place as string) ?? '',
    speaker: (activity.teacher as string) ?? '',
    speakerTitle: (activity.speaker_title as string) ?? '',
    description: (activity.description as string) ?? '',
    coverImage: (activity.cover_image as string | null) ?? null,
    status: activity.status as ActivityLandingDetailDTO['status'],
  };

  return ok(response);
}
