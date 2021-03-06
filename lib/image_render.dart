import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_html/html_parser.dart';
import 'package:flutter_html/src/utils.dart' as utils;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:html/dom.dart' as dom;

typedef ImageSourceMatcher = bool Function(
  Map<String, String> attributes,
  dom.Element? element,
);

final _dataUriFormat = RegExp("^(?<scheme>data):(?<mime>image\/[\\w\+\-\.]+)(?<encoding>;base64)?\,(?<data>.*)");

ImageSourceMatcher dataUriMatcher({String? encoding = 'base64', String? mime}) => (attributes, element) {
      if (_src(attributes) == null) return false;
      final dataUri = _dataUriFormat.firstMatch(_src(attributes)!);
      return dataUri != null &&
          (mime == null || dataUri.namedGroup('mime') == mime) &&
          (encoding == null || dataUri.namedGroup('encoding') == ';$encoding');
    };

ImageSourceMatcher networkSourceMatcher({
  List<String> schemas: const ["https", "http"],
  List<String>? domains,
  String? extension,
}) =>
    (attributes, element) {
      if (_src(attributes) == null) return false;
      try {
        final src = Uri.parse(_src(attributes)!);
        return schemas.contains(src.scheme) &&
            (domains == null || domains.contains(src.host)) &&
            (extension == null || src.path.endsWith(".$extension"));
      } catch (e) {
        return false;
      }
    };

ImageSourceMatcher assetUriMatcher() =>
    (attributes, element) => _src(attributes) != null && _src(attributes)!.startsWith("asset:");

typedef ImageRender = Widget? Function(
  RenderContext context,
  Map<String, String> attributes,
  dom.Element? element,
  BaseCacheManager? cacheManager,
);

ImageRender base64ImageRender() => (context, attributes, element, cacheManager) {
      final decodedImage = base64.decode(_src(attributes)!.split("base64,")[1].trim());
      precacheImage(
        MemoryImage(decodedImage),
        context.buildContext,
        onError: (exception, StackTrace? stackTrace) {
          context.parser.onImageError?.call(exception, stackTrace);
        },
      );
      return Image.memory(
        decodedImage,
        fit: BoxFit.scaleDown,
        frameBuilder: (ctx, child, frame, _) {
          if (frame == null) {
            return Text(_alt(attributes) ?? "", style: context.style.generateTextStyle());
          }
          return child;
        },
      );
    };

ImageRender assetImageRender({
  double? width,
  double? height,
}) =>
    (context, attributes, element, cacheManager) {
      final assetPath = _src(attributes)!.replaceFirst('asset:', '');
      if (_src(attributes)!.endsWith(".svg")) {
        return SvgPicture.asset(assetPath);
      } else {
        return Image.asset(
          assetPath,
          fit: BoxFit.scaleDown,
          width: width ?? _width(attributes),
          height: height ?? _height(attributes),
          frameBuilder: (ctx, child, frame, _) {
            if (frame == null) {
              return Text(_alt(attributes) ?? "", style: context.style.generateTextStyle());
            }
            return child;
          },
        );
      }
    };

ImageRender networkImageRender({
  Map<String, String>? headers,
  String Function(String?)? mapUrl,
  double? width,
  double? height,
  Widget Function(String?)? altWidget,
  Widget Function()? loadingWidget,
}) =>
    (context, attributes, element, cacheManager) {
      final src = mapUrl?.call(_src(attributes)) ?? _src(attributes)!;
      precacheImage(
        NetworkImage(
          src,
          headers: headers,
        ),
        context.buildContext,
        onError: (exception, StackTrace? stackTrace) {
          context.parser.onImageError?.call(exception, stackTrace);
        },
      );
      Completer<Size> completer = Completer();
      Image image = Image(
        image: CachedNetworkImageProvider(src, cacheManager: cacheManager, headers: headers),
        filterQuality: FilterQuality.low,
        frameBuilder: (ctx, child, frame, _) {
          if (frame == null) {
            if (!completer.isCompleted) {
              completer.completeError("error");
            }
            return child;
          } else {
            return child;
          }
        },
      );

      image.image.resolve(ImageConfiguration()).addListener(
            ImageStreamListener((ImageInfo image, bool synchronousCall) {
              var myImage = image.image;
              Size size = Size(myImage.width.toDouble(), myImage.height.toDouble());
              if (!completer.isCompleted) {
                completer.complete(size);
              }
            }, onError: (object, stacktrace) {
              if (!completer.isCompleted) {
                completer.completeError(object);
              }
            }),
          );

      return FutureBuilder<Size>(
        future: completer.future,
        builder: (BuildContext buildContext, AsyncSnapshot<Size> snapshot) {
          if (snapshot.hasData) {
            final w = width ?? _width(attributes) ?? snapshot.data!.width;
            final h = height ?? _height(attributes) ?? snapshot.data!.height;
            final size = utils.calcSize(buildContext, w, h, snapshot.data!.aspectRatio);

            return Image(
              image: CachedNetworkImageProvider(src, cacheManager: cacheManager, headers: headers),
              filterQuality: FilterQuality.low,
              fit: BoxFit.scaleDown,
              width: size.width,
              height: size.height,
              frameBuilder: (ctx, child, frame, _) {
                if (frame == null) {
                  return altWidget?.call(_alt(attributes)) ??
                      Text(_alt(attributes) ?? "", style: context.style.generateTextStyle());
                }
                return child;
              },
            );
          } else if (snapshot.hasError) {
            return altWidget?.call(_alt(attributes)) ??
                Text(_alt(attributes) ?? "", style: context.style.generateTextStyle());
          } else {
            return loadingWidget?.call() ?? const SizedBox();
          }
        },
      );
    };

ImageRender svgDataImageRender() => (context, attributes, element, cacheManager) {
      final dataUri = _dataUriFormat.firstMatch(_src(attributes)!);
      final data = dataUri?.namedGroup('data');
      if (data == null) return null;
      if (dataUri?.namedGroup('encoding') == ';base64') {
        final decodedImage = base64.decode(data.trim());
        return SvgPicture.memory(
          decodedImage,
          fit: BoxFit.contain,
          width: _width(attributes),
          height: _height(attributes),
        );
      }
      return SvgPicture.string(Uri.decodeFull(data));
    };

ImageRender svgNetworkImageRender() => (context, attributes, element, cacheManager) {
      return SvgPicture.network(
        attributes["src"]!,
        fit: BoxFit.contain,
        width: _width(attributes),
        height: _height(attributes),
      );
    };

final Map<ImageSourceMatcher, ImageRender> defaultImageRenders = {
  dataUriMatcher(mime: 'image/svg+xml', encoding: null): svgDataImageRender(),
  dataUriMatcher(): base64ImageRender(),
  assetUriMatcher(): assetImageRender(),
  networkSourceMatcher(extension: "svg"): svgNetworkImageRender(),
  networkSourceMatcher(): networkImageRender(),
};

String? _src(Map<String, String> attributes) {
  return attributes["src"];
}

String? _alt(Map<String, String> attributes) {
  return attributes["alt"];
}

double? _height(Map<String, String> attributes) {
  final heightString = attributes["height"];
  return heightString == null ? heightString as double? : double.tryParse(heightString);
}

double? _width(Map<String, String> attributes) {
  final widthString = attributes["width"];
  return widthString == null ? widthString as double? : double.tryParse(widthString);
}
