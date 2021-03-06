import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/src/html_elements.dart';
import 'package:flutter_youtube_view/flutter_youtube_view.dart';

class AndroidYoutubePlayerScreen extends StatefulWidget {
  final String title;
  final String url;
  final Function? onOpenYoutubeAppClicked;

  AndroidYoutubePlayerScreen(
    this.title,
    this.url, {
    this.onOpenYoutubeAppClicked,
  });

  @override
  _AndroidYoutubePlayerScreenState createState() => _AndroidYoutubePlayerScreenState();
}

class _AndroidYoutubePlayerScreenState extends State<AndroidYoutubePlayerScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var youtubeId = YoutubeVideoContentElement.getYoutubeId(widget.url);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title ?? ''),
        actions: [
          IconButton(
            onPressed: () {
              if (widget.onOpenYoutubeAppClicked != null) {
                widget.onOpenYoutubeAppClicked!();
                Navigator.of(context).maybePop();
              }
            },
            icon: Icon(
              Icons.shop_two,
              size: 18,
              color: Colors.white,
            ),
          )
        ],
      ),
      body: FlutterYoutubeView(
        scaleMode: YoutubeScaleMode.fitWidth, // <option> fitWidth, fitHeight
        params: YoutubeParam(
          videoId: youtubeId!,
          showUI: true,
          startSeconds: 0.0, // <option>
          autoPlay: false,
        ), // <option>
      ),
    );
  }
}
