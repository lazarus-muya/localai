import '../../domain/entities/hardware_profile.dart';

abstract class HardwareDetector {
  Future<HardwareProfile> detect();
}
