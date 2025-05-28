import 'dart:io';

import 'package:mega_commons/mega_commons.dart';

import '../../core/app_urls.dart';
import '../models/profile.dart';

class UserProfileProvider {
  UserProfileProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<Profile> getProfileInfo() async {
    final response = await _restClientDio.get(BaseUrls.profileInfo);
    return Profile.fromJson(response.data);
  }

  Future<Profile> onUpdateProfile(Profile profile, String id) async {
    final response = await _restClientDio.patch(
      '${BaseUrls.profile}/$id',
      data: profile.toJson(),
    );
    return Profile.fromJson(response.data);
  }

  Future<void> unregisterDeviceId({required String deviceId}) async {}

  Future<void> updateImageProfile({
    required String image,
    required String id,
  }) async {
    await _restClientDio.patch(
      '${BaseUrls.profile}/$id',
      data: {
        'photo': image,
      },
    );
  }

  Future<MegaFile> onUploadImage(File fileImage) async {
    return _restClientDio.uploadFile(
      file: fileImage,
      returnWithUrl: true,
    );
  }

  Future<MegaResponse> onRemoveAccount(String id) async {
    final response = await _restClientDio.delete('${BaseUrls.profile}/$id');
    return response;
  }

  Future<void> onRegisterUnregister({
    required String deviceId,
    required bool isRegister,
  }) async {
    await _restClientDio.post(
      BaseUrls.registerDevice,
      data: {
        'deviceId': deviceId,
        'isRegister': isRegister,
      },
    );
  }
}
