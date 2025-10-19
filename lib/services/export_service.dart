import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/bill_hive.dart';
import '../utils/formatters.dart';
import '../utils/logger.dart';

class ExportService {
  static const String _tag = 'ExportService';

  /// Export bills to CSV format
  /// Returns CSV string with headers and bill data
  static String exportToCSV(List<BillHive> bills) {
    // Define headers
    final List<List<dynamic>> rows = [
      ['Title', 'Amount', 'Due Date', 'Payment Date', 'Category', 'Vendor'],
    ];

    // Add bill data
    for (final bill in bills) {
      rows.add([
        bill.title,
        formatCurrencyFull(bill.amount),
        DateFormat('MMM d, yyyy').format(bill.dueAt),
        bill.paidAt != null
            ? DateFormat('MMM d, yyyy').format(bill.paidAt!)
            : 'Not Paid',
        bill.category,
        bill.vendor,
      ]);
    }

    // Convert to CSV string
    return const ListToCsvConverter().convert(rows);
  }

  /// Export bills to Excel format
  /// Returns Excel file bytes
  static List<int> exportToExcel(List<BillHive> bills) {
    final excel = Excel.createExcel();
    final sheet = excel['Bills'];

    // Add headers with bold formatting
    final headerStyle = CellStyle(bold: true, fontSize: 12);

    final headers = [
      'Title',
      'Amount',
      'Due Date',
      'Payment Date',
      'Category',
      'Vendor',
    ];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Add bill data
    for (var rowIndex = 0; rowIndex < bills.length; rowIndex++) {
      final bill = bills[rowIndex];
      final actualRow = rowIndex + 1;

      // Title
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: actualRow))
          .value = TextCellValue(
        bill.title,
      );

      // Amount (formatted as currency)
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: actualRow))
          .value = TextCellValue(
        formatCurrencyFull(bill.amount),
      );

      // Due Date
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: actualRow))
          .value = TextCellValue(
        DateFormat('MMM d, yyyy').format(bill.dueAt),
      );

      // Payment Date
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: actualRow))
          .value = TextCellValue(
        bill.paidAt != null
            ? DateFormat('MMM d, yyyy').format(bill.paidAt!)
            : 'Not Paid',
      );

      // Category
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: actualRow))
          .value = TextCellValue(
        bill.category,
      );

      // Vendor
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: actualRow))
          .value = TextCellValue(
        bill.vendor,
      );
    }

    // Return Excel file bytes
    return excel.encode()!;
  }

  /// Export bills to PDF format
  /// Returns PDF file bytes
  static Future<List<int>> exportToPDF(List<BillHive> bills) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Title
            pw.Header(
              level: 0,
              child: pw.Text(
                'Past Bills Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),

            // Generation date
            pw.Text(
              'Generated on ${dateFormat.format(now)} at ${timeFormat.format(now)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),

            // Summary
            pw.Text(
              'Total Bills: ${bills.length}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Total Amount: ${formatCurrencyFull(bills.fold(0.0, (sum, bill) => sum + bill.amount))}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(2),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _buildTableCell('Title', isHeader: true),
                    _buildTableCell('Amount', isHeader: true),
                    _buildTableCell('Due Date', isHeader: true),
                    _buildTableCell('Payment Date', isHeader: true),
                    _buildTableCell('Category', isHeader: true),
                    _buildTableCell('Vendor', isHeader: true),
                  ],
                ),
                // Data rows
                ...bills.map((bill) {
                  return pw.TableRow(
                    children: [
                      _buildTableCell(bill.title),
                      _buildTableCell(formatCurrencyFull(bill.amount)),
                      _buildTableCell(dateFormat.format(bill.dueAt)),
                      _buildTableCell(
                        bill.paidAt != null
                            ? dateFormat.format(bill.paidAt!)
                            : 'Not Paid',
                      ),
                      _buildTableCell(bill.category),
                      _buildTableCell(bill.vendor),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Helper method to build table cells
  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Save file to device storage
  /// Returns the file path where the file was saved
  static Future<String> saveFile(List<int> bytes, String fileName) async {
    // Get app documents directory
    final directory = await getApplicationDocumentsDirectory();

    // Generate unique filename with timestamp
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final uniqueFileName = '${fileName}_$timestamp';

    // Create file path
    final filePath = '${directory.path}/$uniqueFileName';

    // Write file bytes to storage
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    return filePath;
  }
}
