import { Controller, Post, Get, Patch, Body, HttpCode, HttpStatus, UseGuards, Request } from '@nestjs/common';
import { JwtAuthGuard, AuthPayload } from './jwt-auth.guard';
import { AuthService } from './auth.service';
import { RegisterDto, LoginDto, RefreshDto, UpdateAvatarDto } from './dto/auth.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  async register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  async login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  async me(@Request() req: { user: AuthPayload }) {
    return this.authService.me(req.user.sub);
  }

  @Patch('me/avatar')
  @UseGuards(JwtAuthGuard)
  async updateAvatar(@Request() req: { user: AuthPayload }, @Body() dto: UpdateAvatarDto) {
    return this.authService.updateAvatar(req.user.sub, dto.avatarUrl);
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Body() dto: RefreshDto) {
    return this.authService.refresh(dto.refreshToken);
  }
}
