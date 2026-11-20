import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/inventory/data/stock_entry_data_source.dart';
import '../../features/inventory/presentation/inventory_cubit.dart';
import '../../features/operations/presentation/operations_cubit.dart';
import '../../features/pos/data/datasources/pos_local_data_source.dart';
import '../../features/pos/data/repositories/pos_repository_impl.dart';
import '../../features/pos/domain/repositories/pos_repository.dart';
import '../../features/pos/domain/usecases/create_sale.dart';
import '../../features/pos/domain/usecases/get_catalog.dart';
import '../../features/pos/domain/usecases/get_recent_sales.dart';
import '../../features/pos/presentation/cubit/cart_cubit.dart';
import '../../features/pos/presentation/cubit/catalog_cubit.dart';
import '../../features/pos/presentation/cubit/checkout_cubit.dart';
import '../../features/products/data/catalog_local_data_source.dart';
import '../../features/products/presentation/products_cubit.dart';
import '../config/app_settings.dart';
import '../data/reference_data.dart';
import '../database/app_database.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../session/session_manager.dart';
import '../session/session_storage.dart';
import '../sync/outbox.dart';
import '../sync/sync_cubit.dart';
import '../sync/sync_engine.dart';

final GetIt sl = GetIt.instance;

Future<void> configureDependencies({
  required AppSettings settings,
  AppDatabase? database,
  SessionStorage? sessionStorage,
  ApiClient? apiClient,
}) async {
  // ---- Core ----
  sl
    ..registerSingleton<AppSettings>(settings)
    ..registerSingleton<AppDatabase>(database ?? AppDatabase())
    ..registerSingleton<SessionManager>(SessionManager(sessionStorage ?? SecureSessionStorage()))
    ..registerLazySingleton<Outbox>(() => Outbox(sl()))
    ..registerLazySingleton<ApiClient>(
      () => apiClient ?? ApiClient(tokenProvider: () async => sl<SessionManager>().current?.token),
    )
    ..registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(Connectivity()))
    ..registerLazySingleton(() => ReferenceData(sl()));

  // ---- Sales (POS) ----
  sl
    ..registerLazySingleton(() => PosLocalDataSource(sl(), sl()))
    ..registerLazySingleton<PosRepository>(() => PosRepositoryImpl(sl(), sl(), sl()))
    ..registerLazySingleton(() => GetCatalog(sl()))
    ..registerLazySingleton(() => CreateSale(sl()))
    ..registerLazySingleton(() => GetRecentSales(sl()))
    ..registerFactory(() => CatalogCubit(sl()))
    ..registerFactory(CartCubit.new)
    ..registerFactory(() => CheckoutCubit(sl(), sl()));

  // ---- Products & inventory ----
  sl
    ..registerLazySingleton(() => CatalogLocalDataSource(sl(), sl()))
    ..registerLazySingleton(() => StockEntryDataSource(sl(), sl()))
    ..registerFactory(() => ProductsCubit(sl(), sl()))
    ..registerFactory(() => InventoryCubit(sl(), sl()));

  // ---- Sync ----
  // لربط نوع عملية جديد بأثره المحلي بعد القبول/الرفض: أضف OperationHandler هنا.
  sl
    ..registerLazySingleton(
      () => SyncEngine(api: sl(), database: sl(), outbox: sl(), session: sl(), handlers: [SaleOperationHandler(sl())]),
    )
    ..registerFactory(
      () => SyncCubit(engine: sl(), outbox: sl(), network: sl(), session: sl(), interval: settings.syncInterval),
    )
    ..registerFactory(() => OperationsCubit(sl(), sl(), sl(), sl()));

  // ---- Auth ----
  sl
    ..registerLazySingleton(() => AuthRemoteDataSource(sl()))
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(remote: sl(), session: sl(), settings: sl(), sync: sl()),
    )
    ..registerLazySingleton(() => Login(sl()))
    ..registerFactory(() => AuthCubit(sl(), sl()));
}
