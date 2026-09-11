import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  
  double _manualAngle = 0.0;
  double _calculatedRotation = 0.0;
  double _opacity = 0.7;
  
  // Width aur Height alag kar diye gaye hain
  double _chakraWidth = 250.0;
  double _chakraHeight = 250.0;
  
  int _activeChakraIndex = 1;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController();

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _mapImage = File(picked.path);
        _points.clear();
      });
    }
  }

  void _calculateOrientation() {
    if (_points.length >= 2 && _degreeCtrl.text.isNotEmpty) {
      double inputDeg = double.tryParse(_degreeCtrl.text) ?? 0.0;
      double dx = _points[1].dx - _points[0].dx;
      double dy = _points[1].dy - _points[0].dy;
      double baselineAngle = math.atan2(dy, dx) * (180 / math.pi);
      
      double facingAngle = baselineAngle + 90.0; 
      double finalRotationDeg = inputDeg - facingAngle + 180.0;
      
      setState(() {
        _manualAngle = inputDeg;
        _calculatedRotation = finalRotationDeg * (math.pi / 180);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Degree $inputDeg Locked! Chakra Aligned.'))
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pehle Front Line ke 2 dots lagayein!'))
      );
    }
  }

  // Chakra ko plot ke andar automatically fit karne ka logic
  void _autoFitToPlot() {
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pehle poore plot ke dots lagayein!'))
      );
      return;
    }
    
    double minX = _points[0].dx;
    double maxX = _points[0].dx;
    double minY = _points[0].dy;
    double maxY = _points[0].dy;

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
    
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grid plot ke size mein fit ho gaya!'))
    );
  }

  void _onTapDown(TapDownDetails details) {
    bool tappedExisting = false;
    for (int i = 0; i < _points.length; i++) {
      if ((_points[i] - details.localPosition).distance < 30) {
        tappedExisting = true;
        break;
      }
    }
    if (!tappedExisting) {
      setState(() => _points.add(details.localPosition));
    }
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
    if (_draggedPointIndex != null) {
      setState(() => _points[_draggedPointIndex!] += details.delta);
    }
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
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator())
    );

    final pdf = pw.Document();
    final mapBytes = await _mapImage!.readAsBytes();
    final mapPdfImage = pw.MemoryImage(mapBytes);
    final center = _getPlotCenter();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(level: 0, text: 'Vastu Analysis Report'),
            pw.SizedBox(height: 30),
            pw.Text('Client Name: ${_nameCtrl.text}', style: const pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 10),
            pw.Text('Mobile Number: ${_phoneCtrl.text}', style: const pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 10),
            pw.Text('Address: ${_addressCtrl.text}', style: const pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 10),
            pw.Text('Plot Orientation: $_manualAngle Degree', style: const pw.TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );

    for (int i = 1; i <= 7; i++) {
      try {
        final ByteData data = await rootBundle.load('assets/chakra$i.png');
        final chakraPdfImage = pw.MemoryImage(data.buffer.asUint8List());

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (context) {
              return pw.Center(
                child: pw.SizedBox(
                  width: 350, 
                  height: 350,
                  child: pw.Stack(
                    children: [
                      pw.Positioned.fill(child: pw.Image(mapPdfImage, fit: pw.BoxFit.fill)),
                      pw.Positioned.fill(
                        child: pw.CustomPaint(
                          painter: (canvas, size) {
                            if (_points.isEmpty) return;
                            canvas.moveTo(_points[0].dx, size.y - _points[0].dy);
                            for (int p = 1; p < _points.length; p++) {
                              canvas.lineTo(_points[p].dx, size.y - _points[p].dy);
                            }
                            if (_points.length >= 3) canvas.lineTo(_points[0].dx, size.y - _points[0].dy);
                            canvas.setStrokeColor(PdfColors.red);
                            canvas.setLineWidth(2.0);
                            canvas.strokePath();
                            canvas.drawEllipse(center.dx, size.y - center.dy, 4, 4);
                            canvas.setFillColor(PdfColors.black);
                            canvas.fillPath();
                          }
                        )
                      ),
                      pw.Positioned(
                        left: center.dx - (_chakraWidth / 2),
                        top: center.dy - (_chakraHeight / 2),
                        child: pw.SizedBox(
                          width: _chakraWidth,
                          height: _chakraHeight,
                          child: pw.Transform.rotate(
                            angle: -_calculatedRotation,
                            child: pw.Opacity(
                              opacity: _opacity,
                              child: pw.Image(chakraPdfImage, fit: pw.BoxFit.fill), // Stretch enable
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                )
              );
            }
          )
        );
      } catch (e) {
        debugPrint("Chakra $i not found");
      }
    }

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('Consultant Details', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Gulab Lohani', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Mobile: 9660511419', style: const pw.TextStyle(fontSize: 18)),
              pw.SizedBox(height: 10),
              pw.Text('Address: Sardarpura, Jodhpur', style: const pw.TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );

    Navigator.pop(context);
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    Offset center = _getPlotCenter();

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
                  TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Mobile Number')),
                  TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _degreeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Front Line Degree', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _calculateOrientation,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                        child: const Text('Lock Angle', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(onPressed: _pickImage, child: const Text('Upload Map')),
                      ElevatedButton(
                        onPressed: _autoFitToPlot, 
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        child: const Text('Auto-Fit Plot', style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() => _points.clear()), 
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        child: const Text('Clear Dots', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<int>(
                    value: _activeChakraIndex,
                    items: List.generate(7, (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('Preview Chakra ${i + 1}'),
                    )),
                    onChanged: (val) => setState(() => _activeChakraIndex = val!),
                  )
                ],
              ),
            ),
            if (_mapImage != null)
              Container(
                width: 350,
                height: 350,
                color: Colors.grey[200],
                child: GestureDetector(
                  onTapDown: _onTapDown,
                  onPanDown: _onPanDown,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: (_) => _draggedPointIndex = null,
                  child: Stack(
                    children: [
                      Positioned.fill(child: Image.file(_mapImage!, fit: BoxFit.fill)),
                      Positioned.fill(child: CustomPaint(painter: PolygonPainter(_points, center))),
                      if (_points.length >= 3)
                        Positioned(
                          left: center.dx - (_chakraWidth / 2),
                          top: center.dy - (_chakraHeight / 2),
                          width: _chakraWidth,
                          height: _chakraHeight,
                          child: Transform.rotate(
                            angle: _calculatedRotation,
                            child: Opacity(
                              opacity: _opacity,
                              child: Image.asset('assets/chakra$_activeChakraIndex.png', fit: BoxFit.fill), // Stretch enable
                            ),
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
                    const Text('Transparency Slider', style: TextStyle(fontWeight: FontWeight.bold)),
                    Slider(
                      value: _opacity, min: 0.1, max: 1.0,
                      onChanged: (v) => setState(() => _opacity = v),
                    ),
                    const Text('Chakra Width (X)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Slider(
                      value: _chakraWidth, min: 50.0, max: 600.0,
                      onChanged: (v) => setState(() => _chakraWidth = v),
                    ),
                    const Text('Chakra Height (Y)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Slider(
                      value: _chakraHeight, min: 50.0, max: 600.0,
                      onChanged: (v) => setState(() => _chakraHeight = v),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _generatePdf,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('Download Multi-Page PDF', style: TextStyle(color: Colors.white, fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 40),
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
    final dotPaint = Paint()..color = Colors.blue..style = PaintingStyle.fill;
    final centerPaint = Paint()..color = Colors.black..style = PaintingStyle.fill;

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    if (points.length >= 3) path.close();
    canvas.drawPath(path, pathPaint);

    for (var p in points) canvas.drawCircle(p, 8, dotPaint);
    if (points.length >= 3) canvas.drawCircle(center, 6, centerPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
