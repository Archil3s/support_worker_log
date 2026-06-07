// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MassageGuideHtml extends StatefulWidget {
  const MassageGuideHtml({super.key});

  @override
  State<MassageGuideHtml> createState() => _MassageGuideHtmlState();
}

class _MassageGuideHtmlState extends State<MassageGuideHtml> {
  static int _nextViewId = 0;

  late final Future<_MassageGuidePayload> _payload = _loadGuide();

  Future<_MassageGuidePayload> _loadGuide() async {
    final html = await rootBundle.loadString(
      'assets/massage/everyday_massage_guide.html',
    );
    final bodyReference = await rootBundle.load(
      'assets/massage/body_reference.png',
    );
    final image = base64Encode(bodyReference.buffer.asUint8List());

    return _MassageGuidePayload(html, 'data:image/png;base64,$image');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _payload.then((payload) => _wrapGuide(payload)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 420,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const Text(
            'Could not load the visual massage guide.',
            style: TextStyle(color: Color(0xFFFFD8D8)),
          );
        }

        final viewType = 'massage-guide-${_nextViewId++}';
        final srcdoc = snapshot.data!;

        ui_web.platformViewRegistry.registerViewFactory(viewType, (_) {
          return html.IFrameElement()
            ..srcdoc = srcdoc
            ..style.border = '0'
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.borderRadius = '16px'
            ..style.backgroundColor = '#151B29'
            ..setAttribute('title', 'Everyday massage visual guide');
        });

        final viewportHeight = MediaQuery.sizeOf(context).height;
        final guideHeight = (viewportHeight * 0.82).clamp(760.0, 980.0);

        return SizedBox(
          height: guideHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: HtmlElementView(viewType: viewType),
          ),
        );
      },
    );
  }

  String _wrapGuide(_MassageGuidePayload payload) {
    final source = payload.html.replaceAll(
      '__BODY_REFERENCE_IMAGE__',
      payload.bodyReferenceSrc,
    );
    final patched = source.replaceFirst('</head>', '''
<style>
  html, body {
    width: 100%;
    min-height: 100%;
    overflow-x: hidden;
  }
  body {
    max-width: none !important;
    padding: 12px 8px 28px !important;
    font-size: 16px;
  }
  svg {
    display: block;
    max-width: 100%;
    height: auto;
  }
  .body-reference-map svg {
    width: 100% !important;
    height: 100% !important;
  }
  .panel {
    overflow-x: hidden;
  }
  .panel > svg {
    width: 100% !important;
    max-width: 100% !important;
    margin: 12px auto 14px;
  }
  .page-header {
    display: none;
  }
  .partner-note,
  .frame-note,
  .motion-legend-wrap,
  .body-map-note {
    display: none;
  }
  .tab,
  .style-btn,
  .coach-btn,
  .tool-chip {
    min-height: 42px;
    font-size: 14px !important;
    white-space: nowrap;
  }
  .body-map-note,
  .coach-instruction,
  .step-desc {
    font-size: 15px !important;
    line-height: 1.55 !important;
  }
  .coach-title,
  .step-title {
    font-size: 17px !important;
  }
  .coach-hint,
  .style-current,
  .style-note,
  .step-feel {
    font-size: 13px !important;
    line-height: 1.45 !important;
  }
  .coach-main,
  .style-panel,
  .body-map-note,
  .step-card,
  .warn,
  .info-warn {
    padding: 12px !important;
  }
  .coach-controls {
    padding: 10px 12px 12px !important;
  }
  .motion-guide {
    padding: 10px !important;
  }
  .mg-body {
    align-items: flex-start !important;
  }
  .mg-visual {
    width: 76px !important;
    min-width: 76px !important;
  }
  @media (max-width: 420px) {
    body {
      padding: 8px 6px 24px !important;
    }
    .panel > svg {
      width: 100% !important;
    }
    .style-buttons,
    .coach-controls {
      gap: 7px !important;
    }
    .style-btn,
    .coach-btn {
      padding-left: 10px !important;
      padding-right: 10px !important;
    }
  }
</style>
</head>''');

    return patched;
  }
}

class _MassageGuidePayload {
  const _MassageGuidePayload(this.html, this.bodyReferenceSrc);

  final String html;
  final String bodyReferenceSrc;
}
