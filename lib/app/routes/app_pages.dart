import 'package:get/get.dart';

import '../../modules/add_trip/add_trip_binding.dart';
import '../../modules/add_trip/add_trip_view.dart';
import '../../modules/day_view/day_view_binding.dart';
import '../../modules/day_view/day_view_view.dart';
import '../../modules/home/home_binding.dart';
import '../../modules/home/home_view.dart';
import 'app_routes.dart';

abstract class AppPages {
  static final pages = [
    GetPage(name: Routes.home, page: () => const HomeView(), binding: HomeBinding()),
    GetPage(name: Routes.dayView, page: () => const DayViewView(), binding: DayViewBinding()),
    GetPage(name: Routes.addTrip, page: () => const AddTripView(), binding: AddTripBinding()),
  ];
}
