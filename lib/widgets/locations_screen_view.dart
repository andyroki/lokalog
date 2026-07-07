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
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Locations',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'No locations added yet.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          ...sites.asMap().entries.map((MapEntry<int, JobSite> entry) {
            final JobSite site = entry.value;
            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
                    child: Text(
                      '${entry.key + 1}',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    site.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${site.address}\n'
                      'Lat: ${site.lat.toStringAsFixed(5)}, Lng: ${site.lng.toStringAsFixed(5)}\n'
                      'Log after: ${site.requiredDwellMinutes} minutes',
                    ),
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
              ),
            );
          }),
      ],
    );
  }
}
