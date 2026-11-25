import { Injectable, UnauthorizedException, ConflictException, BadRequestException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { RegisterDto, LoginDto } from './dto/auth.dto';
import { PrismaService } from '../prisma.service';
import * as bcrypt from 'bcrypt';
import { requireJwtSecret } from './jwt-secrets';

@Injectable()
export class AuthService {
  private readonly refreshSecret = requireJwtSecret('JWT_REFRESH_SECRET');

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async register(dto: RegisterDto) {
    // Kiểm tra xem user có cung cấp email không
    if (dto.email) {
      const existingUser = await this.prisma.user.findUnique({ where: { email: dto.email } });
      if (existingUser) {
        throw new ConflictException('Email already in use');
      }
    }

    const salt = await bcrypt.genSalt();
    const passwordHash = await bcrypt.hash(dto.password, salt);

    const user = await this.prisma.user.create({
      data: {
        email: dto.email,
        passwordHash,
        name: dto.name || null,
        phoneNumber: dto.phoneNumber || null,
        authProvider: 'LOCAL',
      },
    });

    return this.generateTokens(user.id, user.email || "", user.name, user.avatarUrl);
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });

    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const isPasswordValid = await bcrypt.compare(dto.password, user.passwordHash);

    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    return this.generateTokens(user.id, user.email || "", user.name, user.avatarUrl);
  }

  async refresh(refreshToken: string) {
    let payload: { sub: string };
    try {
      payload = await this.jwtService.verifyAsync<{ sub: string }>(refreshToken, {
        secret: this.refreshSecret,
      });
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user || user.deletedAt) {
      throw new UnauthorizedException('User no longer exists');
    }

    return this.generateTokens(user.id, user.email || '', user.name, user.avatarUrl);
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || user.deletedAt) {
      throw new UnauthorizedException('User no longer exists');
    }
    return { userId: user.id, email: user.email, name: user.name, avatarUrl: user.avatarUrl };
  }

  /** Lưu (hoặc xóa, khi null) ảnh đại diện. Chỉ nhận URL nằm trong kho ảnh của app. */
  async updateAvatar(userId: string, avatarUrl: string | null) {
    if (avatarUrl) {
      const base = (process.env.S3_PUBLIC_BASE_URL || '').replace(/\/+$/, '');
      if (!base || !avatarUrl.startsWith(base + '/')) {
        throw new BadRequestException('Invalid avatar URL');
      }
    }
    const user = await this.prisma.user.update({ where: { id: userId }, data: { avatarUrl } });
    return { userId: user.id, email: user.email, name: user.name, avatarUrl: user.avatarUrl };
  }

  private async generateTokens(userId: string, email: string, name: string | null, avatarUrl: string | null = null) {
    const payload = { sub: userId, email };

    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(payload, {
        expiresIn: '15m',
      }),
      this.jwtService.signAsync(payload, {
        expiresIn: '7d',
        secret: this.refreshSecret,
      }),
    ]);

    return {
      accessToken,
      refreshToken,
      userId,
      email,
      name,
      avatarUrl,
    };
  }
}
