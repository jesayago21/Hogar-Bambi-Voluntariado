import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

/*class Injector {
  void setUp() {

    //? inicializando las dependencias de modulo child
    final ApiChildDatasourceImpl apiChildDatasourceImpl = ApiChildDatasourceImpl();
    final repositoryChild = ChildRepositoryImpl(childDatasource: apiChildDatasourceImpl);

    final ChildrenBlocBloc childrenBloc = ChildrenBlocBloc(repositoryChild);

    final DeleteChildBloc deleteChildBloc = DeleteChildBloc(repositoryChild);

    getIt.registerFactory(() => deleteChildBloc);

    getIt.registerFactory(() => childrenBloc);

    getIt.registerFactory(() => SearchFilterCubit(childrenBloc));

    getIt.registerFactory(() => ChildBloc(repositoryChild));

    getIt.registerFactory(() => ChildFormCubit(repository: repositoryChild));

  }

}*/