import { IsEmail, MaxLength } from 'class-validator';

export class CreateTenantInviteDto {
  @IsEmail()
  @MaxLength(255)
  email!: string;
}
