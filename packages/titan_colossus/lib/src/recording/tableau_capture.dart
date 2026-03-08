import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'fresco.dart';
import 'glyph.dart';
import 'tableau.dart';

// ---------------------------------------------------------------------------
// TableauCapture — Element tree walker → Glyph extraction
// ---------------------------------------------------------------------------

/// **TableauCapture** — walks the Flutter [Element] tree and extracts
/// [Glyph]s from every visible, meaningful widget.
///
/// This is the engine that makes Glyph capture zero-config. It
/// traverses the live widget tree, classifies each widget, extracts
/// labels from child text, tooltips, hints, and the [Semantics]
/// tree, then builds a [Tableau] snapshot.
///
/// ## Usage (Internal — Called by Shade during recording)
///
/// ```dart
/// final tableau = await TableauCapture.capture(
///   index: 0,
///   route: '/cart',
///   enableScreenCapture: true,
///   screenCapturePixelRatio: 0.5,
/// );
/// ```
///
/// ## Widget Classification
///
/// Widgets are classified into three categories:
///
/// 1. **Always captured (interactive)**: Buttons, text fields,
///    checkboxes, sliders, tabs, navigation items
/// 2. **Always captured (visible content)**: Text, images, icons,
///    cards, dialogs, banners, progress indicators
/// 3. **Skipped (layout noise)**: Container, Padding, SizedBox,
///    Row, Column, Center, Align, Builder, etc.
class TableauCapture {
  // No instances — static API only.
  TableauCapture._();

  /// Maximum tree depth to walk (prevents infinite recursion).
  ///
  /// Flutter widget trees are typically 150–250 levels deep due to
  /// framework overhead (Theme, MediaQuery, Navigator, Overlay,
  /// Focus, Semantics, Scaffold, etc.). The default of 300 provides
  /// headroom for deeply nested custom widgets.
  static int maxDepth = 300;

  /// Maximum number of Glyphs per Tableau (prevents huge snapshots).
  static int maxGlyphs = 200;

  // -----------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------

  /// Capture a [Tableau] of the current screen state.
  ///
  /// Walks the [Element] tree, extracts [Glyph]s from meaningful
  /// widgets, and optionally captures a screenshot ([Fresco]).
  ///
  /// - [index]: Tableau index in the session
  /// - [route]: Current route path
  /// - [triggerImprintIndex]: The Imprint that triggered this capture (-1 for start)
  /// - [enableScreenCapture]: Whether to capture a PNG screenshot
  /// - [screenCapturePixelRatio]: Screenshot resolution multiplier
  static Future<Tableau> capture({
    required int index,
    String? route,
    int triggerImprintIndex = -1,
    bool enableScreenCapture = false,
    double screenCapturePixelRatio = 1.0,
  }) async {
    // Get screen dimensions
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final screenSize = view.physicalSize / view.devicePixelRatio;

    // Walk the element tree
    final glyphs = <Glyph>[];
    final rootElement = WidgetsBinding.instance.rootElement;
    if (rootElement != null) {
      _walkElement(
        element: rootElement,
        glyphs: glyphs,
        depth: 0,
        ancestors: [],
      );
    }

    // Sort by depth (deepest/frontmost first) for hit-test priority
    glyphs.sort((a, b) => b.depth.compareTo(a.depth));

    // Capture screenshot if enabled
    Uint8List? fresco;
    if (enableScreenCapture) {
      fresco = await Fresco.capture(pixelRatio: screenCapturePixelRatio);
    }

    return Tableau(
      index: index,
      timestamp: Duration.zero, // Set by caller with recording timer
      route: route,
      screenWidth: screenSize.width,
      screenHeight: screenSize.height,
      glyphs: glyphs,
      triggerImprintIndex: triggerImprintIndex,
      fresco: fresco,
    );
  }

  // -----------------------------------------------------------------------
  // Tree walking
  // -----------------------------------------------------------------------

