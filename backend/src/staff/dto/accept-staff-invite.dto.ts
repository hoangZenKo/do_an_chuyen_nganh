import { IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class AcceptStaffInviteDto {
  @IsString()
  @MinLength(16)
  @MaxLength(256)
  inviteCode!: string;

  @IsString()
  @MinLength(12)
  @MaxLength(128)
  @Matches(/[A-Z]/)
  @Matches(/[a-z]/)
  @Matches(/[0-9]/)
  @Matches(/[^A-Za-z0-9]/)
  password!: string;
}
