import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/di/injection.dart';
import '../core/session/session.dart';
import '../core/sync/sync_cubit.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/online_orders/presentation/cubit/online_orders_cubit.dart';
import '../features/pos/presentation/cubit/cart_cubit.dart';
import '../features/pos/presentation/cubit/catalog_cubit.dart';
import 'home_page.dart';
import 'theme.dart';

class AnaqaApp extends StatelessWidget {
  const AnaqaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthCubit>()..restore(),
      child: MaterialApp(
        title: 'متجر الأناقة',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: BlocBuilder<AuthCubit, AuthState>(
          buildWhen: (a, b) => a.runtimeType != b.runtimeType || b is AuthAuthenticated,
          builder: (context, state) => switch (state) {
            AuthChecking() => const Scaffold(body: Center(child: CircularProgressIndicator())),
            AuthUnauthenticated() => const LoginPage(),
            AuthAuthenticated(:final session) => SessionScope(key: ValueKey(session.token), session: session),
          },
        ),
      ),
    );
  }
}

/// كل ما يخص المستخدم المسجل: يُنشأ من جديد مع كل تسجيل دخول ويُغلق عند الخروج،
/// فلا تبقى سلة أو مزامنة من جلسة سابقة.
class SessionScope extends StatelessWidget {
  const SessionScope({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<SyncCubit>()..start()),
        BlocProvider(create: (_) => sl<CatalogCubit>()..load()),
        BlocProvider(create: (_) => sl<CartCubit>()),
        if (session.canManageOnlineOrders) BlocProvider(create: (_) => sl<OnlineOrdersCubit>()..load()),
      ],
      child: BlocListener<SyncCubit, SyncState>(
        listenWhen: (a, b) => !a.sessionExpired && b.sessionExpired,
        listener: (context, _) => context.read<AuthCubit>().sessionExpired(),
        child: HomePage(session: session),
      ),
    );
  }
}
