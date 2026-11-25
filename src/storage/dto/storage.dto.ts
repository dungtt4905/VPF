import { IsNotEmpty, IsString } from 'class-validator';

export class PresignedUrlDto {
  @IsString()
  @IsNotEmpty()
  fileName!: string;

  @IsString()
  @IsNotEmpty()
  contentType!: string;
}
