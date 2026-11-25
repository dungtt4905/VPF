import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { SyncPushDto } from './dto/sync.dto';

type Row = Record<string, any>;

// Chỉ cho phép các cột có trong schema Prisma (loại bỏ field lạ từ client)
type Model = 'category' | 'transaction' | 'budget' | 'budgetPlan' | 'budgetJar' | 'budgetCategory';

const FIELDS: Record<Model, string[]> = {
  category: ['id', 'userId', 'parentId', 'name', 'icon', 'color', 'type', 'isPredefined', 'createdAt', 'updatedAt', 'deletedAt'],
  transaction: [
    'id', 'userId', 'categoryId', 'title', 'amount', 'type', 'paymentMethod', 'note',
    'imageUrl', 'imageKey', 'transactionAt', 'createdAt', 'updatedAt', 'deletedAt',
  ],
  budget: [
    'id', 'userId', 'categoryId', 'amount', 'period', 'startDate', 'endDate',
    'alertThreshold', 'rollover', 'createdAt', 'updatedAt', 'deletedAt',
  ],
  budgetPlan: ['id', 'userId', 'periodStart', 'periodEnd', 'expectedIncome', 'createdAt', 'updatedAt', 'deletedAt'],
  budgetJar: [
    'id', 'userId', 'planId', 'jarKey', 'name', 'amount', 'alertThreshold', 'rollover', 'isTotal', 'paidAt',
    'createdAt', 'updatedAt', 'deletedAt',
  ],
  budgetCategory: ['id', 'userId', 'planId', 'jarId', 'categoryId', 'categoryName', 'createdAt', 'updatedAt', 'deletedAt'],
};

const DATE_FIELDS = [
  'createdAt', 'updatedAt', 'deletedAt', 'transactionAt', 'startDate', 'endDate', 'periodStart', 'periodEnd', 'paidAt',
];

@Injectable()
export class SyncService {
  constructor(private prisma: PrismaService) {}

  async push(userId: string, data: SyncPushDto) {
    // Toàn bộ push nằm trong một transaction: thứ tự category -> transaction -> budget -> plan -> jar -> liên kết
    await this.prisma.$transaction(async (tx) => {
      const db = tx as any;
      await this.processTable(db, 'category', userId, this.sortCategoriesParentFirst(data.categories));
      await this.processTable(db, 'transaction', userId, data.transactions);
      await this.processTable(db, 'budget', userId, data.budgets);
      await this.processTable(db, 'budgetPlan', userId, data.budgetPlans);
      await this.processTable(db, 'budgetJar', userId, data.budgetJars);
      await this.processTable(db, 'budgetCategory', userId, data.budgetCategories);
    });

    return { success: true, timestamp: new Date().toISOString() };
  }

  async pull(userId: string, since: Date) {
    const db = this.prisma as any;
    // Chốt mốc thời gian trước khi query để không bỏ sót bản ghi cập nhật giữa chừng
    const timestamp = new Date().toISOString();

    // Danh mục của chính user + danh mục hệ thống (không thuộc user nào)
    const categories = await db.category.findMany({
      where: {
        OR: [{ userId }, { isPredefined: true, userId: null }],
        updatedAt: { gt: since },
      },
    });

    const transactions = await db.transaction.findMany({
      where: { userId, updatedAt: { gt: since } },
    });

    const budgets = await db.budget.findMany({
      where: { userId, updatedAt: { gt: since } },
    });

    const budgetPlans = await db.budgetPlan.findMany({
      where: { userId, updatedAt: { gt: since } },
    });
    const budgetJars = await db.budgetJar.findMany({
      where: { userId, updatedAt: { gt: since } },
    });
    const budgetCategories = await db.budgetCategory.findMany({
      where: { userId, updatedAt: { gt: since } },
    });

    // Prisma Decimal serialize thành chuỗi JSON; ép về number để Flutter (`as num`) parse được
    const toNumber = (rows: Row[]) => rows.map((r) => ({ ...r, amount: Number(r.amount) }));
    const planToNumber = (rows: Row[]) => rows.map((r) => ({ ...r, expectedIncome: Number(r.expectedIncome) }));

    return {
      categories,
      transactions: toNumber(transactions),
      budgets: toNumber(budgets),
      budgetPlans: planToNumber(budgetPlans),
      budgetJars: toNumber(budgetJars),
      budgetCategories,
      timestamp,
    };
  }

  /** Sắp xếp để danh mục cha luôn đứng trước con (hỗ trợ nhiều cấp trong cùng batch). */
  private sortCategoriesParentFirst(categories?: Row[]): Row[] | undefined {
    if (!categories || categories.length === 0) return categories;

    const ids = new Set(categories.map((c) => c.id));
    const sorted: Row[] = [];
    const placed = new Set<string>();
    let remaining = [...categories];

    while (remaining.length > 0) {
      const next: Row[] = [];
      for (const c of remaining) {
        // Đặt được nếu là gốc, cha nằm ngoài batch (đã có trong DB), hoặc cha đã được đặt
        if (!c.parentId || !ids.has(c.parentId) || placed.has(c.parentId)) {
          sorted.push(c);
          placed.add(c.id);
        } else {
          next.push(c);
        }
      }
      if (next.length === remaining.length) {
        sorted.push(...next); // vòng lặp cha-con bất thường: không để treo
        break;
      }
      remaining = next;
    }
    return sorted;
  }

  private async processTable(
    db: any,
    modelName: Model,
    userId: string,
    incomingData?: Row[],
  ) {
    if (!incomingData || incomingData.length === 0) return;

    const ids = incomingData.map((item) => item.id);
    const existingRecords: Row[] = await db[modelName].findMany({ where: { id: { in: ids } } });
    const existingMap = new Map<string, Row>(existingRecords.map((item) => [item.id, item]));

    // Tuần tự (không Promise.all) để giữ thứ tự cha -> con trong transaction
    for (const item of incomingData) {
      const existItem = existingMap.get(item.id);

      const payload: Row = {};
      for (const key of FIELDS[modelName]) {
        if (item[key] !== undefined) payload[key] = item[key];
      }

      // Gắn user; riêng danh mục hệ thống thì không thuộc user nào
      if (modelName === 'category' && item.isPredefined) {
        payload.userId = null;
      } else {
        payload.userId = userId;
      }

      for (const key of DATE_FIELDS) {
        if (payload[key]) payload[key] = new Date(payload[key]);
      }

      // Last-Write-Wins
      if (!existItem) {
        await db[modelName].create({ data: payload });
      } else {
        // Không cho ghi đè bản ghi của user khác (hoặc danh mục hệ thống)
        if (existItem.userId !== userId) continue;
        const incomingDate = new Date(item.updatedAt);
        if (incomingDate > new Date(existItem.updatedAt)) {
          const { id: _id, ...data } = payload;
          await db[modelName].update({ where: { id: item.id }, data });
        }
      }
    }
  }
}
