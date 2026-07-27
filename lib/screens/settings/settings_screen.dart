import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../services/printer_service.dart';
import '../../services/backup_service.dart';
import '../../services/license_service.dart';
import '../../services/database_service.dart';
import 'permissions_screen.dart';
import 'multi_device_sync_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _printerIpController = TextEditingController();
  final _cloudUrlController = TextEditingController();
  final _licenseKeyController = TextEditingController();
  bool _isTestingPrinter = false;
  bool _isCreatingBackup = false;
  bool _isRestoring = false;
  List<FileSystemEntity> _backups = [];
  Map<String, dynamic>? _licenseInfo;

  @override
  void initState() {
    super.initState();
    _loadBackups();
    _loadLicense();
    _loadPrinterIp();
    _loadCloudUrl();
  }

  Future<void> _loadCloudUrl() async {
    final url = await DatabaseService().getSetting('cloud_base_url');
    if (url != null && mounted) {
      setState(() => _cloudUrlController.text = url);
    }
  }

  Future<void> _loadPrinterIp() async {
    final ip = await DatabaseService().getSetting('printer_ip');
    if (ip != null && mounted) {
      setState(() => _printerIpController.text = ip);
    }
  }

  Future<void> _savePrinterIp() async {
    final ip = _printerIpController.text.trim();
    if (ip.isNotEmpty) {
      await DatabaseService().setSetting('printer_ip', ip);
    }
  }

  Future<void> _loadBackups() async {
    final backups = await BackupService().listBackups();
    setState(() => _backups = backups);
  }

  Future<void> _loadLicense() async {
    final info = await LicenseService().getLicenseInfo();
    setState(() => _licenseInfo = info);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          // Store Info
          const _SectionHeader(title: 'معلومات المحل'),
          const ListTile(
            leading: Icon(Icons.store),
            title: Text('اسم المحل'),
            subtitle: Text('ZAD Store'),
            trailing: Icon(Icons.edit),
          ),
          const ListTile(
            leading: Icon(Icons.location_on),
            title: Text('العنوان'),
            subtitle: Text('الجزائر العاصمة'),
            trailing: Icon(Icons.edit),
          ),
          const ListTile(
            leading: Icon(Icons.phone),
            title: Text('الهاتف'),
            subtitle: Text('0555 123 456'),
            trailing: Icon(Icons.edit),
          ),

          // License
          const _SectionHeader(title: 'الترخيص'),
          if (_licenseInfo != null) ...[
            ListTile(
              leading: const Icon(Icons.verified, color: Color(0xFF43A047)),
              title: const Text('حالة الترخيص'),
              subtitle: Text('نشط - ${_licenseInfo!['license_key'] ?? ''}'),
              trailing: const Icon(Icons.check_circle, color: Color(0xFF43A047)),
            ),
            ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('الأجهزة المسموحة'),
              subtitle: Text('${_licenseInfo!['max_devices'] ?? 1} أجهزة'),
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.key, color: Color(0xFFFF9800)),
              title: const Text('تفعيل الترخيص'),
              subtitle: const Text('انقر لتفعيل الترخيص'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showLicenseDialog,
            ),

          // Printer Settings
          const _SectionHeader(title: 'إعدادات الطابعة (WiFi)'),
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('عنوان IP الطابعة'),
            subtitle: TextField(
              controller: _printerIpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '192.168.1.100',
                border: InputBorder.none,
              ),
              onChanged: (_) => _savePrinterIp(),
            ),
            trailing: IconButton(
              icon: _isTestingPrinter
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.print),
              onPressed: _isTestingPrinter ? null : _testPrinter,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.wifi_find),
            title: const Text('البحث عن طابعات'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _discoverPrinters,
          ),

          // Language
          const _SectionHeader(title: 'اللغة'),
          Consumer<AppProvider>(
            builder: (context, app, child) {
              return ListTile(
                leading: const Icon(Icons.language),
                title: const Text('اللغة الحالية'),
                subtitle: Text(app.locale.languageCode == 'ar' ? 'العربية' : app.locale.languageCode == 'fr' ? 'Français' : 'English'),
                trailing: DropdownButton<String>(
                  value: app.locale.languageCode,
                  items: const [
                    DropdownMenuItem(value: 'ar', child: Text('العربية')),
                    DropdownMenuItem(value: 'fr', child: Text('Français')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (value) {
                    if (value != null) app.setLocale(value);
                  },
                ),
              );
            },
          ),

          // Theme
          const _SectionHeader(title: 'المظهر'),
          Consumer<AppProvider>(
            builder: (context, app, child) {
              return SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: const Text('الوضع الليلي'),
                value: app.themeMode == ThemeMode.dark,
                onChanged: (value) {
                  app.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                },
              );
            },
          ),

          // Users & Permissions (Admin only)
          if (auth.isAdmin) ...[
            const _SectionHeader(title: 'المستخدمين والصلاحيات'),
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('إدارة الصلاحيات'),
              subtitle: const Text('تحديد صلاحيات كل دور'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PermissionsScreen()),
                );
              },
            ),
          ],

          // Sync
          const _SectionHeader(title: 'المزامنة'),
          Consumer<SyncProvider>(
            builder: (context, sync, child) {
              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      sync.isOnline ? Icons.cloud_done : Icons.cloud_off,
                      color: sync.isOnline ? const Color(0xFF43A047) : Colors.grey,
                    ),
                    title: const Text('حالة الاتصال'),
                    subtitle: Text(sync.status),
                    trailing: sync.isSyncing
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              value: sync.progress > 0 ? sync.progress : null,
                              strokeWidth: 2,
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.sync),
                            onPressed: sync.syncNow,
                          ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.computer),
                    title: const Text('ربط مع Desktop'),
                    subtitle: const Text('مزامنة مع نسخة Windows'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showSyncDialog(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.devices),
                    title: const Text('مزامنة الأجهزة'),
                    subtitle: const Text('إدارة الأجهزة والمزامنة'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MultiDeviceSyncScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.cloud_upload),
                    title: const Text('مزامنة سحابية'),
                    subtitle: const Text('ربط مع خادم سحابي'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showCloudSyncDialog,
                  ),
                ],
              );
            },
          ),

          // Backup
          const _SectionHeader(title: 'النسخ الاحتياطي'),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('إنشاء نسخة احتياطية'),
            subtitle: const Text('حفظ جميع البيانات'),
            trailing: _isCreatingBackup
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _isCreatingBackup ? null : _createBackup,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('استعادة نسخة'),
            subtitle: const Text('استرجاع البيانات من نسخة احتياطية'),
            trailing: _isRestoring
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _isRestoring ? null : _showRestoreDialog,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('تصدير CSV'),
            subtitle: const Text('تصدير المبيعات كملف CSV'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _exportCSV,
          ),

          // Backups List
          if (_backups.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('النسخ الاحتياطية المتاحة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ..._backups.take(5).map((backup) {
              final fileName = backup.path.split('/').last;
              final stat = backup.statSync();
              final date = stat.modified.toString().split('.')[0];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.backup, size: 20),
                title: Text(fileName, style: const TextStyle(fontSize: 13)),
                subtitle: Text(date, style: const TextStyle(fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share, size: 20),
                      onPressed: () => BackupService().shareBackup(backup.path),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () => _deleteBackup(backup.path),
                    ),
                  ],
                ),
                onTap: () => _restoreBackup(backup.path),
              );
            }),
          ],

          // About
          const _SectionHeader(title: 'حول'),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('ZAD Mobile POS'),
            subtitle: Text('الإصدار 1.0.0 - جميع الحقوق محفوظة'),
          ),
        ],
      ),
    );
  }

  Future<void> _testPrinter() async {
    setState(() => _isTestingPrinter = true);
    final printer = PrinterService();
    final ip = _printerIpController.text.trim().isEmpty ? '192.168.1.100' : _printerIpController.text.trim();
    final connected = await printer.connect(ip);
    if (connected) {
      await printer.printTestPage();
      await printer.disconnect();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال اختبار الطباعة')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الاتصال بالطابعة'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isTestingPrinter = false);
  }

  Future<void> _discoverPrinters() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('جاري البحث عن طابعات...'),
          ],
        ),
      ),
    );

    final printer = PrinterService();
    final printers = await printer.discoverPrinters();

    if (mounted) Navigator.pop(context);

    if (printers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على طابعات')),
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الطابعات المتاحة'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: printers.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(printers[index]),
                trailing: const Icon(Icons.print),
                onTap: () {
                  _printerIpController.text = printers[index];
                  _savePrinterIp();
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _createBackup() async {
    setState(() => _isCreatingBackup = true);
    try {
      final path = await BackupService().createBackup();
      await _loadBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إنشاء النسخة الاحتياطية')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isCreatingBackup = false);
  }

  void _showRestoreDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استعادة نسخة احتياطية'),
        content: const Text('سيتم استبدال جميع البيانات الحالية. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showBackupSelection();
            },
            child: const Text('متابعة', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _showBackupSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر نسخة احتياطية'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _backups.length,
            itemBuilder: (context, index) {
              final backup = _backups[index];
              final fileName = backup.path.split('/').last;
              return ListTile(
                title: Text(fileName),
                onTap: () {
                  Navigator.pop(context);
                  _restoreBackup(backup.path);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _restoreBackup(String filePath) async {
    setState(() => _isRestoring = true);
    try {
      await BackupService().restoreBackup(filePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت الاستعادة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الاستعادة: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isRestoring = false);
  }

  Future<void> _deleteBackup(String filePath) async {
    await BackupService().deleteBackup(filePath);
    await _loadBackups();
    setState(() {});
  }

  Future<void> _exportCSV() async {
    try {
      final path = await BackupService().exportToCSV();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم التصدير: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showLicenseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفعيل الترخيص'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل مفتاح الترخيص الخاص بك:'),
            const SizedBox(height: 12),
            TextField(
              controller: _licenseKeyController,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'XXXX-XXXX-XXXX-XXXX',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final key = _licenseKeyController.text.trim().toUpperCase();
              final success = await LicenseService().activateLicense(key, maxDevices: 5);
              Navigator.pop(context);
              if (success) {
                await _loadLicense();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تفعيل الترخيص بنجاح')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('مفتاح الترخيص غير صالح'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('تفعيل'),
          ),
        ],
      ),
    );
  }

  void _showCloudSyncDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مزامنة سحابية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _cloudUrlController,
              decoration: const InputDecoration(
                labelText: 'عنوان الخادم',
                hintText: 'https://api.zad-pos.com',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final url = _cloudUrlController.text.trim();
              Navigator.pop(context);
              if (url.isEmpty) return;
              final sync = context.read<SyncProvider>();
              await sync.configureCloudSync(url);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(sync.status)),
                );
              }
            },
            child: const Text('ربط'),
          ),
        ],
      ),
    );
  }

  void _showSyncDialog(BuildContext context) {
    final ipController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ربط مع Desktop'),
        content: TextField(
          controller: ipController,
          decoration: const InputDecoration(
            labelText: 'عنوان IP الخادم',
            hintText: '192.168.1.50:8000',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<SyncProvider>().syncWithDesktop(ipController.text);
            },
            child: const Text('ربط'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
