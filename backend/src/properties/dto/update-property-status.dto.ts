import { IsBoolean } from 'class-validator';

export class UpdatePropertyStatusDto {
  @IsBoolean()
  isArchived!: boolean;
}
