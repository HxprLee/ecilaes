// Ecilaes - Cross-platform music player
// Copyright (C) 2024  hxprlee
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_curl/flutter_curl.dart' as fc;

class CurlResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  CurlResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
  });

  @override
  String toString() => 'CurlResponse(status: $statusCode, bodyLength: ${body.length})';
}

class CurlService {
  static fc.Client? _mobileClient;

  static Future<void> init() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _mobileClient ??= fc.Client();
    }
  }

  static Future<CurlResponse> get(
    String url, {
    Map<String, String>? headers,
    bool followRedirects = true,
    String? userAgent,
  }) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return _getMobile(
        url,
        headers: headers,
        followRedirects: followRedirects,
        userAgent: userAgent,
      );
    } else {
      return _getDesktop(
        url,
        headers: headers,
        followRedirects: followRedirects,
        userAgent: userAgent,
      );
    }
  }

  static Future<CurlResponse> _getMobile(
    String url, {
    Map<String, String>? headers,
    bool followRedirects = true,
    String? userAgent,
  }) async {
    await init();
    final requestHeaders = Map<String, String>.from(headers ?? {});
    if (userAgent != null) {
      requestHeaders['User-Agent'] = userAgent;
    }

    final request = fc.Request(
      url: url,
      method: 'GET',
      headers: requestHeaders,
    );

    final response = await _mobileClient!.send(request);
    final body = utf8.decode(response.body);

    return CurlResponse(
      statusCode: response.statusCode,
      body: body,
      headers: response.headers.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  static Future<CurlResponse> _getDesktop(
    String url, {
    Map<String, String>? headers,
    bool followRedirects = true,
    String? userAgent,
  }) async {
    final args = <String>['-s', '-i'];
    if (followRedirects) {
      args.add('-L');
    }
    if (userAgent != null) {
      args.addAll(['-A', userAgent]);
    }
    if (headers != null) {
      headers.forEach((k, v) {
        args.addAll(['-H', '$k: $v']);
      });
    }
    args.add(url);

    final result = await Process.run('curl', args);
    if (result.exitCode != 0) {
      throw Exception('curl failed with exit code ${result.exitCode}: ${result.stderr}');
    }

    final String output = result.stdout as String;
    // Standard curl -i uses CRLF, but handle LF as fallback
    int separatorIndex = output.indexOf('\r\n\r\n');
    int separatorLength = 4;
    if (separatorIndex == -1) {
      separatorIndex = output.indexOf('\n\n');
      separatorLength = 2;
    }

    if (separatorIndex == -1) {
      // Return everything as body if no separator found (unlikely with -i)
      return CurlResponse(
        statusCode: 200,
        body: output,
        headers: {},
      );
    }

    final headerPart = output.substring(0, separatorIndex);
    final bodyPart = output.substring(separatorIndex + separatorLength);

    final headerLines = headerPart.split(separatorLength == 4 ? '\r\n' : '\n');
    final statusLine = headerLines.first;
    int statusCode = 0;
    try {
      final parts = statusLine.split(' ');
      if (parts.length > 1) {
        statusCode = int.parse(parts[1]);
      }
    } catch (e) {
      debugPrint('CurlService: Status code parse error: $e');
    }

    final responseHeaders = <String, String>{};
    for (var i = 1; i < headerLines.length; i++) {
        final line = headerLines[i];
        final colonIndex = line.indexOf(':');
        if (colonIndex != -1) {
            final key = line.substring(0, colonIndex).trim().toLowerCase();
            final value = line.substring(colonIndex + 1).trim();
            // Append multiple values (like set-cookie) if needed, but for now just store
            if (responseHeaders.containsKey(key)) {
                responseHeaders[key] = '${responseHeaders[key]}; $value';
            } else {
                responseHeaders[key] = value;
            }
        }
    }

    return CurlResponse(
      statusCode: statusCode,
      body: bodyPart,
      headers: responseHeaders,
    );
  }
}
