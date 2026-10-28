import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class ReviewPaymentProofDto {
  @IsIn(['approved', 'rejected', 'APPROVED', 'REJECTED'])
  status!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
