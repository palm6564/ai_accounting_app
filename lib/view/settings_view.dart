import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../control/app_preferences.dart';
import '../control/account_controller.dart';
import '../l10n/app_text.dart';
import '../service/auth_service.dart';
import '../service/export_service.dart';

class SettingsView extends StatefulWidget {
  final AccountController controller;
  final AppPreferences preferences;

  const SettingsView({
    super.key,
    required this.controller,
    required this.preferences,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  AccountController get controller => widget.controller;
  AppPreferences get preferences => widget.preferences;

  Future<void> _showEditProfileDialog(User user) async {
    final nameController = TextEditingController(text: user.displayName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppText.tr(context, 'แก้ไขข้อมูลผู้ใช้')),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: AppText.tr(context, 'ชื่อผู้ใช้'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppText.tr(context, 'ยกเลิก')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, nameController.text),
            child: Text(AppText.tr(context, 'บันทึก')),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || name.trim().isEmpty) return;

    try {
      await AuthService().updateDisplayName(name);
      if (!mounted) return;
      setState(() {});
      _showMessage(AppText.tr(context, 'บันทึกข้อมูลผู้ใช้แล้ว'));
    } catch (error) {
      if (mounted) {
        _showMessage('${AppText.tr(context, 'บันทึกไม่สำเร็จ')}: $error');
      }
    }
  }

  Future<void> _showCategoryManager() async {
    final tags = List<String>.of(controller.categoryTags);
    final newTagController = TextEditingController();
    late StateSetter updateSheetState;

    void addTag() {
      final normalized = newTagController.text.trim();
      if (normalized.isEmpty ||
          tags.any((tag) => tag.toLowerCase() == normalized.toLowerCase())) {
        return;
      }
      updateSheetState(() {
        tags.add(normalized);
        newTagController.clear();
      });
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          updateSheetState = setSheetState;
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppText.tr(context, 'จัดการหมวดหมู่'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppText.tr(
                      context,
                      'แก้ชื่อ เพิ่ม หรือลบแท็กที่ใช้กับรายการ',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: tags.length,
                      itemBuilder: (context, index) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.label_outline),
                        title: Text(tags[index]),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: AppText.tr(context, 'แก้ไขหมวดหมู่'),
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () async {
                                final edited = await _editTagDialog(
                                  tags[index],
                                );
                                if (edited == null || edited.trim().isEmpty) {
                                  return;
                                }
                                final normalized = edited.trim();
                                if (tags.any(
                                  (tag) =>
                                      tag.toLowerCase() ==
                                          normalized.toLowerCase() &&
                                      tag != tags[index],
                                )) {
                                  return;
                                }
                                setSheetState(() => tags[index] = normalized);
                              },
                            ),
                            IconButton(
                              tooltip: AppText.tr(context, 'ลบหมวดหมู่'),
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                if (tags.length <= 1) {
                                  _showMessage(
                                    AppText.tr(
                                      context,
                                      'ต้องมีหมวดหมู่อย่างน้อย 1 รายการ',
                                    ),
                                  );
                                  return;
                                }
                                setSheetState(() => tags.removeAt(index));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newTagController,
                          decoration: InputDecoration(
                            labelText: AppText.tr(context, 'ชื่อหมวดหมู่ใหม่'),
                            border: const OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => addTag(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: AppText.tr(context, 'เพิ่มหมวดหมู่'),
                        onPressed: addTag,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        try {
                          await controller.saveCategoryTags(tags);
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        } catch (error) {
                          if (!context.mounted) return;
                          _showMessage(
                            '${AppText.tr(context, 'บันทึกไม่สำเร็จ')}: $error',
                          );
                        }
                      },
                      child: Text(AppText.tr(context, 'บันทึกแท็ก')),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    newTagController.dispose();
  }

  Future<String?> _editTagDialog(String currentTag) async {
    final tagController = TextEditingController(text: currentTag);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppText.tr(context, 'แก้ไขหมวดหมู่')),
        content: TextField(controller: tagController, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppText.tr(context, 'ยกเลิก')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, tagController.text),
            child: Text(AppText.tr(context, 'บันทึก')),
          ),
        ],
      ),
    );
    tagController.dispose();
    return result;
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppText.tr(context, 'ลบบัญชีถาวร?')),
        content: Text(
          AppText.tr(
            context,
            'ระบบจะลบข้อมูลบัญชีและรายการที่แอปจัดเก็บไว้ การดำเนินการนี้ย้อนกลับไม่ได้',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppText.tr(context, 'ยกเลิก')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppText.tr(context, 'ดำเนินการต่อ')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppText.tr(context, 'ยืนยันรหัสผ่าน')),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppText.tr(context, 'รหัสผ่าน'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppText.tr(context, 'ยกเลิก')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () =>
                Navigator.pop(dialogContext, passwordController.text),
            child: Text(AppText.tr(context, 'ลบบัญชี')),
          ),
        ],
      ),
    );
    passwordController.dispose();
    if (password == null || password.isEmpty) return;

    try {
      await AuthService().deleteCurrentAccount(password: password);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showMessage(
        error.code == 'wrong-password' || error.code == 'invalid-credential'
            ? AppText.tr(context, 'รหัสผ่านไม่ถูกต้อง')
            : AppText.tr(
                context,
                'ลบบัญชีไม่สำเร็จ กรุณาเข้าสู่ระบบใหม่แล้วลองอีกครั้ง',
              ),
      );
    } catch (error) {
      if (mounted) {
        _showMessage('${AppText.tr(context, 'ลบบัญชีไม่สำเร็จ')}: $error');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    final userName = displayName == null || displayName.isEmpty
        ? AppText.tr(context, 'ผู้ใช้บัญชี')
        : displayName;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(userName.substring(0, 1).toUpperCase()),
            ),
            title: Text(userName),
            subtitle: Text(user?.email ?? 'ไม่พบอีเมลบัญชี'),
            trailing: IconButton(
              tooltip: AppText.tr(context, 'แก้ไขข้อมูลผู้ใช้'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: user == null
                  ? null
                  : () => _showEditProfileDialog(user),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppText.tr(context, 'บัญชีและข้อมูล'),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(AppText.tr(context, 'จัดการหมวดหมู่')),
                subtitle: Text(
                  AppText.tr(context, 'เพิ่มหรือแก้แท็กที่ใช้กับรายการ'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showCategoryManager,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: Text(AppText.tr(context, 'ส่งออกข้อมูลรายการ')),
                subtitle: Text(
                  AppText.tr(context, 'บันทึกรายรับและรายจ่ายเป็นไฟล์ CSV'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  try {
                    await ExportService.exportTransactionsToCSV(
                      controller.transactions,
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    _showMessage(
                      '${AppText.tr(context, 'ส่งออกข้อมูลไม่สำเร็จ')}: $error',
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppText.tr(context, 'การแสดงผล'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppText.tr(context, 'ธีม')),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(AppText.tr(context, 'ธีมสว่าง')),
                        icon: const Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(AppText.tr(context, 'ธีมมืด')),
                        icon: const Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {
                      preferences.themeMode == ThemeMode.dark
                          ? ThemeMode.dark
                          : ThemeMode.light,
                    },
                    onSelectionChanged: (selection) {
                      preferences.setThemeMode(selection.first);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppText.tr(context, 'ภาษา')),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'th',
                        label: Text(AppText.tr(context, 'ภาษาไทย')),
                      ),
                      ButtonSegment(
                        value: 'en',
                        label: Text(AppText.tr(context, 'อังกฤษ')),
                      ),
                    ],
                    selected: {preferences.locale.languageCode},
                    onSelectionChanged: (selection) {
                      preferences.setLocale(Locale(selection.first));
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppText.tr(context, 'ตั้งค่าปฏิทิน'),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppText.tr(context, 'รูปแบบปีที่แสดง')),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        label: Text(AppText.tr(context, 'พ.ศ.')),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text(AppText.tr(context, 'ค.ศ.')),
                      ),
                    ],
                    selected: {preferences.useBuddhistYear},
                    onSelectionChanged: (selection) {
                      preferences.setUseBuddhistYear(selection.first);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppText.tr(context, 'ความปลอดภัย'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(AppText.tr(context, 'ออกจากระบบ')),
                onTap: () => AuthService().signOut(),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_outlined,
                  color: Colors.red,
                ),
                title: Text(
                  AppText.tr(context, 'ลบบัญชี'),
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: _confirmDeleteAccount,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
