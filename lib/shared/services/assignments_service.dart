import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import 'api_service.dart';

class AssignmentsService {
  final ApiService _apiService;
  AssignmentsService(this._apiService);

  Future<List<Map<String, dynamic>>> getRecentAssignments(
      {int limit = 5}) async {
    final Response response = await _apiService.get(
      ApiConstants.recentAssignments,
      queryParameters: {'limit': limit},
    );
    final data = response.data as Map<String, dynamic>;
    final list = (data['assignments'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>();
  }
}

final assignmentsServiceProvider = Provider<AssignmentsService>((ref) {
  final api = ref.read(apiServiceProvider);
  return AssignmentsService(api);
});
