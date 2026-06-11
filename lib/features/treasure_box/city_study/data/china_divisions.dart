import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/city_study.dart';

class ChinaDivisions {
  static ChinaDivisions? _instance;
  List<ProvinceInfo> _provinces = [];
  List<CountyInfo> _counties = [];
  final Map<int, ProvinceInfo> _provinceMap = {};
  final Map<int, CountyInfo> _countyMap = {};
  final Map<int, List<CountyInfo>> _provinceCounties = {};
  bool _loaded = false;

  ChinaDivisions._();

  static ChinaDivisions get instance {
    _instance ??= ChinaDivisions._();
    return _instance!;
  }

  bool get isLoaded => _loaded;

  List<ProvinceInfo> get provinces => _provinces;
  List<CountyInfo> get counties => _counties;

  ProvinceInfo? getProvince(int adcode) => _provinceMap[adcode];
  CountyInfo? getCounty(int adcode) => _countyMap[adcode];

  List<CountyInfo> getCountiesInProvince(int provinceAdcode) =>
      _provinceCounties[provinceAdcode] ?? [];

  Future<void> load() async {
    if (_loaded) return;

    final provinceJson = await rootBundle.loadString(
      'assets/data/city_study/provinces.json',
    );
    final provinceData = jsonDecode(provinceJson) as Map<String, dynamic>;
    _provinces = (provinceData['provinces'] as List)
        .map((e) => ProvinceInfo.fromJson(e as Map<String, dynamic>))
        .where((p) => p.adcode != 100000)
        .toList();

    for (final p in _provinces) {
      _provinceMap[p.adcode] = p;
    }

    final countyJson = await rootBundle.loadString(
      'assets/data/city_study/counties.json',
    );
    final countyData = jsonDecode(countyJson) as Map<String, dynamic>;
    _counties = (countyData['counties'] as List)
        .map((e) => CountyInfo.fromJson(e as Map<String, dynamic>))
        .toList();

    for (final c in _counties) {
      _countyMap[c.adcode] = c;
      _provinceCounties
          .putIfAbsent(c.provinceAdcode, () => [])
          .add(c);
    }

    _loaded = true;
  }

  List<CountyInfo> searchCounties(String query) {
    if (query.isEmpty) return [];
    final lower = query.toLowerCase();
    return _counties.where((c) {
      return c.name.toLowerCase().contains(lower);
    }).toList();
  }

  CountyInfo? getRandomCounty() {
    if (_counties.isEmpty) return null;
    final random = DateTime.now().microsecondsSinceEpoch;
    return _counties[random % _counties.length];
  }
}
