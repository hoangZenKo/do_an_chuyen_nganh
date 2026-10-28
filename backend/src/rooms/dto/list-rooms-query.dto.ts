import { IsIn, IsOptional } from 'class-validator';

export const ROOM_LIFECYCLE_FILTER = ['active', 'inactive', 'all'] as const;
export type RoomLifecycleFilter = (typeof ROOM_LIFECYCLE_FILTER)[number];

export class ListRoomsQueryDto {
  @IsOptional()
  @IsIn(ROOM_LIFECYCLE_FILTER)
  lifecycle?: RoomLifecycleFilter;
}
