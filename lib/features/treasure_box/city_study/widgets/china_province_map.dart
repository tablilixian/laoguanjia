import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/city_study.dart';
import '../data/china_divisions.dart';

class ChinaProvinceMap extends StatefulWidget {
  final CityStudyStore store;
  final void Function(int provinceAdcode)? onProvinceTap;
  final void Function(CountyInfo county)? onCountyTap;

  const ChinaProvinceMap({
    super.key,
    required this.store,
    this.onProvinceTap,
    this.onCountyTap,
  });

  @override
  State<ChinaProvinceMap> createState() => _ChinaProvinceMapState();
}

class _ChinaProvinceMapState extends State<ChinaProvinceMap> {
  List<Map<String, dynamic>>? _features;
  bool _loaded = false;
  int? _selectedProvince;
  CountyInfo? _selectedCounty;
  final _transformController = TransformationController();
  bool _showReset = false;

  static const double _minLng = 73.66;
  static const double _maxLng = 135.05;
  static const double _minLat = 3.86;
  static const double _maxLat = 53.55;

  @override
  void initState() {
    super.initState();
    _loadGeoJSON();
    _transformController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    final show = scale > 1.05;
    if (show != _showReset) {
      setState(() => _showReset = show);
    }
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  Future<void> _loadGeoJSON() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/data/city_study/province_boundary.json',
      );
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      setState(() {
        _features = (data['features'] as List)
            .cast<Map<String, dynamic>>()
            .toList();
        _loaded = true;
      });
    } catch (e) {
      debugPrint('Failed to load GeoJSON: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final mapW = width - 32;
        final mapH = mapW / 1.27;

        return Column(
          children: [
            SizedBox(
              width: width,
              height: mapH + 40,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 1.0,
                    maxScale: 3.0,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    child: GestureDetector(
                      onTapDown: (details) =>
                          _handleTap(details.localPosition, mapW, mapH),
                      child: CustomPaint(
                        size: Size(width, mapH + 40),
                        painter: _ChinaMapPainter(
                          features: _features!,
                          store: widget.store,
                          selectedProvince: _selectedProvince,
                          selectedCounty: _selectedCounty,
                          minLng: _minLng,
                          maxLng: _maxLng,
                          minLat: _minLat,
                          maxLat: _maxLat,
                        ),
                      ),
                    ),
                  ),
                  if (_showReset)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _resetZoom,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_out_map,
                                    size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  '重置',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildLegend(),
          ],
        );
      },
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendDot(Colors.grey.shade300, '未开始'),
          const SizedBox(width: 16),
          _legendDot(const Color(0xFFFFD54F), '进行中'),
          const SizedBox(width: 16),
          _legendDot(const Color(0xFF81C784), '已完成'),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade400, width: 0.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  void _handleTap(Offset position, double mapW, double mapH) {
    final padding = 16.0;
    final tx = (position.dx - padding) / (mapW - 2 * padding);
    final ty = (position.dy - padding) / (mapH - 2 * padding);
    final lng = _minLng + tx * (_maxLng - _minLng);
    final lat = _maxLat - ty * (_maxLat - _minLat);

    // Check county dots first
    final divisions = ChinaDivisions.instance;
    final counties = divisions.counties;
    CountyInfo? closestCounty;
    double minDist = double.infinity;

    for (final c in counties) {
      final cx = padding + (c.lng - _minLng) / (_maxLng - _minLng) * (mapW - 2 * padding);
      final cy = padding + (_maxLat - c.lat) / (_maxLat - _minLat) * (mapH - 2 * padding);
      final dist = sqrt(pow(position.dx - cx, 2) + pow(position.dy - cy, 2));
      if (dist < 12 && dist < minDist) {
        minDist = dist;
        closestCounty = c;
      }
    }

    if (closestCounty != null) {
      setState(() => _selectedCounty = closestCounty);
      widget.onCountyTap?.call(closestCounty);
      return;
    }

    // Check province hit test
    for (final feature in _features!) {
      final props = feature['properties'] as Map<String, dynamic>;
      final adcode = _adcodeToInt(props['adcode']);
      if (adcode == null || adcode == 100000) continue;

      final geometry = feature['geometry'] as Map<String, dynamic>;
      final type = geometry['type'] as String;
      final coords = geometry['coordinates'] as List;

      if (_pointInProvince(lng, lat, type, coords)) {
        setState(() => _selectedProvince = adcode);
        widget.onProvinceTap?.call(adcode);
        return;
      }
    }
  }

  bool _pointInProvince(
      double lng, double lat, String type, List coords) {
    if (type == 'Polygon') {
      return _pointInPolygon(lng, lat, coords[0] as List);
    } else if (type == 'MultiPolygon') {
      for (final polygon in coords) {
        if (_pointInPolygon(lng, lat, (polygon as List)[0] as List)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _pointInPolygon(double lng, double lat, List exterior) {
    int i, j = exterior.length - 1;
    bool inside = false;
    for (i = 0; i < exterior.length; i++) {
      final pi = exterior[i] as List;
      final pj = exterior[j] as List;
      final xi = pi[0] as num;
      final yi = pi[1] as num;
      final xj = pj[0] as num;
      final yj = pj[1] as num;
      if ((yi > lat) != (yj > lat) &&
          lng < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }
}

class _ChinaMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> features;
  final CityStudyStore store;
  final int? selectedProvince;
  final CountyInfo? selectedCounty;
  final double minLng, maxLng, minLat, maxLat;

  _ChinaMapPainter({
    required this.features,
    required this.store,
    this.selectedProvince,
    this.selectedCounty,
    required this.minLng,
    required this.maxLng,
    required this.minLat,
    required this.maxLat,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 16.0;
    final mapW = size.width - 2 * padding;
    final mapH = mapW / 1.27;

    final bgPaint = Paint()..color = const Color(0xFFF5F0EB);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, mapH + 40), bgPaint);

    final strokePaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final selectedStroke = Paint()
      ..color = const Color(0xFFD4A574)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final feature in features) {
      final props = feature['properties'] as Map<String, dynamic>;
      final adcode = _adcodeToInt(props['adcode']);
      if (adcode == null || adcode == 100000) continue;

      final geometry = feature['geometry'] as Map<String, dynamic>;
      final type = geometry['type'] as String;
      final coords = geometry['coordinates'] as List;

      final completion = _getCompletion(adcode);
      final isSelected = selectedProvince == adcode;
      final hasData = store.studies.values.any(
        (s) => _isInProvince(s.adcode, adcode),
      );

      Color fillColor;
      if (hasData && completion > 0) {
        final alpha = (completion * 200 + 55).round().clamp(30, 180);
        fillColor = const Color(0xFFD4A574).withAlpha(alpha);
      } else {
        fillColor = Colors.transparent;
      }

      if (type == 'Polygon') {
        _drawPolygon(canvas, coords[0] as List, padding, mapW, mapH,
            fillColor, isSelected ? selectedStroke : strokePaint);
      } else if (type == 'MultiPolygon') {
        for (final polygon in coords) {
          _drawPolygon(canvas, (polygon as List)[0] as List, padding, mapW,
              mapH, fillColor, isSelected ? selectedStroke : strokePaint);
        }
      }
    }

    _drawCountyDots(canvas, padding, mapW, mapH);

    _drawLabels(canvas, padding, mapW, mapH);

    // Stats text
    final textPainter = TextPainter(
      text: TextSpan(
        text:
            '已完成 ${store.completedCount} / ${store.totalCount} 个县',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(padding, mapH + 16));
  }

  double _getCompletion(int provinceAdcode) {
    final provinceCounties =
        divisions.getCountiesInProvince(provinceAdcode);
    if (provinceCounties.isEmpty) return 0;
    int completed = 0;
    for (final c in provinceCounties) {
      final study = store.studies[c.adcode];
      if (study != null && study.status == CityStudyStatus.completed) {
        completed++;
      }
    }
    return completed / provinceCounties.length;
  }

  bool _isInProvince(int countyAdcode, int provinceAdcode) {
    final county = divisions.getCounty(countyAdcode);
    return county?.provinceAdcode == provinceAdcode;
  }

  void _drawPolygon(Canvas canvas, List coords, double padding, double mapW,
      double mapH, Color fillColor, Paint strokePaint) {
    final path = Path();
    bool first = true;

    for (final pt in coords) {
      final x = padding +
          ((pt[0] as num).toDouble() - minLng) /
              (maxLng - minLng) *
              (mapW - 2 * padding);
      final y = padding +
          (maxLat - (pt[1] as num).toDouble()) /
              (maxLat - minLat) *
              (mapH - 2 * padding);

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    if (fillColor.a > 0) {
      canvas.drawPath(path, Paint()..color = fillColor);
    }
    canvas.drawPath(path, strokePaint);
  }

  void _drawCountyDots(
      Canvas canvas, double padding, double mapW, double mapH) {
    final divisions = ChinaDivisions.instance;
    final radius = 2.0;
    final hitRadius = 4.0;

    for (final county in divisions.counties) {
      final x = padding +
          (county.lng - minLng) / (maxLng - minLng) * (mapW - 2 * padding);
      final y = padding +
          (maxLat - county.lat) / (maxLat - minLat) * (mapH - 2 * padding);

      final study = store.studies[county.adcode];
      final isSelected = selectedCounty?.adcode == county.adcode;

      Color dotColor;
      double dotRadius;

      if (study == null || study.status == CityStudyStatus.notStarted) {
        dotColor = Colors.grey.shade300;
        dotRadius = radius;
      } else if (study.status == CityStudyStatus.inProgress) {
        dotColor = const Color(0xFFFFD54F);
        dotRadius = hitRadius;
      } else {
        dotColor = const Color(0xFF81C784);
        dotRadius = hitRadius;
      }

      if (isSelected) {
        dotRadius += 2;
        canvas.drawCircle(
          Offset(x, y),
          dotRadius + 2,
          Paint()..color = const Color(0xFFD4A574).withAlpha(100),
        );
      }

      canvas.drawCircle(
        Offset(x, y),
        dotRadius,
        Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill,
      );

      if (isSelected) {
        canvas.drawCircle(
          Offset(x, y),
          dotRadius,
          Paint()
            ..color = const Color(0xFFD4A574)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  void _drawLabels(
      Canvas canvas, double padding, double mapW, double mapH) {
    final textStyle = TextStyle(
      color: Colors.grey.shade500,
      fontSize: 9,
      fontWeight: FontWeight.w400,
    );

    for (final feature in features) {
      final props = feature['properties'] as Map<String, dynamic>;
      final adcode = _adcodeToInt(props['adcode']);
      if (adcode == null || adcode == 100000) continue;
      final centroid = props['centroid'] as List?;
      if (centroid == null) continue;

      final x = padding +
          ((centroid[0] as num).toDouble() - minLng) /
              (maxLng - minLng) *
              (mapW - 2 * padding);
      final y = padding +
          (maxLat - (centroid[1] as num).toDouble()) /
              (maxLat - minLat) *
              (mapH - 2 * padding);

      final name = props['name'] as String;
      final tp = TextPainter(
        text: TextSpan(
          text: name.length > 3 ? '${name.substring(0, 2)}…' : name,
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: 50);
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _ChinaMapPainter oldDelegate) {
    return oldDelegate.store != store ||
        oldDelegate.selectedProvince != selectedProvince ||
        oldDelegate.selectedCounty != selectedCounty;
  }
}

ChinaDivisions get divisions => ChinaDivisions.instance;

int? _adcodeToInt(dynamic value) {
  if (value is int) return value;
  if (value is String) {
    final match = RegExp(r'^(\d+)').firstMatch(value);
    if (match != null) return int.tryParse(match.group(1)!);
  }
  return null;
}
