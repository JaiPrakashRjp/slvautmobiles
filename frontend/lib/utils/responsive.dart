import 'package:flutter/material.dart';

/// Layout breakpoints (logical pixels).
class Breakpoints {
  const Breakpoints._();

  static const double tablet = 600;
  static const double largeTablet = 900;
}

enum DeviceClass { phone, tablet, largeTablet }

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  DeviceClass get deviceClass {
    // The phone layout is used on every device — tablets get the exact same
    // single-column experience as the phone (full-width content, bottom nav,
    // no centred/constrained forms or side rail). To re-enable tablet-specific
    // layouts, restore the width-based logic below.
    return DeviceClass.phone;
    // final w = screenWidth;
    // if (w >= Breakpoints.largeTablet) return DeviceClass.largeTablet;
    // if (w >= Breakpoints.tablet) return DeviceClass.tablet;
    // return DeviceClass.phone;
  }

  bool get isPhone => deviceClass == DeviceClass.phone;
  bool get isTablet => deviceClass != DeviceClass.phone;
  bool get isLargeTablet => deviceClass == DeviceClass.largeTablet;

  /// Screen horizontal padding: 16 phone, 24 tablet+.
  double get screenHPadding => isPhone ? 16 : 24;
}

/// Wraps a screen body and adapts it to the device class. On phone it renders
/// [phone] (or [builder]); on tablet it can centre/constrain or hand off to a
/// master-detail layout via [tablet].
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    this.phone,
    this.tablet,
    this.builder,
    this.maxFormWidth,
    this.centerOnTablet = false,
  }) : assert(phone != null || builder != null,
            'Provide either phone or builder');

  /// Phone (and default) content.
  final Widget? phone;

  /// Optional dedicated tablet layout (e.g. master-detail split).
  final Widget? tablet;

  /// Builder form, receives the resolved device class.
  final Widget Function(BuildContext context, DeviceClass device)? builder;

  /// When set, content is constrained to this width and centred on tablet —
  /// used for forms (spec: max 500dp centred on tablet).
  final double? maxFormWidth;

  /// Centre the content horizontally on tablet without constraining width.
  final bool centerOnTablet;

  @override
  Widget build(BuildContext context) {
    final device = context.deviceClass;
    if (builder != null) return builder!(context, device);

    if (device != DeviceClass.phone && tablet != null) return tablet!;

    Widget content = phone!;
    if (device != DeviceClass.phone && maxFormWidth != null) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxFormWidth!),
          child: content,
        ),
      );
    } else if (device != DeviceClass.phone && centerOnTablet) {
      content = Center(child: content);
    }
    return content;
  }
}
