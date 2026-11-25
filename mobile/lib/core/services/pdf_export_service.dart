import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/transaction/payment_methods.dart';
import '../../models/category_model.dart';
import '../../models/enums.dart';
import '../../models/transaction_model.dart';
import '../currency/currency_format.dart';

/// Xuất báo cáo giao dịch ra file PDF (chỉ dữ liệu văn bản, không kèm hình ảnh giao dịch).
class PdfExportService {
  static const _primary = PdfColor.fromInt(0xFF1B7F5C);
  static const _income = PdfColor.fromInt(0xFF2E7D32);
  static const _expense = PdfColor.fromInt(0xFFC62828);
  static const _border = PdfColor.fromInt(0xFFE0E0E0);
  static const _headerBg = PdfColor.fromInt(0xFFF1F5F3);

  /// Tạo file PDF trong thư mục tạm và trả về file đó.
  /// [from]/[to] null nghĩa là không giới hạn; [to] tính hết ngày.
  Future<File> export({
    required List<TransactionModel> transactions,
    required List<CategoryModel> categories,
    required String userName,
    DateTime? from,
    DateTime? to,
  }) async {
    final money = CurrencyFormat.vnd;
    final dateFmt = DateFormat('dd/MM/yyyy');

    final rows = transactions.where((t) {
      if (t.deletedAt != null) return false;
      if (from != null && t.transactionAt.isBefore(from)) return false;
      if (to != null && t.transactionAt.isAfter(to)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.transactionAt.compareTo(a.transactionAt));

    final catNames = {for (final c in categories) c.syncId: c.name};
    final totalIncome = rows.where((t) => t.type == TransactionType.income).fold<double>(0, (s, t) => s + t.amount);
    final totalExpense = rows.where((t) => t.type == TransactionType.expense).fold<double>(0, (s, t) => s + t.amount);

    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/BeVietnamPro-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/BeVietnamPro-Bold.ttf'));

    final rangeText = (from == null && to == null)
        ? 'Tất cả thời gian'
        : '${from != null ? dateFmt.format(from) : '...'} - ${to != null ? dateFmt.format(to) : '...'}';

    final doc = pw.Document(title: 'Báo cáo giao dịch', author: userName);

    pw.Widget summaryBox(String label, String value, PdfColor color) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _border),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                pw.SizedBox(height: 4),
                pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 13, color: color)),
              ],
            ),
          ),
        );

    pw.Widget cell(String text, {pw.Font? font, PdfColor? color, pw.Alignment align = pw.Alignment.centerLeft}) =>
        pw.Container(
          alignment: align,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9, color: color)),
        );

    final balance = totalIncome - totalExpense;

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(base: regular, bold: bold),
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Trang ${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          pw.Text('BÁO CÁO GIAO DỊCH', style: pw.TextStyle(font: bold, fontSize: 20, color: _primary)),
          pw.SizedBox(height: 6),
          pw.Text('Người dùng: $userName', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Thời gian: $rangeText', style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            'Ngày xuất: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 14),
          pw.Row(children: [
            summaryBox('Tổng thu', money.format(totalIncome), _income),
            pw.SizedBox(width: 8),
            summaryBox('Tổng chi', money.format(totalExpense), _expense),
            pw.SizedBox(width: 8),
            summaryBox(
              'Chênh lệch',
              '${balance < 0 ? '-' : ''}${money.format(balance.abs())}',
              balance < 0 ? _expense : _income,
            ),
          ]),
          pw.SizedBox(height: 6),
          pw.Text('${rows.length} giao dịch', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 10),
          if (rows.isEmpty)
            pw.Text('Không có giao dịch nào trong khoảng thời gian này.')
          else
            pw.Table(
              border: pw.TableBorder.all(color: _border, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(58),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(3),
                3: pw.FixedColumnWidth(66),
                4: pw.FixedColumnWidth(80),
              },
              children: [
                pw.TableRow(
                  repeat: true,
                  decoration: const pw.BoxDecoration(color: _headerBg),
                  children: [
                    cell('Ngày', font: bold),
                    cell('Danh mục', font: bold),
                    cell('Nội dung', font: bold),
                    cell('Phương thức', font: bold),
                    cell('Số tiền', font: bold, align: pw.Alignment.centerRight),
                  ],
                ),
                for (final t in rows)
                  pw.TableRow(
                    children: [
                      cell(dateFmt.format(t.transactionAt)),
                      cell(catNames[t.categoryId] ?? 'Khác'),
                      cell(_content(t)),
                      cell(paymentLabel(t.paymentMethod)),
                      cell(
                        '${t.type == TransactionType.income ? '+' : '-'}${money.format(t.amount)}',
                        font: bold,
                        color: t.type == TransactionType.income ? _income : _expense,
                        align: pw.Alignment.centerRight,
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/bao-cao-giao-dich_$stamp.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  /// Nội dung hiển thị: ghi chú nếu có, ngược lại là tiêu đề.
  static String _content(TransactionModel t) {
    final note = t.note?.trim() ?? '';
    return note.isNotEmpty ? note : t.title;
  }
}
