import 'package:alpha/pages/home.dart';
import 'package:alpha/pages/fingerprint_page.dart';
import 'package:alpha/pages/listen_mic_page.dart';
import 'package:alpha/pages/social_media_report_page.dart';
import 'package:flutter/material.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  final List<Widget> pages = const [
    Home(),
    FingerprintPage(),
    ListenMicPage(),
    SocialMediaReportPage()
  ];
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],

      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.home, color: currentIndex == 0 ? Colors.blue : Colors.grey),
              onPressed: (){
                setState(() {
                  currentIndex=0;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.fingerprint, color: currentIndex == 1 ? Colors.blue : Colors.grey),
              onPressed: (){
                setState(() {
                  currentIndex=1;
                });
              },
            ),
             IconButton(
              icon: Icon(Icons.mic, color: currentIndex == 2 ? Colors.blue : Colors.grey),
              onPressed: (){
                setState(() {
                  currentIndex=2;
                });
              },
            ),
             IconButton( 
              icon: Icon(Icons.assessment, color: currentIndex == 3 ? Colors.blue : Colors.grey),
              onPressed: (){
                setState(() {
                  currentIndex=3;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}