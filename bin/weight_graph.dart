import 'dart:io';
import 'dart:math' as math;

import 'package:args/args.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:vector_math/vector_math_64.dart';

const String version = '0.0.1';

ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag('version', negatable: false, help: 'Print the tool version.')
    ..addOption(
      'lines',
      abbr: 'l',
      defaultsTo: '10',
      help: 'Number of lines per inch.',
    )
    ..addOption(
      'margin',
      abbr: 'm',
      defaultsTo: '0.25',
      help: 'Margin size in inches.',
    )
    ..addOption(
      'output',
      abbr: 'o',
      defaultsTo: 'graph_paper.pdf',
      help: 'Output file path.',
    )
    ..addOption(
      'top-weight',
      abbr: 'w',
      defaultsTo: '180',
      help: 'Top weight value on Y-axis.',
    )
    ..addOption(
      'weight-range',
      abbr: 'r',
      defaultsTo: '32',
      help: 'Total pounds to display (down from top weight).',
    );
}

void printUsage(ArgParser argParser) {
  print('Usage: dart weight_graph.dart [options]');
  print('');
  print('Generates a PDF weight tracking graph.');
  print('');
  print(argParser.usage);
}

void main(List<String> arguments) async {
  final ArgParser argParser = buildParser();
  try {
    final ArgResults results = argParser.parse(arguments);

    if (results.flag('help')) {
      printUsage(argParser);
      return;
    }
    if (results.flag('version')) {
      print('weight_graph version: $version');
      return;
    }

    final int linesPerInch = int.parse(results.option('lines')!);
    final double marginInches = double.parse(results.option('margin')!);
    final String outputPath = results.option('output')!;
    final double topWeight = double.parse(results.option('top-weight')!);
    final double weightRange = double.parse(results.option('weight-range')!);

    final pdf = generateWeightGraph(
      linesPerInch: linesPerInch,
      marginInches: marginInches,
      topWeight: topWeight,
      weightRange: weightRange,
    );

    final file = File(outputPath);
    await file.writeAsBytes(await pdf.save());
    print('Weight graph saved to: $outputPath');
    print('  Lines per inch: $linesPerInch');
    print('  Margin: $marginInches inches');
    print(
      '  Weight range: ${topWeight - weightRange} - $topWeight lbs',
    );
  } on FormatException catch (e) {
    print(e.message);
    print('');
    printUsage(argParser);
  }
}

pw.Document generateWeightGraph({
  required int linesPerInch,
  required double marginInches,
  required double topWeight,
  required double weightRange,
}) {
  final pdf = pw.Document();

  // US Letter landscape size in points (72 points per inch)
  const double pageWidthInches = 11.0;
  const double pageHeightInches = 8.5;
  const double pointsPerInch = 72.0;

  final double marginPoints = marginInches * pointsPerInch;
  final double lineSpacingPoints = pointsPerInch / linesPerInch;

  // Reserve space for labels
  const double leftLabelMargin = 36.0; // Space for weight labels
  const double topLabelMargin = 36.0; // Space for date labels

  final today = DateTime.now();
  final font = pw.Font.helvetica();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.letter.landscape,
      margin: pw.EdgeInsets.all(marginPoints),
      build: (pw.Context context) {
        final availableWidth =
            (pageWidthInches - 2 * marginInches) * pointsPerInch;
        final availableHeight =
            (pageHeightInches - 2 * marginInches) * pointsPerInch;

        final graphWidth = availableWidth - leftLabelMargin;
        final graphHeight = availableHeight - topLabelMargin;

        return pw.CustomPaint(
          size: PdfPoint(availableWidth, availableHeight),
          painter: (canvas, size) {
            final gridColor = PdfColor.fromInt(0xFFCCCCCC);
            const lineWidth = 0.5;

            // Calculate grid dimensions
            final numVerticalLines = (graphWidth / lineSpacingPoints).floor();
            final numHorizontalLines = (graphHeight / lineSpacingPoints)
                .floor();

            // Adjust to fit evenly
            final actualGridWidth = numVerticalLines * lineSpacingPoints;
            final actualGridHeight = numHorizontalLines * lineSpacingPoints;

            final gridLeft = leftLabelMargin;
            final gridBottom = 0.0;
            final gridTop = gridBottom + actualGridHeight;

            // Draw vertical lines (dates)
            for (int i = 0; i <= numVerticalLines; i++) {
              final x = gridLeft + i * lineSpacingPoints;
              canvas.drawLine(x, gridBottom, x, gridBottom + actualGridHeight);
              canvas.setStrokeColor(gridColor);
              canvas.setLineWidth(lineWidth);
              canvas.strokePath();
            }

            // Draw horizontal lines (weight)
            for (int i = 0; i <= numHorizontalLines; i++) {
              final y = gridBottom + i * lineSpacingPoints;
              canvas.drawLine(gridLeft, y, gridLeft + actualGridWidth, y);
              canvas.setStrokeColor(gridColor);
              canvas.setLineWidth(lineWidth);
              canvas.strokePath();
            }

            // Calculate weight per line
            final poundsPerLine = weightRange / numHorizontalLines;
            final minWeight = topWeight - weightRange;
            final maxWeight = topWeight;

            // Points per pound
            final pointsPerPound = actualGridHeight / weightRange;

            final pdfFont = font.getFont(context);
            canvas.setFillColor(PdfColors.black);

            // Draw weight labels for every pound, centered on middle weight
            const tickLength = 4.0;
            for (int pound = minWeight.ceil(); pound <= maxWeight.floor(); pound++) {
              final y = gridBottom + (pound - minWeight) * pointsPerPound;

              // Check if this pound aligns with a grid line
              final lineIndex = (pound - minWeight) / poundsPerLine;
              final isOnGridLine = (lineIndex - lineIndex.round()).abs() < 0.001;

              // Draw tick mark if not on a grid line
              if (!isOnGridLine) {
                canvas.drawLine(gridLeft - tickLength, y, gridLeft, y);
                canvas.setStrokeColor(PdfColors.black);
                canvas.setLineWidth(0.5);
                canvas.strokePath();
              }

              // Draw label
              final weightText = pound.toString();
              canvas.drawString(
                pdfFont,
                8,
                weightText,
                gridLeft - tickLength - 4 - weightText.length * 4.5,
                y - 3,
              );
            }

            // Draw date labels on top (every other tick)
            for (int i = 0; i <= numVerticalLines; i += 2) {
              final x = gridLeft + i * lineSpacingPoints;
              final date = today.add(Duration(days: i));
              final dateText = '${date.month}/${date.day}';

              // Save canvas state and rotate for angled text (slant up to the left)
              canvas.saveContext();
              final matrix = Matrix4.identity()
                ..translate(x, gridTop + 4)
                ..rotateZ(math.pi / 4); // 45 degrees
              canvas.setTransform(matrix);

              canvas.drawString(pdfFont, 6, dateText, 0, 0);
              canvas.restoreContext();
            }
          },
        );
      },
    ),
  );

  return pdf;
}