  /// Recursively walk the [Element] tree and extract [Glyph]s.
  ///
  /// When [suppressInteractiveLabel] is non-null, any child interactive widget
  /// that resolves to the same label is skipped. This prevents nested widget
  /// layers (e.g. FilledButton → InkWell → GestureDetector) from producing
  /// multiple glyphs for a single logical button.
  static void _walkElement({
    required Element element,
    required List<Glyph> glyphs,
    required int depth,
    required List<String> ancestors,
    String? suppressInteractiveLabel,
  }) {
    if (depth > maxDepth || glyphs.length >= maxGlyphs) return;

    final widget = element.widget;
    final widgetType = widget.runtimeType.toString();

    // Check if this widget should be captured
    final classification = _classify(widget);

    // Track whether this node captured an interactive glyph so children
    // with the same label can be suppressed.
    String? childSuppressLabel = suppressInteractiveLabel;

    if (classification != _WidgetClassification.skip) {
      final isInteractive = classification == _WidgetClassification.interactive;

      // If a parent interactive glyph already captured this label, skip.
      if (isInteractive && suppressInteractiveLabel != null) {
        final label = _extractLabel(element, widget);
        if (label == suppressInteractiveLabel) {
          // Skip this glyph but continue walking children — they may
          // contain content (Text, Icon) that should still be captured.
          final childAncestors = [widgetType, ...ancestors.take(7)];
          element.visitChildren((child) {
            _walkElement(
              element: child,
              glyphs: glyphs,
              depth: depth + 1,
              ancestors: childAncestors,
              suppressInteractiveLabel: suppressInteractiveLabel,
            );
          });
          return;
        }
      }

      // Try to extract a Glyph from this element
      final glyph = _extractGlyph(
        element: element,
        widget: widget,
        widgetType: widgetType,
        classification: classification,
        depth: depth,
        ancestors: ancestors,
      );

      if (glyph != null) {
        glyphs.add(glyph);

        // If we just captured an interactive glyph with a label, suppress
        // duplicate interactive children with the same label.
        if (isInteractive && glyph.label != null) {
          childSuppressLabel = glyph.label;
        }
      }
    }

    // Build ancestor list for children (max 8)
    final childAncestors = [widgetType, ...ancestors.take(7)];

    // Recurse into children
    element.visitChildren((child) {
      _walkElement(
        element: child,
        glyphs: glyphs,
        depth: depth + 1,
        ancestors: childAncestors,
        suppressInteractiveLabel: childSuppressLabel,
      );
    });
  }

  /// Extract a [Glyph] from a widget [Element].
  ///
  /// Returns `null` if the widget has no render object or is not
  /// visible on screen.
  static Glyph? _extractGlyph({
    required Element element,
    required Widget widget,
    required String widgetType,
    required _WidgetClassification classification,
    required int depth,
    required List<String> ancestors,
  }) {
    // Get bounds from the render object
    final renderObject = element.renderObject;
    if (renderObject == null) return null;
    if (renderObject is! RenderBox) return null;
    if (!renderObject.hasSize) return null;

    final size = renderObject.size;
    if (size.isEmpty) return null;

    // Convert to global position
    final Offset globalPosition;
    try {
      globalPosition = renderObject.localToGlobal(Offset.zero);
    } catch (_) {
      return null; // Widget not yet laid out
    }

    // Skip off-screen elements
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final screenSize = view.physicalSize / view.devicePixelRatio;
    if (globalPosition.dx + size.width < 0 ||
        globalPosition.dy + size.height < 0 ||
        globalPosition.dx > screenSize.width ||
        globalPosition.dy > screenSize.height) {
      return null;
    }

    // Extract widget-specific properties
    final isInteractive = classification == _WidgetClassification.interactive;
    final label = _extractLabel(element, widget);
    final interactionType = isInteractive ? _getInteractionType(widget) : null;
    final fieldId = _getFieldId(widget);
    final key = _getKey(widget);
    final semanticRole = _getSemanticRole(element);
    final isEnabled = _getEnabledState(widget);
    final currentValue = _getCurrentValue(widget);

    return Glyph(
      widgetType: widgetType,
      label: label,
      left: globalPosition.dx,
      top: globalPosition.dy,
      width: size.width,
      height: size.height,
      isInteractive: isInteractive,
      interactionType: interactionType,
      fieldId: fieldId,
      key: key,
      semanticRole: semanticRole,
      isEnabled: isEnabled,
      currentValue: currentValue,
      ancestors: ancestors,
      depth: depth,
    );
  }

  // -----------------------------------------------------------------------
  // Widget classification
  // -----------------------------------------------------------------------

  /// Classify a widget: interactive, content, or skip.
  static _WidgetClassification _classify(Widget widget) {
    // Interactive widgets
    if (widget is ButtonStyleButton || // ElevatedButton, TextButton, etc.
        widget is IconButton ||
        widget is FloatingActionButton ||
        widget is InkWell ||
        widget is GestureDetector ||
        widget is TextField ||
        widget is TextFormField ||
        widget is Checkbox ||
        widget is Radio ||
        widget is Switch ||
        widget is Slider ||
        widget is DropdownButton ||
        widget is PopupMenuButton ||
        widget is NavigationDestination ||
        widget is TabBar ||
        widget is ListTile ||
        widget is ExpansionTile ||
        widget is SegmentedButton ||
        widget is SearchBar ||
        widget is MenuAnchor ||
        widget is Autocomplete) {
      return _WidgetClassification.interactive;
    }

    // Visible content widgets
    if (widget is Text ||
        widget is RichText ||
        widget is Image ||
        widget is Icon ||
        widget is AppBar ||
        widget is Card ||
        widget is AboutDialog ||
        widget is Dialog ||
        widget is AlertDialog ||
        widget is SimpleDialog ||
        widget is SnackBar ||
        widget is BottomSheet ||
        widget is Chip ||
        widget is Badge ||
        widget is Banner ||
        widget is Tooltip ||
        widget is Drawer ||
        widget is CircularProgressIndicator ||
        widget is LinearProgressIndicator) {
      return _WidgetClassification.content;
    }

    // Everything else is layout noise — skip
    return _WidgetClassification.skip;
  }

