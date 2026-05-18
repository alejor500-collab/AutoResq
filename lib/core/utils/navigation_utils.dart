import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';

void safeBack(BuildContext context, {String fallback = AppRoutes.welcome}) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(fallback);
}
