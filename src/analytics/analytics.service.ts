import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma.service';

@Injectable()
export class AnalyticsService {
  constructor(private prisma: PrismaService) {}

  async getSummary(userId: string) {
    const db = this.prisma as any;

    // We fetch all active transactions to group them by month
    // For extreme scale, this would be a raw query using db.$queryRaw
    const transactions = await db.transaction.findMany({
      where: { userId, deletedAt: null },
      select: { amount: true, type: true, transactionAt: true },
      orderBy: { transactionAt: 'asc' },
    });

    const monthlyStats: Record<string, { income: number; expense: number }> = {};
    let totalBalance = 0;

    for (const tx of transactions) {
      const date = new Date(tx.transactionAt);
      const monthYear = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;

      if (!monthlyStats[monthYear]) {
        monthlyStats[monthYear] = { income: 0, expense: 0 };
      }

      // Prisma returns Decimal types as objects, convert to number
      const val = Number(tx.amount);

      if (tx.type === 'INCOME') {
        monthlyStats[monthYear].income += val;
        totalBalance += val;
      } else {
        monthlyStats[monthYear].expense += val;
        totalBalance -= val;
      }
    }

    return {
      totalBalance,
      totalTransactions: transactions.length,
      monthlyStats,
    };
  }
}
