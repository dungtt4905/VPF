import { IsEmail, IsString, MinLength, IsOptional, IsNotEmpty, ValidateIf } from 'class-validator';

export class RegisterDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(6)
  password!: string;

  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsString()
  phoneNumber?: string;
}

export class LoginDto {
  @IsEmail()
  email!: string;

  @IsString()
  password!: string;
}

export class RefreshDto {
  @IsString()
  @IsNotEmpty()
  refreshToken!: string;
}

export class UpdateAvatarDto {
  /** URL ảnh đại diện; null để xóa ảnh. */
  @ValidateIf((o) => o.avatarUrl !== null)
  @IsString()
  @IsNotEmpty()
  avatarUrl!: string | null;
}
