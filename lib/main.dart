import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
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
  final List<Offset> _points = [];
  double _manualAngle = 0.0;
  double _calculatedRotation = 0.0;
  double _opacity = 0.5;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _mapImage = File(picked.path));
  }

  void _calculateOrientation(double inputDeg) {
    if (_points.length >= 2) {
      double dx = _points[1].dx - _points[0].dx;
      double dy = _points[1].dy - _points[0].dy;
      double baselineAngle = math.atan2(dy, dx) * (180 / math.pi);
      setState(() {
        _manualAngle = inputDeg;
        _calculatedRotation = (inputDeg - baselineAngle) * (math.pi / 180);
      });
    }
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();

    // Page 1: Customer Details
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(level: 0, text: 'Vastu Analysis Report'),
            pw.SizedBox(height: 20),
            pw.Text('Client Name: ${_nameCtrl.text}', style: const pw.TextStyle(fontSize: 18)),
            pw.Text('Mobile Number: ${_phoneCtrl.text}', style: const pw.TextStyle(fontSize: 18)),
            pw.Text('Address: ${_addressCtrl.text}', style: const pw.TextStyle(fontSize: 18)),
            pw.Text('Plot Orientation: $_manualAngle°', style: const pw.TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );

    // Inner Pages: Chakra overlays can be added here as dynamic image pages

    // Last Page: Consultant Contact Details
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('Consultant Details', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Text('Gulab Lohani', style: const pw.TextStyle(fontSize: 18)),
              pw.Text('Mobile: 9660511419', style: const pw.TextStyle(fontSize: 18)),
              pw.Text('Sardarpura, Jodhpur', style: const pw.TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );

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
                  ElevatedButton(onPressed: _pickImage, child: const Text('Upload Map Image')),
                ],
              ),
            ),
            if (_mapImage != null)
              GestureDetector(
                onTapDown: (details) => setState(() => _points.add(details.localPosition)),
                child: Stack(
                  children: [
                    Image.file(_mapImage!),
                    CustomPaint(
                      painter: PolygonPainter(_points),
                      size: const Size(double.infinity, 350),
                    ),
                    Positioned.fill(
                      child: Transform.rotate(
                        angle: _calculatedRotation,
                        child: Opacity(
                          opacity: _opacity,
                          child: Image.asset('assets/chakra1.png'), // Corrected aligned chakra
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Slider(
              value: _opacity,
              min: 0.1,
              max: 1.0,
              onChanged: (v) => setState(() => _opacity = v),
            ),
            ElevatedButton(
              onPressed: () => _calculateOrientation(45.0), // Example: input degree dialog se aayega
              child: const Text('Set Plot Degree (First 2 Dots)'),
            ),
            ElevatedButton(
              onPressed: _generatePdf,
              child: const Text('Download Multi-Page PDF'),
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
    final paint = Paint()..color = Colors.red..strokeWidth = 3..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = Colors.blue..style = PaintingStyle.fill;

    for (var p in points) {
      canvas.drawCircle(p, 6, dotPaint);
    }
    if (points.length > 1) {
      final path = Path()..moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