  // -----------------------------------------------------------------------
  // Label extraction
  // -----------------------------------------------------------------------

  /// Extract a human-readable label from a widget.
  ///
  /// Strategy varies by widget type:
  /// - Buttons → child [Text] widget
  /// - [TextField] → `decoration.hintText` or `decoration.labelText`
  /// - [Text] → `data` property (truncated)
  /// - [Icon] → [Tooltip.message] or `semanticLabel`
  /// - [AppBar] → title [Text] widget
  /// - [ListTile] → title [Text] widget
  /// - Falls back to [Semantics.label]
  static String? _extractLabel(Element element, Widget widget) {
    // Text widget — direct data access
    if (widget is Text) {
      final data = widget.data;
      if (data != null && data.isNotEmpty) {
        return data.length > Glyph.maxLabelLength
            ? data.substring(0, Glyph.maxLabelLength)
            : data;
      }
      return widget.textSpan?.toPlainText();
    }

    // RichText
    if (widget is RichText) {
      final plain = widget.text.toPlainText();
      if (plain.isNotEmpty) {
        return plain.length > Glyph.maxLabelLength
            ? plain.substring(0, Glyph.maxLabelLength)
            : plain;
      }
    }

    // TextField — hint or label
    if (widget is TextField) {
      return widget.decoration?.labelText ?? widget.decoration?.hintText;
    }
    if (widget is TextFormField) {
      // TextFormField wraps TextField — get its decoration
      return _findChildLabel(element);
    }

    // Icon — semanticLabel
    if (widget is Icon) {
      return widget.semanticLabel ?? widget.icon?.toString();
    }

    // NavigationDestination — use label property
    if (widget is NavigationDestination) {
      return widget.label;
    }

    // Image — semanticLabel
    if (widget is Image) {
      return widget.semanticLabel;
    }

    // AppBar — title text
    if (widget is AppBar) {
      return _findChildLabel(element);
    }

    // ListTile — title text
    if (widget is ListTile) {
      return _findChildLabel(element);
    }

    // Tooltip — message
    if (widget is Tooltip) {
      return widget.message;
    }

    // For buttons and other interactive widgets — find child Text
    if (widget is ButtonStyleButton ||
        widget is InkWell ||
        widget is GestureDetector ||
        widget is IconButton ||
        widget is FloatingActionButton ||
        widget is Chip ||
        widget is Card ||
        widget is ExpansionTile ||
        widget is SegmentedButton) {
      return _findChildLabel(element);
    }

    // Fallback: check Semantics
    return _getSemanticLabel(element);
  }

  /// Walk children to find the first human-readable [Text] label.
  ///
  /// Skips icon codepoints (Unicode Private Use Area characters)
  /// to prefer real text labels over icon glyphs. For example,
  /// `FilledButton.icon(label: Text('Submit'), icon: Icon(...))` will
  /// return `'Submit'` rather than the icon's codepoint.
  static String? _findChildLabel(Element element) {
    String? label;
    String? iconFallback; // Keep icon text as fallback
    element.visitChildren((child) {
      if (label != null) return;
      final widget = child.widget;
      if (widget is Text && widget.data != null && widget.data!.isNotEmpty) {
        final data = widget.data!;
        if (_isIconText(data)) {
          iconFallback ??= data;
        } else {
          label = data.length > Glyph.maxLabelLength
              ? data.substring(0, Glyph.maxLabelLength)
              : data;
        }
        return;
      }
      if (widget is RichText) {
        final plain = widget.text.toPlainText();
        if (plain.isNotEmpty) {
          if (_isIconText(plain)) {
            iconFallback ??= plain;
          } else {
            label = plain.length > Glyph.maxLabelLength
                ? plain.substring(0, Glyph.maxLabelLength)
                : plain;
          }
          return;
        }
      }
      // Check tooltip on IconButton
      if (widget is Tooltip) {
        label = widget.message;
        return;
      }
      // Recurse deeper (but only a few levels)
      final childLabel = _findChildLabel(child);
      if (childLabel != null) {
        if (_isIconText(childLabel)) {
          iconFallback ??= childLabel;
        } else {
          label = childLabel;
        }
      }
    });
    return label ?? iconFallback;
  }

