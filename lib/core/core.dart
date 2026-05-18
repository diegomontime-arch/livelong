/// Core layer: config, routing, theme, errors, tenant scope.
library;

export 'bootstrap.dart';
export 'config/app_config.dart';
export 'config/tenant_config.dart';
export 'constants/firestore_paths.dart';
export 'constants/route_paths.dart';
export 'errors/app_exception.dart';
export 'errors/failure.dart';
export 'routing/app_router.dart';
export 'routing/route_guards.dart';
export 'tenant/tenant_scope.dart';
export 'theme/app_colors.dart';
export 'theme/app_theme.dart';
export 'utils/result.dart';
