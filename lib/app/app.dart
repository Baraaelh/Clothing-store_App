import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/di/injection.dart';
import '../core/sync/sync_cubit.dart';
import '../features/online_orders/presentation/cubit/online_orders_cubit.dart';
import '../features/pos/presentation/cubit/cart_cubit.dart';
import '../features/pos/presentation/cubit/catalog_cubit.dart';
import 'home_page.dart';
import 'theme.dart';

class AnaqaApp extends StatelessWidget {
  const AnaqaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<SyncCubit>()..start()),
        BlocProvider(create: (_) => sl<CatalogCubit>()..load()),
        BlocProvider(create: (_) => sl<CartCubit>()),
        BlocProvider(create: (_) => sl<OnlineOrdersCubit>()..load()),
      ],
      child: MaterialApp(
        title: 'متجر الأناقة',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const HomePage(),
      ),
    );
  }
}