  /// Whether [text] consists solely of icon codepoints (Unicode PUA).
  ///
  /// Icon fonts (MaterialIcons, CupertinoIcons) render glyphs as
  /// characters in the Private Use Area (U+E000–U+F8FF) or
  /// Supplementary PUA (U+F0000–U+10FFFF). Such strings are not
  /// meaningful labels for targeting purposes.
  static bool _isIconText(String text) {
    if (text.isEmpty) return false;
    for (final rune in text.runes) {
      // BMP Private Use Area: U+E000 – U+F8FF
      if (rune >= 0xE000 && rune <= 0xF8FF) continue;
      // Supplementary PUA-A: U+F0000 – U+FFFFD
      if (rune >= 0xF0000 && rune <= 0xFFFFD) continue;
      // Supplementary PUA-B: U+100000 – U+10FFFD
      if (rune >= 0x100000 && rune <= 0x10FFFD) continue;
      // Non-icon character found
      return false;
    }
    return true;
  }

  // -----------------------------------------------------------------------
  // Property extraction
  // -----------------------------------------------------------------------

  /// Determine interaction type for interactive widgets.
  static String _getInteractionType(Widget widget) {
    if (widget is TextField || widget is TextFormField) return 'textInput';
    if (widget is Checkbox) return 'checkbox';
    if (widget is Radio) return 'radio';
    if (widget is Switch) return 'switch';
    if (widget is Slider) return 'slider';
    if (widget is DropdownButton) return 'dropdown';
    if (widget is PopupMenuButton) return 'dropdown';
    if (widget is GestureDetector) {
      if (widget.onLongPress != null) return 'longPress';
    }
    return 'tap';
  }

  /// Get the text field ID if this is a text-related widget.
  static String? _getFieldId(Widget widget) {
    // ShadeTextControllers set key-based IDs
    if (widget is TextField && widget.controller != null) {
      final key = widget.key;
      if (key is ValueKey) return key.value.toString();
    }
    return null;
  }

  /// Get the widget's string key representation.
  static String? _getKey(Widget widget) {
    final key = widget.key;
    if (key == null) return null;
    if (key is ValueKey) return key.value.toString();
    if (key is GlobalKey) return key.toString();
    return key.toString();
  }

  /// Get the semantic role from the Semantics tree.
  static String? _getSemanticRole(Element element) {
    String? role;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is Semantics) {
        final semantics = ancestor.widget as Semantics;
        if (semantics.properties.button ?? false) {
          role = 'button';
          return false;
        }
        if (semantics.properties.textField ?? false) {
          role = 'textField';
          return false;
        }
        if (semantics.properties.header ?? false) {
          role = 'header';
          return false;
        }
        if (semantics.properties.image ?? false) {
          role = 'image';
          return false;
        }
        if (semantics.properties.link ?? false) {
          role = 'link';
          return false;
        }
        if (semantics.properties.slider ?? false) {
          role = 'slider';
          return false;
        }
        if (semantics.properties.toggled != null) {
          role = 'toggle';
          return false;
        }
      }
      return true;
    });
    return role;
  }

  /// Get the semantic label from nearest [Semantics] ancestor.
  static String? _getSemanticLabel(Element element) {
    String? label;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is Semantics) {
        final semantics = ancestor.widget as Semantics;
        if (semantics.properties.label != null &&
            semantics.properties.label!.isNotEmpty) {
          label = semantics.properties.label;
          return false;
        }
      }
      return true;
    });
    return label;
  }

  /// Get the enabled state from a widget.
  static bool _getEnabledState(Widget widget) {
    if (widget is ButtonStyleButton) return widget.enabled;
    if (widget is IconButton) return widget.onPressed != null;
    if (widget is TextField) return widget.enabled ?? true;
    if (widget is Checkbox) return widget.onChanged != null;
    if (widget is Radio) {
      // ignore: deprecated_member_use
      return widget.onChanged != null;
    }
    if (widget is Switch) return widget.onChanged != null;
    if (widget is Slider) return widget.onChanged != null;
    if (widget is ListTile) return widget.enabled;
    return true;
  }

  /// Get the current value for stateful widgets.
  static String? _getCurrentValue(Widget widget) {
    if (widget is Checkbox) return widget.value?.toString();
    if (widget is Switch) return widget.value ? 'on' : 'off';
    if (widget is Slider) return widget.value.toStringAsFixed(2);
    if (widget is Radio) {
      // ignore: deprecated_member_use
      return widget.groupValue?.toString();
    }
    if (widget is TextField) return widget.controller?.text;
    if (widget is TextFormField) return widget.controller?.text;
    return null;
  }
}

// ---------------------------------------------------------------------------
// Internal classification
// ---------------------------------------------------------------------------

/// Widget classification for the tree walker.
enum _WidgetClassification {
  /// Interactive widget — always captured.
  interactive,

  /// Visible content widget — always captured.
  content,

  /// Layout/structural widget — skipped.
  skip,
}
