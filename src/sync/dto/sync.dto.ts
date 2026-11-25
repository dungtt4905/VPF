import { IsArray, IsObject, IsOptional } from 'class-validator';

export class SyncPushDto {
  @IsOptional()
  @IsArray()
  @IsObject({ each: true })
  categories?: Record<string, any>[];

  @IsOptional()
  @IsArray()
  @IsObject({ each: true })
  transactions?: Record<string, any>[];

  @IsOptional()
  @IsArray()
  @IsObject({ each: true })
  budgets?: Record<string, any>[];


  @IsOptional()
  @IsArray()
  @IsObject({ each: true })
  budgetPlans?: Record<string, any>[];

  @IsOptional()
  @IsArray()
  @IsObject({ each: true })
  budgetJars?: Record<string, any>[];

  @IsOptional()
  @IsArray()
  @IsObject({ each: true })
  budgetCategories?: Record<string, any>[];
}
