import { Transform, Type } from 'class-transformer';
import { IsBoolean, IsIn, IsInt, IsISO8601, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength } from 'class-validator';
import { AdminReasonDto } from './admin-console.dto';

export class RegistryPageDto {
  @Type(() => Number) @IsInt() @Min(1) @Max(100000) page = 1;
  @Type(() => Number) @IsInt() @Min(1) @Max(50) limit = 20;
  @IsOptional() @IsIn(['PENDING', 'NEEDS_INFO', 'APPROVED', 'REJECTED']) status?: string;
}

export class SubmitVerificationDto extends AdminReasonDto {
  @IsUUID() landlordId!: string;
  @IsUUID() ticketId!: string;
  @IsInt() @Min(0) version!: number;
}

export class SubmitOwnVerificationDto extends AdminReasonDto {
  @IsUUID() ticketId!: string;
  @IsInt() @Min(0) version!: number;
}

export class ReviewRegistryDto extends AdminReasonDto {
  @IsInt() @Min(1) version!: number;
  @IsIn(['APPROVED', 'REJECTED', 'NEEDS_INFO']) status!: 'APPROVED' | 'REJECTED' | 'NEEDS_INFO';
}

export class SubmitPropertyReviewDto extends AdminReasonDto {
  @IsInt() @Min(0) version!: number;
}

export class SaveServicePlanDto extends AdminReasonDto {
  @IsIn(['FREE', 'PRO', 'PREMIUM']) code!: string;
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString() @MinLength(2) @MaxLength(80) name!: string;
  @IsInt() @Min(0) @Max(2147483647) price!: number;
  @IsInt() @Min(1) @Max(1000000) maxProperties!: number;
  @IsInt() @Min(1) @Max(1000000) maxRooms!: number;
  @IsBoolean() isActive!: boolean;
  @IsInt() @Min(0) version!: number;
}

export class AssignSubscriptionDto extends AdminReasonDto {
  @IsUUID() planId!: string;
  @IsInt() @Min(1) planVersion!: number;
  @IsInt() @Min(0) version!: number;
  @IsOptional() @IsISO8601() endsAt?: string;
}
export class CancelSubscriptionDto extends AdminReasonDto {
  @IsInt() @Min(1) version!: number;
}
