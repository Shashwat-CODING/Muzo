import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
    _allFonts.insert(0, 'Karst');
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
    final currentFont = ref.watch(settingsProvider).appFontFamily;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark 
                ? Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8) 
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.0,
              ),
            ),
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
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        ref.read(settingsProvider.notifier).setAppFontFamily('AR One Sans');
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: theme.primaryColor,
                      ),
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
                  style: TextStyle(color: cs.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search fonts...',
                    hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 13),
                    prefixIcon: Icon(FluentIcons.search_24_regular, color: cs.onSurface.withValues(alpha: 0.4), size: 18),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.02),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.primaryColor.withValues(alpha: 0.3)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                  : Colors.white.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? theme.primaryColor.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onTap: () {
                                ref.read(settingsProvider.notifier).setAppFontFamily(fontName);
                              },
                              title: Text(
                                fontName,
                                style: fontName == 'Karst'
                                    ? TextStyle(
                                        fontFamily: 'Karst',
                                        fontSize: 16,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? theme.primaryColor : cs.onSurface,
                                      )
                                    : GoogleFonts.getFont(
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
                                style: fontName == 'Karst'
                                    ? TextStyle(
                                        fontFamily: 'Karst',
                                        fontSize: 13,
                                        color: cs.onSurface.withValues(alpha: 0.6),
                                      )
                                    : GoogleFonts.getFont(
                                        fontName,
                                        textStyle: TextStyle(
                                          fontSize: 13,
                                          color: cs.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                              ),
                              trailing: isSelected
                                  ? Icon(FluentIcons.checkmark_24_filled, color: theme.primaryColor, size: 20)
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
