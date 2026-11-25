import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { StorageService } from './storage.service';
import { PresignedUrlDto } from './dto/storage.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('storage')
export class StorageController {
  constructor(private readonly storageService: StorageService) {}

  @Post('presigned-url')
  @UseGuards(JwtAuthGuard)
  getPresignedUrl(@Body() dto: PresignedUrlDto) {
    return this.storageService.generatePresignedUrl(dto.fileName, dto.contentType);
  }
}
