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
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaletteCacheService {
  static const String _keyPrefix = 'palette_cache_';

  static Future<Map<String, Color?>?> getPalette(String songPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hash = songPath.hashCode.abs().toString();
      final key = '$_keyPrefix$hash';
      final jsonStr = prefs.getString(key);
      if (jsonStr == null) return null;

      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return {
        'dominant': _colorFromHex(map['dominant']),
        'muted': _colorFromHex(map['muted']),
        'seed': _colorFromHex(map['seed']),
      };
    } catch (e) {
      return null;
    }
  }

  static Future<void> savePalette(String songPath, Color? dominant, Color? muted, Color? seed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hash = songPath.hashCode.abs().toString();
      final key = '$_keyPrefix$hash';
      
      final map = {
        'dominant': _colorToHex(dominant),
        'muted': _colorToHex(muted),
        'seed': _colorToHex(seed),
      };
      await prefs.setString(key, jsonEncode(map));
    } catch (e) {
      // Ignore
    }
  }

  static String? _colorToHex(Color? color) {
    if (color == null) return null;
    return color.value.toRadixString(16).padLeft(8, '0');
  }

  static Color? _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return null;
    }
  }
}