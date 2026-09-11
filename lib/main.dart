import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MaterialApp(home: VastuApp()));

class VastuApp extends StatefulWidget {
  const VastuApp({super.key});
  @override
  State<VastuApp> createState() => _VastuAppState();
}

class _VastuAppState extends State<VastuApp> {
  File? _mapImage;
  List<Offset> _points = [];
  int? _draggedPointIndex;
  
  double _chakraRotationDeg = 0.0; // Gol Chakras ke liye (1,2,3,4)
  double _gridRotationDeg = 0.0;   // Square Chakras ke liye (5,6,7)
  
  double _opacity = 0.7;
  double _chakraWidth = 250.0;
  double _chakraHeight = 250.0;
  int _activeChakraIndex = 1;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _mapImage = File(picked.path);
        _points.clear();
      });
    }
  }

  void _autoFitToPlot() {
    if (_points.length < 3) return;
    double minX = _points[0].dx, maxX = _points[0].dx;
    double minY = _points[0].dy, maxY = _points[0].dy;

    for (var p in _points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    setState(() {
      _chakraWidth = (maxX - minX);
      _chakraHeight = (maxY - minY);
    });
  }

  void _onTapDown(TapDownDetails details) {
    bool tappedExisting = false;
    for (int i = 0; i < _points.length; i++) {
      if ((_points[i] - details.localPosition).distance < 30) {
        tappedExisting = true;
        break;
      }
    }
    if (!tappedExisting) setState(() => _points.add(details.localPosition));
  }

  void _onPanDown(DragDownDetails details) {
    for (int i = 0; i < _points.length; i++) {
      if ((_points[i] - details.localPosition).distance < 30) {
        _draggedPointIndex = i;
        return;
      }
    }
    _draggedPointIndex = null;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_draggedPointIndex != null) setState(() => _points[_draggedPointIndex!] += details.delta);
  }

  Offset _getPlotCenter() {
    if (_points.isEmpty) return const Offset(175, 175);
    if (_points.length < 3) {
      double sumX = 0, sumY = 0;
      for (var p in _points) { sumX += p.dx; sumY += p.dy; }
      return Offset(sumX / _points.length, sumY / _points.length);
    }
    double area = 0, cx = 0, cy = 0;
    for (int i = 0; i < _points.length; i++) {
      int j = (i + 1) % _points.length;
      double crossProduct = (_points[i].dx * _points[j].dy - _points[j].dx * _points[i].dy);
      area += crossProduct;
      cx += (_points[i].dx + _points[j].dx) * crossProduct;
      cy += (_points[i].dy + _points[j].dy) * crossProduct;
    }
    area /= 2.0;
    if (area.abs() < 0.0001) {
      double sumX = 0, sumY = 0;
      for (var p in _points) { sumX += p.dx; sumY += p.dy; }
      return Offset(sumX / _points.length, sumY / _points.length);
    }
    return Offset(cx / (6.0 * area), cy / (6.0 * area));
  }

  Future<void> _generatePdf() async {
    if (_mapImage == null) return;
    final pdf = pw.Document();
    final mapBytes = await _mapImage!.readAsBytes();
    final mapPdfImage = pw.MemoryImage(mapBytes);
    final center = _getPlotCenter();

    pdf.addPage(pw.Page(build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Header(level: 0, text: 'Vastu Analysis Report'),
      pw.SizedBox(height: 30),
      pw.Text('Client Name: ${_nameCtrl.text}', style: const pw.TextStyle(fontSize: 18)),
      pw.Text('Mobile Number: ${_phoneCtrl.text}', style: const pw.TextStyle(fontSize: 18)),
      pw.Text('Address: ${_addressCtrl.text}', style: const pw.TextStyle(fontSize: 18)),
    ])));

    for (int i = 1; i <= 7; i++) {
      try {
        final ByteData data = await rootBundle.load('assets/chakra$i.png');
        final chakraPdfImage = pw.MemoryImage(data.buffer.asUint8List());
        
        // Dynamically apply correct rotation based on Chakra type
        double applyRotation = (i >= 5) ? -(_gridRotationDeg * (math.pi / 180)) : -(_chakraRotationDeg * (math.pi / 180));

        pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (context) {
          return pw.Center(child: pw.SizedBox(width: 350, height: 350, child: pw.Stack(children: [
            pw.Positioned.fill(child: pw.Image(mapPdfImage, fit: pw.BoxFit.fill)),
            pw.Positioned.fill(child: pw.CustomPaint(painter: (canvas, size) {
              if (_points.isEmpty) return;
              canvas.moveTo(_points[0].dx, size.y - _points[0].dy);
              for (int p = 1; p < _points.length; p++) canvas.lineTo(_points[p].dx, size.y - _points[p].dy);
              if (_points.length >= 3) canvas.lineTo(_points[0].dx, size.y - _points[0].dy);
              canvas.setStrokeColor(PdfColors.red); canvas.setLineWidth(2.0); canvas.strokePath();
            }))),
            pw.Positioned(
              left: center.dx - (_chakraWidth / 2), top: center.dy - (_chakraHeight / 2),
              child: pw.SizedBox(width: _chakraWidth, height: _chakraHeight,
                child: pw.Transform.rotate(angle: applyRotation, child: pw.Opacity(opacity: _opacity, child: pw.Image(chakraPdfImage, fit: pw.BoxFit.fill)))
              )
            )
          ])));
        }));
      } catch (e) { debugPrint("Missing asset $i"); }
    }

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    Offset center = _getPlotCenter();
    double previewRotation = (_activeChakraIndex >= 5) ? (_gridRotationDeg * (math.pi / 180)) : (_chakraRotationDeg * (math.pi / 180));

    return Scaffold(
      appBar: AppBar(title: const Text('Vastu Plot Mapper')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Customer Name')),
                  TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Mobile')),
                  TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(onPressed: _pickImage, child: const Text('Upload Map')),
                      ElevatedButton(onPressed: _autoFitToPlot, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text('Auto-Fit Plot')),
                      ElevatedButton(onPressed: () => setState(() => _points.clear()), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Clear Dots')),
                    ],
                  ),
                  DropdownButton<int>(
                    value: _activeChakraIndex,
                    items: List.generate(7, (i) => DropdownMenuItem(value: i + 1, child: Text('Preview Chakra ${i + 1}'))),
                    onChanged: (val) => setState(() => _activeChakraIndex = val!),
                  )
                ],
              ),
            ),
            if (_mapImage != null)
              Container(
                width: 350, height: 350, color: Colors.grey[200],
                child: GestureDetector(
                  onTapDown: _onTapDown, onPanDown: _onPanDown, onPanUpdate: _onPanUpdate, onPanEnd: (_) => _draggedPointIndex = null,
                  child: Stack(
                    children: [
                      Positioned.fill(child: Image.file(_mapImage!, fit: BoxFit.fill)),
                      Positioned.fill(child: CustomPaint(painter: PolygonPainter(_points, center))),
                      if (_points.length >= 3)
                        Positioned(
                          left: center.dx - (_chakraWidth / 2), top: center.dy - (_chakraHeight / 2),
                          width: _chakraWidth, height: _chakraHeight,
                          child: Transform.rotate(
                            angle: previewRotation,
                            child: Opacity(opacity: _opacity, child: Image.asset('assets/chakra$_activeChakraIndex.png', fit: BoxFit.fill)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (_mapImage != null)
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    if (_activeChakraIndex < 5) ...[
                      Text('Compass Angle (Circles): ${_chakraRotationDeg.round()}°', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Slider(value: _chakraRotationDeg, min: 0.0, max: 360.0, onChanged: (v) => setState(() => _chakraRotationDeg = v)),
                    ] else ...[
                      Text('Square Grid Angle: ${_gridRotationDeg.round()}°', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      Slider(value: _gridRotationDeg, min: -45.0, max: 45.0, activeColor: Colors.deepOrange, onChanged: (v) => setState(() => _gridRotationDeg = v)),
                    ],
                    const Divider(),
                    const Text('Transparency Slider', style: TextStyle(fontWeight: FontWeight.bold)),
                    Slider(value: _opacity, min: 0.1, max: 1.0, onChanged: (v) => setState(() => _opacity = v)),
                    const Text('Grid Width (X)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Slider(value: _chakraWidth, min: 50.0, max: 600.0, onChanged: (v) => setState(() => _chakraWidth = v)),
                    const Text('Grid Height (Y)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Slider(value: _chakraHeight, min: 50.0, max: 600.0, onChanged: (v) => setState(() => _chakraHeight = v)),
                    const SizedBox(height: 20),
                    ElevatedButton(onPressed: _generatePdf, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)), child: const Text('Download PDF', style: TextStyle(color: Colors.white, fontSize: 18))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PolygonPainter extends CustomPainter {
  final List<Offset> points;
  final Offset center;
  PolygonPainter(this.points, this.center);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final pathPaint = Paint()..color = Colors.red..strokeWidth = 3..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) path.lineTo(points[i].dx, points[i].dy);
    if (points.length >= 3) path.close();
    canvas.drawPath(path, pathPaint);
    for (var p in points) canvas.drawCircle(p, 8, Paint()..color = Colors.blue);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
