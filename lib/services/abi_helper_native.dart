import 'dart:ffi';

/// Returns the correct APK filename for the running Android ABI,
/// or null if the ABI is unrecognised (e.g. desktop).
String? detectApkFilename() {
  final abi = Abi.current();
  if (abi == Abi.androidArm64) return 'app-arm64-v8a-release.apk';
  if (abi == Abi.androidArm)   return 'app-armeabi-v7a-release.apk';
  if (abi == Abi.androidX64)   return 'app-x86_64-release.apk';
  return null;
}
