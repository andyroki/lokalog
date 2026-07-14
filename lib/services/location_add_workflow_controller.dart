import 'package:flutter/material.dart';

import '../models/lokalog_models.dart';
import '../widgets/add_location_sheet.dart';
import 'location_geocoding_service.dart';
import 'ui_feedback_service.dart';

typedef DuplicateLocationNameChecker = bool Function(
  String name, {
  int? excludingIndex,
});

class LocationAddWorkflowController {
  static Future<JobSite?> collectLocationFromManualEntry({
    required BuildContext context,
    required List<int> logMinuteOptions,
    required DuplicateLocationNameChecker isDuplicateLocationName,
    required String title,
    required String submitLabel,
    String geocodeProgressMessage = 'Looking up latitude/longitude...',
  }) async {
    AddLocationInput? prefill;
    String? sheetError;

    while (true) {
      final AddLocationInput? result = await _showLocationSheet(
        context: context,
        title: title,
        submitLabel: submitLabel,
        logMinuteOptions: logMinuteOptions,
        initialInput: prefill,
        errorMessage: sheetError,
      );

      if (result == null || !context.mounted) {
        return null;
      }

      if (_hasMissingRequiredFields(result)) {
        prefill = result;
        sheetError = 'Please fill name, street, city, state, and ZIP.';
        continue;
      }

      if (isDuplicateLocationName(result.name)) {
        prefill = result;
        sheetError = 'Location name already exists. Please use a unique name.';
        continue;
      }

      UiFeedbackService.showMessage(context, geocodeProgressMessage);
      final GeocodePoint? point =
          await LocationGeocodingService.lookupCoordinates(result);
      if (!context.mounted) {
        return null;
      }
      UiFeedbackService.hideCurrentMessage(context);

      if (point == null) {
        prefill = result;
        sheetError =
            'Could not find that address. Please correct it and try again.';
        continue;
      }

      return _buildJobSite(result, point);
    }
  }

  static Future<JobSite?> collectLocationFromCurrentFix({
    required BuildContext context,
    required LocationFix fix,
    required List<int> logMinuteOptions,
    required int defaultRequiredMinutes,
    required DuplicateLocationNameChecker isDuplicateLocationName,
  }) async {
    UiFeedbackService.showMessage(context, 'Looking up address from GPS...');

    final AddLocationInput? reversePrefill =
        await LocationGeocodingService.reverseLookupAddress(
      fix,
      defaultRequiredMinutes: defaultRequiredMinutes,
    );
    if (!context.mounted) {
      return null;
    }
    UiFeedbackService.hideCurrentMessage(context);

    AddLocationInput? prefill = reversePrefill ??
        AddLocationInput(
          name: '',
          street: '',
          city: '',
          state: '',
          zip: '',
          requiredMinutes: defaultRequiredMinutes,
        );
    String? sheetError = reversePrefill == null
        ? 'Could not detect full address from GPS. Please enter or correct it.'
        : 'Confirm the address and enter a name.';

    while (true) {
      final AddLocationInput? result = await _showLocationSheet(
        context: context,
        title: 'Add From Current Location',
        submitLabel: 'Add',
        logMinuteOptions: logMinuteOptions,
        initialInput: prefill,
        errorMessage: sheetError,
      );

      if (result == null || !context.mounted) {
        return null;
      }

      if (_hasMissingRequiredFields(result)) {
        prefill = result;
        sheetError = 'Please fill name, street, city, state, and ZIP.';
        continue;
      }

      if (isDuplicateLocationName(result.name)) {
        prefill = result;
        sheetError = 'Location name already exists. Please use a unique name.';
        continue;
      }

      UiFeedbackService.showMessage(context, 'Verifying address coordinates...');
      final GeocodePoint? point =
          await LocationGeocodingService.lookupCoordinates(result);
      if (!context.mounted) {
        return null;
      }
      UiFeedbackService.hideCurrentMessage(context);

      if (point == null) {
        prefill = result;
        sheetError =
            'Could not find that address. Please correct it and try again.';
        continue;
      }

      return _buildJobSite(result, point);
    }
  }

  static Future<JobSite?> collectUpdatedLocation({
    required BuildContext context,
    required JobSite existingSite,
    required int excludingIndex,
    required List<int> logMinuteOptions,
    required DuplicateLocationNameChecker isDuplicateLocationName,
    String geocodeProgressMessage = 'Looking up updated latitude/longitude...',
  }) async {
    AddLocationInput? prefill = AddLocationInput(
      name: existingSite.name,
      street: existingSite.street,
      city: existingSite.city,
      state: existingSite.state,
      zip: existingSite.zip,
      requiredMinutes: existingSite.requiredDwellMinutes,
    );
    String? sheetError;

    while (true) {
      final AddLocationInput? result = await _showLocationSheet(
        context: context,
        title: 'Edit Location',
        submitLabel: 'Save',
        logMinuteOptions: logMinuteOptions,
        initialInput: prefill,
        errorMessage: sheetError,
      );

      if (result == null || !context.mounted) {
        return null;
      }

      if (_hasMissingRequiredFields(result)) {
        prefill = result;
        sheetError = 'Please fill name, street, city, state, and ZIP.';
        continue;
      }

      if (isDuplicateLocationName(result.name, excludingIndex: excludingIndex)) {
        prefill = result;
        sheetError = 'Location name already exists. Please use a unique name.';
        continue;
      }

      UiFeedbackService.showMessage(context, geocodeProgressMessage);
      final GeocodePoint? point =
          await LocationGeocodingService.lookupCoordinates(result);
      if (!context.mounted) {
        return null;
      }
      UiFeedbackService.hideCurrentMessage(context);

      if (point == null) {
        prefill = result;
        sheetError = 'Could not geocode address. Please verify and try again.';
        continue;
      }

      return _buildJobSite(result, point);
    }
  }

  static Future<AddLocationInput?> _showLocationSheet({
    required BuildContext context,
    required String title,
    required String submitLabel,
    required List<int> logMinuteOptions,
    AddLocationInput? initialInput,
    String? errorMessage,
  }) {
    return showModalBottomSheet<AddLocationInput>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return AddLocationSheet(
          title: title,
          submitLabel: submitLabel,
          logMinuteOptions: logMinuteOptions,
          initialInput: initialInput,
          errorMessage: errorMessage,
        );
      },
    );
  }

  static bool _hasMissingRequiredFields(AddLocationInput input) {
    return input.name.trim().isEmpty ||
        input.street.trim().isEmpty ||
        input.city.trim().isEmpty ||
        input.state.trim().isEmpty ||
        input.zip.trim().isEmpty;
  }

  static JobSite _buildJobSite(AddLocationInput input, GeocodePoint point) {
    return JobSite(
      name: input.name.trim(),
      street: input.street,
      city: input.city,
      state: input.state,
      zip: input.zip,
      lat: point.lat,
      lng: point.lng,
      requiredDwellMinutes: input.requiredMinutes,
    );
  }

}
