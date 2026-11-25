import { Module } from "@nestjs/common";
import { AppController } from "./app.controller";
import { PrismaService } from "./prisma.service";

import { AuthModule } from "./auth/auth.module";
import { StorageModule } from "./storage/storage.module";
import { SyncModule } from "./sync/sync.module";
import { AnalyticsModule } from "./analytics/analytics.module";

@Module({
  imports: [
    AuthModule,
    StorageModule,
    SyncModule,
    AnalyticsModule,
  ],
  controllers: [AppController],
  providers: [PrismaService],
})
export class AppModule {}
