import 'package:http/http.dart' as http;
import 'dart:convert';

class Crud {
  getrequest(String url, Map<String, String> map) async {
    try {
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var responsebody = jsonDecode(response.body);
        return responsebody;
      } else {
        print('Error ${response.statusCode}');
      }
    } catch (e) {
      print('Catch Error $e');
    }
  }

  postrequest(String url, Map data) async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      var response = await http.post(Uri.parse(url), body: data);
      if (response.statusCode == 200) {
        var responsebody = jsonDecode(response.body);
        return responsebody;
      } else {
        print('Error ${response.statusCode}');
      }
    } catch (e) {
      print('Catch Error $e');
    }
  }
}
