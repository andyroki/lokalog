import 'package:flutter/material.dart';

import '../models/lokalog_models.dart';

class LocationsScreenView extends StatelessWidget {
  const LocationsScreenView({
    super.key,
    required this.sites,
    required this.onResetAllSites,
    required this.onEditLocation,
    required this.onDeleteLocation,
  });

  final List<JobSite> sites;
  final VoidCallback onResetAllSites;
  final void Function(int index, JobSite site) onEditLocation;
  final void Function(int index, JobSite site) onDeleteLocation;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Locations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: onResetAllSites,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (sites.isEmpty)
          const Text('No locations added yet.')
        else
          ...sites.asMap().entries.map((MapEntry<int, JobSite> entry) {
            final JobSite site = entry.value;
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${entry.key + 1}')),
                title: Text(site.name),
                subtitle: Text(
                  '${site.address}\n'
                  'Lat: ${site.lat.toStringAsFixed(5)}, Lng: ${site.lng.toStringAsFixed(5)}\n'
                  'Log after: ${site.requiredDwellMinutes} minutes',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (String action) {
                    if (action == 'edit') {
                      onEditLocation(entry.key, site);
                    } else if (action == 'delete') {
                      onDeleteLocation(entry.key, site);
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
