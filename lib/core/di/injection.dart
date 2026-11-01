import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/online_orders/data/datasources/online_orders_local_data_source.dart';
import '../../features/online_orders/data/datasources/online_orders_remote_data_source.dart';
import '../../features/online_orders/data/repositories/online_orders_repository_impl.dart';
import '../../features/online_orders/data/repositories/online_orders_sync_handlers.dart';
import '../../features/online_orders/domain/repositories/online_orders_repository.dart';
import '../../features/online_orders/domain/usecases/change_online_order_status.dart';
import '../../features/online_orders/domain/usecases/get_online_orders.dart';
import '../../features/online_orders/presentation/cubit/online_orders_cubit.dart';
import '../../features/pos/data/datasources/pos_local_data_source.dart';
import '../../features/pos/data/datasources/pos_remote_data_source.dart';
import '../../features/pos/data/repositories/pos_repository_impl.dart';
import '../../features/pos/data/repositories/pos_sync_handlers.dart';
import '../../features/pos/domain/repositories/pos_repository.dart';
import '../../features/pos/domain/usecases/create_sale.dart';
import '../../features/pos/domain/usecases/get_catalog.dart';
import '../../features/pos/presentation/cubit/cart_cubit.dart';
import '../../features/pos/presentation/cubit/catalog_cubit.dart';
import '../../features/pos/presentation/cubit/checkout_cubit.dart';
import '../config/api_config.dart';
import '../config/app_settings.dart';
import '../database/app_database.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../session/session_manager.dart';
import '../session/session_storage.dart';
import '../sync/sync_cubit.dart';
import '../sync/sync_queue.dart';
import '../sync/sync_service.dart';

final GetIt sl = GetIt.instance;

Future<void> configureDependencies({
  required AppSettings settings,
  AppDatabase? database,
  SessionStorage? sessionStorage,
}) async {
  // ---- Core ----
  sl
    ..registerSingleton<AppSettings>(settings)
    ..registerSingleton<AppDatabase>(database ?? AppDatabase())
    ..registerSingleton<SessionManager>(SessionManager(sessionStorage ?? SecureSessionStorage()))
    ..registerLazySingleton<SyncQueue>(() => SyncQueue(sl()))
    ..registerLazySingleton<ApiClient>(() => ApiClient(tokenProvider: () async => sl<SessionManager>().current?.token))
    ..registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(Connectivity()));

  // ---- POS ----
  sl
    ..registerLazySingleton(() => PosLocalDataSource(sl(), sl()))
    ..registerLazySingleton(() => PosRemoteDataSource(sl()))
    ..registerLazySingleton<PosRepository>(() => PosRepositoryImpl(sl(), sl()))
    ..registerLazySingleton(() => GetCatalog(sl()))
    ..registerLazySingleton(() => CreateSale(sl()))
    ..registerFactory(() => CatalogCubit(sl()))
    ..registerFactory(CartCubit.new)
    ..registerFactory(() => CheckoutCubit(sl()));

  // ---- Online orders ----
  sl
    ..registerLazySingleton(() => OnlineOrdersLocalDataSource(sl(), sl()))
    ..registerLazySingleton(() => OnlineOrdersRemoteDataSource(sl()))
    ..registerLazySingleton<OnlineOrdersRepository>(() => OnlineOrdersRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetOnlineOrders(sl()))
    ..registerLazySingleton(() => ChangeOnlineOrderStatus(sl()))
    ..registerFactory(() => OnlineOrdersCubit(sl(), sl()));

  // ---- Auth ----
  sl
    ..registerLazySingleton(() => AuthRemoteDataSource(sl()))
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remote: sl(),
        session: sl(),
        settings: sl(),
        pos: sl(),
        orders: sl(),
        allowDevLogin: ApiConfig.isDevMode,
      ),
    )
    ..registerLazySingleton(() => Login(sl()))
    ..registerFactory(() => AuthCubit(sl(), sl()));

  // ---- Sync ----
  // لإضافة ميزة جديدة للمزامنة: أضف SyncHandler (إرسال) و/أو PullHandler (سحب) هنا.
  sl
    ..registerLazySingleton(
      () => SyncService(
        queue: sl(),
        maxAttempts: settings.maxSyncAttempts,
        handlers: [CreateSaleSyncHandler(sl(), sl()), UpdateOrderStatusSyncHandler(sl(), sl())],
        pullers: [CatalogPullHandler(sl(), sl(), sl()), OnlineOrdersPullHandler(sl(), sl())],
      ),
    )
    ..registerFactory(() => SyncCubit(service: sl(), queue: sl(), network: sl(), interval: settings.syncInterval));
}
