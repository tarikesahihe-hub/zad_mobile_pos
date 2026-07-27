import 'dart:io';
import 'dart:typed_data';
import 'package:esc_pos_printer_plus/esc_pos_printer_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/sale.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  NetworkPrinter? _printer;
  String? _printerIp;
  int _printerPort = 9100;

  String? get printerIp => _printerIp;
  int get printerPort => _printerPort;

  Future<bool> connect(String ip, {int port = 9100}) async {
    try {
      _printerIp = ip;
      _printerPort = port;
      final profile = await CapabilityProfile.load();
      _printer = NetworkPrinter(PaperSize.mm80, profile);
      final result = await _printer!.connect(ip, port: port);
      return result == PosPrintResult.success;
    } catch (e) {
      print('Printer connection error: $e');
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      _printer?.disconnect();
      _printer = null;
      return true;
    } catch (e) {
      return false;
    }
  }

  bool get isConnected => _printer != null;

  Future<void> printSaleReceipt(Sale sale, {
    String storeName = 'ZAD Store',
    String? storeAddress,
    String? storePhone,
    String? storeLogo,
    bool printQr = true,
  }) async {
    if (_printer == null) return;

    final printer = _printer!;
    final now = DateTime.now();

    // Header
    printer.setStyles(PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    printer.text(storeName, styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    printer.setStyles(PosStyles(align: PosAlign.center));
    if (storeAddress != null) printer.text(storeAddress);
    if (storePhone != null) printer.text(storePhone);
    printer.hr();

    // Invoice info
    printer.text('فاتورة مبيعات', styles: PosStyles(align: PosAlign.center, bold: true));
    printer.text('رقم: ${sale.invoiceNumber}', styles: PosStyles(align: PosAlign.center));
    printer.text('التاريخ: ${_formatDate(sale.date)}', styles: PosStyles(align: PosAlign.center));
    if (sale.customerName != null) {
      printer.text('العميل: ${sale.customerName}', styles: PosStyles(align: PosAlign.center));
    }
    printer.hr();

    // Items header
    printer.row([
      PosColumn(text: 'المنتج', width: 5, styles: PosStyles(bold: true)),
      PosColumn(text: 'السعر', width: 3, styles: PosStyles(bold: true)),
      PosColumn(text: 'الكمية', width: 2, styles: PosStyles(bold: true)),
      PosColumn(text: 'الإجمالي', width: 2, styles: PosStyles(bold: true)),
    ]);
    printer.hr();

    // Items
    for (final item in sale.items) {
      printer.row([
        PosColumn(text: item.productName, width: 5),
        PosColumn(text: item.unitPrice.toStringAsFixed(2), width: 3),
        PosColumn(text: item.quantity.toString(), width: 2),
        PosColumn(text: item.total.toStringAsFixed(2), width: 2),
      ]);
    }

    printer.hr();

    // Totals
    printer.row([
      PosColumn(text: 'المجموع:', width: 8, styles: PosStyles(bold: true)),
      PosColumn(text: sale.subtotal.toStringAsFixed(2), width: 4, styles: PosStyles(bold: true)),
    ]);
    if (sale.discount > 0) {
      printer.row([
        PosColumn(text: 'الخصم:', width: 8),
        PosColumn(text: sale.discount.toStringAsFixed(2), width: 4),
      ]);
    }
    if (sale.tax > 0) {
      printer.row([
        PosColumn(text: 'الضريبة:', width: 8),
        PosColumn(text: sale.tax.toStringAsFixed(2), width: 4),
      ]);
    }
    printer.row([
      PosColumn(text: 'الإجمالي:', width: 8, styles: PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(text: sale.total.toStringAsFixed(2), width: 4, styles: PosStyles(bold: true, height: PosTextSize.size2)),
    ]);

    printer.hr();

    // Payment method
    printer.text('طريقة الدفع: ${_getPaymentMethodName(sale.paymentMethod)}', styles: PosStyles(align: PosAlign.center));

    if (printQr) {
      printer.qrcode(sale.invoiceNumber, size: QRSize.Size4);
    }

    printer.feed(2);
    printer.text('شكراً لزيارتكم', styles: PosStyles(align: PosAlign.center, bold: true));
    printer.text('ZAD Mobile POS', styles: PosStyles(align: PosAlign.center));
    printer.feed(4);
    printer.cut();
  }

  Future<void> printTestPage() async {
    if (_printer == null) return;
    final printer = _printer!;
    printer.setStyles(PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    printer.text('ZAD Mobile POS', styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    printer.text('اختبار الطابعة', styles: PosStyles(align: PosAlign.center));
    printer.text('Printer Test Page', styles: PosStyles(align: PosAlign.center));
    printer.hr();
    printer.text('الطابعة تعمل بشكل صحيح', styles: PosStyles(align: PosAlign.center));
    printer.text('Printer is working correctly', styles: PosStyles(align: PosAlign.center));
    printer.feed(4);
    printer.cut();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'cash': return 'نقداً';
      case 'card': return 'بطاقة';
      case 'transfer': return 'تحويل';
      case 'credit': return 'آجل';
      default: return method;
    }
  }

  Future<List<String>> discoverPrinters() async {
    final info = NetworkInfo();
    final wifiIP = await info.getWifiIP();
    if (wifiIP == null) return [];

    final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
    final printers = <String>[];

    for (int i = 1; i < 255; i++) {
      final ip = '$subnet.$i';
      try {
        final socket = await Socket.connect(ip, 9100, timeout: const Duration(milliseconds: 200));
        await socket.close();
        printers.add(ip);
      } catch (_) {}
    }
    return printers;
  }
}
