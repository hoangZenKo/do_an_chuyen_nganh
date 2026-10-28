import { IsString, MaxLength, MinLength } from "class-validator";

export class CreateTenantZaloMessageDto {
  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  message!: string;
}
