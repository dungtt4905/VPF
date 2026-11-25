/// Parse an toàn cho số từ JSON: Prisma Decimal có thể serialize thành String hoặc num.
double parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.parse(value);
  throw FormatException('Cannot parse number from: $value');
}
