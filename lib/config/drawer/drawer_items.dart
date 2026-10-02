import 'package:flutter/material.dart';


class DrawerItem {
  final String title;
  final String link;
  final IconData icon;

  const DrawerItem({
    required this.title,
    required this.link,
    required this.icon
  });
}


const appMenuItems = <DrawerItem>[

  DrawerItem(
    title: 'Home', 
    link: '/', 
    icon: Icons.home
  ),

  DrawerItem(
    title: 'Sistema', 
    link: '/system', 
    icon: Icons.analytics
  ),

];