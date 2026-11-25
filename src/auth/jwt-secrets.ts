/**
 * Đọc secret ký JWT từ biến môi trường. Thiếu thì báo lỗi ngay, không dùng giá trị mặc định.
 * Chỉ gọi lúc khởi tạo provider: ở thời điểm import module, file .env chưa được nạp.
 */
export function requireJwtSecret(name: 'JWT_SECRET' | 'JWT_REFRESH_SECRET'): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}
