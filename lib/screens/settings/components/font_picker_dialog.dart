import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'package:muzo/providers/settings_provider.dart';

class FontPickerDialog extends ConsumerStatefulWidget {
  const FontPickerDialog({super.key});

  @override
  ConsumerState<FontPickerDialog> createState() => _FontPickerDialogState();
}

class _FontPickerDialogState extends ConsumerState<FontPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _allFonts = GoogleFonts.asMap().keys.toList();
  List<String> _filteredFonts = [];

  @override
  void initState() {
    super.initState();
    _allFonts.sort();
    _filteredFonts = _allFonts;
  }

  void _filterFonts(String query) {
    if (query.isEmpty) {
      setState(() => _filteredFonts = _allFonts);
    } else {
      setState(() {
        _filteredFonts = _allFonts
            .where((font) => font.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final currentFont = ref.watch(settingsProvider).appFontFamily;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title Support
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Select App Font',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(settingsProvider.notifier).setAppFontFamily('Archivo Black');
                    Navigator.pop(context);
                  },
                  child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _filterFonts,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Search fonts...',
                hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                prefixIcon: Icon(FluentIcons.search_24_regular, color: cs.onSurface.withValues(alpha: 0.5)),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Font List
          Expanded(
            child: _filteredFonts.isEmpty
                ? Center(
                    child: Text(
                      'No fonts found',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredFonts.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (context, index) {
                      final fontName = _filteredFonts[index];
                      final isSelected = fontName == currentFont;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.primaryColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? theme.primaryColor.withValues(alpha: 0.5)
                                : isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onTap: () {
                            ref.read(settingsProvider.notifier).setAppFontFamily(fontName);
                          },
                          title: Text(
                            fontName,
                            style: GoogleFonts.getFont(
                              fontName,
                              textStyle: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? theme.primaryColor : cs.onSurface,
                              ),
                            ),
                          ),
                          subtitle: Text(
                            'The quick brown fox jumps over the lazy dog',
                            style: GoogleFonts.getFont(
                              fontName,
                              textStyle: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(FluentIcons.checkmark_24_filled, color: theme.primaryColor)
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
