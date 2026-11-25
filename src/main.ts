import "reflect-metadata";
import { NestFactory } from "@nestjs/core";
import { ValidationPipe } from "@nestjs/common";
import { AppModule } from "./app.module";

try {
  process.loadEnvFile();
} catch {
  // Không có file .env: dùng biến môi trường của hệ thống
}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Bật CORS cho mobile và web
  app.enableCors();

  // Bật Validate DTO
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  const rawPort = (process.env.PORT ?? "").trim();
  const parsedPort = rawPort.length > 0 ? Number(rawPort) : Number.NaN;
  const port = Number.isFinite(parsedPort) && parsedPort >= 0 && parsedPort <= 65535 ? parsedPort : 3000;

  // Ràng buộc IPv4 (0.0.0.0) để tránh lỗi adb reverse tcp IPv6
  await app.listen(port, '0.0.0.0');
  console.log(`Server running at http://0.0.0.0:${port}`);
}

bootstrap().catch((error) => {
  console.error("Failed to start server", error);
  process.exit(1);
});
