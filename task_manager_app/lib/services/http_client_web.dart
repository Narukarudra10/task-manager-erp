import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';

http.Client createClient() {
  return BrowserClient()..withCredentials = true;
}
