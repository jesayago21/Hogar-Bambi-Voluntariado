import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:voluntariado_desktop_app/config/drawer/drawer_items.dart';


class MainDrawer extends StatelessWidget {
  const MainDrawer({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            child: Align(
            alignment: Alignment.bottomCenter, // Alinea el texto al fondo izquierdo
            child: Text(
              'Navigacion',
              style: TextStyle(
                color: Colors.black26,
                fontSize: 24,
              ),
            ),
          ),
          ),
          
          Center(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: appMenuItems.length,
                itemBuilder: (context, index) {
                  final menuItem = appMenuItems[index];

                  return _CustomListTile(menuItem: menuItem);
                },
              ),
            ),
        ],
      ),
    ); 
  }
}

class _CustomListTile extends StatelessWidget {
  const _CustomListTile({
    required this.menuItem,
  });

  final DrawerItem menuItem;

  @override
  Widget build(BuildContext context) {

    final colors = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: Icon( menuItem.icon, color: colors.primary ),
      trailing: Icon( Icons.arrow_forward_ios_rounded, color:colors.primary ),
      title: Text(menuItem.title),

      onTap: () {
        if (menuItem.link != '/') {
          context.go(menuItem.link);
        }
      },
    );
  }
}