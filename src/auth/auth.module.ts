import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { requireJwtSecret } from './jwt-secrets';
import { PrismaService } from '../prisma.service';

@Module({
  imports: [
    JwtModule.registerAsync({
      global: true,
      useFactory: () => ({ secret: requireJwtSecret('JWT_SECRET') }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, PrismaService],
  exports: [AuthService],
})
export class AuthModule {}
