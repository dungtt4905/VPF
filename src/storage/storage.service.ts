import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { v4 as uuidv4 } from 'uuid';
import * as path from 'node:path';

const URL_EXPIRES_IN_SECONDS = 5 * 60;

/**
 * Lưu ảnh trên Supabase Storage thông qua S3 API.
 * Giữ nguyên hợp đồng API: { uploadUrl, publicUrl, key }.
 * Client upload bằng PUT tới uploadUrl, với header Content-Type trùng contentType đã gửi lên.
 */
@Injectable()
export class StorageService {
  private readonly bucket = this.requireEnv('S3_BUCKET');
  private readonly publicBaseUrl = this.requireEnv('S3_PUBLIC_BASE_URL').replace(/\/+$/, '');
  private readonly s3 = new S3Client({
    endpoint: this.requireEnv('S3_ENDPOINT'),
    region: this.requireEnv('S3_REGION'),
    forcePathStyle: true, // Supabase yêu cầu path-style
    credentials: {
      accessKeyId: this.requireEnv('S3_ACCESS_KEY'),
      secretAccessKey: this.requireEnv('S3_SECRET_KEY'),
    },
  });

  async generatePresignedUrl(fileName: string, contentType: string) {
    const ext = path.extname(fileName).toLowerCase().replace(/[^.a-z0-9]/g, '').slice(0, 10);
    const key = `${uuidv4()}${ext}`;

    const uploadUrl = await getSignedUrl(
      this.s3,
      new PutObjectCommand({ Bucket: this.bucket, Key: key, ContentType: contentType }),
      { expiresIn: URL_EXPIRES_IN_SECONDS },
    );

    return { uploadUrl, publicUrl: `${this.publicBaseUrl}/${key}`, key };
  }

  private requireEnv(name: string): string {
    const value = process.env[name]?.trim();
    if (!value) throw new InternalServerErrorException(`Missing environment variable ${name}`);
    return value;
  }
}
