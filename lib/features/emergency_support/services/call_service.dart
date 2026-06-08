import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class CallService {
  CallService._();

  static Future<bool> call(String number) async {
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    final result = await FlutterPhoneDirectCaller.callNumber(clean);
    return result ?? false;
  }
}
