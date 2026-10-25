import 'package:get/get.dart';

import '../../modules/day_view/day_view_binding.dart';
import '../../modules/day_view/day_view_view.dart';
import '../../modules/shell/shell_binding.dart';
import '../../modules/shell/shell_view.dart';
import '../../modules/station_picker/station_picker_view.dart';
import 'app_routes.dart';

abstract class AppPages {
  static final pages = [
    GetPage(name: Routes.home, page: () => const ShellView(), binding: ShellBinding()),
    GetPage(name: Routes.dayView, page: () => const DayViewView(), binding: DayViewBinding()),
    GetPage(name: Routes.stationPicker, page: () => const StationPickerView()),
  ];
}
