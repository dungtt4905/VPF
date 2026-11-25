import { Controller, Post, Get, Body, Query, UseGuards, Request } from '@nestjs/common';
import { SyncService } from './sync.service';
import { SyncPushDto } from './dto/sync.dto';
import { JwtAuthGuard, AuthPayload } from '../auth/jwt-auth.guard';

@Controller('sync')
@UseGuards(JwtAuthGuard)
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  @Post('push')
  async push(@Request() req: { user: AuthPayload }, @Body() data: SyncPushDto) {
    return this.syncService.push(req.user.sub, data);
  }

  @Get('pull')
  async pull(@Request() req: { user: AuthPayload }, @Query('lastSyncedAt') lastSyncedAt?: string) {
    // Mặc định epoch nếu chưa từng sync / giá trị rỗng hoặc không hợp lệ
    const parsed = lastSyncedAt ? new Date(lastSyncedAt) : null;
    const syncTime = parsed && !Number.isNaN(parsed.getTime()) ? parsed : new Date(0);
    return this.syncService.pull(req.user.sub, syncTime);
  }
}
