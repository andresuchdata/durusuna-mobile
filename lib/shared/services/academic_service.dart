import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/academic_period.dart';
import 'api_service.dart';

class AcademicService {
  final ApiService _apiService;

  AcademicService(this._apiService);

  /// Get current academic period information
  Future<AcademicPeriodInfo> getCurrentAcademicPeriod() async {
    try {
      final response = await _apiService.get('/api/academic/current-period');

      if (response.statusCode == 200) {
        return AcademicPeriodInfo.fromJson(response.data);
      } else {
        throw ApiException(
          message: 'Failed to get current academic period',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to get current academic period: ${e.toString()}',
        statusCode: 0,
      );
    }
  }
}

// Provider for AcademicService
final academicServiceProvider = Provider<AcademicService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return AcademicService(apiService);
});

// Provider for current academic period
final currentAcademicPeriodProvider =
    FutureProvider<AcademicPeriodInfo>((ref) async {
  final service = ref.read(academicServiceProvider);
  return await service.getCurrentAcademicPeriod();
});
