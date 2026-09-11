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
  double _opacity = 0.6;
  int _activeChakraIndex = 1; // Screen par preview ke liye

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController();

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() {
      _mapImage = File(picked.path);
      _points.clear();
    });
  }

  void _calculateOrientation() {
    if (_points.length >= 2 && _degreeCtrl.text.isNotEmpty) {
      double inputDeg = double.tryParse(_degreeCtrl.text) ?? 0.0;
      double dx = _points[1].dx - _points[0].dx;
      double dy = _points[1].dy - _points[0].dy;
      double baselineAngle = math.atan2(dy, dx) * (180 / math.pi);
      
      setState(() {
        _manualAngle = inputDeg;
        _calculatedRotation = (inputDeg - baselineAngle) * (math.pi / 180);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plot Angle & Rotation Locked!'))
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kam se kam 2 dots lagayein aur degree likhein!'))
      );
    }
  }

  // Dots ko drag (move) karne ka logic
  void _onPanStart(DragStartDetails details) {
    RenderBox box = context.findRenderObject() as RenderBox;
    Offset localPosition = details.localPosition;
    
    // Check if touch is near an existing point (within 30 pixels)
    for (int i = 0; i < _points.length; i++) {
      if ((_points[i] - localPosition).distance < 30) {
        _draggedPointIndex = i;
        return;
      }
    }
    // If not near, add new point
    setState(() {
      _points.add(localPosition);
      _draggedPointIndex = _points.length - 1;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_draggedPointIndex != null) {
      setState(() {
        _points[_draggedPointIndex!] += details.delta;
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _draggedPointIndex = null;
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

    // Page 1: Customer Details
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

    // Dynamic Pages for 7 Chakras
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
                    alignment: pw.Alignment.center,
                    children: [
                      // Base Map
                      pw.Positioned.fill(
                        child: pw.Image(mapPdfImage, fit: pw.BoxFit.fill),
                      ),
                      // Polygon Lines & Dots drawn manually for PDF
                      pw.Positioned.fill(
                        child: pw.CustomPaint(
                          painter: (canvas, size) {
                            if (_points.isEmpty) return;
                            
                            // Draw path
                            canvas.moveTo(_points[0].dx, size.y - _points[0].dy);
                            for (int p = 1; p < _points.length; p++) {
                              canvas.lineTo(_points[p].dx, size.y - _points[p].dy);
                            }
                            canvas.setStrokeColor(PdfColors.red);
                            canvas.setLineWidth(2.0);
                            canvas.strokePath();
                            
                            // Draw dots
                            for (var pt in _points) {
                              canvas.drawEllipse(pt.dx, size.y - pt.dy, 4, 4);
                              canvas.setFillColor(PdfColors.blue);
                              canvas.fillPath();
                            }
                          }
                        )
                      ),
                      // Overlay Chakra Rotated
                      pw.Positioned.fill(
                        child: pw.Transform.rotate(
                          angle: -_calculatedRotation, // Match PDF rotation
                          child: pw.Opacity(
                            opacity: _opacity,
                            child: pw.Image(chakraPdfImage),
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
        debugPrint("Image assets/chakra$i.png not found. Skipping.");
      }
    }

    // Last Page: Consultant Contact Details
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

    Navigator.pop(context); // Close loading dialog
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
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
                          decoration: const InputDecoration(labelText: 'Plot Degree (Front facing)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _calculateOrientation,
                        child: const Text('Lock Angle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(onPressed: _pickImage, child: const Text('Upload Map')),
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
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.file(_mapImage!, fit: BoxFit.fill),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: PolygonPainter(_points),
                        ),
                      ),
                      Positioned.fill(
                        child: Transform.rotate(
                          angle: _calculatedRotation,
                          child: Opacity(
                            opacity: _opacity,
                            child: Image.asset('assets/chakra$_activeChakraIndex.png', fit: BoxFit.contain),
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
                    const Text('Transparency Slider'),
                    Slider(
                      value: _opacity,
                      min: 0.1,
                      max: 1.0,
                      onChanged: (v) => setState(() => _opacity = v),
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
  PolygonPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    
    final pathPaint = Paint()..color = Colors.red..strokeWidth = 3..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = Colors.blue..style = PaintingStyle.fill;

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    
    // Line close karna hai ya nahi, ye aapse decide hoga (path.close())
    canvas.drawPath(path, pathPaint);

    for (var p in points) {
      canvas.drawCircle(p, 8, dotPaint); // Dot size thoda bada kiya hai pakadne me aasan ho
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
